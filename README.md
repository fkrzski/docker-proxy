# Local Docker Proxy with Traefik & HTTPS

A fully configurable, local reverse proxy for Docker development. This project eliminates port conflicts (e.g., "Port 8080 is already in use") and provides trusted SSL certificates for local domains.

It runs a single Traefik container handling routing for all local projects via custom domains (e.g., `https://my-app.docker.localhost`). Additionally, it includes optional, pre-configured services like Redis, MySQL, and phpMyAdmin.

## Prerequisites

- **OS:** Linux, macOS, or Windows WSL2
  - Linux: Tested on Debian/Ubuntu derivatives (also supports Fedora, Arch, Alpine)
  - macOS: Requires Docker Desktop for Mac
  - Windows: Requires WSL2 with Docker Desktop integration
- **Software:**
  - Docker Engine & Docker Compose
  - `curl`
  - Package manager: apt, dnf, yum, pacman, brew, or apk
  - (NSS tools and mkcert will be installed automatically by setup.sh)

## Installation

### Automated Setup (Recommended)

The provided script installs necessary dependencies (`mkcert`), generates a local Certificate Authority, creates the Docker network, and starts the proxy.

```bash
chmod +x setup.sh
./setup.sh
```

### Manual Installation

If you prefer to configure the environment manually or are using a non-Debian distribution:

1.  **Install `mkcert`**
    Follow the official instructions for your OS: [mkcert documentation](https://github.com/FiloSottile/mkcert).
    Ensure you run `mkcert -install` to generate the local Root CA.

2.  **Create Docker Network**
    ```bash
    docker network create traefik-proxy
    ```

3.  **Generate SSL Certificates**
    ```bash
    mkcert -key-file certs/local-key.pem \
      -cert-file certs/local-cert.pem \
      "localhost" "*.docker.localhost" "127.0.0.1" "::1"
    
    chmod 644 certs/local-cert.pem certs/local-key.pem
    ```

4.  **Start Proxy**
    ```bash
    docker compose up -d
    ```

Access the Traefik dashboard at [https://traefik.docker.localhost](https://traefik.docker.localhost).

## Configuration

The project is configured via a `.env` file, which is automatically created from `.env.example` during setup.

### Enabling/Disabling Services

You can control which services start by editing the `COMPOSE_PROFILES` variable in your `.env` file.

```dotenv
# Enable all services (default)
COMPOSE_PROFILES=redis,mysql,pma

# Enable only Redis
COMPOSE_PROFILES=redis

# Enable only Traefik (leave empty or remove other profiles)
COMPOSE_PROFILES=
```

**Available Profiles:**
- `redis`: Starts a Redis container.
- `mysql`: Starts a MySQL 8.0 container.
- `pma`: Starts phpMyAdmin (available at [https://pma.docker.localhost](https://pma.docker.localhost)).

### Database Configuration

- **Root Password:** Controlled by `MYSQL_ROOT_PASSWORD` in `.env`. Default is `root`.

## Usage in Projects

📖 **For comprehensive integration guides, framework-specific examples, and troubleshooting, see the [Integration Guide](docs/INTEGRATION_GUIDE.md).**

### Quick Start Example

To expose a container via this proxy, configure your project's `compose.yml` as follows:

1.  **Network:** Connect to the external `traefik-proxy` network.
2.  **Labels:** Add Traefik labels to define the router and domain.
3.  **Ports:** Do not map ports to the host (remove `ports` section unless specifically needed for other tools).

**Example Configuration:**

```yaml
services:
  web:
    image: nginx:alpine
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      # Router configuration
      - "traefik.http.routers.my-app.rule=Host(`project.docker.localhost`)"
      - "traefik.http.routers.my-app.tls=true"
      # Internal service port (if different from 80)
      # - "traefik.http.services.my-app.loadbalancer.server.port=3000"

networks:
  traefik-proxy:
    external: true
```

## Uninstallation

To remove the proxy and clean up system changes:

1.  Stop the container: `docker compose down`
2.  Remove the network: `docker network rm traefik-proxy`
3.  Uninstall local CA (optional): `mkcert -uninstall`
4.  Remove this directory.
