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

PHP applications typically require a web server (Nginx or Apache) and PHP-FPM. The examples below show production-ready configurations for popular PHP frameworks.

#### Laravel with Nginx + PHP-FPM

Laravel applications work best with Nginx as a reverse proxy and PHP-FPM for processing PHP scripts.

**Directory structure:**
```
my-laravel-app/
├── compose.yml
├── docker/
│   └── nginx/
│       └── default.conf
├── Dockerfile
└── (your Laravel application files)
```

**compose.yml:**
```yaml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: laravel-app
    restart: unless-stopped
    working_dir: /var/www
    volumes:
      - ./:/var/www
    networks:
      - traefik-proxy
      - app-network
    environment:
      - DB_HOST=mysql
      - DB_DATABASE=laravel
      - DB_USERNAME=laravel
      - DB_PASSWORD=secret
      - REDIS_HOST=redis
    healthcheck:
      test: ["CMD", "php-fpm", "-t"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  nginx:
    image: nginx:alpine
    container_name: laravel-nginx
    restart: unless-stopped
    volumes:
      - ./:/var/www
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - app
    networks:
      - traefik-proxy
      - app-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.laravel.rule=Host(`laravel.docker.localhost`)"
      - "traefik.http.routers.laravel.tls=true"
      - "traefik.docker.network=traefik-proxy"

networks:
  traefik-proxy:
    external: true
  app-network:
    driver: bridge
```

**docker/nginx/default.conf:**
```nginx
server {
    listen 80;
    server_name laravel.docker.localhost;
    root /var/www/public;

    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass app:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
```

**Dockerfile:**
```dockerfile
FROM php:8.2-fpm

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip

# Install PHP extensions
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www

# Copy application files
COPY . .

# Install dependencies
RUN composer install --no-dev --optimize-autoloader

# Set permissions
RUN chown -R www-data:www-data /var/www
```

**Usage:**
```bash
docker compose up -d
```

Access your Laravel app at: `https://laravel.docker.localhost`

**Connecting to proxy's MySQL:**
To use the MySQL service from the main proxy, modify the `compose.yml`:
```yaml
services:
  app:
    # ... other config
    environment:
      - DB_HOST=mysql  # Name of the MySQL container in traefik-proxy network
      - DB_DATABASE=laravel
      - DB_USERNAME=root
      - DB_PASSWORD=root  # Use MYSQL_ROOT_PASSWORD from proxy's .env
    networks:
      - traefik-proxy  # Must be on the same network as MySQL
```

---

#### Symfony with Nginx + PHP-FPM

Symfony applications follow a similar pattern to Laravel, with adjustments for Symfony's directory structure.

**compose.yml:**
```yaml
services:
  php:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: symfony-php
    restart: unless-stopped
    working_dir: /var/www/symfony
    volumes:
      - ./:/var/www/symfony
    networks:
      - traefik-proxy
      - symfony-network
    environment:
      - DATABASE_URL=mysql://symfony:secret@mysql:3306/symfony?serverVersion=8.0
      - APP_ENV=dev
      - APP_SECRET=your-secret-key
    healthcheck:
      test: ["CMD", "php-fpm", "-t"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  nginx:
    image: nginx:alpine
    container_name: symfony-nginx
    restart: unless-stopped
    volumes:
      - ./:/var/www/symfony
      - ./docker/nginx/symfony.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - php
    networks:
      - traefik-proxy
      - symfony-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.symfony.rule=Host(`symfony.docker.localhost`)"
      - "traefik.http.routers.symfony.tls=true"
      - "traefik.docker.network=traefik-proxy"

networks:
  traefik-proxy:
    external: true
  symfony-network:
    driver: bridge
```

**docker/nginx/symfony.conf:**
```nginx
server {
    listen 80;
    server_name symfony.docker.localhost;
    root /var/www/symfony/public;

    location / {
        try_files $uri /index.php$is_args$args;
    }

    location ~ ^/index\.php(/|$) {
        fastcgi_pass php:9000;
        fastcgi_split_path_info ^(.+\.php)(/.*)$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT $realpath_root;
        internal;
    }

    location ~ \.php$ {
        return 404;
    }
}
```

**Dockerfile:**
```dockerfile
FROM php:8.2-fpm

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    libicu-dev \
    libpq-dev \
    libzip-dev

# Install PHP extensions
RUN docker-php-ext-install \
    pdo \
    pdo_mysql \
    intl \
    zip \
    opcache

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/symfony

# Copy application
COPY . .

# Install dependencies
RUN composer install --no-dev --optimize-autoloader

# Set permissions
RUN chown -R www-data:www-data /var/www/symfony/var
```

**Usage:**
```bash
docker compose up -d
```

Access your Symfony app at: `https://symfony.docker.localhost`

---

#### WordPress with MySQL

WordPress requires both a web server with PHP support and a MySQL database. This example shows WordPress connecting to the proxy's MySQL service.

**compose.yml:**
```yaml
services:
  wordpress:
    image: wordpress:latest
    container_name: wordpress
    restart: unless-stopped
    environment:
      WORDPRESS_DB_HOST: mysql
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DB_USER: root
      WORDPRESS_DB_PASSWORD: root  # Must match MYSQL_ROOT_PASSWORD from proxy
    volumes:
      - wordpress_data:/var/www/html
    networks:
      - traefik-proxy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.wordpress.rule=Host(`wordpress.docker.localhost`)"
      - "traefik.http.routers.wordpress.tls=true"

volumes:
  wordpress_data:

networks:
  traefik-proxy:
    external: true
```

**Prerequisites:**
1. Ensure the proxy's MySQL service is running with the `mysql` profile enabled
2. Create the WordPress database:

```bash
# Access MySQL container from the proxy
docker exec -it mysql mysql -uroot -proot

# In MySQL prompt:
CREATE DATABASE wordpress CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EXIT;
```

**Usage:**
```bash
docker compose up -d
```

Access WordPress at: `https://wordpress.docker.localhost`

**First-time setup:**
1. Navigate to `https://wordpress.docker.localhost`
2. Select your language
3. Complete the installation form with:
   - Site Title: Your site name
   - Username: admin username
   - Password: secure password
   - Email: your email
4. Click "Install WordPress"

**Custom PHP settings (optional):**
To customize PHP configuration, create a custom Dockerfile:

```dockerfile
FROM wordpress:latest

# Custom PHP settings
RUN echo "upload_max_filesize = 64M" > /usr/local/etc/php/conf.d/uploads.ini && \
    echo "post_max_size = 64M" >> /usr/local/etc/php/conf.d/uploads.ini && \
    echo "memory_limit = 256M" >> /usr/local/etc/php/conf.d/uploads.ini
```

Update `compose.yml`:
```yaml
services:
  wordpress:
    build:
      context: .
      dockerfile: Dockerfile
    # ... rest of configuration
```

**Using phpMyAdmin:**
If you enabled the `pma` profile in the proxy, access the database at `https://pma.docker.localhost` with:
- Server: `mysql`
- Username: `root`
- Password: `root` (or your configured password)

---

**Common PHP Configuration Notes:**

1. **Database connections:** When connecting to the proxy's MySQL/Redis services, use the container name (`mysql`, `redis`) as the host, not `localhost` or `127.0.0.1`.

2. **Multiple networks:** Services that need to communicate with both Traefik and other containers should be on both `traefik-proxy` and a private network.

3. **Environment variables:** Store sensitive data in `.env` files (excluded from git) and reference them in `compose.yml`.

4. **Volume persistence:** Use named volumes for databases and uploads to prevent data loss.

5. **Traefik network specification:** When exposing services through Traefik that are on multiple networks, add the `traefik.docker.network=traefik-proxy` label to ensure proper routing.

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
