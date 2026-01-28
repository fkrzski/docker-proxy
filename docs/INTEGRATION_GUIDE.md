# Integration Guide

This guide provides detailed instructions for integrating the Local Docker Proxy with various project types and development environments.

## Table of Contents

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
