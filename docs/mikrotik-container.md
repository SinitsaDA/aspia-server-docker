# Aspia Server в контейнере на MikroTik

**Русский** | [English](mikrotik-container.en.md)

Router и Relay запускаются **прямо на роутере MikroTik** в контейнере RouterOS. Отдельный сервер не нужен.
Проверено на **L009UiGS** (RouterOS 7.24, 32-битный ARM, 512 МБ ОЗУ, 128 МБ флеш): сервер
работает из встроенной памяти без USB-накопителя, занимает ~100–150 МБ ОЗУ и почти не нагружает процессор.

> Разработчик Aspia выпускает серверные пакеты только для x86_64. Сборки под ARM делает этот проект:
> armv7 собирается из исходников, arm64 берётся из CI разработчика. Это неофициальные сборки.

## Образы

| Образ | Для чего | Размер (распакованный) |
|---|---|---|
| `ghcr.io/sinitsada/aspia-server-mikrotik` | MikroTik: программы сжаты UPX, минимальная система, помещается во встроенную флеш | ~55 МБ |
| `ghcr.io/sinitsada/aspia-server-arm` | Raspberry Pi, ARM-NAS, MikroTik с USB-диском; обычный Debian | ~180 МБ |

Архитектуры: **armv7** (L009, hAP ac², RB4011 и др. 32-битные ARM) и **arm64** (hAP ax², ax³, RB5009,
Raspberry Pi 4/5 с 64-битной ОС). Docker и RouterOS сами берут нужную.

Теги: `3.1.2` (точная версия), `3.1`, `latest` — последняя версия Aspia;
`3.0.37`, `3.0` — последняя версия **с поддержкой хостов 2.x** (см. [ниже](#хосты-2x-и-версия-3037)).

## Что нужно

- RouterOS **7.x** с пакетом **container** (System → Packages; для arm — из «Extra packages»).
- Режим контейнеров: `/system/device-mode/update container=yes`, затем в течение 5 минут коротко
  нажать **Reset** на роутере (или выключить и включить питание). Проверка: `/system/device-mode/print` → `container: yes`.
- Место: ~60 МБ во встроенной памяти (`/system/resource/print` → `free-hdd-space`) или USB-диск.
- Память: ~150 МБ свободной ОЗУ.
- Внешний («белый») IP на роутере, если хосты и консоли подключаются из интернета.

## Установка

Команды вводятся в терминале RouterOS (Winbox → New Terminal или SSH). Адреса и имена
(`172.17.0.2`, `containers`, `aspia/...`) можно поменять на свои.

### 1. Сеть контейнера

```
/interface/veth/add name=veth-aspia address=172.17.0.2/24 gateway=172.17.0.1
/interface/bridge/add name=containers
/ip/address/add address=172.17.0.1/24 interface=containers
/interface/bridge/port/add bridge=containers interface=veth-aspia
/interface/list/member/add list=LAN interface=containers
```

Мост добавлен в список **LAN**: правило стандартной конфигурации «drop all not coming from LAN»
иначе не пустит контейнер к DNS роутера (контейнер не сможет проверять обновления).
В интернет контейнер выходит через стандартный masquerade (`out-interface-list=WAN`).
Если такого правила нет: `/ip/firewall/nat/add chain=srcnat action=masquerade src-address=172.17.0.0/24`.

### 2. Папки и настройки

Настройки и база — во встроенной памяти (`aspia/...`). С USB-диском замените на `usb1/aspia/...`.

```
/container/mounts/add list=aspia src=aspia/etc  dst=/etc/aspia
/container/mounts/add list=aspia src=aspia/data dst=/var/lib/aspia

/container/envs/add list=aspia key=TZ value="Europe/Moscow"
/container/envs/add list=aspia key=EXTERNAL_IP value="203.0.113.10"
```

- `etc` — настройки и ключи (`router.conf`, `relay.conf`, `*.pub`);
- `data` — база `router.db3` (пользователи, хосты), а также бэкапы и скачанные обновления;
- `EXTERNAL_IP` — внешний IP роутера: его Relay сообщает консолям и хостам.

Если есть USB-диск, скачанные обновления и бэкапы можно держать на нём, а базу — во встроенной памяти:
`/container/mounts/add list=aspia src=usb1/aspia/store dst=/var/lib/aspia-store`.

### 3. Образ: из GitHub или файлом

**Из GitHub (проще).** Образ скачивается во временный RAM-диск и распаковывается во флеш:

```
/disk/add type=tmpfs tmpfs-max-size=150M
/disk/print
```
Запомните имя диска (например, `tmp1`) и подставьте ниже.
```
/container/config/set registry-url=https://ghcr.io tmpdir=tmp1/tmp
/container/add remote-image=sinitsada/aspia-server-mikrotik:latest interface=veth-aspia root-dir=aspia/root mountlists=aspia envlist=aspia name=aspia logging=yes start-on-boot=yes
```

**Файлом** (роутер без доступа к ghcr.io). На компьютере с Docker:
```bash
docker pull --platform linux/arm/v7 ghcr.io/sinitsada/aspia-server-mikrotik:latest
docker save ghcr.io/sinitsada/aspia-server-mikrotik:latest -o aspia-server-mikrotik.tar
```
(для arm64-роутеров — `--platform linux/arm64`). Создайте RAM-диск, как выше, перетащите файл
в Winbox → Files → `tmp1` и выполните:
```
/container/config/set tmpdir=tmp1/tmp
/container/add file=tmp1/aspia-server-mikrotik.tar interface=veth-aspia root-dir=aspia/root mountlists=aspia envlist=aspia name=aspia logging=yes start-on-boot=yes
```

### 4. Запуск

```
/container/print
```
Дождитесь `status=stopped` (распаковка 1–3 минуты), затем:
```
/container/start aspia
/log print where topics~"container"
```

После этого RAM-диск можно убрать (ОЗУ освободится):
```
/container/config/set tmpdir=""
/disk/remove [find slot=tmp1]
```

Контейнер запускается вместе с роутером (`start-on-boot=yes`). Если Router или Relay упадут,
скрипт внутри контейнера перезапустит их сам.

## Первый вход

При **чистой установке** в логе (`/log print where topics~"container"`) появятся пароль пользователя
`admin` и ключ для хостов:

```
User name: admin
Password: ...
Public key for hosts: ...
```

Пароль показывается **один раз**, сохраните его. Подключение консолью: адрес роутера, порт **8062**.
Если вы перенесли данные с другого сервера, пароль в логе не появится: входите прежним пользователем.

## Порты и NAT

| Порт | Назначение |
|---|---|
| 8061/tcp | хосты 3.x |
| 8062/tcp | консоли |
| 8070/tcp | Relay (подключения через ретранслятор) |
| 8065/udp | STUN |

Проброс с внешнего интерфейса на контейнер (`ether1` и `203.0.113.10` замените на свои):

```
/ip/firewall/nat/add chain=dstnat action=dst-nat to-addresses=172.17.0.2 protocol=tcp in-interface=ether1 dst-port=8061,8062,8070 comment="Aspia"
/ip/firewall/nat/add chain=dstnat action=dst-nat to-addresses=172.17.0.2 protocol=udp in-interface=ether1 dst-port=8065 comment="Aspia"
```

Чтобы компьютеры **внутри сети** могли подключаться по внешнему адресу:
```
/ip/firewall/nat/add chain=dstnat action=dst-nat to-addresses=172.17.0.2 protocol=tcp src-address=192.168.88.0/24 dst-address=203.0.113.10 dst-port=8061,8062,8070 comment="Aspia LAN"
/ip/firewall/nat/add chain=dstnat action=dst-nat to-addresses=172.17.0.2 protocol=udp src-address=192.168.88.0/24 dst-address=203.0.113.10 dst-port=8065 comment="Aspia LAN"
```

**Подключение по имени** (например, `aspia.example.com`). Если в DNS роутера есть статическая запись
этого имени для локальной сети, направьте её на контейнер:
```
/ip/dns/static/set [find name=aspia.example.com] address=172.17.0.2 ttl=5m
```
Windows помнит старый адрес до суток: на компьютерах в локальной сети выполните `ipconfig /flushdns`
(или перезапустите службу Aspia Host).

## Перенос с другого сервера

Остановите контейнер (`/container/stop aspia`) и положите файлы через Winbox → Files
(или `scp` в папки `aspia/etc` и `aspia/data`):

| Файлы | Куда |
|---|---|
| `router.conf`, `relay.conf`, `host.pub`, `relay.pub`, `router.pub` | `aspia/etc` |
| `router.db3` | `aspia/data` |

Если база в режиме WAL (рядом лежат `router.db3-wal` и `router.db3-shm`), перенесите их вместе
с базой или остановите старый сервер перед копированием.

Ключи остаются прежними, поэтому хосты переподключаются к новому серверу сами, если адрес (IP или
имя) не изменился: достаточно перенаправить порты и DNS на контейнер. Журналы переносить не нужно.

Данные **2.x** (`router.json`, `relay.json`) Aspia 3.1 уже не конвертирует — сначала запустите
версию `3.0.37` (см. ниже), затем обновитесь.

## Обновление

По умолчанию контейнер **сам проверяет обновления каждый день в 04:00** и ставит новую версию
через 2 дня после её выхода: скачивает программы, делает бэкап настроек и базы, переключается
и проверяет, что сервер заработал, иначе возвращает прежнюю версию.

Вручную — в консоли контейнера:
```
/container/shell aspia
aspia_update --check
```
Команда покажет установленную и последнюю версию и спросит `Update ...? [y/N]`.
Другие команды: `aspia_update --status` (версии, бэкапы, журнал обновлений),
`aspia_update --version 3.1.2` (поставить конкретную версию, в том числе более старую). Выход — `exit`.

Переход с 3.0.x на 3.1 и новее **автоматически не выполняется** (в 3.1 нет поддержки хостов 2.x),
только через `--check` или `--version`.

Переменные (`/container/envs/add list=aspia key=... value=...`, затем перезапуск контейнера):

| Переменная | По умолчанию | Описание |
|---|---|---|
| `AUTO_UPDATE` | `1` (`0` в образах 3.0.x) | ежедневная проверка обновлений |
| `UPDATE_TIME` | `04:00` | время проверки |
| `MIN_AGE_DAYS` | `2` | через сколько дней после выхода ставить версию |
| `LOGS` | `0` | `1` — подробные журналы Aspia в файлы (растут быстро, во флеш лучше не включать надолго) |
| `KEEP_BACKUPS` | `5` | сколько бэкапов хранить |

Образ контейнера переустанавливать при обновлениях не нужно: новые версии программ ставятся
внутрь контейнера. Обновить сам образ (например, после изменений в этом проекте):
`/container/stop aspia`, `/container/remove [find name=aspia]` и снова шаг 3 — данные в
`aspia/etc` и `aspia/data` сохранятся.

## Хосты 2.x и версия 3.0.37

В Aspia **3.1** разработчик убрал поддержку хостов 2.x (порт 8060) и перенос данных 2.x.
Если у вас остались хосты 2.x, используйте тег **`3.0.37`**: он их поддерживает (хосты от 2.6.2),
а автообновление в нём выключено. Добавьте порт 8060 в правила NAT. Когда все хосты обновлены до 3.x,
выполните `aspia_update --check` и согласитесь на обновление до 3.1.

## Бэкапы

Перед каждым обновлением контейнер сохраняет настройки и базу в `aspia/data/backups`
(или `aspia-store/backups`). Скопировать вручную: Winbox → Files, папки `aspia/etc` и `aspia/data`.

## Устранение неполадок

| Признак | Причина и решение |
|---|---|
| `Unable to get the latest Aspia release` при `aspia_update --check` | контейнер не выходит в интернет: мост `containers` не в списке LAN или нет masquerade |
| Хосты в локальной сети не подключаются, внешние — да | хосты берут адрес из DNS роутера или из кэша Windows: обновите статическую запись DNS, выполните `ipconfig /flushdns` |
| `Key with id ... is NOT found!` сразу после переноса | одноразовые ключи Relay от старого сервера; проходит само после переподключения |
| `Host with id ... NOT found!` | консоль подключается к хосту, который ещё не подключился к этому серверу |
| Хост 2.x не подключается | Aspia 3.1 не поддерживает 2.x: обновите хост или используйте `3.0.37` |
| Мало места на флеше | скачанные версии и бэкапы — на USB (`/var/lib/aspia-store`), журналы — выключить (`LOGS=0`) |

## Удаление

```
/container/stop aspia
/container/remove [find name=aspia]
/container/mounts/remove [find list=aspia]
/container/envs/remove [find list=aspia]
/ip/firewall/nat/remove [find comment~"^Aspia"]
/interface/list/member/remove [find interface=containers]
/interface/bridge/port/remove [find interface=veth-aspia]
/ip/address/remove [find interface=containers]
/interface/bridge/remove [find name=containers]
/interface/veth/remove [find name=veth-aspia]
```
Папку `aspia` (настройки и база) удалите в Winbox → Files, если она больше не нужна.
