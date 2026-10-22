# Aspia Server in a MikroTik container

[Русский](mikrotik-container.md) | **English**

Router and Relay run **on the MikroTik router itself** in a RouterOS container, no separate server needed.
Tested on **L009UiGS** (RouterOS 7.24, 32-bit ARM, 512 MB RAM, 128 MB flash): the server runs from the
built-in flash without USB storage, uses ~100–150 MB of RAM and almost no CPU.

> The developer of Aspia releases server packages for x86_64 only. The ARM builds are made by this
> project: armv7 is built from the sources, arm64 is taken from the developer's CI. These builds are unofficial.

## Images

| Image | Purpose | Size (unpacked) |
|---|---|---|
| `ghcr.io/sinitsada/aspia-server-mikrotik` | MikroTik: UPX-compressed binaries, minimal system, fits into the built-in flash | ~55 MB |
| `ghcr.io/sinitsada/aspia-server-arm` | Raspberry Pi, ARM NAS, MikroTik with a USB disk; plain Debian | ~180 MB |

Architectures: **armv7** (L009, hAP ac², RB4011 and other 32-bit ARM) and **arm64** (hAP ax², ax³, RB5009,
Raspberry Pi 4/5 with a 64-bit OS). Docker and RouterOS pick the right one.

Tags: `3.1.2` (exact version), `3.1`, `latest` — the newest Aspia;
`3.0.37`, `3.0` — the last version **with 2.x hosts support** (see [below](#2x-hosts-and-version-3037)).

## Requirements

- RouterOS **7.x** with the **container** package (System → Packages; for arm from "Extra packages").
- Container mode: `/system/device-mode/update container=yes`, then press **Reset** briefly within 5 minutes
  (or power-cycle the router). Check: `/system/device-mode/print` → `container: yes`.
- Space: ~60 MB of built-in flash (`/system/resource/print` → `free-hdd-space`) or a USB disk.
- Memory: ~150 MB of free RAM.
- A public IP on the router if hosts and consoles connect from the Internet.

## Installation

Run the commands in the RouterOS terminal (Winbox → New Terminal or SSH). The addresses and names
(`172.17.0.2`, `containers`, `aspia/...`) can be changed.

### 1. Container network

```
/interface/veth/add name=veth-aspia address=172.17.0.2/24 gateway=172.17.0.1
/interface/bridge/add name=containers
/ip/address/add address=172.17.0.1/24 interface=containers
/interface/bridge/port/add bridge=containers interface=veth-aspia
/interface/list/member/add list=LAN interface=containers
```

The bridge is added to the **LAN** list: otherwise the default rule "drop all not coming from LAN" blocks
the container from the router's DNS (and it cannot check for updates). The container reaches the Internet
through the default masquerade (`out-interface-list=WAN`). If there is none:
`/ip/firewall/nat/add chain=srcnat action=masquerade src-address=172.17.0.0/24`.

### 2. Folders and settings

The settings and the database live in the built-in flash (`aspia/...`). With a USB disk use `usb1/aspia/...`.

```
/container/mounts/add list=aspia src=aspia/etc  dst=/etc/aspia
/container/mounts/add list=aspia src=aspia/data dst=/var/lib/aspia

/container/envs/add list=aspia key=TZ value="Europe/Berlin"
/container/envs/add list=aspia key=EXTERNAL_IP value="203.0.113.10"
```

- `etc` — settings and keys (`router.conf`, `relay.conf`, `*.pub`);
- `data` — the database `router.db3` (users, hosts), the backups and the downloaded updates;
- `EXTERNAL_IP` — the public IP of the router, the Relay announces it to consoles and hosts.

With a USB disk the downloaded updates and the backups can stay on it while the database stays in the flash:
`/container/mounts/add list=aspia src=usb1/aspia/store dst=/var/lib/aspia-store`.

### 3. The image: from GitHub or from a file

**From GitHub (easier).** The image is downloaded to a temporary RAM disk and unpacked into the flash:

```
/disk/add type=tmpfs tmpfs-max-size=150M
/disk/print
```
Note the disk name (e.g. `tmp1`) and use it below.
```
/container/config/set registry-url=https://ghcr.io tmpdir=tmp1/tmp
/container/add remote-image=sinitsada/aspia-server-mikrotik:latest interface=veth-aspia root-dir=aspia/root mountlists=aspia envlist=aspia name=aspia logging=yes start-on-boot=yes
```

**From a file** (the router cannot reach ghcr.io). On a computer with Docker:
```bash
docker pull --platform linux/arm/v7 ghcr.io/sinitsada/aspia-server-mikrotik:latest
docker save ghcr.io/sinitsada/aspia-server-mikrotik:latest -o aspia-server-mikrotik.tar
```
(`--platform linux/arm64` for arm64 routers). Create the RAM disk as above, drag the file into
Winbox → Files → `tmp1` and run:
```
/container/config/set tmpdir=tmp1/tmp
/container/add file=tmp1/aspia-server-mikrotik.tar interface=veth-aspia root-dir=aspia/root mountlists=aspia envlist=aspia name=aspia logging=yes start-on-boot=yes
```

### 4. Start

```
/container/print
```
Wait for `status=stopped` (unpacking takes 1–3 minutes), then:
```
/container/start aspia
/log print where topics~"container"
```

The RAM disk can be removed afterwards (frees the RAM):
```
/container/config/set tmpdir=""
/disk/remove [find slot=tmp1]
```

The container starts with the router (`start-on-boot=yes`). If Router or Relay crash, the script inside
the container restarts them.

## First login

On a **clean installation** the log (`/log print where topics~"container"`) shows the password of the user
`admin` and the key for the hosts:

```
User name: admin
Password: ...
Public key for hosts: ...
```

The password is shown **once**, save it. Connect the console to the router address, port **8062**.
If the data was moved from another server, no password is shown: log in with the existing user.

## Ports and NAT

| Port | Purpose |
|---|---|
| 8061/tcp | 3.x hosts |
| 8062/tcp | consoles |
| 8070/tcp | Relay (connections through the relay) |
| 8065/udp | STUN |

Forwarding from the WAN interface to the container (replace `ether1` and `203.0.113.10`):

```
/ip/firewall/nat/add chain=dstnat action=dst-nat to-addresses=172.17.0.2 protocol=tcp in-interface=ether1 dst-port=8061,8062,8070 comment="Aspia"
/ip/firewall/nat/add chain=dstnat action=dst-nat to-addresses=172.17.0.2 protocol=udp in-interface=ether1 dst-port=8065 comment="Aspia"
```

For computers **inside the network** connecting to the public address:
```
/ip/firewall/nat/add chain=dstnat action=dst-nat to-addresses=172.17.0.2 protocol=tcp src-address=192.168.88.0/24 dst-address=203.0.113.10 dst-port=8061,8062,8070 comment="Aspia LAN"
/ip/firewall/nat/add chain=dstnat action=dst-nat to-addresses=172.17.0.2 protocol=udp src-address=192.168.88.0/24 dst-address=203.0.113.10 dst-port=8065 comment="Aspia LAN"
```

**Connecting by name** (e.g. `aspia.example.com`). If the router's DNS has a static record of this name for
the LAN, point it to the container:
```
/ip/dns/static/set [find name=aspia.example.com] address=172.17.0.2 ttl=5m
```
Windows remembers the old address for up to a day: run `ipconfig /flushdns` on the LAN computers
(or restart the Aspia Host service).

## Moving from another server

Stop the container (`/container/stop aspia`) and put the files via Winbox → Files
(or `scp` into `aspia/etc` and `aspia/data`):

| Files | Where |
|---|---|
| `router.conf`, `relay.conf`, `host.pub`, `relay.pub`, `router.pub` | `aspia/etc` |
| `router.db3` | `aspia/data` |

If the database is in WAL mode (`router.db3-wal` and `router.db3-shm` next to it), move them together with
the database or stop the old server before copying.

The keys stay the same, so the hosts reconnect to the new server by themselves when the address (IP or
name) is unchanged: just point the ports and the DNS to the container. The logs are not needed.

Aspia 3.1 no longer converts **2.x** data (`router.json`, `relay.json`) — start version `3.0.37` first
(see below), then update.

## Updates

By default the container **checks for updates every day at 04:00** and installs a new version 2 days after
its release: it downloads the binaries, backs up the settings and the database, switches over and checks
that the server works, otherwise it goes back to the previous version.

Manually, in the container console:
```
/container/shell aspia
aspia_update --check
```
The command shows the installed and the latest version and asks `Update ...? [y/N]`.
Other commands: `aspia_update --status` (versions, backups, update log),
`aspia_update --version 3.1.2` (install a given version, also an older one). Leave with `exit`.

An update from 3.0.x to 3.1 and newer is **never automatic** (3.1 has no 2.x hosts support),
only with `--check` or `--version`.

Variables (`/container/envs/add list=aspia key=... value=...`, then restart the container):

| Variable | Default | Description |
|---|---|---|
| `AUTO_UPDATE` | `1` (`0` in the 3.0.x images) | daily update check |
| `UPDATE_TIME` | `04:00` | time of the check |
| `MIN_AGE_DAYS` | `2` | days after a release before it is installed |
| `LOGS` | `0` | `1` — full Aspia logs to files (they grow fast, do not keep it on in the flash) |
| `KEEP_BACKUPS` | `5` | backups to keep |

The image does not have to be reinstalled for updates: new versions of the binaries are installed inside
the container. To update the image itself (e.g. after changes in this project):
`/container/stop aspia`, `/container/remove [find name=aspia]` and step 3 again — the data in
`aspia/etc` and `aspia/data` stays.

## 2.x hosts and version 3.0.37

In Aspia **3.1** the developer removed the 2.x hosts support (port 8060) and the 2.x data migration.
If you still have 2.x hosts, use the tag **`3.0.37`**: it supports them (hosts from 2.6.2) and its
automatic update is off. Add port 8060 to the NAT rules. When all hosts run 3.x,
run `aspia_update --check` and accept the update to 3.1.

## Backups

Before each update the container saves the settings and the database to `aspia/data/backups`
(or `aspia-store/backups`). A backup takes tens of kilobytes (settings and database only, compressed),
the **last 5** are kept, older ones are removed automatically. To keep fewer, e.g. 2
(then restart the container):
```
/container/envs/add list=aspia key=KEEP_BACKUPS value="2"
```
Manual copy: Winbox → Files, folders `aspia/etc` and `aspia/data`.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `Unable to get the latest Aspia release` on `aspia_update --check` | no Internet in the container: the `containers` bridge is not in the LAN list or there is no masquerade |
| LAN hosts do not connect, external ones do | they get the address from the router's DNS or the Windows cache: update the static DNS record, run `ipconfig /flushdns` |
| `Key with id ... is NOT found!` right after a move | one-time Relay keys of the old server; goes away after reconnecting |
| `Host with id ... NOT found!` | the console connects to a host that has not connected to this server yet |
| A 2.x host does not connect | Aspia 3.1 does not support 2.x: update the host or use `3.0.37` |
| Little space in the flash | downloaded versions and backups on USB (`/var/lib/aspia-store`), logs off (`LOGS=0`) |

## Removal

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
Delete the folder `aspia` (settings and database) in Winbox → Files if it is no longer needed.
