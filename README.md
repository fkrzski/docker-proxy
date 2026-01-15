# Local Docker Proxy with Traefik & HTTPS

A fully configurable, local reverse proxy for Docker development. This project eliminates port conflicts (e.g., "Port 8080 is already in use") and provides trusted SSL certificates for local domains.

It runs a single Traefik container handling routing for all local projects via custom domains (e.g., `https://my-app.localhost`).

## Prerequisites

- **OS:** Linux (Script optimized for Debian/Ubuntu derivatives).
- **Software:**
  - Docker Engine & Docker Compose
  - `curl`
  - `libnss3-tools` (Required for browser certificate trust management)

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
      "localhost" "*.localhost" "traefik.localhost" "127.0.0.1" "::1"
    
    chmod 644 certs/local-cert.pem certs/local-key.pem
    ```

4.  **Start Proxy**
    ```bash
    docker compose up -d
    ```

Access the Traefik dashboard at [https://traefik.localhost](https://traefik.localhost).

## Usage in Projects

To expose a container via this proxy, configure your project's `docker-compose.yml` as follows:

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
      - "traefik.http.routers.my-app.rule=Host(`project.localhost`)"
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
