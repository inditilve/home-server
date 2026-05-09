# Home Server

My current home lab setup - a dockerised media, monitoring, and networking stack on Ubuntu 24.04 LTS. All services are managed via Docker Compose, segmented into focused stacks, and connected via a shared `tailscale-net` Docker bridge network for container-to-container DNS.

> **Work in progress** — tracked via [issues](https://github.com/inditilve/home-server/issues).

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

---

## Service Stacks

| Stack | Path | Services |
|-------|------|----------|
| **Networking** | [`networking/`](networking/) | Tailscale, Gluetun (NordVPN), qBittorrent |
| **Media Apps** | [`media/apps/`](media/apps/) | Plex |
| **Media Services** | [`media/services/`](media/services/) | Sonarr, Radarr, Prowlarr |
| **Monitoring** | [`monitoring/`](monitoring/) | Grafana, Prometheus, Portainer, deunhealth |
| **Dashboard** | [`dashboard/`](dashboard/) | Homepage |

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

Plex runs in `network_mode: host` for optimal LAN streaming and hardware transcoding via `/dev/dri`. It mount `/data` for media content.

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

Prometheus Node Exporter is installed **on the host** (not in Docker) for accurate host-level metrics:

```bash
sudo apt install prometheus-node-exporter
```

The Grafana dashboard is a pared-down version of [Node Exporter Full](https://grafana.com/grafana/dashboards/1860-node-exporter-full/) — import it after configuring Prometheus.

**deunhealth** watches for containers labelled `deunhealth.restart.on.unhealthy=true` and restarts them when they go unhealthy. It runs with `network_mode: none` (only needs the Docker socket).

### Dashboard — `dashboard/`

| Container | Image | Port | Purpose |
|-----------|-------|------|---------|
| `homepage` | `ghcr.io/gethomepage/homepage:latest` | 3001 | Service dashboard |

Homepage config lives in a named volume. It mounts the Docker socket to auto-discover running containers.

---

## Storage Layout (ZFS)

```
storage_pool/docker  →  /var/lib/docker    (named Docker volumes)
storage_pool/data    →  /data              (all media content)
```

Named volumes store service config under `/var/lib/docker`. All media (TV, movies, music, photos, books) lives under `/data`, mounted consistently across the respective media apps/services.

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
