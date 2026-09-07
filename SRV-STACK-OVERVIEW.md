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
Consider adding resource limits (memory, CPU) to containers to prevent any single service from consuming excessive resources.

### 3. Backup Strategies
Implement regular backups for:
- Database volumes (PostgreSQL, etc.)
- Configuration directories
- Important media libraries

### 4. Monitoring
- Use the existing Uptime Kuma and Glances services for monitoring
- Consider setting up alerts for service downtime or resource exhaustion

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

Last Updated: $(date)