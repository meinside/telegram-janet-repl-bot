(declare-project
  :name "telegram-janet-repl-bot"
  :description ```A 'Janet REPL' Telegram Bot ```
  :version "0.0.7"
  :dependencies ["https://github.com/meinside/telegram-bot-janet"
                 "https://github.com/janet-lang/spork"])

(declare-executable
  :name "repl-bot"
  :entry "src/main.janet")
