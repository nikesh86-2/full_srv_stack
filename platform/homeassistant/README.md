## 📸 Visuals & Dashboards
View my custom Lovelace UI and Music Assistant setup in the [Screenshots Gallery](./docs/SCREENSHOTS.md).

# - Home Automation & Infrastructure

This repository contains my personal **Home Assistant** and **Music Assistant** configuration. It is managed via Docker Compose and follows an **Infrastructure-as-Code (IaC)** approach.

## - Architecture

The project is built around two primary containers managed by a central `docker-compose.yml` file.

* **Home Assistant:** The central brain for device state, automations, and frontend dashboard management.
* **Music Assistant:** An abstraction layer managing multi-room audio and media library synchronization.

---

## - Installation & Setup

### 1. Clone the Repository

git clone [https://github.com/nikesh86-2/Home-Music-assistant_setup.git](https://github.com/nikesh86-2/Home-Music-assistant_setup.git)
cd Home-Music-assistant_setup

### 2. Environment Configuration
System Variables: Copy .env.example to .env and update PUID, PGID.

Secrets: Create config/secrets.yaml for sensitive credentials.

### 3. Deploy

docker compose up -d

## - Key Technical Features
Modular Configuration
Separating concerns into logical files for better maintenance:

masterlights.yaml & switches.yaml: Entity management.

templates.yaml: Custom Jinja2 logic.

scripts.yaml & automations.yaml: Business logic.

Custom Frontend (Lovelace)
YAML Mode: Full version control of dashboard layouts.

Custom Cards: Utilizing Bubble-Card, Mushroom, and Mini-graph-card.

## - Networking: Host Mode
To ensure seamless integration with the local IoT ecosystem, this stack utilizes Docker Host Networking.

mDNS & Discovery: Essential for discovering Google Cast and DLNA devices.

Low Latency: Music Assistant requires direct network access to prevent jitter.

## Security 
Processes run as a non-root user (PUID/PGID: 1002).

## Project Structure
```
.
├── config/                 # Home Assistant core configuration
│   ├── custom_components/  # HACS and custom integrations
│   ├── dashboards/         # Version-controlled YAML UI layouts
│   ├── configuration.yaml  # Main entry point
│   └── secrets.yaml        # [GIT IGNORED] Sensitive credentials
├── ma-config/              # Music Assistant persistent data
└── docker-compose.yml      # Service orchestration
