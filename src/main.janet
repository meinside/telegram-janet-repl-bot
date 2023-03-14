# src/main.janet
#
# created on : 2022.09.19.
# last update: 2022.12.20.

(import telegram-bot-janet :as tg)
(import spork/json)

# constants
(def- command-start "/start")
(def- command-help "/help")
(def- description-help ``Print a help message of this bot.``)
(def- commands [{:command command-help
                 :description description-help}])

# edited `eval-string` example from: https://janetdocs.com/run-context
(defn- eval-str
  ``Evaluates given string, and returns the result as string.
  ``
  [str]
  (var state (string str))
  (defn chunks [buf _]
    (def ret state)
    (set state nil)
    (when ret
      (buffer/push-string buf str)
      (buffer/push-string buf "\n")))
  (var returnval nil)
  (run-context {:env root-env
                :chunks chunks
                :on-compile-error (fn compile-error [msg errf &]
                                    (error (string "compile error: " msg)))
                :on-parse-error (fn parse-error [p x]
                                  (error (string "parse error: " (:error p))))
                :fiber-flags :i
                :on-status (fn on-status [f val]
                             (if-not (= (fiber/status f) :dead)
                               (error val))
                             (set returnval val))
                :source :eval-str})

  #(pp returnval)

  (cond
    (nil? returnval) "nil"
    (function? returnval) (string returnval)
    (number? returnval) (string returnval)
    (boolean? returnval) (string returnval)
    (empty? returnval) "<empty>"
    # else
    (string/replace-all "\\n" "\n"
                        (string/format "%m" returnval))))

(defn- help-message
  ``Returns the help message of this bot.
  ``
  []
  ``This bot replies to your messages with strings evaluated by Janet language.

  Some functions were overridden for using in Telegram.

  https://github.com/meinside/telegram-janet-repl-bot
  ``)

(defn- run-bot
  ``Runs bot with given parameters.
  ``
  [token interval-seconds allowed-telegram-usernames verbose?]

  # bot
  (var bot (tg/new-bot token
                       :interval-seconds interval-seconds
                       :verbose? verbose?))
  (setdyn :bot bot) # for using in overridden functions

  # active chat ids
  (var chats @{})
  (setdyn :chats chats) # for using in overridden functions

  # print bot information
  (if-let [me (:get-me bot)
           first-name (get-in me [:result :first-name])
           username (get-in me [:result :username])]
    (do
      (print (string/format "starting bot: %s (@%s)... " first-name username)))
    (do
      (print "cannot get bot information, exiting...")
      (os/exit 1)))

  # overridden functions
  #
  # override `doc` macro to return string (original one returns nil)
  (eval-string ``(defmacro- doc
                   "Returns the docstring of given symbol as a string. (Overridden for this bot.)"
                   [sym]
                   ~(get (dyn ',sym) :doc))
               ``)
  # override `print` and `printf` functions to return string, not to print to stdio
  (eval-string ``(defn- print
                   "Sends given parameters to each chat as a string. (Overridden for this bot.)"
                   [& xs]
                   (var buf @"")
                   (xprint buf ;xs)
                   (if-let [bot (dyn :bot)
                            chats (dyn :chats)]
                     (ev/spawn-thread
                       (loop [(chat-id _) :in (pairs chats)]
                         (:send-message bot chat-id buf))))
                   nil)
               ``)
  (eval-string ``(defn- printf
                   "Sends a formatted string with given parameters to each chat. (Overridden for this bot.)"
                   [fmt & xs]
                   (var buf @"")
                   (xprintf buf fmt ;xs)
                   (if-let [bot (dyn :bot)
                            chats (dyn :chats)]
                     (ev/spawn-thread
                       (loop [(chat-id _) :in (pairs chats)]
                         (:send-message bot chat-id buf))))
                   nil)
               ``)

  # set bot commands
  (:set-my-commands bot commands)

  # delete webhook before polling updates
  (:delete-webhook bot)

  # start polling updates
  (let [updates-ch (:poll-updates bot interval-seconds)]
    (ev/do-thread
      (forever
        (if-let [updates (ev/take updates-ch)]
          # fetch updates from updates channel,
          (if-not (empty? updates)
            (loop [update :in updates]
              (let [message (or (get-in update [:message])
                                (get-in update [:edited-message]))
                    username (get-in message [:from :username])
                    allowed? (index-of username allowed-telegram-usernames)]
                (if allowed?
                  (do
                      (if-let [chat-id (get-in message [:chat :id])
                               text (get-in message [:text])
                               original-message-id (get-in message [:message-id])]
                        (if-not (string/has-prefix? "/" text)
                          # handle non-command messages
                          (do
                            # 'typing...'
                            (ev/spawn-thread
                              (:send-chat-action bot chat-id :typing))

                            # save active chat id
                            (put chats chat-id true)

                            # evaluate and send response
                            (try
                              (do
                                (let [evaluated (eval-str text)
                                      response (:send-message bot chat-id evaluated :reply-to-message-id original-message-id)]
                                  (if-not (response :ok)
                                    (print (string/format "failed to send evaluated string: %m" response)))))
                              ([err] (do
                                       (let [err (string err)
                                             response (:send-message bot chat-id err :reply-to-message-id original-message-id)]
                                         (if-not (response :ok)
                                           (print (string/format "failed to send error message: %m" response))))))))
                          # handle telegram commands
                          (do
                            (cond
                              (or (= text command-start)
                                  (= text command-help))
                              (do
                                (:send-message bot chat-id (help-message)))

                              # else
                              (do
                                (:send-message bot chat-id (string/format "no such command: %s" text) :reply-to-message-id original-message-id)))))))
                  (do
                    # remove chat id
                    (if-let [chat-id (get-in message [:chat :id])]
                      (put chats chat-id nil))

                    (print (string/format "telegram username: %s not allowed" username)))))))
          # or break when fetching fails
          (do
            (print "failed to take from updates channel")
            (break))))))

  (print "stopping the bot..."))

(defn- print-usage
  ``Prints usage of this application.
  ``
  [prog-name]
  (print (string/format "Usage:\n\n$ %s [config-file-path]" prog-name)))

(defn main [& args]
  (if (< (length args) 2)
    (print-usage (first args))
    (try
      (with [f (file/open (args 1) :r)]
        (let [config (file/read f :all)
              parsed (json/decode config)
              token (or (parsed "token") "--token-not-provided--")
              interval-seconds (or (parsed "interval_seconds") 1)
              allowed-telegram-usernames (or (parsed "allowed_telegram_usernames") [])
              verbose? (or (parsed "is_verbose") false)]
          (run-bot token interval-seconds allowed-telegram-usernames verbose?)))
      ([err] (do
               (print err)
               (os/exit 1))))))

