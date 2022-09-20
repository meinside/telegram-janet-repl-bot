# telegram-janet-repl-bot

A Telegram Bot which works as a Janet REPL.

<img width="569" alt="screenshot" src="https://user-images.githubusercontent.com/185988/191209382-d77e0ff3-db08-4b7d-bad4-0fa1952da03e.png">

It will evaluate your messages and send the results back as replies.

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
ProtectHome=read-only
ProtectSystem=strict
PrivateTmp=yes
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

## Note

Following functions/macros are overridden for use in Telegram:

- `doc`: will reply with the resulting document.
- `print`, `printf`: will send results to each chat, instead of stdout.

## Warning

This bot accepts messages only from allowed telegram usernames,

but is not free from bad messages, (eg. infinite loops, malicious shell commands, etc.)

so be careful not to blow up your servers :-)

