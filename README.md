# Docker Property Automation

A comprehensive Docker Compose setup for deploying self-hosted services on Ubuntu servers. This repository is designed to be easily cloned and customized for different client deployments.

## 🚀 Quick Start

### Prerequisites

- Ubuntu Server (20.04 or later recommended)
- Docker and Docker Compose installed
- Git installed
- Root or sudo access

### Installation

1. **Clone the repository:**
   ```bash
   git clone <your-repo-url> docker-property-automation
   cd docker-property-automation
   ```

2. **Run the setup script:**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

3. **Configure the `.env` file:**
   ```bash
   nano .env  # or use your preferred editor
   ```
   - Set `BASE_DOMAIN` to your server's domain
   - Generate required secrets (use provided `openssl` commands)
   - Configure service-specific paths

4. **Deploy services:**
   ```bash
   # Start with the reverse proxy
   cd Nginx-Proxy-Manager
   docker compose up -d

   # Then deploy other services
   cd ../VaultWarden
   docker compose up -d
   ```

## 📁 Project Structure

```
.
├── .env.example              # Template configuration file
├── .env                      # Your actual configuration (not in git)
├── setup.sh                  # Interactive setup script
├── manage-all.sh             # Bulk service management
├── README.md
│
├── Nginx-Proxy-Manager/      # Reverse proxy & SSL
├── Cloudflared/              # Cloudflare Tunnel
├── Portainer/                # Docker management UI
├── NTP-Server/               # Network time server
│
├── Plex/                     # Media server
├── Frigate/                  # NVR for security cameras
├── Arr-Stack/                # Media automation
│   ├── Prowlarr/             # Indexer manager
│   ├── Radarr/               # Movies
│   ├── Sonarr/               # TV Shows
│   └── Overseerr/            # Request management
├── qBittorrent/              # Torrent client
├── SabNZBd/                  # Usenet client
│
├── Immich/                   # Photo & video management
├── NextCloud-AIO/            # Cloud storage & collaboration
├── VaultWarden/              # Password manager
├── StirlingPDF/              # PDF tools
│
├── OpenWebUI/                # LLM chat interface
├── LiteLLM/                  # LLM API proxy
├── Perplexica/               # AI search engine
├── SearXNG/                  # Privacy search
│
├── n8n/                      # Workflow automation
├── Homarr/                   # Dashboard
├── Uptime-Kuma/              # Status monitoring
│
├── Homebridge/               # HomeKit bridge
├── Whisper-STT/              # Speech-to-text
├── Piper-TTS/                # Text-to-speech
│
├── Tandoor/                  # Recipe manager
├── Book-Worms/               # Book management
│   ├── BookLore/             # Library manager
│   └── Shelfmark/            # Book downloader
│
├── Obsidian-LiveSync/        # Note sync server
└── Minecraft-Server/         # Game server
```

## 📦 Services Overview

### Infrastructure
| Service | Port | Description |
|---------|------|-------------|
| **Nginx Proxy Manager** | 80, 81, 443 | Reverse proxy with SSL management |
| **Portainer** | 9000 | Docker container management |
| **Cloudflared** | - | Cloudflare Tunnel for secure access |
| **NTP Server** | 123/UDP | Network time synchronization |
| **Uptime Kuma** | 3001 | Service status monitoring |

### Media & Entertainment
| Service | Port | Description |
|---------|------|-------------|
| **Plex** | 32400 | Media streaming server |
| **Frigate** | 8971 | AI-powered NVR for cameras |
| **Prowlarr** | 9696 | Indexer manager for *arr apps |
| **Radarr** | 7878 | Movie collection manager |
| **Sonarr** | 8989 | TV series collection manager |
| **Overseerr** | 5055 | Media request management |
| **qBittorrent** | 8080 | Torrent download client |
| **SABnzbd** | 8080 | Usenet download client |

### AI & LLM
| Service | Port | Description |
|---------|------|-------------|
| **Open WebUI** | 8080 | Chat interface for LLMs |
| **LiteLLM** | 4000 | LLM API proxy (OpenAI, Claude, etc.) |
| **Perplexica** | 3000 | AI-powered search engine |
| **Whisper STT** | 10300 | Speech-to-text (Wyoming) |
| **Piper TTS** | 10200 | Text-to-speech (Wyoming) |

### Productivity
| Service | Port | Description |
|---------|------|-------------|
| **VaultWarden** | 80 | Bitwarden-compatible password manager |
| **NextCloud AIO** | 8080 | Cloud storage & collaboration |
| **n8n** | 5678 | Workflow automation |
| **StirlingPDF** | 8080 | PDF manipulation tools |
| **Homarr** | 7575 | Service dashboard |

### Home & Utility
| Service | Port | Description |
|---------|------|-------------|
| **Homebridge** | 8581 | HomeKit bridge (host network) |
| **Immich** | 2283 | Photo & video management |
| **Tandoor** | 80 | Recipe manager |
| **Obsidian LiveSync** | 5984 | Obsidian vault sync |

### Books
| Service | Port | Description |
|---------|------|-------------|
| **BookLore** | 6060 | Book library manager |
| **Shelfmark** | 8084 | Book download manager |

### Search
| Service | Port | Description |
|---------|------|-------------|
| **SearXNG** | 8080 | Privacy-focused meta search |

### Gaming
| Service | Port | Description |
|---------|------|-------------|
| **Minecraft** | 25565 | Minecraft game server |

## ⚙️ Configuration

### Root `.env` File

All services use a shared `.env` file in the project root. Key sections include:

1. **Server Configuration** - Domain, timezone, user IDs
2. **Container Versions** - Pinned versions for all images
3. **Network Configuration** - Docker network name
4. **Service-Specific Variables** - Credentials, paths, settings

### Version Management

All container images use version variables defined in `.env`:

```bash
# Pin versions for stability
PLEX_VERSION=latest
IMMICH_VERSION=v2.5.2
LITELLM_VERSION=v1.81.0-stable

# Update and redeploy
docker compose pull
docker compose up -d
```

## 🔧 Usage

### Managing Individual Services

```bash
cd ServiceName
docker compose up -d      # Start
docker compose down       # Stop
docker compose logs -f    # View logs
docker compose pull       # Update image
docker compose restart    # Restart
```

### Managing All Services

```bash
./manage-all.sh status    # Check all services
./manage-all.sh up        # Start all
./manage-all.sh down      # Stop all
./manage-all.sh pull      # Update all images
./manage-all.sh restart   # Restart all
```

## 🌐 Network Architecture

```
                    Internet
                        │
                        ▼
            ┌───────────────────┐
            │  Cloudflare (DNS) │
            └─────────┬─────────┘
                      │
            ┌─────────▼─────────┐
            │ Nginx Proxy Mgr   │ ◄── SSL Termination
            │   (ports 80/443)  │
            └─────────┬─────────┘
                      │
         ┌────────────┴────────────┐
         │      proxy-network      │
         │                         │
    ┌────┴────┐  ┌────┴────┐  ┌───┴────┐
    │ Service │  │ Service │  │Service │
    │    A    │  │    B    │  │   C    │
    └─────────┘  └─────────┘  └────────┘
```

### Special Network Modes

| Service | Network Mode | Reason |
|---------|--------------|--------|
| **Homebridge** | `host` | mDNS/Bonjour for HomeKit discovery |
| **Minecraft** | Direct ports | Game clients need direct TCP access |
| **Plex** | Hybrid | Direct port for local network discovery |

## 🔒 Security Best Practices

1. **Never commit `.env` files** - They're in `.gitignore`
2. **Generate strong secrets** - Use provided `openssl` commands
3. **Use reverse proxy** - Route all HTTP traffic through NPM with SSL
4. **Limit port exposure** - Use `expose` instead of `ports` where possible
5. **Keep services updated** - Regularly run `docker compose pull`
6. **Backup credentials** - Store encryption keys securely

## 🐛 Troubleshooting

### Services can't communicate
```bash
# Verify network exists
docker network inspect proxy-network

# Check if service is on network
docker inspect <container_name> | grep -A 20 Networks
```

### Permission issues
```bash
# Check your user IDs
id $USER

# Update .env with correct values
PUID=1000
PGID=1000
```

### Container won't start
```bash
# Check logs
docker compose logs -f

# Verify environment variables
docker compose config
```

### Port conflicts
```bash
# Find what's using a port
sudo netstat -tulpn | grep :PORT
sudo lsof -i :PORT
```

## 📚 Service Documentation

| Service | Documentation |
|---------|---------------|
| Nginx Proxy Manager | https://nginxproxymanager.com/ |
| VaultWarden | https://github.com/dani-garcia/vaultwarden |
| Immich | https://immich.app/docs |
| Plex | https://support.plex.tv/ |
| Frigate | https://docs.frigate.video/ |
| *arr Apps | https://wiki.servarr.com/ |
| n8n | https://docs.n8n.io/ |
| LiteLLM | https://docs.litellm.ai/ |
| Tandoor | https://docs.tandoor.dev/ |
| Homebridge | https://homebridge.io/ |

## 🤝 Contributing

When adding or modifying services:

1. Follow the existing compose file patterns
2. Use `env_file: - ../.env` for root-level services
3. Add version variable to setup.sh
4. Add service to the `proxy-network`
5. Include healthcheck
6. Add compose labels
7. Document in this README


## 🆘 Support

For issues or questions, please [open an issue](your-repo-url/issues) or contact support@barium.in.
