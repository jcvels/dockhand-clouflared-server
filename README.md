# Dockhand Server Config

Run [Dockhand](https://dockhand.pro) — a modern Docker management UI — on your own server, exposed securely to the internet through a **Cloudflare Tunnel** and a **Traefik** reverse proxy.

## Architecture

| Service            | Container name     | Image                         | Purpose                                     |
| ------------------ | ------------------ | ----------------------------- | ------------------------------------------- |
| Traefik            | `srv-reverse-proxy`| `traefik:latest`              | Reverse proxy, routes traffic to Dockhand   |
| Cloudflare Tunnel  | `srv-tunnel`       | `cloudflare/cloudflared:latest`| Exposes your services over a Cloudflare Tunnel |
| Dockhand           | `srv-dockhand`     | `fnsys/dockhand:latest`       | Docker management UI (internal port 3000)   |

All services share the `proxied` Docker network.

## Prerequisites

- A machine with **Docker** and **Docker Compose** installed.
- A domain hosted on **Cloudflare** (e.g. `app.example.com`).
- A **Cloudflare Tunnel token**. Create one in the Cloudflare dashboard: *Zero Trust → Networks → Tunnels → Create a tunnel* (Cloudflare-managed connector), then copy the tunnel token.

## Configuration

The stack reads two environment variables from a `.env` file:

| Variable          | Description                                            | Example            |
| ----------------- | ------------------------------------------------------ | ------------------ |
| `TUNNEL_TOKEN`    | Cloudflare Tunnel token that connects this server to your tunnel | `eyJ...` |
| `DOCKHAND_DOMAIN` | The public domain where Dockhand will be accessible     | `app.example.com`  |

Dockhand data (SQLite database, settings, stacks) is stored locally in the `./dockhand` folder, which is mounted into the container.

## Setup

### Option A: Automatic (recommended)

Run the setup script — it prompts for the two values and creates `.env` and the `./dockhand` folder for you:

```bash
chmod +x setup.sh
./setup.sh
```

### Option B: Manual

Copy the example file and fill in your values:

```bash
cp .env.example .env
mkdir -p dockhand
```

Then edit `.env`:

```
TUNNEL_TOKEN=your_cloudflare_tunnel_token
DOCKHAND_DOMAIN=app.example.com
```

> The `.env` file is git-ignored. Never commit real credentials.

## Start

```bash
docker compose up -d
```

Verify everything is running:

```bash
docker compose ps
```

The Cloudflare Tunnel automatically exposes the domain; make sure a DNS route for `DOCKHAND_DOMAIN` points at your tunnel (the tunnel will create this route for you).

## Expose Your Own Apps

Traefik only routes containers that are explicitly labeled — it runs with `--providers.docker.exposedbydefault=false`. To expose another app through the same reverse proxy, attach it to the `proxied` network and add these labels:

- `traefik.enable=true`
- `traefik.http.routers.<app-name>.rule=Host(`<app-host>.<your-domain>`)`

For example, to expose an app at `myapp.example.com`:

```yaml
services:
  myapp:
    image: nginx:latest
    networks:
      - proxied
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.example.com`)"
      - "traefik.http.services.myapp.loadbalancer.server.port=80"
```

Notes:

- Replace `<app-name>` with a unique name per app and `<app-host>.<your-domain>` with the subdomain you want (it resolves through the same Cloudflare Tunnel DNS setup).
- Add `traefik.http.services.<app-name>.loadbalancer.server.port=<port>` only if the app listens on a port other than 80.
- The container **must** be on the `proxied` network so Traefik can reach it.

## First Use

1. Open `https://<DOCKHAND_DOMAIN>` (e.g. `https://app.example.com`).
2. Register the **first account** — it automatically becomes the administrator with full access.
3. From the dashboard you can manage containers, compose stacks, images, volumes, logs, and more.

## Common Commands

```bash
# View logs
docker compose logs -f srv-dockhand

# Restart a service
docker compose restart srv-dockhand

# Stop the stack
docker compose down

# Update Dockhand to the latest image
docker compose pull srv-dockhand && docker compose up -d srv-dockhand
```

## Troubleshooting

**The site doesn't load / `ERR_CONNECTION_CLOSED`.**
Check that the tunnel is healthy in the Cloudflare dashboard and that `TUNNEL_TOKEN` is correct, then restart the tunnel:

```bash
docker compose restart srv-tunnel
docker compose logs srv-tunnel
```

**DNS doesn't resolve.**
Make sure the domain in `DOCKHAND_DOMAIN` matches the one routed through your tunnel, and that the DNS record is on Cloudflare.

**Dockhand is up but the UI shows errors.**
Check the Dockhand container logs:

```bash
docker compose logs -f srv-dockhand
```

## Security Note

Dockhand mounts the Docker socket (`/var/run/docker.sock`), which gives it full control over the Docker daemon on this host. Only expose Dockhand to users you trust, and use strong admin credentials. The tunnel is the only way in — there is no public port forwarded to Dockhand itself.
