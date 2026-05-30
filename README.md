# MTProxy Pool

[powered by https://2vpn.site | https://t.me/to2vpnbot]

Установка Telegram MTProxy на сервер одной командой. Управление несколькими прокси-ссылками через `mtproxy-pool`.

Работает на Ubuntu/Debian

Для обхода ТСПУ, ставить прокси только на российских серврах

## Быстрый старт

```bash
git clone https://github.com/2vpn/tg.git && cd tg && sudo bash install.sh
```

После установки получить ссылки:

```bash
sudo mtproxy-pool links
```

Открой ссылку в Telegram — прокси добавится автоматически.

---

## Установка с параметрами

```bash
# Создать 5 прокси с конкретным SNI-доменом
sudo env COUNT=5 SNI_DOMAIN=google.com bash install.sh

# Указать IP вручную (если сервер за NAT)
sudo env COUNT=3 PUBLIC_IP=1.2.3.4 bash install.sh
```

---

## Команды

| Команда | Что делает |
|---|---|
| `sudo mtproxy-pool list` | Показать все инстансы и их статус |
| `sudo mtproxy-pool links` | Получить ссылки для Telegram |
| `sudo mtproxy-pool links --host 1.2.3.4` | Ссылки с конкретным IP или доменом |
| `sudo mtproxy-pool add --count 2` | Добавить 2 новых прокси |
| `sudo mtproxy-pool add --count 1 --sni google.com` | Добавить с конкретным SNI |
| `sudo mtproxy-pool add --count 1 --tag TAG` | Добавить с Telegram promotion tag |
| `sudo mtproxy-pool remove INSTANCE` | Удалить инстанс |
| `sudo mtproxy-pool restart` | Перезапустить все инстансы |
| `sudo mtproxy-pool status` | Статус всех инстансов |
| `sudo mtproxy-pool refresh` | Обновить конфиги Telegram вручную |
| `sudo mtproxy-pool doctor` | Диагностика — проверить что всё работает |
| `sudo mtproxy-pool uninstall` | Полностью удалить MTProxy с сервера |

---

## Переменные окружения

| Переменная | По умолчанию | Описание |
|---|---|---|
| `COUNT` | `1` | Сколько прокси создать при установке |
| `SNI_DOMAIN` | `yandex.ru` | Домен для fake-TLS секрета |
| `PUBLIC_IP` | авто | IP или домен в ссылках (если сервер за NAT) |
| `PROXY_TAG` | — | Telegram promotion tag |

---

## Файлы на сервере

| Путь | Что |
|---|---|
| `/opt/MTProxy` | Исходник и бинарник MTProxy |
| `/etc/mtproxy-pool/instances/*.env` | Настройки каждого прокси |
| `/usr/local/bin/mtproxy-pool` | CLI-команда |
| `/usr/local/bin/mtproxy-instance-run.sh` | Runner для systemd |
| `/etc/systemd/system/mtproxy@.service` | Systemd-шаблон |
| `/etc/systemd/system/mtproxy-pool-refresh.timer` | Автообновление конфигов каждые 6 часов |

---

## Безопасность

Скрипты запускаются от `root` — они ставят пакеты, пишут systemd unit-файлы и управляют сервисами. Секреты инстансов хранятся в `/etc/mtproxy-pool/instances` с правами `600`.

