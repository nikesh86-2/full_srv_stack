# Monitoring Stack: Loki + Prometheus + Grafana

A complete observability stack for the SRV stack, providing:
- **Loki** - Log aggregation (port 3100)
- **Prometheus** - Metrics collection & alerting (port 9090)
- **Alertmanager** - Alert routing & deduplication (port 9093)
- **Grafana** - Dashboards & visualization (port 3000)
- **Promtail** - Log shipper (Docker → Loki)
- **Node Exporter** - Host metrics
- **cAdvisor** - Container metrics

## Quick Start

```bash
# 1. Create data directories
sudo mkdir -p /mnt/monitoring/{loki,prometheus,alertmanager,grafana}
sudo chown -R 472:472 /mnt/monitoring/grafana  # Grafana runs as UID 472

# 2. Configure environment
cp /srv/infra/monitoring/.env.example /srv/infra/monitoring/.env
# Edit .env with your values (especially GRAFANA_ADMIN_PASSWORD)

# 3. Deploy
cd /srv/infra/monitoring
docker compose up -d

# 4. Verify
docker compose ps
docker compose logs -f
```

## Access URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://localhost:3002 | admin / (from .env) |
| Prometheus | http://localhost:9091 | — |
| Alertmanager | http://localhost:9093 | — |
| Loki | http://localhost:3100 | — |
| cAdvisor | http://localhost:8082 | — |

## Pre-configured Dashboards

On first Grafana login, you'll find these dashboards under **Dashboards → SRV Stack**:

1. **Host Overview** - CPU, memory, disk, network, service status
2. **Container Overview** - Per-container CPU, memory, network, disk I/O, restarts
3. **Logs Overview** - Live error logs, log volume, log level distribution

## Alerting

Alerting rules are in `/srv/infra/monitoring/prometheus/rules/alerts.yml`:

- **Host alerts**: CPU, memory, disk, host down
- **Container alerts**: Down, high CPU/memory, restart loops
- **Service alerts**: Immich, Nextcloud, Jellyfin, Pi-hole specific
- **Monitoring alerts**: Prometheus/Loki/Grafana/Alertmanager health

### Configure Notifications

Edit `/srv/infra/monitoring/alertmanager/alertmanager.yml` and uncomment/configure:

```yaml
receivers:
  - name: 'critical-alerts'
    email_configs:
      - to: 'oncall@example.com'
        smarthost: 'smtp.example.com:587'
        auth_username: 'alertmanager'
        auth_password: '${EMAIL_PASSWORD}'

  - name: 'default'
    slack_configs:
      - api_url: '${SLACK_WEBHOOK_URL}'
        channel: '#alerts'
```

Then reload: `docker compose exec alertmanager alertmanager --config.file=/etc/alertmanager/alertmanager.yml --reload`

## Adding Service Metrics

For each service you want to monitor, ensure it exposes a `/metrics` endpoint. The Prometheus config (`prometheus/prometheus.yml`) already includes scrape configs for:

- Immich (`immich_server:2283/api/stats/metrics`)
- Nextcloud (`nextcloud-app:80/metrics`)
- Home Assistant (`home-assistant:8123/api/prometheus`)
- Jellyfin (`jellyfin:8096/Metrics/Prometheus`)
- Audiobookshelf (`audiobookshelf:80/api/metrics/prometheus`)
- Nginx Proxy Manager (`nginx-proxy-manager:81/metrics`)
- Pi-hole (`pihole:80/admin/api.php?prometheus`)
- Glances (`glances:61208/api/3/metrics/prometheus`)
- Watchtower (`watchtower:8080/metrics`)
- Uptime Kuma (`uptime-kuma:3001/api/metrics`)
- Media stack services (Sonarr, Radarr, etc.)

For services without native Prometheus endpoints, consider:
1. Exporter sidecars (e.g., `prometheus-community/postgres-exporter`)
2. Application-level metrics libraries
3. cAdvisor container metrics (always available)

## Log Aggregation (Loki)

Promtail ships all Docker container logs to Loki with labels:
- `container_name`, `container_image`
- `compose_project`, `compose_service`

### Query Examples (LogQL)

```logql
# All errors across all containers
{job="docker"} |= "error"

# Errors from specific service
{job="docker", compose_service="immich-server"} |= "error"

# Rate of errors by container
sum by(container_name) (rate({job="docker"} |= "error" [5m]))

# Search for specific pattern
{job="docker"} |~ "(?i)(exception|fatal|critical)"
```

## Data Retention

| Component | Retention | Config Location |
|-----------|-----------|-----------------|
| Loki | 7 days (configurable) | `loki/local-config.yaml` |
| Prometheus | 15 days | `docker-compose.yml` command |
| Grafana | Indefinite (dashboards) | — |
| Alertmanager | Indefinite | — |

To adjust Loki retention, edit `limits_config.retention_period` in `loki/local-config.yaml`.

## Maintenance

```bash
# Update images
docker compose pull && docker compose up -d

# Backup Grafana dashboards/datasources
docker compose exec grafana grafana-cli admin export-dashboard --dashboard=* --path=/tmp

# Reset Prometheus data (caution!)
docker compose down prometheus && rm -rf /mnt/monitoring/prometheus/* && docker compose up -d prometheus
```

## Network Integration

The monitoring stack creates a `monitoring` network. To scrape metrics from services in other compose files:

1. **Option A**: Add services to the monitoring network
   ```yaml
   # In your service's docker-compose.yml
   networks:
     - monitoring
   networks:
     monitoring:
       external: true
   ```

2. **Option B**: Use host networking (already configured for node-exporter)

3. **Option C**: Expose metrics ports on host and scrape via `host.docker.internal`

## Troubleshooting

**Grafana can't connect to Loki/Prometheus**: Ensure all containers are on the `monitoring` network and use service names (e.g., `http://loki:3100`).

**No logs in Loki**: Check Promtail logs: `docker compose logs promtail`. Verify `/var/lib/docker/containers` is mounted.

**Prometheus scrape failures**: Check targets at `http://localhost:9090/targets`. Ensure metrics endpoints are accessible from the monitoring network.

**High disk usage**: Adjust retention in Loki/Prometheus configs. Loki chunks in `/mnt/monitoring/loki/chunks`.