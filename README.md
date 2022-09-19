# telegram-janet-repl-bot

A Telegram Bot which works as a Janet REPL bot.

## How to configure

Build,

```bash
$ git clone https://github.com/meinside/telegram-janet-repl-bot.git
$ cd telegram-janet-repl-bot
$ jpm deps
$ jpm build
```

then create a config file:

```bash
$ cp config.json.sample config.json
```

and edit it:

```json
{
  "token": "your:telegram-bot-token-here",
  "interval_seconds": 1,
  "allowed_telegram_usernames": ["allowed_telegram_username1", "allowed_telegram_username2"],
  "is_verbose": false
}
```

Now run with:

```bash
$ build/repl-bot config.json
```

## How to run as a service

### Linux/Systemd

Create a systemd service file:

```bash
$ vi /lib/systemd/system/telegram-janet-repl-bot.service
```

and fill it with:

```
[Unit]
Description=Telegram Janet REPL Bot
After=syslog.target
After=network.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=/dir/to/telegram-janet-repl-bot
ExecStart=/path/to/build/repl-bot /path/to/config.json
Restart=always
RestartSec=5
MemoryLimit=100M

#StandardOutput=file:/home/ubuntu/tmp/output.log
#StandardError=file:/home/ubuntu/tmp/error.log

[Install]
WantedBy=multi-user.target
```

then make it autostart on reboots:

```bash
$ sudo systemctl enable telegram-janet-repl-bot.service
```

and start/stop it:

```bash
$ sudo systemctl start telegram-janet-repl-bot
$ sudo systemctl restart telegram-janet-repl-bot
$ sudo systemctl stop telegram-janet-repl-bot
```

