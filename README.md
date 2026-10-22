# Aspia Server в Docker

[![Publish images](https://github.com/SinitsaDA/aspia-server-docker/actions/workflows/publish.yml/badge.svg)](https://github.com/SinitsaDA/aspia-server-docker/actions/workflows/publish.yml)
[![Image](https://img.shields.io/badge/ghcr.io-aspia--server-blue?logo=docker)](https://github.com/SinitsaDA/aspia-server-docker/pkgs/container/aspia-server)

**Русский** | [English](README.en.md)

[Aspia](https://aspia.org) — система удалённого доступа с открытым исходным кодом. Этот проект запускает её серверную часть, **Router** и **Relay**, в одном Docker-контейнере и умеет **сам держать её в актуальной версии**.

> Это неофициальный проект. Aspia разрабатывает [Дмитрий Чапышев](https://github.com/dchapyshev/aspia). Здесь только упаковка в Docker.

```
ghcr.io/sinitsada/aspia-server:latest
```

## Возможности

- **Router + Relay в одном контейнере.** Готовый образ для каждой версии Aspia: `3.0.18`, `3.0`, `3`, `latest`.
- **Универсальный образ.** Работает в Docker Compose, через обычный `docker run`, в Portainer, на Synology и других NAS. Подходит как сеть хоста, так и обычная сеть Docker с пробросом портов.
- **Автообновление с откатом.** Контейнер `aspia-updater` каждую ночь проверяет релизы Aspia. Найдя новую версию, он:
  1. делает бэкап данных;
  2. ставит новую версию;
  3. если она не заработала, **сам возвращает прежнюю**.
- **Проверка здоровья.** Docker показывает статус `healthy`, когда Router принимает подключения, а Relay подключён к Router.
- **Миграция с Aspia 2.x.** Конфигурация и база 2.x переносятся автоматически при первом запуске, в том числе с образа [`paprikkafox/aspia-server`](https://hub.docker.com/r/paprikkafox/aspia-server).
- **`EXTERNAL_IP=auto`.** Внешний IP определяется сам, удобно при динамическом IP.
- **Проверенные образы.** GitHub Actions собирает образ в течение 6 часов после релиза Aspia и перед публикацией проверяет его запуском. Раз в неделю образ пересобирается с обновлениями безопасности Debian.

## Содержание

- [Что нужно](#что-нужно)
- [Установка](#установка)
  - [Способ 1. Docker Compose с автообновлением (рекомендуется)](#способ-1-docker-compose-с-автообновлением-рекомендуется)
  - [Способ 2. Synology NAS](docs/synology.md)
  - [ARM и MikroTik (контейнер на роутере)](docs/mikrotik-container.md)
  - [Способ 3. Просто Docker (docker run, Portainer)](#способ-3-просто-docker-docker-run-portainer)
- [Первый вход и ключ для хостов](#первый-вход-и-ключ-для-хостов)
- [Порты и проброс на роутере](#порты-и-проброс-на-роутере)
- [Обновление](#обновление)
- [Переход с Aspia 2.x](#переход-с-aspia-2x)
- [Настройки (.env)](#настройки-env)
- [Бэкапы и восстановление](#бэкапы-и-восстановление)
- [Устранение неполадок](#устранение-неполадок)
- [Локальная сборка](#локальная-сборка)
- [Как это устроено](#как-это-устроено)

## Что нужно

- Сервер или ВМ с Linux на **x86_64** (Intel/AMD). Aspia выпускает серверные пакеты только под эту архитектуру: на ARM (Raspberry Pi, часть NAS) образ не запустится. Для ARM есть отдельные образы, в том числе для контейнера прямо на роутере MikroTik: [docs/mikrotik-container.md](docs/mikrotik-container.md).
- Docker 24 или новее.
- Внешний («белый») IP-адрес или проброс портов на этот сервер, см. [Порты](#порты-и-проброс-на-роутере).
- Около 1 ГБ свободного места.

## Установка

| Способ | Кому подходит | Обновление |
|---|---|---|
| [1. Docker Compose с автообновлением](#способ-1-docker-compose-с-автообновлением-рекомендуется) | Linux-сервер или ВМ | автоматически, с бэкапом и откатом |
| [2. Synology NAS](docs/synology.md) | Synology с Container Manager | автоматически, с бэкапом и откатом |
| [ARM и MikroTik](docs/mikrotik-container.md) | Raspberry Pi, ARM-NAS, контейнер на роутере MikroTik | автоматически внутри контейнера, с бэкапом и откатом |
| [3. Просто Docker](#способ-3-просто-docker-docker-run-portainer) | любая ВМ, Portainer, Unraid, TrueNAS и т.п. | вручную одной командой или через Watchtower |

### Способ 1. Docker Compose с автообновлением (рекомендуется)

Запускаются два контейнера:
- `aspia-server` — сам сервер;
- `aspia-updater` — автообновление.

**1. Скачайте файлы проекта:**

```bash
sudo mkdir -p /opt/aspia && cd /opt/aspia
sudo curl -fsSLO https://raw.githubusercontent.com/SinitsaDA/aspia-server-docker/main/compose.yaml
sudo curl -fsSL -o .env https://raw.githubusercontent.com/SinitsaDA/aspia-server-docker/main/.env.example
```

**2. Отредактируйте `.env`** (`sudo nano .env`). Обязательны три параметра:

```ini
EXTERNAL_IP=203.0.113.10   # внешний IP сервера или auto
ASPIA_DIR=/opt/aspia       # путь к этой папке, должен совпадать с реальным
TZ=Europe/Moscow           # часовой пояс
```

Остальное можно не трогать, см. [Настройки](#настройки-env).

Если переходите с Aspia 2.x, сейчас положите старые данные в `data/`, см. [Переход с Aspia 2.x](#переход-с-aspia-2x).

**3. Запустите:**

```bash
sudo docker compose up -d
```

**4. Проверьте:** через минуту `aspia-server` должен быть в статусе `healthy`.

```bash
sudo docker compose ps
sudo docker logs aspia-server
```

Дальше переходите к [первому входу](#первый-вход-и-ключ-для-хостов) и [пробросу портов](#порты-и-проброс-на-роутере).

### Способ 3. Просто Docker (docker run, Portainer)

Один контейнер без автообновления. Подходит, если у вас своя система управления контейнерами.

```bash
docker run -d --name aspia-server --restart unless-stopped \
  -p 8060-8062:8060-8062 -p 8065:8065/udp -p 8070:8070 \
  -e EXTERNAL_IP=auto \
  -e TZ=Europe/Moscow \
  -v aspia-config:/etc/aspia \
  -v aspia-data:/var/lib/aspia \
  -v aspia-logs:/var/log/aspia \
  ghcr.io/sinitsada/aspia-server:latest
```

Главные правила:
- **Порты публикуются без изменений** (`8062:8062`, а не `9062:8062`): Relay сообщает клиентам свой порт, и с другим внешним портом соединения не заработают.
- **Данные храните в томах.** Три тома `-v`: конфигурация и ключи, база, логи. Без них при пересоздании контейнера создастся новая конфигурация с новыми ключами, и хосты придётся перенастраивать.
- **Вместо проброса портов можно `--network host`.** Тогда опции `-p` не нужны.
- **Для Portainer (Stacks) и других систем с compose-файлами:**

  ```yaml
  services:
    aspia-server:
      image: ghcr.io/sinitsada/aspia-server:latest
      container_name: aspia-server
      restart: unless-stopped
      ports:
        - "8060-8062:8060-8062"
        - "8065:8065/udp"
        - "8070:8070"
      environment:
        EXTERNAL_IP: auto
        TZ: Europe/Moscow
      volumes:
        - aspia-config:/etc/aspia
        - aspia-data:/var/lib/aspia
        - aspia-logs:/var/log/aspia
  volumes:
    aspia-config:
    aspia-data:
    aspia-logs:
  ```

- **Данные 2.x или папка на диске вместо томов.** Замените тома на папки, например `-v /srv/aspia/config:/etc/aspia -v /srv/aspia/database:/var/lib/aspia -v /srv/aspia/logs:/var/log/aspia`. Файлы 2.x положите туда до первого запуска, см. [Переход с Aspia 2.x](#переход-с-aspia-2x).

Обновление при этом способе описано в разделе [Обновление](#способ-3-просто-docker).

## Первый вход и ключ для хостов

При первом запуске без данных создаётся новая конфигурация и пользователь **admin** с паролем **admin**. Ключ и порты выводятся в журнал контейнера:

```bash
docker logs aspia-server
```

```
User name: admin
Password: admin
...
------------------------------------------------------------------------
 External IP (relay):  203.0.113.10
 Public key for hosts: 2ae2eccd180e552f27803de6bdca1a95bcd74ae33e0db9162739fbfdc0e8117c
 Ports: 8060/tcp hosts 2.x, 8061/tcp hosts 3.x, 8062/tcp consoles,
        8065/udp STUN, 8070/tcp relay
------------------------------------------------------------------------
```

1. Установите консоль Aspia **3.x** ([релизы](https://github.com/dchapyshev/aspia/releases)).
2. Подключитесь к Router: адрес сервера, порт **8062**, пользователь `admin`.
3. **Смените пароль.** В Aspia 3.x для пользователей Router обязательна двухфакторная аутентификация (TOTP): консоль предложит её настроить при первом входе.
4. В настройках хостов укажите:
   - адрес сервера;
   - порт **8061** (хосты 3.x) или **8060** (хосты 2.x);
   - публичный ключ из журнала. Он же лежит в файле `data/config/host.pub` (способ 1) или внутри контейнера: `docker exec aspia-server cat /etc/aspia/host.pub`.

Сбросить двухфакторную аутентификацию пользователю:

```bash
docker exec aspia-server aspia_router --reset-otp admin
```

## Порты и проброс на роутере

| Порт | Сервис | Для чего | Открыть наружу |
|---|---|---|---|
| 8060/tcp | Router | хосты Aspia 2.x (2.6.2 и новее) | если есть хосты 2.x |
| 8061/tcp | Router | хосты Aspia 3.x | да |
| 8062/tcp | Router | консоли (клиенты) | да |
| 8063/tcp | Router | подключение Relay к Router внутри контейнера | нет |
| 8065/udp | Router | встроенный STUN-сервер | да |
| 8070/tcp | Relay | соединения между консолью и хостом | да |

- Если сервер стоит за роутером, пробросьте эти порты на его локальный IP без изменения номеров.
- Для **MikroTik** есть готовый скрипт: [docs/mikrotik.md](docs/mikrotik.md).
- Если на сервере включён брандмауэр (`ufw`, `firewalld`), разрешите в нём эти порты.

## Обновление

### Способ 1 и Synology: автоматически

Контейнер `aspia-updater` проверяет обновления при запуске и каждый день в `UPDATE_TIME` (по умолчанию 04:00):

1. Находит последний [релиз Aspia](https://github.com/dchapyshev/aspia/releases) и ждёт, пока ему исполнится `MIN_AGE_DAYS` дней (по умолчанию 2): сразу после выхода нередко выходит исправление.
2. Скачивает новый образ, пока текущая версия продолжает работать. Пересобранный образ той же версии, например с обновлениями безопасности, тоже считается обновлением.
3. Останавливает сервер и сохраняет `data/config` и `data/database` в `backups/`.
4. Запускает новую версию и ждёт статуса `healthy` до 3 минут. **Если не дождался — восстанавливает бэкап и прежнюю версию.**
5. Удаляет старые образы, лишние бэкапы и старые логи, затем обновляет сам себя.

Простой при обновлении — 10–40 секунд. Журнал пишется в `update.log` и в `docker logs aspia-updater`. Делать ничего не нужно.

Ручное управление:

```bash
docker exec aspia-updater update.sh                                  # проверить сейчас
docker exec -e MIN_AGE_DAYS=0 aspia-updater update.sh                # поставить свежий релиз сразу
docker exec -e DRY_RUN=1 -e MIN_AGE_DAYS=0 aspia-updater update.sh   # только показать, что будет сделано
docker exec -e FORCE_VERSION=3.0.18 aspia-updater update.sh          # перейти на конкретную версию
docker compose stop updater                                          # отключить автообновление
```

**Обновление самого проекта.** Если в репозитории поменялся `compose.yaml` (новые возможности), скачайте его заново. Ваш `.env` при этом не меняется.

```bash
cd /opt/aspia
sudo curl -fsSLO https://raw.githubusercontent.com/SinitsaDA/aspia-server-docker/main/compose.yaml
sudo docker compose up -d
```

### Способ 3: просто Docker

**Вручную.** Сделайте бэкап (см. [Бэкапы](#бэкапы-и-восстановление)), скачайте новый образ и пересоздайте контейнер той же командой `docker run`, что и при установке. Данные останутся в томах.

```bash
docker pull ghcr.io/sinitsada/aspia-server:latest
docker stop aspia-server && docker rm aspia-server
docker run -d --name aspia-server ...   # та же команда, что при установке
```

В Portainer: Stacks → ваш стек → **Update the stack** с отметкой **Re-pull image**.

**Автоматически через [Watchtower](https://watchtower.nickfedor.com/)** (поддерживаемый форк; оригинальный `containrrr/watchtower` заархивирован) или аналог. Он следит за тегом `latest` и пересоздаёт контейнер, когда выходит новый образ. Пример с проверкой каждый день в 04:00:

```bash
docker run -d --name watchtower --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  nickfedor/watchtower aspia-server --schedule "0 0 4 * * *" --cleanup
```

В отличие от способа 1, Watchtower не делает бэкап и не откатывает неудачное обновление.

**Хотите остаться на определённой версии?** Укажите точный тег вместо `latest`, например `ghcr.io/sinitsada/aspia-server:3.0.18`.

## Переход с Aspia 2.x

> **Внимание: в Aspia 3.1 разработчик убрал поддержку хостов 2.x (порт 8060) и перенос данных 2.x.**
> Всё, что написано ниже, работает только в версиях **3.0.x**. Если у вас остались хосты 2.x или нужно
> перенести данные 2.x, используйте последнюю версию 3.0 — **3.0.37** — и не давайте ей обновиться до 3.1:
> способ 1 и Synology — `ASPIA_VERSION=3.0.37` в `.env` и остановленный обновлятель
> (`docker compose stop updater`, на Synology — контейнер `aspia-updater`);
> способ 3 — тег `ghcr.io/sinitsada/aspia-server:3.0.37` вместо `latest` и без Watchtower.
> Данные, перенесённые в 3.0.37, затем без проблем обновляются до 3.1.

Сервер 3.x сам конвертирует данные 2.x при первом запуске:
- `router.json` → `router.conf`, `relay.json` → `relay.conf`, старые файлы сохраняются как `*.json.bak`;
- база `router.db3` обновляется, хосты и пользователи сохраняются;
- **ключ шифрования остаётся прежним**: `host.pub` = старый `router.pub`, на хостах ничего менять не нужно.

**Куда положить файлы до первого запуска:**

| Файл 2.x | Способ 1 и Synology | Способ 3 (внутри контейнера) |
|---|---|---|
| `router.json`, `relay.json`, `router.pub` | `data/config/` | `/etc/aspia` |
| `router.db3` | `data/database/` | `/var/lib/aspia` |

**С образа `paprikkafox/aspia-server`.** Его папки `./data/config` и `./data/database` имеют ту же структуру. Остановите старый контейнер (он занимает те же порты), скопируйте папки в `data/` нового проекта и запустите.

**В уже работающую установку (способ 1).** Положите архив (`.zip` или `.tar.gz`) с этими четырьмя файлами в папку проекта и выполните:

```bash
docker exec aspia-updater import-2x.sh import/aspia.zip
```

Перед импортом текущие данные сохраняются в `backups/`.

**Что проверить после перехода:**

- **Хосты старше 2.6.2 к Router 3.x не подключатся.** В логе Router это выглядит как `Invalid peer architecture (size: 0)`. Их нужно обновить.
- **Консоль** нужна версии 3.x, порт **8062**.
- **Порты 8061, 8062 и 8065/udp** нужно открыть или пробросить дополнительно к старым 8060 и 8070.

## Настройки (.env)

Для способов 1 и 2. Образец — [.env.example](.env.example). После изменения `.env` выполните `docker compose up -d`.

| Параметр | По умолчанию | Описание |
|---|---|---|
| `EXTERNAL_IP` | — | внешний IP или DNS-имя сервера; `auto` — определить автоматически при запуске |
| `ASPIA_DIR` | — | **абсолютный путь** к папке проекта на хосте. Должен совпадать с реальным: планировщик монтирует папку по тому же пути |
| `TZ` | `UTC` | часовой пояс (логи, время проверки обновлений) |
| `ASPIA_VERSION` | — | версия Aspia; **меняется автоматически** планировщиком |
| `COMPOSE_PROJECT_NAME` | `aspia` | имя проекта Compose |
| `UPDATE_TIME` | `04:00` | время ежедневной проверки обновлений |
| `MIN_AGE_DAYS` | `2` | ставить релиз, когда ему исполнится столько дней (`0` — сразу) |
| `KEEP_BACKUPS` | `10` | сколько бэкапов хранить в `backups/` |
| `LOG_RETENTION_DAYS` | `30` | через сколько дней удалять логи Aspia |
| `SELF_UPDATE` | `1` | обновлять и сам планировщик |
| `ASPIA_IMAGE`, `UPDATER_IMAGE` | `ghcr.io/sinitsada/...` | откуда брать образы |
| `COMPOSE_FILE` | — | `compose.yaml:compose.build.yaml` — собирать образы локально |

Для способа 3 используются только переменные контейнера `EXTERNAL_IP` и `TZ`.

## Бэкапы и восстановление

**Способ 1 и Synology.** Перед каждым обновлением и импортом создаётся архив `backups/data_<версия>_<дата>.tar.gz` с `data/config` и `data/database`. Восстановление:

```bash
cd /opt/aspia
docker compose stop server
rm -rf data/config data/database
tar -xzf backups/<архив>.tar.gz
docker compose up -d server
```

Если бэкап сделан на другой версии, переключитесь на неё: `docker exec -e FORCE_VERSION=<версия> aspia-updater update.sh`.

**Способ 3.** Бэкап томов:

```bash
docker stop aspia-server
docker run --rm -v aspia-config:/config -v aspia-data:/data -v "$PWD":/backup alpine \
  tar -czf /backup/aspia-backup-$(date +%F).tar.gz /config /data
docker start aspia-server
```

## Устранение неполадок

| Симптом | Что делать |
|---|---|
| `aspia-server` в статусе `unhealthy` | `docker inspect --format '{{json .State.Health}}' aspia-server` покажет причину; подробные логи в `data/logs` (или `/var/log/aspia` в контейнере) |
| Контейнер сразу завершается с `exec format error` | процессор не x86_64 (ARM) — Aspia под него не выпускается |
| Хосты 2.x не подключаются, в логе `Invalid peer architecture` | хост старше 2.6.2, обновите его |
| Консоль не подключается | консоль должна быть 3.x и подключаться к порту 8062; проверьте проброс портов |
| Консоль подключается, но сеанс с хостом не устанавливается | порт 8070 не открыт или неверный `EXTERNAL_IP` (см. журнал контейнера) |
| `ERROR: .../.env not found` в журнале `aspia-updater` | `ASPIA_DIR` в `.env` не совпадает с реальным путём к проекту |
| `address already in use` | порты заняты: остановите старый сервер Aspia |
| `Bind mount failed: '...' does not exist` (Synology) | Synology не создаёт папки для томов сам: создайте `data/config`, `data/database`, `data/logs` и проверьте, что `ASPIA_DIR` в `.env` — точный путь к папке проекта. Если ошибка про `/root/.docker`, скачайте свежий `compose.yaml` из репозитория |

Строки `sd_login_monitor_new failed` и `Unable to install signal handler for SIGKILL/SIGSTOP` в логах безобидны: в контейнере нет systemd.

> Встроенный механизм обновления Aspia (`--install-update`, обновление из консоли) в контейнере не используйте. Он рассчитан на systemd, а изменения пропадут при пересоздании контейнера. Обновляйтесь, как описано в разделе [Обновление](#обновление).

## Локальная сборка

Если не хотите пользоваться готовыми образами:

```bash
git clone https://github.com/SinitsaDA/aspia-server-docker.git /opt/aspia
cd /opt/aspia
cp .env.example .env
# в .env: EXTERNAL_IP, ASPIA_DIR=/opt/aspia и раскомментируйте
#   COMPOSE_FILE=compose.yaml:compose.build.yaml
docker compose up -d --build
```

Планировщик в этом режиме сам собирает каждую новую версию на этой машине.

Собрать только образ сервера:

```bash
docker build --build-arg ASPIA_VERSION=3.0.18 -t aspia-server:3.0.18 server
```

## Как это устроено

```
├── compose.yaml            сервер + планировщик (готовые образы)
├── compose.build.yaml      дополнение для локальной сборки
├── .env.example            образец настроек
├── docs/                   Synology, MikroTik
├── server/                 образ ghcr.io/sinitsada/aspia-server
│   ├── Dockerfile          Debian slim + официальные .deb пакеты Aspia
│   ├── aspia_start         подготовка конфигурации, миграция 2.x, запуск Router и Relay
│   └── aspia_health        healthcheck (читает /proc/net/tcp, не создаёт подключений)
├── updater/                образ ghcr.io/sinitsada/aspia-server-updater
│   ├── entrypoint.sh       ежедневный запуск
│   ├── update.sh           обновление с бэкапом и откатом
│   └── import-2x.sh        импорт данных Aspia 2.x
└── .github/workflows/
    └── publish.yml         сборка, проверка и публикация образов
```

## Лицензия

[GPL-3.0](LICENSE), как и у самой Aspia.

Благодарности:
- [Дмитрий Чапышев](https://github.com/dchapyshev) — автор Aspia;
- [Dmitry Fox (paprikkafox)](https://github.com/paprikkafox/aspia-server-docker) — автор первого Docker-образа Aspia Server, на идеях которого основан этот проект.
