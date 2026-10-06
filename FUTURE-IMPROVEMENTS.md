# Future Improvements for SRV Stack

This document outlines recommended future improvements for the SRV stack, organized by implementation timeline.

### 3. Implement Resource Limits — ✅ Implemented
**Problem:** Without resource limits, a single service could consume excessive resources and impact others.
**Solution:**
- Add memory and CPU limits to Docker Compose configurations
- Start with conservative limits based on observed usage
- Example:
  ```yaml
  deploy:
    resources:
      limits:
        cpus: "1.0"
        memory: 2G
        reservations:
          cpus: "0.5"
          memory: 1G
  ```
- Consider using `mem_limit` and `cpu_quota` for version 2 Compose files
- Monitor and adjust limits based on actual usage patterns

**Status:** ✅ Implemented across all 39 services in every `docker-compose.yml`.
Each service now declares `deploy.resources.limits` (CPU + memory) plus
`reservations`, sized conservatively from observed usage on the host
(4 vCPU / 7.6 GiB RAM). See the **Resource Limits** section of
`SRV-STACK-OVERVIEW.md` for the full table and rollout instructions.

> **Notes:**
> - Under plain `docker compose` (non-swarm): `limits.cpus` is enforced and
>   `reservations.memory` is applied as a cgroup memory soft limit, while
>   `limits.memory` requires the host memory cgroup controller and
>   `reservations.cpus` is advisory only.
> - Existing containers must be recreated (`docker compose up -d`) for the
>   limits to take effect.
> - Memory limits require a host kernel/cgroup with the memory controller
>   available (check `docker info` for `WARNING: No memory limit support`).

## ⚙️ Medium-term Improvements (3-12 months)

### 1. Automated Backup Scripts
**Problem:** Manual backup processes are error-prone and inconsistent.
**Solution:**
- Implement automated backup scripts for:
  - Database volumes (PostgreSQL, MariaDB, etc.)
  - Configuration directories
  - Critical application data (Immich library, Nextcloud data, etc.)
- Use tools like `restic`, `borgbackup`, or simple `rsync`/`tar` scripts
- Implement rotation policies (daily, weekly, monthly backups)
- Store backups in multiple locations (local + remote/cloud)
- Example backup script structure:
  ```bash
  #!/usr/bin/env bash
  BACKUP_DIR="/mnt/backups/srv-stack"
  TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
  
  # Backup databases
  docker exec srv-stack-postgres-1 pg_dumpall -U postgres > "$BACKUP_DIR/postgres-$TIMESTAMP.sql"
  
  # Backup configs
  tar -czf "$BACKUP_DIR/configs-$TIMESTAMP.tar.gz" \
    /srv/apps/immich/.env \
    /srv/apps/nextcloud/.env \
    /srv/media/media-stack/*.conf
  
  # Apply retention policy
  find "$BACKUP_DIR" -type f -mtime +30 -delete
  ```

### 2. Enhanced Monitoring & Alerting
**Problem:** Current monitoring (Uptime Kuma, Glances) lacks proactive alerting.
**Solution:**
- Configure Uptime Kuma alert notifications (email, Discord, Slack, etc.)
- Set up service-specific health checks in Uptime Kuma
- Implement log aggregation and monitoring:
  - Consider Loki/Prometheus/Grafana stack
  - Or use simpler solutions like GoAccess for web logs
- Create dashboards for key metrics:
  - Service uptime/response times
  - Resource usage (CPU, memory, disk, network)
  - Application-specific metrics (e.g., Immich upload rates, Nextcloud active users)
- [x] Implement log rotation policies to prevent disk exhaustion
  - Docker `json-file` logging with `max-size: 10m` / `max-file: 3` added to all services (see `SRV-STACK-OVERVIEW.md`)
- [x] Scaffold Loki/Prometheus/Grafana observability stack
  - Complete stack at `infra/monitoring/` with docker-compose, configs, dashboards, alerting rules
  - See `infra/monitoring/README.md` for deployment guide

### 3. Add Health Checks to Services
**Problem:** Some services lack proper health checks, making failure detection difficult.
**Solution:**
- Add or improve healthcheck sections in Docker Compose files
- Use appropriate health check commands for each service:
  - Web services: `curl -f http://localhost:PORT/health || exit 1`
  - Databases: `pg_isready -U postgres` or `mysqladmin ping`
  - Custom apps: Check for specific endpoints or process states
- Example:
  ```yaml
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8080/api/status"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 40s
  ```

## 🔒 Long-term Improvements (12+ months)

### 1. Security Hardening
**Problem:** Current configuration may have unnecessary privileges and attack surface.
**Solution:**
- Implement read-only root filesystem where possible:
  ```yaml
  read_only: true
  tmpfs:
    - /tmp
    - /var/log
  ```
- Drop unnecessary Linux capabilities:
  ```yaml
  cap_drop:
    - ALL
  cap_add:
    - NET_BIND_SERVICE  # Only if needed
  ```
- Use Docker secrets for sensitive credentials:
  ```yaml
  secrets:
    - db_password
    - api_key
  secrets:
    db_password:
      external: true
  ```
- Implement user namespace remapping for better isolation
- Regularly scan images for vulnerabilities (Trivy, Grype, etc.)
- Implement automated security updates for base OS and Docker

### 2. Improved Network Segmentation
**Problem:** Current network structure may not adequately isolate services by sensitivity/trust level.
**Solution:**
- Create separate Docker networks for different trust zones:
  - `public`: Exposed services (Homepage, Uptime Kuma)
  - `internal`: Internal services (databases, caching)
  - `media`: Media stack services (with VPN)
  - `homeassistant`: Home automation and IoT services
- Implement network aliases and internal DNS for service discovery
- Consider using reverse proxy (Nginx Proxy Manager) for all external access
- Implement service mesh concepts for complex inter-service communication
- Use network policies to restrict inter-service communication where appropriate

### 3. Comprehensive Backup Validation & Disaster Recovery
**Problem:** Backups may not be regularly tested, and DR procedures are undocumented.
**Solution:**
- Implement automated backup validation:
  - Regularly restore backups to test environments
  - Validate data integrity (checksums, row counts, etc.)
  - Test application functionality with restored data
- Create detailed disaster recovery runbooks:
  - Step-by-step recovery procedures for various failure scenarios
  - Contact information and escalation procedures
  - RTO (Recovery Time Objective) and RPO (Recovery Point Objective) definitions
- Implement geo-redundant backups for critical data
- Consider implementing chaos engineering practices to test resilience
- Regular DR drills to ensure team readiness

## 📋 Implementation Prioritization

### **Immediate Actions (Next 2 weeks):**
1. [x] Create `.env.example` files for all services
3. [x] Add basic resource limits to high-usage services

### **Short-term Goals (Next 3 months):**
1. [ ] Complete version pinning for all services
2. [x] Implement resource limits across all services
3. [ ] Set up automated backup scripts for databases
4. [ ] Configure Uptime Kuma alerting

### **Medium-term Goals (Next 6-12 months):**
1. [ ] Implement comprehensive backup validation
2. [ ] Enhance monitoring with custom metrics and dashboards
3. [ ] Add health checks to all services
4. [ ] Begin security hardening initiatives

### **Long-term Goals (Ongoing):**
1. [ ] Complete security hardening implementation
2. [ ] Implement advanced network segmentation
3. [ ] Establish regular DR testing schedule
4. [ ] Continuously monitor and improve based on usage patterns

## 📊 Success Metrics

Track these metrics to measure improvement over time:
- **Mean Time To Recovery (MTTR):** Target: < 30 minutes
- **Backup Success Rate:** Target: 100%
- **Security Findings (Critical/High):** Target: 0 critical, < 5 medium per month
- **Resource Utilization:** Target: < 80% average CPU/Memory usage
- **Service Uptime:** Target: > 99.9% monthly
- **User Satisfaction:** Qualitative feedback from users

## 🔄 Review Process

This document should be reviewed and updated:
- Quarterly: Assess progress and adjust priorities
- After major incidents: Update based on lessons learned
- When adding new services: Ensure new additions follow established patterns
- Annually: Comprehensive review of all improvement categories

Last Updated: 2026-10-06
Next Review: 2027-01-06
