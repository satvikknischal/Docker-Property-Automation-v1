# Nextcloud AIO (All-In-One)

Nextcloud AIO is a self-hosted cloud storage solution that provides file sync, sharing, and collaboration features.

## ⚠️ Important: How Nextcloud AIO Works

Unlike other services in this repository, **Nextcloud AIO is an orchestrator**. The `mastercontainer` you deploy will automatically create and manage several other containers:

- `nextcloud-aio-apache` - Web server (port 11000)
- `nextcloud-aio-database` - PostgreSQL database
- `nextcloud-aio-redis` - Redis cache
- `nextcloud-aio-nextcloud` - Nextcloud application
- `nextcloud-aio-notify-push` - Push notifications
- And more depending on enabled features...

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              Nginx Proxy Manager (ports 80/443)                 │
│                    cloud.yourdomain.com                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼ (proxy to host-ip:11000)
┌─────────────────────────────────────────────────────────────────┐
│              nextcloud-aio-apache (port 11000)                  │
│                  (created by mastercontainer)                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│     nextcloud-aio-mastercontainer (admin panel port 8080)       │
│           Manages all other Nextcloud containers                │
└─────────────────────────────────────────────────────────────────┘
```

## Environment Variables

Add these to your `.env` file:

```bash
# ============================================
# Nextcloud AIO Configuration
# ============================================
# Your Nextcloud domain (MUST match your NPM proxy host exactly)
NEXTCLOUD_DOMAIN=cloud.yourdomain.com

# Skip domain validation (set to true if using Cloudflare Tunnel)
NEXTCLOUD_SKIP_DOMAIN_VALIDATION=false

# AIO Admin interface port
NEXTCLOUD_AIO_PORT=8080

# Optional features (yes/no)
NEXTCLOUD_COLLABORA_ENABLED=no
NEXTCLOUD_TALK_ENABLED=no
NEXTCLOUD_IMAGINARY_ENABLED=no
NEXTCLOUD_FULLTEXTSEARCH_ENABLED=no
```

## Setup Instructions

### Step 1: Configure Environment Variables

Edit your `.env` file and set `NEXTCLOUD_DOMAIN` to your desired domain.

### Step 2: Start the Mastercontainer

```bash
cd NextCloud-AIO
docker compose up -d
```

### Step 3: Get the Admin Password

```bash
docker logs nextcloud-aio-mastercontainer 2>&1 | grep "password"
```

Or check the logs in Portainer/Docker Desktop.

### Step 4: Access AIO Admin Panel

Open `https://<your-server-ip>:8080` in your browser.

- Accept the self-signed certificate warning
- Enter the password from Step 3
- Enter your domain name when prompted

### Step 5: Configure Nginx Proxy Manager

Create a new Proxy Host in NPM:

| Setting | Value |
|---------|-------|
| **Domain Names** | `cloud.yourdomain.com` |
| **Scheme** | `https` |
| **Forward Hostname/IP** | `<your-server-ip>` (e.g., `192.168.1.100`) |
| **Forward Port** | `11000` |
| **Websockets Support** | ✅ Enabled |
| **Block Common Exploits** | ❌ **Disabled** |

#### SSL Tab
- Request a new SSL certificate or use existing
- Force SSL: ✅ Enabled
- HTTP/2 Support: ✅ Enabled

#### Advanced Tab (Custom Nginx Configuration)

```nginx
client_body_buffer_size 512k;
proxy_read_timeout 86400s;
client_max_body_size 0;
```

### Step 6: Start Nextcloud

Return to the AIO admin panel (`https://<your-server-ip>:8080`) and click **Start containers**.

Wait for all containers to start (this may take several minutes on first run).

### Step 7: Access Nextcloud

Once started, access Nextcloud at `https://cloud.yourdomain.com`

The initial admin credentials will be shown in the AIO admin panel.

## Cloudflare Tunnel Configuration

If you're using Cloudflare Tunnel instead of exposing ports directly:

1. Set `NEXTCLOUD_SKIP_DOMAIN_VALIDATION=true` in your `.env`

2. In Cloudflare Zero Trust Dashboard, add a public hostname:
   - **Subdomain**: `cloud`
   - **Domain**: `yourdomain.com`
   - **Service**: `https://<your-server-ip>:11000`
   - **Additional settings**:
     - No TLS Verify: ✅ Enabled (if using self-signed cert)
     - HTTP Host Header: `cloud.yourdomain.com`

## Troubleshooting

### "Domain validation failed"

- Ensure `NEXTCLOUD_DOMAIN` exactly matches your NPM proxy host
- If using Cloudflare Tunnel, set `NEXTCLOUD_SKIP_DOMAIN_VALIDATION=true`
- Check that NPM is properly proxying to port 11000

### "Bad Gateway" or "502 Error"

- Ensure you're proxying to the **host IP**, not `localhost` or container name
- The Apache container may not be running - check AIO admin panel
- Verify port 11000 is accessible: `curl -k https://<host-ip>:11000`

### Can't access AIO admin panel

- Ensure port 8080 is exposed and not blocked by firewall
- Access via `https://` not `http://`
- Accept the self-signed certificate warning

### Containers won't start

- Check Docker socket permissions: `ls -la /var/run/docker.sock`
- Ensure sufficient disk space and memory
- Check logs: `docker logs nextcloud-aio-mastercontainer`

## Backup & Restore

Nextcloud AIO includes built-in backup functionality accessible from the AIO admin panel.

**Backup location**: Configured during setup in the AIO admin panel.

## Updating

Nextcloud AIO handles updates automatically through the admin panel. When an update is available, you'll see a notification in the AIO interface.

To manually update the mastercontainer:

```bash
cd NextCloud-AIO
docker compose pull
docker compose up -d
```

## Port Reference

| Port | Service | Purpose |
|------|---------|---------|
| 8080 | Mastercontainer | AIO Admin interface |
| 11000 | Apache container | Nextcloud web (proxied by NPM) |
| 3478 | Talk container | Nextcloud Talk (if enabled) |

## Additional Resources

- [Nextcloud AIO GitHub](https://github.com/nextcloud/all-in-one)
- [Reverse Proxy Documentation](https://github.com/nextcloud/all-in-one/blob/main/reverse-proxy.md)
- [Nextcloud Documentation](https://docs.nextcloud.com/)

