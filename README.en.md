# Aspia Server in Docker

[![Publish images](https://github.com/SinitsaDA/aspia-server-docker/actions/workflows/publish.yml/badge.svg)](https://github.com/SinitsaDA/aspia-server-docker/actions/workflows/publish.yml)
[![Image](https://img.shields.io/badge/ghcr.io-aspia--server-blue?logo=docker)](https://github.com/SinitsaDA/aspia-server-docker/pkgs/container/aspia-server)

[Русский](README.md) | **English**

[Aspia](https://aspia.org) is an open source remote access system. This project runs its server side, **Router** and **Relay**, in a single Docker container and can **keep it on the latest release automatically**.

> Unofficial project. Aspia is developed by [Dmitry Chapyshev](https://github.com/dchapyshev/aspia); this repository only packages it for Docker.

```
ghcr.io/sinitsada/aspia-server:latest
```

## Features

- **Router + Relay in one container.** An image for every Aspia version: `3.0.18`, `3.0`, `3`, `latest`.
- **Universal image.** Works with Docker Compose, plain `docker run`, Portainer, Synology and other NAS systems, with host networking or published ports.
- **Automatic updates with rollback.** The `aspia-updater` container checks for Aspia releases every night. For a new release it:
  1. backs up the data;
  2. installs the new version;
  3. **restores the previous version** if the new one does not become healthy.
- **Health check.** Docker reports `healthy` when the Router accepts connections and the Relay is connected to it.
- **Migration from Aspia 2.x.** The 2.x configuration and database are converted automatically on the first start, including data from the [`paprikkafox/aspia-server`](https://hub.docker.com/r/paprikkafox/aspia-server) image.
- **`EXTERNAL_IP=auto`.** The public IP is detected automatically, handy for dynamic IPs.
- **Tested images.** GitHub Actions builds an image within 6 hours of an Aspia release and starts it before publishing. The image is rebuilt weekly with Debian security updates.

## Requirements

- **x86_64** (Intel/AMD) Linux server or VM. Aspia ships its server packages for this architecture only. For ARM there are separate images, including a container right on a MikroTik router: [docs/mikrotik-container.en.md](docs/mikrotik-container.en.md).
- Docker 24 or later.
- A public IP address or port forwarding to this server.
- About 1 GB of disk space.

## Installation

| Method | For | Updates |
|---|---|---|
| [1. Docker Compose with automatic updates](#method-1-docker-compose-with-automatic-updates-recommended) | Linux server or VM | automatic, with backup and rollback |
| [2. Synology NAS](docs/synology.md) (in Russian) | Synology Container Manager | automatic, with backup and rollback |
| [ARM and MikroTik](docs/mikrotik-container.en.md) | Raspberry Pi, ARM NAS, a container on a MikroTik router | automatic inside the container, with backup and rollback |
| [3. Plain Docker](#method-3-plain-docker-docker-run-portainer) | any VM, Portainer, Unraid, TrueNAS... | one command, or Watchtower |

### Method 1. Docker Compose with automatic updates (recommended)

This method runs two containers:
- `aspia-server`, the server itself;
- `aspia-updater`, which handles the automatic updates.

**1. Download the project files:**

```bash
sudo mkdir -p /opt/aspia && cd /opt/aspia
sudo curl -fsSLO https://raw.githubusercontent.com/SinitsaDA/aspia-server-docker/main/compose.yaml
sudo curl -fsSL -o .env https://raw.githubusercontent.com/SinitsaDA/aspia-server-docker/main/.env.example
```

**2. Edit `.env`** (`sudo nano .env`). Three settings are required:

```ini
EXTERNAL_IP=203.0.113.10   # public IP of the server, or auto
ASPIA_DIR=/opt/aspia       # path of this directory, must match the real one
TZ=Europe/Berlin           # time zone
```

If you are migrating from Aspia 2.x, put the old data into `data/` now (see [Migrating from 2.x](#migrating-from-aspia-2x)).

**3. Start it:**

```bash
sudo docker compose up -d
```

**4. Check it.** `aspia-server` becomes `healthy` in about a minute:

```bash
sudo docker compose ps
sudo docker logs aspia-server
```

### Method 3. Plain Docker (docker run, Portainer)

A single container without the updater:

```bash
docker run -d --name aspia-server --restart unless-stopped \
  -p 8060-8062:8060-8062 -p 8065:8065/udp -p 8070:8070 \
  -e EXTERNAL_IP=auto \
  -e TZ=Europe/Berlin \
  -v aspia-config:/etc/aspia \
  -v aspia-data:/var/lib/aspia \
  -v aspia-logs:/var/log/aspia \
  ghcr.io/sinitsada/aspia-server:latest
```

- **Publish the ports unchanged** (`8062:8062`, not `9062:8062`): the Relay announces its own port to the clients.
- **Keep the data on volumes.** Without the three volumes, a recreated container generates new keys, and the hosts would have to be reconfigured.
- **Host networking also works:** use `--network host` instead of the `-p` options.
- **For Portainer stacks,** use the same image, ports, environment and volumes in a compose file (see the Russian README for a ready-made example).

## First login and the key for hosts

A fresh installation creates the user **admin** with the password **admin**. The container log shows the key for hosts and the ports:

```bash
docker logs aspia-server
```

1. Install Aspia Console **3.x** and connect to the server on port **8062**.
2. Change the password. Two-factor authentication (TOTP) is mandatory for Router users in 3.x. To reset it for a user, run `docker exec aspia-server aspia_router --reset-otp admin`.
3. Configure the hosts:
   - the server address;
   - port **8061** for 3.x hosts, **8060** for 2.x hosts;
   - the public key, which is also stored in `data/config/host.pub` (or `/etc/aspia/host.pub` inside the container).

## Ports

| Port | Service | Purpose | Expose |
|---|---|---|---|
| 8060/tcp | Router | Aspia 2.x hosts (2.6.2 and later) | if you have 2.x hosts |
| 8061/tcp | Router | Aspia 3.x hosts | yes |
| 8062/tcp | Router | consoles (clients) | yes |
| 8063/tcp | Router | Relay to Router inside the container | no |
| 8065/udp | Router | built-in STUN server | yes |
| 8070/tcp | Relay | console to host traffic | yes |

Behind a MikroTik router: a ready-made script is in [docs/mikrotik.md](docs/mikrotik.md). The guide is in Russian; the RouterOS commands are universal.

## Updates

### Method 1 and Synology: automatic

`aspia-updater` runs on start and daily at `UPDATE_TIME` (04:00 by default):

1. Takes the latest [Aspia release](https://github.com/dchapyshev/aspia/releases) once it is `MIN_AGE_DAYS` days old (2 by default).
2. Pulls the new image while the current version keeps running.
3. Stops the server and backs up `data/config` and `data/database` to `backups/`.
4. Starts the new version and waits up to 3 minutes for `healthy`. **Otherwise it restores the backup and the previous version.**
5. Cleans up old images, extra backups and old logs, then updates itself.

Manual control:

```bash
docker exec aspia-updater update.sh                                  # check now
docker exec -e MIN_AGE_DAYS=0 aspia-updater update.sh                # install a fresh release right away
docker exec -e DRY_RUN=1 -e MIN_AGE_DAYS=0 aspia-updater update.sh   # only report
docker exec -e FORCE_VERSION=3.0.18 aspia-updater update.sh          # switch to a specific version
docker compose stop updater                                          # disable automatic updates
```

To update the project files themselves, download `compose.yaml` again and run `docker compose up -d`. Your `.env` is kept.

### Method 3: plain Docker

**Manually:** pull the new image, then recreate the container with the same `docker run` command. The data stays on the volumes.

```bash
docker pull ghcr.io/sinitsada/aspia-server:latest
docker stop aspia-server && docker rm aspia-server
docker run -d --name aspia-server ...   # the same command as for the installation
```

**Automatically** with [Watchtower](https://watchtower.nickfedor.com/), the maintained fork (the original `containrrr/watchtower` is archived). Unlike method 1, it has no backup or rollback.

```bash
docker run -d --name watchtower --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  nickfedor/watchtower aspia-server --schedule "0 0 4 * * *" --cleanup
```

To stay on a specific version, use an exact tag such as `ghcr.io/sinitsada/aspia-server:3.0.18` instead of `latest`.

## Migrating from Aspia 2.x

> **Note: Aspia 3.1 removed the 2.x hosts support (port 8060) and the 2.x data migration.**
> Everything below works in the **3.0.x** versions only. If you still have 2.x hosts or 2.x data to move,
> use the last 3.0 — **3.0.37** — and do not let it update to 3.1:
> method 1 and Synology — `ASPIA_VERSION=3.0.37` in `.env` and the updater stopped
> (`docker compose stop updater`, on Synology the container `aspia-updater`);
> method 3 — the tag `ghcr.io/sinitsada/aspia-server:3.0.37` instead of `latest` and no Watchtower.
> Data moved into 3.0.37 updates to 3.1 without problems afterwards.

On the first start, the 3.x server converts 2.x data by itself:
- `router.json` and `relay.json` become `*.conf`, the old files are kept as `*.json.bak`;
- the `router.db3` database keeps its hosts and users;
- the encryption key stays the same, so nothing has to change on the hosts.

**Where to put the files before the first start:**

| 2.x file | Method 1 / Synology | Method 3 (inside the container) |
|---|---|---|
| `router.json`, `relay.json`, `router.pub` | `data/config/` | `/etc/aspia` |
| `router.db3` | `data/database/` | `/var/lib/aspia` |

**Other cases:**
- **From `paprikkafox/aspia-server`:** its `./data/config` and `./data/database` have the same layout. Stop the old container first (it uses the same ports), then copy the folders.
- **Into a running installation (method 1):** put a `.zip` or `.tar.gz` with the four files into the project directory and run `docker exec aspia-updater import-2x.sh import/aspia.zip`.

**Keep in mind:**
- **Hosts older than 2.6.2 cannot connect** to a 3.x Router (`Invalid peer architecture` in the Router log). Update them.
- **Consoles** must be 3.x and connect to port 8062.
- **Open the new ports** 8061, 8062 and 8065/udp in addition to 8060 and 8070.

## Settings (`.env`, methods 1 and 2)

| Variable | Default | Description |
|---|---|---|
| `EXTERNAL_IP` | — | public IP or DNS name announced by the Relay; `auto` = detect on start |
| `ASPIA_DIR` | — | **absolute path** of the project directory on the host (the updater mounts it at the same path) |
| `TZ` | `UTC` | time zone |
| `ASPIA_VERSION` | — | Aspia version, **changed automatically** by the updater |
| `COMPOSE_PROJECT_NAME` | `aspia` | Compose project name |
| `UPDATE_TIME` | `04:00` | daily update check |
| `MIN_AGE_DAYS` | `2` | install a release only when it is this many days old (`0` = right away) |
| `KEEP_BACKUPS` | `10` | backups kept in `backups/` |
| `LOG_RETENTION_DAYS` | `30` | Aspia log files older than this are deleted |
| `SELF_UPDATE` | `1` | update the updater image as well |
| `ASPIA_IMAGE`, `UPDATER_IMAGE` | `ghcr.io/sinitsada/...` | image locations |
| `COMPOSE_FILE` | — | `compose.yaml:compose.build.yaml` to build the images locally |

Method 3 only uses the container variables `EXTERNAL_IP` and `TZ`.

## Backups (method 1)

Every update and import stores `data/config` and `data/database` in `backups/*.tar.gz`. To restore:

```bash
docker compose stop server
rm -rf data/config data/database
tar -xzf backups/<archive>.tar.gz
docker compose up -d server
```

## Troubleshooting

| Symptom | What to do |
|---|---|
| `aspia-server` is `unhealthy` | `docker inspect --format '{{json .State.Health}}' aspia-server`; detailed logs are in `data/logs` or `/var/log/aspia` |
| `exec format error` | the CPU is not x86_64 |
| 2.x hosts fail with `Invalid peer architecture` | the host is older than 2.6.2, update it |
| The console connects but sessions fail | port 8070 is closed or `EXTERNAL_IP` is wrong |
| `.env not found` in the `aspia-updater` log | `ASPIA_DIR` does not match the real project path |
| `Bind mount failed: '...' does not exist` (Synology) | Synology does not create bind mount folders: create `data/config`, `data/database`, `data/logs` and make sure `ASPIA_DIR` is the exact project path. If it mentions `/root/.docker`, download the current `compose.yaml` |

The log lines `sd_login_monitor_new failed` and `Unable to install signal handler for SIGKILL/SIGSTOP` are harmless: there is no systemd in the container.

Don't use Aspia's built-in updater (`--install-update`, updates from the console) in the container. Its changes are lost when the container is recreated.

## Local build

Clone the repository, set `COMPOSE_FILE=compose.yaml:compose.build.yaml` in `.env` and run `docker compose up -d --build`. The updater then builds every new release locally.

## License

[GPL-3.0](LICENSE), same as Aspia. Thanks to [Dmitry Chapyshev](https://github.com/dchapyshev) for Aspia and to [paprikkafox](https://github.com/paprikkafox/aspia-server-docker) for the original Aspia Server Docker image.
