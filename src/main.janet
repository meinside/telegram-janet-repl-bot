# src/main.janet
#
# created on : 2022.09.19.
# last update: 2022.09.20.

(import telegram-bot-janet :as tg)
(import spork/json)

# Edited `eval-string` example from: https://janetdocs.com/run-context
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

  (cond
    (nil? returnval) "nil"
    (function? returnval) (string returnval)
    (number? returnval) (string returnval)
    (empty? returnval) "<empty>"
    # else
    (string/replace-all "\\n" "\n"
                        (string/format "%m" returnval))))

(defn- run-bot
  ``Runs bot with given parameters.
  ``
  [token interval-seconds allowed-telegram-usernames verbose?]

  (var bot (tg/new-bot token
                       :interval-seconds interval-seconds
                       :verbose? verbose?))

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
  # override `doc` function to return string (original one returns nil)
  (eval-string ``(defn- doc
                   "Returns the docstring of given symbol as a string. (Overrided for this bot.)"
                   [sym]
                   (get (dyn sym) :doc))
               ``)
  # override `print` and `printf` functions to return string, not to print to stdio
  (eval-string ``(defn- print
                   "Returns given parameters as a string. (Overrided for this bot.)"
                   [& xs]
                   (var buf @"")
                   (xprint buf ;xs)
                   buf)
               ``)
  (eval-string ``(defn- printf
                   "Returns a formatted string with given parameters. (Overrided for this bot.)"
                   [fmt & xs]
                   (var buf @"")
                   (xprintf buf fmt ;xs)
                   buf)
               ``)

  # delete webhook before polling updates
  (:delete-webhook bot)

  # start polling updates
  (let [updates-ch (:poll-updates bot interval-seconds)]
    (ev/do-thread
      (forever
        (if-let [updates (ev/take updates-ch)]
          # fetch updates from updates channel,
          (do
            (if-not (empty? updates)
              (loop [update :in updates]
                (let [username (get-in update [:message :from :username])
                      allowed? (index-of username allowed-telegram-usernames)]
                  (if allowed?
                    (do
                        (if-let [chat-id (get-in update [:message :chat :id])
                                 text (get-in update [:message :text])
                                 original-message-id (get-in update [:message :message-id])]
                          # skip telegram commands
                          (if-not (string/has-prefix? "/" text)
                            (do
                              # 'typing...'
                              (ev/spawn-thread
                                (:send-chat-action bot chat-id :typing))

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
                                             (print (string/format "failed to send error message: %m" response)))))))))))
                    (do
                      (print (string/format "telegram username: %s not allowed" username))))))))
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

