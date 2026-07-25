# Home Server

<a name="top"></a>

My current home lab setup — a dockerised media, monitoring, and networking stack on Ubuntu 24.04 LTS. All services are managed via Docker Compose, segmented into focused stacks, and connected via a shared `tailscale-net` Docker bridge network for container-to-container DNS.

> **Work in progress** — tracked via [issues](https://github.com/inditilve/home-server/issues).

---

## Table of Contents

- [Operations](#operations)
  - [Self-Hosted Runner](#self-hosted-runner)
  - [CI/CD Deploy Workflow](#cicd-deploy-workflow)
  - [Discord Notifications for CI/CD](#discord-notifications-for-cicd)
  - [Watchtower — Auto-Updates](#watchtower--auto-updates)
  - [Watchtower Discord Notifications](#watchtower-discord-notifications)
- [Hardware](#hardware)
- [Service Stacks](#service-stacks)
- [Networking Architecture](#networking-architecture)
- [Setup Guide](#setup-guide)
- [Stack Details + Configuration Nuances](#stack-details--configuration-nuances)
- [Storage Layout](#storage-layout-zfs)
- [Volume Mount Conventions](#volume-mount-conventions)

---

## Operations

### Self-Hosted Runner

The GitHub Actions self-hosted runner runs directly on `indika-media` (Ubuntu 24.04.4 LTS). It listens for workflow jobs and executes them in-place, giving the CI/CD pipeline direct access to the Docker socket and compose files without any SSH gymnastics. The runner is registered under this repo and runs as a persistent background service.

- **Server:** `indika-media`
- **Working repo path:** `~/workspace/home-server`
- **Runner registration:** Settings → Actions → Runners

[⬆ Back to top](#top)

### CI/CD Deploy Workflow

The **Deploy Home Server** workflow is triggered manually via `workflow_dispatch` — it does not run on push. To trigger it, go to [Actions → Deploy Home Server](https://github.com/inditilve/home-server/actions/workflows/deploy.yml), click **Run workflow**, and select the `master` branch.

What it does:
1. Pulls the latest `master` onto `indika-media` via `git pull`
2. Runs `docker compose up -d --remove-orphans` across all stacks
3. Posts a success/failure notification to Discord (see below)

[⬆ Back to top](#top)

### Discord Notifications for CI/CD

Deploy workflow outcomes are posted to the `#home-server` Discord channel via [sarisia/actions-status-discord](https://github.com/sarisia/actions-status-discord). The webhook URL is stored as the **`DISCORD_WEBHOOK_URL`** GitHub Actions secret (Settings → Secrets and variables → Actions). This secret is only used by the CI/CD workflow — it is separate from the Watchtower notification URL below.

[⬆ Back to top](#top)

### Watchtower — Auto-Updates

Watchtower runs in `monitoring/` and polls for updated images at **5:00 AM daily** (`0 0 5 * * *`). It uses `WATCHTOWER_LABEL_ENABLE=true`, so only containers explicitly opted-in with `com.centurylinklabs.watchtower.enable=true` are auto-updated. Old images are cleaned up automatically (`WATCHTOWER_CLEANUP=true`).


**Manual update only (no label):**

| Service | Rationale |
|---|---|
| `plex` | Major version changes can require DB migration; update intentionally |
| `tailscale` | Infrastructure-level — unattended update risks losing remote access |
| `gluetun` | VPN tunnel — unattended update risks kill-switch gap |
| `immich` | Requires coordinated DB + app upgrades; must follow official migration guide |
| `deunhealth` | Health watchdog — update manually to avoid restart loop during update |
| `watchtower` | Not self-labeled — never auto-updates itself |


[⬆ Back to top](#top)

### Watchtower Discord Notifications

Watchtower uses [shoutrrr](https://containrrr.dev/shoutrrr/) for notifications, which requires a **different URL format** than the standard Discord webhook used by CI/CD.

Add the following to `monitoring/.env` (already gitignored — do **not** add to GitHub Secrets):

```env
# Watchtower notification URL — shoutrrr discord format
# Different from the DISCORD_WEBHOOK_URL GitHub Secret used by the CI/CD deploy workflow
WATCHTOWER_NOTIFICATION_URL=discord://TOKEN@WEBHOOK_ID
```

To get the shoutrrr-format URL from a standard Discord webhook URL (`https://discord.com/api/webhooks/WEBHOOK_ID/TOKEN`), rearrange as `discord://TOKEN@WEBHOOK_ID`.

`WATCHTOWER_NOTIFICATION_REPORT=true` is already set in the compose file, so Watchtower will send a single summary report after each update run rather than one message per container.

[⬆ Back to top](#top)

---

## Hardware

| Component | Spec |
|-----------|------|
| **OS** | Ubuntu 24.04.3 LTS |
| **CPU** | Intel i5-14600K |
| **Motherboard** | MSI B760M Gaming Plus Wifi (4 SATA ports; 3 in use) |
| **GPU** | GTX 970 (hardware-accelerated Plex transcoding) |
| **RAM** | 32GB DDR5 |
| **Cooling** | Thermalright Peerless Assassin (dual-fan air cooler) |
| **Boot Drive** | 256GB SATA SSD |
| **Storage** | 1TB SATA SSD + 2TB SATA SSD |
| **PSU** | 750W |
| **Case** | NZXT H440i (2× front intake, 1× rear exhaust) |

[⬆ Back to top](#top)

---

## Service Stacks

| Stack | Path | Services |
|-------|------|----------|
| **Networking** | [`networking/`](networking/) | Tailscale, Gluetun (NordVPN), qBittorrent |
| **Media Apps** | [`media/apps/`](media/apps/) | Plex |
| **Media Services** | [`media/services/`](media/services/) | Sonarr, Radarr, Prowlarr |
| **Monitoring** | [`monitoring/`](monitoring/) | Grafana, Prometheus, Portainer, deunhealth, Watchtower |
| **Dashboard** | [`dashboard/`](dashboard/) | Homepage |

[⬆ Back to top](#top)

---

## Networking Architecture

All stacks share a single external Docker bridge network called `tailscale-net`. Each compose file declares it as the default network:

```yaml
networks:
  default:
    external: true
    name: tailscale-net
```

This means every container automatically joins `tailscale-net` without needing a per-service `networks:` block, and containers can reach each other by name via Docker DNS (e.g. `sonarr:8989`, `gluetun:8080`).

**Tailscale** runs in `network_mode: host` and is used for secure remote admin access to services — not as a VPN tunnel for traffic. The Tailscale container exposes services to the tailnet via `tailscale serve`.

**Gluetun** routes qBittorrent's outbound traffic through NordVPN (OpenVPN). qBittorrent uses `network_mode: service:gluetun`, so all torrent traffic exits via a Nord IP. Gluetun's healthcheck acts as an implicit kill-switch: if the VPN tunnel drops, qBittorrent loses all network access.

**Why not `network_mode: service:tailscale`?** That approach disables Docker DNS, forcing container-to-container communication via static Tailscale IPs rather than container names. The current approach keeps Docker DNS and only uses Tailscale for admin control-plane access.

[⬆ Back to top](#top)

---

## Setup Guide

### 1. Install Docker and Prometheus Node Exporter

```bash
# Install Docker
# https://docs.docker.com/engine/install/ubuntu/

# Install Node Exporter on host
sudo apt install prometheus-node-exporter
```

### 2. Create shared network

```bash
docker network create tailscale-net
```

### 3. Configure `.env` files

Each stack folder has a `.env` file. Populate at minimum:

```env
PUID=1000
PGID=1000
TZ=Asia/Hong_Kong
HOSTNAME=<your-host>
```

**Required `.env` keys:**
Create `networking/.env` with credentials (already added to `.gitignore`)

```env
TS_AUTHKEY=
NORDVPN_SERVICE_USER=   # NordVPN service credential (Account → Manual Setup), NOT login email
NORDVPN_SERVICE_PASS=
VPN_TYPE=openvpn
SERVER_COUNTRIES=Japan
TZ=
```

For Watchtower notifications, add to `monitoring/.env`:

```env
WATCHTOWER_NOTIFICATION_URL=discord://TOKEN@WEBHOOK_ID
```

### 4. Bring up stacks (order matters)

```bash
# Networking first — Tailscale + Gluetun + qBittorrent
cd networking && docker compose up -d
```
**To verify VPN is working:**

```bash
docker exec qbittorrent curl -s https://ipinfo.io/json
# Should show a NordVPN IP, not your real IP
```


Then remaining stacks (any order)
```bash
cd ../media/apps && docker compose up -d
cd ../media/services && docker compose up -d
cd ../monitoring && docker compose up -d
cd ../dashboard && docker compose up -d
```

### 5. Tailscale serve (for TLS + clean URLs on tailnet)

```bash
docker exec tailscale tailscale serve --set-path /grafana http://grafana:3000
docker exec tailscale tailscale serve --set-path /portainer https://portainer:9443
docker exec tailscale tailscale serve --set-path /sonarr http://sonarr:8989
docker exec tailscale tailscale serve --set-path /radarr http://radarr:7878
docker exec tailscale tailscale serve --set-path /prowlarr http://prowlarr:9696
docker exec tailscale tailscale serve --set-path /qbt http://gluetun:8080
docker exec tailscale tailscale serve --set-path /homepage http://homepage:3000
```

[⬆ Back to top](#top)

---

## Stack Details + Configuration Nuances

### Networking — `networking/`

| Container | Image | Port | Purpose |
|-----------|-------|------|---------|
| `tailscale` | `tailscale/tailscale:latest` | host | Secure remote access via Tailscale |
| `gluetun` | `qmcgaw/gluetun:latest` | 8080, 6881 | NordVPN tunnel for qBittorrent |
| `qbittorrent` | `lscr.io/linuxserver/qbittorrent:latest` | via gluetun | Torrent client, VPN-routed |


### Media Apps — `media/apps/`

| Container | Image | Port | Purpose |
|-----------|-------|------|---------|
| `plex` | `lscr.io/linuxserver/plex:latest` | 32400 (host) | Media server |

Plex runs in `network_mode: host` for optimal LAN streaming and hardware transcoding via `/dev/dri`. It mounts `/data` for media content.

### Media Services — `media/services/`

| Container | Image | Port | Purpose |
|-----------|-------|------|---------|
| `sonarr` | `lscr.io/linuxserver/sonarr:latest` | 8989 | TV show management |
| `radarr` | `lscr.io/linuxserver/radarr:latest` | 7878 | Movie management |
| `prowlarr` | `lscr.io/linuxserver/prowlarr:latest` | 9696 | Indexer aggregator |

Configure Sonarr/Radarr's qBittorrent download client with:
- **Host:** `gluetun`
- **Port:** `8080`

### Monitoring — `monitoring/`

| Container | Image | Port | Purpose |
|-----------|-------|------|---------|
| `grafana` | `grafana/grafana` | 3000 | Metrics dashboards |
| `prometheus` | `prom/prometheus` | 9090 | Metrics collection |
| `deunhealth` | `qmcgaw/deunhealth` | — | Auto-restart unhealthy containers |
| `portainer` | `portainer/portainer-ee:lts` | 9000 | Docker management UI |
| `watchtower` | `containrrr/watchtower` | — | Label-scoped auto-image-updates (5 AM daily) |

Prometheus Node Exporter is installed **on the host** (not in Docker) for accurate host-level metrics:

```bash
sudo apt install prometheus-node-exporter
```

The Grafana dashboard is a pared-down version of [Node Exporter Full](https://grafana.com/grafana/dashboards/1860-node-exporter-full/) — import it after configuring Prometheus.

**deunhealth** watches for containers labelled `deunhealth.restart.on.unhealthy=true` and restarts them when they go unhealthy. It runs with `network_mode: none` (only needs the Docker socket).

**Watchtower** runs with `WATCHTOWER_LABEL_ENABLE=true` — only containers with `com.centurylinklabs.watchtower.enable=true` are touched. See the [Watchtower — Auto-Updates](#watchtower--auto-updates) section in Operations for the full opted-in/opted-out list.

### Dashboard — `dashboard/`

| Container | Image | Port | Purpose |
|-----------|-------|------|---------|
| `homepage` | `ghcr.io/gethomepage/homepage:latest` | 3001 | Service dashboard |

Homepage config lives in a named volume. It mounts the Docker socket to auto-discover running containers.

[⬆ Back to top](#top)

---

## Storage Layout (ZFS)

```
storage_pool/docker  →  /var/lib/docker    (named Docker volumes)
storage_pool/data    →  /data              (all media content)
```

Named volumes store service config under `/var/lib/docker`. All media (TV, movies, music, photos, books) lives under `/data`, mounted consistently across the respective media apps/services.

[⬆ Back to top](#top)

---

## Volume Mount Conventions

Consistent `/data` layout used across all services:

```
/data/media/tv        → TV shows (Sonarr, Plex)
/data/media/movies    → Movies (Radarr, Plex)
/data/media/music     → Music (Plex)
/data/downloads       → qBittorrent download staging
```

Ensure all services that need to cross-reference files (e.g. Sonarr hardlinking into Plex's library) mount the same `/data` root.

[⬆ Back to top](#top)
