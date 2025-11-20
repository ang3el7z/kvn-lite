telegram bot to manage servers (inside the bot)

- VLESS (Reality OR Websocket)
- AdguardHome
- WARP
- automatic ssl

---
environment: ubuntu 22.04/24.04, debian 11/12

## Install:

```shell
wget -O- https://raw.githubusercontent.com/ang3el7z/kvn-lite/master/scripts/init.sh | sh -s YOUR_TELEGRAM_BOT_KEY master
```
#### Restart:
```shell
make r
```

> **Примечание:** Автозапуск при перезагрузке сервера настраивается автоматически при установке через скрипт `init.sh`
