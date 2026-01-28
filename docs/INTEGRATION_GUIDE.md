# Integration Guide

This guide provides detailed instructions for integrating the Local Docker Proxy with various project types and development environments.

## Table of Contents

- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Basic Integration](#basic-integration)
- [Framework-Specific Examples](#framework-specific-examples)
  - [PHP Projects](#php-projects)
  - [Node.js Applications](#nodejs-applications)
  - [Python/Django Projects](#pythondjango-projects)
  - [Static Sites](#static-sites)
- [Advanced Configuration](#advanced-configuration)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Quick Start

**Goal:** Connect your first Docker project to the proxy in under 5 minutes.

In this walkthrough, you'll expose a simple Nginx container through the proxy and access it via `https://quickstart.docker.localhost`.

### Before You Begin

Verify the proxy is running and ready:

```bash
# Check Traefik is running
docker ps | grep traefik

# Verify the network exists
docker network ls | grep traefik-proxy

# Test Traefik dashboard access
curl -k https://traefik.docker.localhost
```

**Expected output:**
- Traefik container shows as "Up"
- Network `traefik-proxy` exists
- Dashboard returns HTML (or open in browser to see the interface)

If any check fails, return to the main [README.md](../README.md) and complete the installation steps.

### Step-by-Step Integration

1. **Create a test project directory:**

   ```bash
   mkdir ~/quickstart-test && cd ~/quickstart-test
   ```

2. **Create a `compose.yml` file** with the following configuration:

   ```yaml
   services:
     web:
       image: nginx:alpine
       networks:
         - traefik-proxy
       labels:
         - "traefik.enable=true"
         - "traefik.http.routers.quickstart.rule=Host(`quickstart.docker.localhost`)"
         - "traefik.http.routers.quickstart.tls=true"

   networks:
     traefik-proxy:
       external: true
   ```

   **What this does:**
   - `image: nginx:alpine` - Uses a lightweight Nginx web server
   - `networks: traefik-proxy` - Connects to the proxy's network
   - `traefik.enable=true` - Tells Traefik to route this container
   - `Host(\`quickstart.docker.localhost\`)` - Defines the domain
   - `tls=true` - Enables HTTPS

   **Note:** No `ports:` section needed! Traefik handles all routing.

3. **Start the container:**

   ```bash
   docker compose up -d
   ```

4. **Verify the container is running:**

   ```bash
   docker compose ps
   ```

   You should see the `web` service in "Up" state.

### Verification

1. **Check Traefik recognized your service:**

   Open the Traefik dashboard at [https://traefik.docker.localhost](https://traefik.docker.localhost)

   Navigate to **HTTP Routers** section. You should see:
   - Router name: `quickstart`
   - Rule: `Host(\`quickstart.docker.localhost\`)`
   - TLS: ✓ (enabled)
   - Status: Success (green indicator)

2. **Access your application:**

   Open [https://quickstart.docker.localhost](https://quickstart.docker.localhost) in your browser.

   **Expected outcome:**
   - ✅ Browser shows "Welcome to nginx!" default page
   - ✅ Connection is secure (padlock icon in address bar)
   - ✅ No certificate warnings
   - ✅ URL shows `https://quickstart.docker.localhost`

3. **Test from command line:**

   ```bash
   curl https://quickstart.docker.localhost
   ```

   You should see the Nginx welcome page HTML.

### What You've Accomplished

In less than 5 minutes, you've:

- ✅ Connected a containerized service to the proxy
- ✅ Accessed it via a custom domain with HTTPS
- ✅ Eliminated the need for port mapping
- ✅ Verified end-to-end connectivity

### Clean Up (Optional)

To remove the test project:

```bash
cd ~/quickstart-test
docker compose down
cd ~ && rm -rf ~/quickstart-test
```

### Next Steps

- Explore [Framework-Specific Examples](#framework-specific-examples) for your stack
- Learn about [Advanced Configuration](#advanced-configuration) for custom ports and domains
- Review [Best Practices](#best-practices) for production-ready configurations

---

## Prerequisites

Before integrating your project with the Docker Proxy, ensure:

- The proxy is running (`docker compose ps` in the proxy directory)
- The `traefik-proxy` network exists
- Your project uses Docker Compose

## Basic Integration

### Minimal Configuration

To expose any containerized service through the proxy:

1. **Add the external network** to your project's `compose.yml`:

```yaml
networks:
  traefik-proxy:
    external: true
```

2. **Configure your service** with Traefik labels:

```yaml
services:
  app:
    image: your-image:tag
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app-name.rule=Host(`app-name.docker.localhost`)"
      - "traefik.http.routers.app-name.tls=true"
```

3. **Start your project:**

```bash
docker compose up -d
```

4. **Access your application** at `https://app-name.docker.localhost`

## Framework-Specific Examples

### PHP Projects

**TODO:** Add PHP/Apache and PHP-FPM/Nginx examples

### Node.js Applications

**TODO:** Add Express, Next.js, and React development server examples

### Python/Django Projects

**TODO:** Add Django and Flask examples with Gunicorn/uWSGI

### Static Sites

**TODO:** Add Nginx static site serving example

## Advanced Configuration

### Custom Port Mapping

**TODO:** Document how to configure services running on non-standard ports

### Multiple Services per Project

**TODO:** Show how to expose multiple containers from one project

### Custom Domain Configuration

**TODO:** Explain how to use custom domains beyond *.docker.localhost

### Middleware Configuration

**TODO:** Document common Traefik middleware (auth, rate limiting, etc.)

## Troubleshooting

### Common Issues

**Service not accessible**
- **TODO:** Add diagnostic steps

**Certificate warnings**
- **TODO:** Add certificate troubleshooting

**Network connectivity issues**
- **TODO:** Add network debugging steps

## Best Practices

### Naming Conventions

**TODO:** Document recommended naming patterns for routers and services

### Security Considerations

**TODO:** Document security best practices

### Performance Optimization

**TODO:** Add performance tuning tips

---

*This guide is under active development. Sections marked with TODO will be completed in upcoming updates.*
