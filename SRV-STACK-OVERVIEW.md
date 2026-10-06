# SRV Stack Overview

This document provides an overview of the services running in the srv directory, along with configuration guidance and common troubleshooting tips.

## Services Overview

### Applications (/srv/apps/)
- **Immich**: Self-hosted photo and video backup solution
- **Nextcloud**: Self-hosted file sharing and collaboration platform

### Automation (/srv/automation/)
- **Scripts**: Various automation scripts for media management
- **Watchtower**: Automatic Docker container updates

### Home Assistant (/srv/homeasistant/ and /srv/platform/homeassistant/)
- Home Assistant: Home automation platform
- Music Assistant: Music server for Home Assistant
- Wyoming Whisper: Speech-to-text service
- Wyoming Piper: Text-to-speech service

### Infrastructure (/srv/infra/)
- DDNS-Updater: Dynamic DNS updates
- DuckDNS: Dynamic DNS service
- Nginx Proxy Manager: Reverse proxy and SSL management
- Pi-hole: Network-wide ad blocking

### Media Stack (/srv/media/media-stack/)
- VPN (Gluetun): Secure VPN tunnel
- Soulseek (slskd): Music sharing network
- Soularr: Soulseek automation
- qBittorrent: Torrent client
- Lidarr: Music collection manager
- Prowlarr: Indexer manager
- Sonarr: TV show manager
- Radarr: Movie manager
- Audiobookrequest: Audiobook downloader
- FlareSolverr: Cloudflare bypass service
- Audiobookshelf: Audiobook and podcast server
- Jellyfin: Media server

### Tools (/srv/tools/)
- Homepage: Service dashboard
- Uptime Kuma: Uptime monitoring
- Dozzle: Docker log viewer
- Glances: System monitoring

## Configuration Guidance

### Environment Variables
Many services rely on environment variables for configuration. While specific .env files are not included in this repository for security reasons, here are the key variables used:

#### Common Variables (used across multiple services):
- `TZ`: Timezone (e.g., "America/New_York")
- `PUID`: User ID for file permissions
- `PGID`: Group ID for file permissions

#### Service-Specific Variables:
See individual docker-compose.yml files for service-specific variables.

### Volumes and Paths
Services often mount host directories for persistent storage. Common patterns include:
- `${CONFIG_PATH}`: Configuration files
- `${DATA_PATH}`: Application data
- `${MEDIA_*}`: Media libraries (movies, TV, music, etc.)
- `${DOWNLOADS_*}`: Download directories

## Common Issues and Solutions

### Music Watcher Script
Fixed regex issue in `should_ignore()` function that was causing script failures.

### Flaresolverr
Corrected image name from `ghcr.io/thephaseless/byparr:latest` to `ghcr.io/flaresolverr/flaresolverr:latest`.

### VPN Privacy Features
Enabled DNS-over-HTTPS and blocking features in the Gluetun VPN service for improved privacy and security.

## Optimization Recommendations

### 1. Use Specific Image Tags
Consider replacing `:latest` tags with specific versions for production stability:
- Example: `ghcr.io/home-assistant/home-assistant:2024.1.0` instead of `latest`

### 2. Resource Limits
Resource limits (CPU + memory) are now applied to every service in the stack —
see the **Resource Limits** section below for the full table and rollout steps.

### 3. Backup Strategies
Implement regular backups for:
- Database volumes (PostgreSQL, etc.)
- Configuration directories
- Important media libraries

### 4. Monitoring
- Use the existing Uptime Kuma and Glances services for monitoring
- Consider setting up alerts for service downtime or resource exhaustion

## Log Management

### Docker Log Rotation
Container log growth is capped to prevent disk exhaustion. Every service in
the stack enforces JSON-file log rotation via its `docker-compose.yml`:

```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

Each container is limited to 3 rotated files of up to 10 MiB each (~30 MiB
per service). Existing containers must be recreated for the new logging
options to take effect:

```bash
# Recreate a single service (e.g. Uptime Kuma)
docker compose -f /srv/tools/docker-compose.yml up -d uptime-kuma

# Or apply across a whole compose project
cd /srv/tools && docker compose up -d
```

## Resource Limits

Every service in the stack declares CPU and memory limits so a single container
cannot starve the rest of the host (4 vCPU / 7.6 GiB RAM). Limits use the Compose
`deploy.resources` specification:

```yaml
deploy:
  resources:
    limits:          # hard caps enforced by the container runtime
      cpus: "1.0"
      memory: 512M
    reservations:    # guaranteed minimum; honoured by Swarm, advisory otherwise
      cpus: "0.25"
      memory: 64M
```

### How limits are enforced
- **`limits` are hard caps enforced by `docker compose up`** (non-swarm). CPU is
  enforced through the `cpu` cgroup controller; memory through the `memory`
  controller.
- **`reservations` are only honoured by Docker Swarm** (`docker stack deploy`).
  Plain `docker compose` records them but does not enforce them.
- Memory limits require a kernel/cgroup with the **memory controller** enabled.
  Check `docker info` — a `WARNING: No memory limit support` line means memory
  caps are discarded in that environment (CPU limits still apply).

### Applied limits

**apps/immich**

| Service | CPUs | Memory | CPU reserve | Mem reserve |
|---|---|---|---|---|
| immich-server | 2.0 | 2G | 0.5 | 256M |
| immich-machine-learning | 2.0 | 2G | 0.5 | 256M |
| immich (redis) | 0.5 | 256M | 0.1 | 32M |
| immich (postgres) | 1.0 | 1G | 0.25 | 128M |

**apps/nextcloud**

| Service | CPUs | Memory | CPU reserve | Mem reserve |
|---|---|---|---|---|
| db | 1.0 | 1G | 0.25 | 128M |
| redis | 0.5 | 256M | 0.1 | 32M |
| app | 2.0 | 2G | 0.5 | 256M |

**automation/watchtower**

| Service | CPUs | Memory | CPU reserve | Mem reserve |
|---|---|---|---|---|
| watchtower | 0.5 | 256M | 0.1 | 32M |

**infra**

| Service | CPUs | Memory | CPU reserve | Mem reserve |
|---|---|---|---|---|
| ddns-updater | 0.25 | 128M | 0.05 | 16M |
| duckdns | 0.25 | 128M | 0.05 | 16M |
| npm (nginx-proxy-manager) | 1.0 | 512M | 0.25 | 64M |
| pihole | 1.0 | 512M | 0.25 | 64M |

**infra/monitoring**

| Service | CPUs | Memory | CPU reserve | Mem reserve |
|---|---|---|---|---|
| loki | 1.0 | 1G | 0.25 | 128M |
| promtail | 0.5 | 256M | 0.1 | 32M |
| prometheus | 1.0 | 1G | 0.25 | 128M |
| alertmanager | 0.5 | 256M | 0.1 | 32M |
| grafana | 1.0 | 512M | 0.25 | 64M |
| node-exporter | 0.5 | 256M | 0.1 | 32M |
| cadvisor | 1.0 | 1G | 0.25 | 128M |

**media/media-stack**

| Service | CPUs | Memory | CPU reserve | Mem reserve |
|---|---|---|---|---|
| vpn (gluetun) | 1.0 | 512M | 0.25 | 64M |
| slskd | 1.0 | 1G | 0.25 | 128M |
| soularr | 0.5 | 256M | 0.1 | 32M |
| qbittorrent | 1.0 | 1G | 0.25 | 128M |
| lidarr | 1.0 | 512M | 0.25 | 64M |
| prowlarr | 1.0 | 512M | 0.25 | 64M |
| sonarr | 1.0 | 512M | 0.25 | 64M |
| radarr | 1.0 | 512M | 0.25 | 64M |
| audiobookrequest | 0.5 | 512M | 0.1 | 64M |
| byparr | 1.0 | 1G | 0.25 | 128M |
| audiobookshelf | 1.0 | 1G | 0.25 | 128M |
| jellyfin | 2.0 | 2G | 0.5 | 256M |

**platform/homeassistant**

| Service | CPUs | Memory | CPU reserve | Mem reserve |
|---|---|---|---|---|
| home-assistant | 2.0 | 2G | 0.5 | 256M |
| music-assistant | 1.0 | 1G | 0.25 | 128M |
| whisper | 2.0 | 2G | 0.5 | 256M |
| piper | 1.0 | 512M | 0.25 | 64M |

**tools**

| Service | CPUs | Memory | CPU reserve | Mem reserve |
|---|---|---|---|---|
| homepage | 0.5 | 512M | 0.1 | 64M |
| uptime-kuma | 1.0 | 512M | 0.25 | 64M |
| dozzle | 0.5 | 256M | 0.1 | 32M |
| glances | 0.5 | 256M | 0.1 | 32M |

### Applying and adjusting limits

Existing containers keep their current settings until they are recreated:

```bash
# Recreate one project so the limits take effect
cd /srv/media/media-stack && docker compose up -d

# Verify a container's effective CPU limit (NanoCpus = cores x 1e9)
docker inspect -f '{{.HostConfig.NanoCpus}}' jellyfin
```

Start conservative, monitor actual usage in Grafana (**Dashboards → SRV Stack →
Container Overview**) or with `docker stats`, and raise a service's limits if it
regularly approaches its cap.

## Observability Stack (Loki + Prometheus + Grafana)

A full observability stack is scaffolded at `/srv/infra/monitoring/`:

### Components
- **Loki** (port 3100) - Log aggregation from all Docker containers via Promtail
- **Prometheus** (port 9090) - Metrics collection with pre-configured scrape targets for all SRV services
- **Alertmanager** (port 9093) - Alert routing, grouping, and deduplication
- **Grafana** (port 3000) - Dashboards with pre-provisioned datasources and 3 starter dashboards
- **Promtail** - Ships Docker container logs to Loki with rich labels
- **Node Exporter** - Host-level metrics (CPU, memory, disk, network)
- **cAdvisor** - Container-level metrics

### Quick Deploy
```bash
# 1. Create data directories
sudo mkdir -p /mnt/monitoring/{loki,prometheus,alertmanager,grafana}
sudo chown -R 472:472 /mnt/monitoring/grafana

# 2. Configure
cp /srv/infra/monitoring/.env.example /srv/infra/monitoring/.env
# Edit .env (set GRAFANA_ADMIN_PASSWORD at minimum)

# 3. Deploy
cd /srv/infra/monitoring && docker compose up -d
```

### Pre-built Dashboards
On first Grafana login (admin / password from .env), find under **Dashboards → SRV Stack**:
1. **Host Overview** - System health: CPU, memory, disk, network, service up/down
2. **Container Overview** - Per-container CPU, memory, network I/O, disk I/O, restart rates
3. **Logs Overview** - Live error stream, log volume by container, log level distribution

### Alerting
Prometheus rules at `infra/monitoring/prometheus/rules/alerts.yml` cover:
- Host: CPU, memory, disk, down
- Containers: down, high CPU/memory, restart loops
- Services: Immich uploads, Nextcloud space, Jellyfin transcoding, Pi-hole block rate
- Monitoring stack self-health

Configure notification channels in `infra/monitoring/alertmanager/alertmanager.yml` (email, Slack, Discord, etc.).

See `infra/monitoring/README.md` for full documentation.

## Services Overview
## Security Recommendations

### 1. Regular Updates
- Use Watchtower or similar service to keep containers updated
- Regularly update the host system

### 2. Network Segmentation
- Consider separating services into different networks based on sensitivity
- The media stack already uses VPN isolation for torrent-related services

### 3. Access Controls
- Ensure proper file permissions on mounted volumes
- Consider using separate users/groups for different services where appropriate

## Troubleshooting

### Checking Service Logs
```bash
# View logs for a specific service
docker-compose -f /path/to/docker-compose.yml logs -f service_name

# Or if using docker directly
docker logs -f container_name
```

### Common Commands
```bash
# List running containers
docker ps

# Check disk usage
docker system df

# Prune unused resources
docker system prune -a
```

## Getting Help

For issues with specific services, consult their official documentation:
- Immich: https://immich.app/docs/
- Home Assistant: https://www.home-assistant.io/documentation/
- Jellyfin: https://jellyfin.org/documentation
- And similarly for other services

Last Updated: 2026-10-06