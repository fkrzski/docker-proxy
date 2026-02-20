# Integration Guide

This guide provides detailed instructions for integrating the Local Docker Proxy with various project types and
development environments.

## Table of Contents

- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Basic Integration](#basic-integration)
- [Framework-Specific Examples](#framework-specific-examples)
    - [PHP Projects](#php-projects)
    - [Node.js Applications](#nodejs-applications)
    - [Python/Django Projects](#pythondjango-projects)
    - [Static Sites](#static-sites)
    - [Go Applications](#go-applications)
- [Common Scenarios](#common-scenarios)
    - [Multi-Service Project (Frontend + Backend)](#multi-service-project-frontend--backend)
    - [Using Proxy-Provided MySQL and Redis](#using-proxy-provided-mysql-and-redis)
    - [Using Proxy-Provided Mailpit Email Testing](#using-proxy-provided-mailpit-email-testing)
    - [Custom Domain Patterns](#custom-domain-patterns)
    - [Path-Based Routing](#path-based-routing)
    - [Multiple Domains for One Service](#multiple-domains-for-one-service)
- [Advanced Configuration](#advanced-configuration)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [FAQ](#faq)

## Quick Start

**Goal:** Connect your first Docker project to the proxy in under 5 minutes.

In this walkthrough, you'll expose a simple Nginx container through the proxy and access it via
`https://quickstart.docker.localhost`.

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
    - `Host('quickstart.docker.localhost')` - Defines the domain
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
    - Rule: `Host('quickstart.docker.localhost')`
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

PHP applications typically require a web server (Nginx or Apache) and PHP-FPM. The examples below show production-ready
configurations for popular PHP frameworks.

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
      test: [ "CMD", "php-fpm", "-t" ]
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
      test: [ "CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost/" ]
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
      test: [ "CMD", "php-fpm", "-t" ]
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
      test: [ "CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost/" ]
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

WordPress requires both a web server with PHP support and a MySQL database. This example shows WordPress connecting to
the proxy's MySQL service.

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
      test: [ "CMD", "curl", "-f", "http://localhost/" ]
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

1. **Database connections:** When connecting to the proxy's MySQL/Redis services, use the container name (`mysql`,
   `redis`) as the host, not `localhost` or `127.0.0.1`.

2. **Multiple networks:** Services that need to communicate with both Traefik and other containers should be on both
   `traefik-proxy` and a private network.

3. **Environment variables:** Store sensitive data in `.env` files (excluded from git) and reference them in
   `compose.yml`.

4. **Volume persistence:** Use named volumes for databases and uploads to prevent data loss.

5. **Traefik network specification:** When exposing services through Traefik that are on multiple networks, add the
   `traefik.docker.network=traefik-proxy` label to ensure proper routing.

### Node.js Applications

Node.js applications can run directly with Node or through process managers like PM2. The examples below cover popular
frameworks with both development and production configurations.

#### Express.js Application

Express.js applications typically run on port 3000 by default. This example shows a simple Express app with custom port
configuration.

**Directory structure:**

```
my-express-app/
├── compose.yml
├── Dockerfile
├── package.json
├── app.js
└── (other application files)
```

**compose.yml:**

```yaml
services:
  express:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: express-app
    restart: unless-stopped
    environment:
      - NODE_ENV=development
      - PORT=3000
    volumes:
      - ./:/app
      - /app/node_modules
    networks:
      - traefik-proxy
    healthcheck:
      test: [ "CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/health" ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.express.rule=Host(`express.docker.localhost`)"
      - "traefik.http.routers.express.tls=true"
      - "traefik.http.services.express.loadbalancer.server.port=3000"

networks:
  traefik-proxy:
    external: true
```

**Dockerfile:**

```dockerfile
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy application files
COPY . .

# Expose port
EXPOSE 3000

# Start application
CMD ["npm", "start"]
```

**app.js (minimal example):**

```javascript
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

// Health check endpoint (required for healthcheck)
app.get('/health', (req, res) => {
  res.status(200).json({status: 'ok'});
});

// Main route
app.get('/', (req, res) => {
  res.json({message: 'Hello from Express!'});
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

**package.json:**

```json
{
    "name": "express-docker-app",
    "version": "1.0.0",
    "scripts": {
        "start": "node app.js",
        "dev": "nodemon app.js"
    },
    "dependencies": {
        "express": "^4.18.2"
    },
    "devDependencies": {
        "nodemon": "^3.0.1"
    }
}
```

**Usage:**

```bash
docker compose up -d
```

Access your Express app at: `https://express.docker.localhost`

**Development mode with hot reload:**
To enable hot reload during development, modify the `compose.yml`:

```yaml
services:
  express:
    # ... other config
    command: npm run dev
    volumes:
      - ./:/app
      - /app/node_modules  # Prevents overwriting node_modules
    environment:
      - NODE_ENV=development
```

**Custom port configuration:**
If your Express app runs on a different port (e.g., 8080):

```yaml
services:
  express:
    environment:
      - PORT=8080
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.express.rule=Host(`express.docker.localhost`)"
      - "traefik.http.routers.express.tls=true"
      - "traefik.http.services.express.loadbalancer.server.port=8080"  # Match your port
```

---

#### Next.js Application

Next.js applications require special consideration for hot reload and development server configuration. This example
includes both development and production setups.

**Directory structure:**

```
my-nextjs-app/
├── compose.yml
├── Dockerfile
├── Dockerfile.dev
├── next.config.js
├── package.json
└── (Next.js application files)
```

**compose.yml (Development):**

```yaml
services:
  nextjs:
    build:
      context: .
      dockerfile: Dockerfile.dev
    container_name: nextjs-app
    restart: unless-stopped
    environment:
      - NODE_ENV=development
      - WATCHPACK_POLLING=true  # Enable hot reload in Docker
    volumes:
      - ./:/app
      - /app/node_modules
      - /app/.next
    networks:
      - traefik-proxy
    healthcheck:
      test: [ "CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/" ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.nextjs.rule=Host(`nextjs.docker.localhost`)"
      - "traefik.http.routers.nextjs.tls=true"
      - "traefik.http.services.nextjs.loadbalancer.server.port=3000"

networks:
  traefik-proxy:
    external: true
```

**Dockerfile.dev:**

```dockerfile
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci

# Copy application files
COPY . .

# Expose port
EXPOSE 3000

# Start development server
CMD ["npm", "run", "dev"]
```

**Dockerfile (Production):**

```dockerfile
FROM node:20-alpine AS builder

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci

# Copy application and build
COPY . .
RUN npm run build

# Production image
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

# Copy built files
COPY --from=builder /app/next.config.js ./
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

EXPOSE 3000

CMD ["node", "server.js"]
```

**next.config.js:**

```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
    // Enable standalone output for Docker
    output: 'standalone',

    // Required for hot reload in Docker
    webpackDevMiddleware: config => {
      config.watchOptions = {
        poll: 1000,
        aggregateTimeout: 300,
      }
      return config
    },
  }

module.exports = nextConfig
```

**package.json:**

```json
{
    "name": "nextjs-docker-app",
    "version": "1.0.0",
    "scripts": {
        "dev": "next dev",
        "build": "next build",
        "start": "next start"
    },
    "dependencies": {
        "next": "^14.0.0",
        "react": "^18.2.0",
        "react-dom": "^18.2.0"
    }
}
```

**Usage (Development):**

```bash
docker compose up -d
```

Access your Next.js app at: `https://nextjs.docker.localhost`

**Hot reload verification:**

1. Edit any page in `pages/` or `app/`
2. Save the file
3. Browser should auto-refresh with changes

**Production build:**
Switch to production Dockerfile in `compose.yml`:

```yaml
services:
  nextjs:
    build:
      context: .
      dockerfile: Dockerfile  # Use production Dockerfile
    environment:
      - NODE_ENV=production
    # Remove volumes for production
```

**Troubleshooting hot reload:**
If hot reload isn't working:

1. Ensure `WATCHPACK_POLLING=true` is set
2. Verify volume mounts include source code
3. Check `next.config.js` has webpack dev middleware config
4. Try increasing poll interval: `poll: 2000`

---

#### NestJS Application

NestJS applications follow a modular architecture and work well with Docker. This example includes development and
production configurations.

**Directory structure:**

```
my-nestjs-app/
├── compose.yml
├── Dockerfile
├── Dockerfile.dev
├── nest-cli.json
├── package.json
├── src/
│   ├── main.ts
│   └── (other source files)
└── tsconfig.json
```

**compose.yml:**

```yaml
services:
  nestjs:
    build:
      context: .
      dockerfile: Dockerfile.dev
    container_name: nestjs-app
    restart: unless-stopped
    environment:
      - NODE_ENV=development
      - PORT=3000
    volumes:
      - ./:/app
      - /app/node_modules
      - /app/dist
    networks:
      - traefik-proxy
    healthcheck:
      test: [ "CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/health" ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.nestjs.rule=Host(`nestjs.docker.localhost`)"
      - "traefik.http.routers.nestjs.tls=true"
      - "traefik.http.services.nestjs.loadbalancer.server.port=3000"

networks:
  traefik-proxy:
    external: true
```

**Dockerfile.dev:**

```dockerfile
FROM node:20-alpine

# Install development dependencies
RUN apk add --no-cache wget

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy application files
COPY . .

# Expose port
EXPOSE 3000

# Start development server with watch mode
CMD ["npm", "run", "start:dev"]
```

**Dockerfile (Production):**

```dockerfile
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source files
COPY . .

# Build application
RUN npm run build

# Production stage
FROM node:20-alpine AS runner

RUN apk add --no-cache wget

WORKDIR /app

# Copy package files and install production dependencies only
COPY package*.json ./
RUN npm ci --only=production

# Copy built application
COPY --from=builder /app/dist ./dist

EXPOSE 3000

CMD ["node", "dist/main"]
```

**src/main.ts:**

```typescript
import {NestFactory} from '@nestjs/core';
import {AppModule} from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Enable CORS if needed
  app.enableCors();

  const port = process.env.PORT || 3000;
  await app.listen(port);

  console.log(`Application is running on: http://localhost:${port}`);
}

bootstrap();
```

**package.json:**

```json
{
    "name": "nestjs-docker-app",
    "version": "1.0.0",
    "scripts": {
        "start": "nest start",
        "start:dev": "nest start --watch",
        "start:prod": "node dist/main",
        "build": "nest build"
    },
    "dependencies": {
        "@nestjs/common": "^10.0.0",
        "@nestjs/core": "^10.0.0",
        "@nestjs/platform-express": "^10.0.0",
        "reflect-metadata": "^0.1.13",
        "rxjs": "^7.8.1"
    },
    "devDependencies": {
        "@nestjs/cli": "^10.0.0",
        "@nestjs/schematics": "^10.0.0",
        "@types/node": "^20.0.0",
        "typescript": "^5.0.0"
    }
}
```

**Health check endpoint (src/health/health.controller.ts):**

```typescript
import {Controller, Get} from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  check() {
    return {status: 'ok', timestamp: new Date().toISOString()};
  }
}
```

**Usage:**

```bash
docker compose up -d
```

Access your NestJS app at: `https://nestjs.docker.localhost`

**Development with hot reload:**
The Dockerfile.dev configuration automatically enables hot reload through NestJS's watch mode. Changes to TypeScript
files will trigger automatic recompilation.

**Production deployment:**
Update `compose.yml` to use production Dockerfile:

```yaml
services:
  nestjs:
    build:
      context: .
      dockerfile: Dockerfile
    environment:
      - NODE_ENV=production
    # Remove volumes for production
```

**Connecting to proxy services:**
To connect NestJS to the proxy's MySQL or Redis:

```yaml
services:
  nestjs:
    # ... other config
    environment:
      - DATABASE_HOST=mysql
      - DATABASE_PORT=3306
      - DATABASE_USER=root
      - DATABASE_PASSWORD=root
      - REDIS_HOST=redis
      - REDIS_PORT=6379
    networks:
      - traefik-proxy  # Must be on same network as MySQL/Redis
```

---

**Common Node.js Configuration Notes:**

1. **Port configuration:** Always use the `traefik.http.services.<name>.loadbalancer.server.port` label to specify the
   port your Node.js app listens on. This is crucial when your app doesn't use port 80.

2. **Hot reload in Docker:**
    - For Next.js: Use `WATCHPACK_POLLING=true` and configure webpack dev middleware
    - For NestJS: Use `--watch` flag in development
    - For Express/custom apps: Use `nodemon` with polling enabled
    - Always mount source code as volumes for development

3. **node_modules handling:** Use a separate volume for `node_modules` to prevent host files from overwriting container
   dependencies:
   ```yaml
   volumes:
     - ./:/app
     - /app/node_modules  # Anonymous volume with higher priority
   ```

4. **Environment variables:** Use `.env` files for local development and pass them through `compose.yml`:
   ```yaml
   services:
     app:
       env_file:
         - .env
   ```

5. **Health checks:** Implement a `/health` endpoint in your app for proper container health monitoring.

6. **Multi-stage builds:** For production, use multi-stage Dockerfiles to reduce final image size and include only
   necessary files.

7. **Custom ports examples:**
    - Port 8080: `traefik.http.services.myapp.loadbalancer.server.port=8080`
    - Port 4000: `traefik.http.services.myapp.loadbalancer.server.port=4000`
    - Port 5000: `traefik.http.services.myapp.loadbalancer.server.port=5000`

8. **Database connections:** When connecting to the proxy's MySQL service, use `mysql` as the hostname (not `localhost`
   or `127.0.0.1`).

### Python/Django Projects

Python applications can be served using various WSGI/ASGI servers like Gunicorn, Uvicorn, or directly with built-in
development servers. The examples below cover popular frameworks with production-ready configurations.

#### Django with Gunicorn

Django applications are best served with Gunicorn in production environments. This example includes PostgreSQL database
integration.

**Directory structure:**

```
my-django-app/
├── compose.yml
├── Dockerfile
├── requirements.txt
├── manage.py
├── myproject/
│   ├── __init__.py
│   ├── settings.py
│   ├── urls.py
│   └── wsgi.py
└── (other Django files)
```

**compose.yml:**

```yaml
services:
  django:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: django-app
    restart: unless-stopped
    command: gunicorn myproject.wsgi:application --bind 0.0.0.0:8000 --workers 4
    environment:
      - DJANGO_SETTINGS_MODULE=myproject.settings
      - DATABASE_URL=postgresql://django:secret@postgres:5432/django_db
      - REDIS_URL=redis://redis:6379/0
    volumes:
      - ./:/app
      - static_volume:/app/staticfiles
      - media_volume:/app/media
    networks:
      - traefik-proxy
      - django-network
    depends_on:
      - postgres
    healthcheck:
      test: [ "CMD", "curl", "-f", "http://localhost:8000/health/" ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.django.rule=Host(`django.docker.localhost`)"
      - "traefik.http.routers.django.tls=true"
      - "traefik.http.services.django.loadbalancer.server.port=8000"
      - "traefik.docker.network=traefik-proxy"

  postgres:
    image: postgres:16-alpine
    container_name: django-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: django_db
      POSTGRES_USER: django
      POSTGRES_PASSWORD: secret
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - django-network
    healthcheck:
      test: [ "CMD", "pg_isready", "-U", "django" ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  postgres_data:
  static_volume:
  media_volume:

networks:
  traefik-proxy:
    external: true
  django-network:
    driver: bridge
```

**Dockerfile:**

```dockerfile
FROM python:3.12-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    postgresql-client \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .

# Collect static files
RUN python manage.py collectstatic --noinput || true

# Create media directory
RUN mkdir -p /app/media

# Expose port
EXPOSE 8000

# Default command (can be overridden in compose.yml)
CMD ["gunicorn", "myproject.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "4"]
```

**requirements.txt:**

```
Django>=5.0,<6.0
gunicorn>=21.2.0
psycopg2-binary>=2.9.9
django-environ>=0.11.2
redis>=5.0.1
```

**myproject/settings.py (database configuration):**

```python
import os
import environ

# Initialize environ
env = environ.Env()

# Database configuration
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': env('POSTGRES_DB', default='django_db'),
        'USER': env('POSTGRES_USER', default='django'),
        'PASSWORD': env('POSTGRES_PASSWORD', default='secret'),
        'HOST': env('DB_HOST', default='postgres'),
        'PORT': env('DB_PORT', default='5432'),
    }
}

# Redis cache configuration
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.redis.RedisCache',
        'LOCATION': env('REDIS_URL', default='redis://redis:6379/0'),
    }
}

# Static and media files
STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')

MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

# Health check
ALLOWED_HOSTS = ['django.docker.localhost', 'localhost', '127.0.0.1']
```

**Health check view (myproject/urls.py):**

```python
from django.http import JsonResponse
from django.urls import path

def health_check(request):
    return JsonResponse({'status': 'ok'}, status=200)

urlpatterns = [
    path('health/', health_check),
    # ... your other URLs
]
```

**Usage:**

```bash
# Start the services
docker compose up -d

# Run migrations
docker compose exec django python manage.py migrate

# Create superuser
docker compose exec django python manage.py createsuperuser
```

Access your Django app at: `https://django.docker.localhost`

**Using proxy's MySQL instead of PostgreSQL:**
To connect to the proxy's MySQL service, modify `compose.yml`:

```yaml
services:
  django:
    # ... other config
    environment:
      - DATABASE_URL=mysql://root:root@mysql:3306/django_db
    networks:
      - traefik-proxy  # Must be on same network as MySQL
    # Remove postgres dependency
```

Update `requirements.txt`:

```
Django>=5.0,<6.0
gunicorn>=21.2.0
mysqlclient>=2.2.0  # MySQL driver instead of psycopg2
```

Create the database:

```bash
docker exec -it mysql mysql -uroot -proot -e "CREATE DATABASE django_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

**Development mode with auto-reload:**
For development with hot reload, modify `compose.yml`:

```yaml
services:
  django:
    # ... other config
    command: python manage.py runserver 0.0.0.0:8000
    environment:
      - DEBUG=True
    volumes:
      - ./:/app  # Enable code hot-reload
```

---

#### FastAPI with Uvicorn

FastAPI is a modern, async Python framework that's perfect for building APIs. This example shows FastAPI with Uvicorn
ASGI server.

**Directory structure:**

```
my-fastapi-app/
├── compose.yml
├── Dockerfile
├── requirements.txt
├── main.py
└── app/
    ├── __init__.py
    ├── models.py
    └── routers/
```

**compose.yml:**

```yaml
services:
  fastapi:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: fastapi-app
    restart: unless-stopped
    command: uvicorn main:app --host 0.0.0.0 --port 8000
    environment:
      - DATABASE_URL=postgresql://fastapi:secret@postgres:5432/fastapi_db
      - REDIS_HOST=redis
      - REDIS_PORT=6379
    volumes:
      - ./:/app
    networks:
      - traefik-proxy
      - fastapi-network
    depends_on:
      - postgres
    healthcheck:
      test: [ "CMD", "curl", "-f", "http://localhost:8000/health" ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.fastapi.rule=Host(`fastapi.docker.localhost`)"
      - "traefik.http.routers.fastapi.tls=true"
      - "traefik.http.services.fastapi.loadbalancer.server.port=8000"
      - "traefik.docker.network=traefik-proxy"

  postgres:
    image: postgres:16-alpine
    container_name: fastapi-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: fastapi_db
      POSTGRES_USER: fastapi
      POSTGRES_PASSWORD: secret
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - fastapi-network
    healthcheck:
      test: [ "CMD", "pg_isready", "-U", "fastapi" ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  postgres_data:

networks:
  traefik-proxy:
    external: true
  fastapi-network:
    driver: bridge
```

**Dockerfile:**

```dockerfile
FROM python:3.12-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    postgresql-client \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .

# Expose port
EXPOSE 8000

# Start application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**requirements.txt:**

```
fastapi>=0.109.0
uvicorn[standard]>=0.27.0
sqlalchemy>=2.0.25
psycopg2-binary>=2.9.9
pydantic>=2.5.3
pydantic-settings>=2.1.0
redis>=5.0.1
```

**main.py:**

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os

app = FastAPI(
    title="FastAPI Docker App",
    description="FastAPI application with Traefik proxy",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health check endpoint
@app.get("/health")
async def health_check():
    return {"status": "ok", "message": "Service is healthy"}

# Root endpoint
@app.get("/")
async def root():
    return {
        "message": "Welcome to FastAPI!",
        "docs": "/docs",
        "redoc": "/redoc"
    }

# Example database endpoint
@app.get("/api/items")
async def get_items():
    return {"items": ["item1", "item2", "item3"]}

# Startup event
@app.on_event("startup")
async def startup_event():
    print("FastAPI application starting...")
    print(f"Database URL: {os.getenv('DATABASE_URL', 'Not configured')}")

# Shutdown event
@app.on_event("shutdown")
async def shutdown_event():
    print("FastAPI application shutting down...")
```

**Database configuration (app/database.py):**

```python
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://fastapi:secret@postgres:5432/fastapi_db"
)

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Dependency for database sessions
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

**Usage:**

```bash
# Start the services
docker compose up -d

# View logs
docker compose logs -f fastapi
```

Access your FastAPI app at:

- Application: `https://fastapi.docker.localhost`
- API Docs: `https://fastapi.docker.localhost/docs`
- ReDoc: `https://fastapi.docker.localhost/redoc`

**Development mode with auto-reload:**
For development with hot reload, modify `compose.yml`:

```yaml
services:
  fastapi:
    # ... other config
    command: uvicorn main:app --host 0.0.0.0 --port 8000 --reload
    volumes:
      - ./:/app  # Enable code hot-reload
```

**Using proxy's MySQL:**
To use the proxy's MySQL service:

```yaml
services:
  fastapi:
    # ... other config
    environment:
      - DATABASE_URL=mysql://root:root@mysql:3306/fastapi_db
    networks:
      - traefik-proxy  # Must be on same network as MySQL
    # Remove postgres service
```

Update `requirements.txt`:

```
fastapi>=0.109.0
uvicorn[standard]>=0.27.0
sqlalchemy>=2.0.25
pymysql>=1.1.0
cryptography>=42.0.0
```

Create the database:

```bash
docker exec -it mysql mysql -uroot -proot -e "CREATE DATABASE fastapi_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

---

#### Flask Application

Flask is a lightweight, flexible Python web framework. This example shows Flask with Gunicorn for production.

**Directory structure:**

```
my-flask-app/
├── compose.yml
├── Dockerfile
├── requirements.txt
├── app.py
├── config.py
└── templates/
```

**compose.yml:**

```yaml
services:
  flask:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: flask-app
    restart: unless-stopped
    command: gunicorn -w 4 -b 0.0.0.0:5000 app:app
    environment:
      - FLASK_ENV=production
      - DATABASE_URL=postgresql://flask:secret@postgres:5432/flask_db
      - REDIS_URL=redis://redis:6379/0
      - SECRET_KEY=your-secret-key-here
    volumes:
      - ./:/app
    networks:
      - traefik-proxy
      - flask-network
    depends_on:
      - postgres
    healthcheck:
      test: [ "CMD", "curl", "-f", "http://localhost:5000/health" ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.flask.rule=Host(`flask.docker.localhost`)"
      - "traefik.http.routers.flask.tls=true"
      - "traefik.http.services.flask.loadbalancer.server.port=5000"
      - "traefik.docker.network=traefik-proxy"

  postgres:
    image: postgres:16-alpine
    container_name: flask-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: flask_db
      POSTGRES_USER: flask
      POSTGRES_PASSWORD: secret
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - flask-network
    healthcheck:
      test: [ "CMD", "pg_isready", "-U", "flask" ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  postgres_data:

networks:
  traefik-proxy:
    external: true
  flask-network:
    driver: bridge
```

**Dockerfile:**

```dockerfile
FROM python:3.12-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    postgresql-client \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .

# Expose port
EXPOSE 5000

# Start application
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "app:app"]
```

**requirements.txt:**

```
Flask>=3.0.0
gunicorn>=21.2.0
Flask-SQLAlchemy>=3.1.1
psycopg2-binary>=2.9.9
Flask-Redis>=0.4.0
python-dotenv>=1.0.0
```

**app.py:**

```python
from flask import Flask, jsonify, render_template
from flask_sqlalchemy import SQLAlchemy
import os

app = Flask(__name__)

# Configuration
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'dev-secret-key')
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv(
    'DATABASE_URL',
    'postgresql://flask:secret@postgres:5432/flask_db'
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Initialize extensions
db = SQLAlchemy(app)

# Health check endpoint
@app.route('/health')
def health_check():
    try:
        # Check database connection
        db.session.execute('SELECT 1')
        return jsonify({'status': 'ok', 'database': 'connected'}), 200
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 503

# Root endpoint
@app.route('/')
def index():
    return jsonify({
        'message': 'Welcome to Flask!',
        'version': '1.0.0',
        'endpoints': {
            'health': '/health',
            'api': '/api/items'
        }
    })

# Example API endpoint
@app.route('/api/items')
def get_items():
    return jsonify({
        'items': [
            {'id': 1, 'name': 'Item 1'},
            {'id': 2, 'name': 'Item 2'},
            {'id': 3, 'name': 'Item 3'}
        ]
    })

# Example database model
class User(db.Model):
    __tablename__ = 'users'

    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)

    def __repr__(self):
        return f'<User {self.username}>'

# Create tables
with app.app_context():
    db.create_all()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
```

**config.py (optional configuration file):**

```python
import os

class Config:
    SECRET_KEY = os.getenv('SECRET_KEY', 'dev-secret-key')
    SQLALCHEMY_DATABASE_URI = os.getenv('DATABASE_URL')
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # Redis configuration
    REDIS_URL = os.getenv('REDIS_URL', 'redis://redis:6379/0')

    # Application settings
    JSON_SORT_KEYS = False
    JSONIFY_PRETTYPRINT_REGULAR = True

class DevelopmentConfig(Config):
    DEBUG = True

class ProductionConfig(Config):
    DEBUG = False

config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'default': DevelopmentConfig
}
```

**Usage:**

```bash
# Start the services
docker compose up -d

# Run database migrations (if using Flask-Migrate)
docker compose exec flask flask db upgrade

# View logs
docker compose logs -f flask
```

Access your Flask app at: `https://flask.docker.localhost`

**Development mode with auto-reload:**
For development with Flask's built-in server and hot reload:

```yaml
services:
  flask:
    # ... other config
    command: flask run --host=0.0.0.0 --port=5000
    environment:
      - FLASK_ENV=development
      - FLASK_DEBUG=1
    volumes:
      - ./:/app  # Enable code hot-reload
```

**Using proxy's MySQL:**
To connect to the proxy's MySQL service:

```yaml
services:
  flask:
    # ... other config
    environment:
      - DATABASE_URL=mysql://root:root@mysql:3306/flask_db
    networks:
      - traefik-proxy  # Must be on same network as MySQL
    # Remove postgres service
```

Update `requirements.txt`:

```
Flask>=3.0.0
gunicorn>=21.2.0
Flask-SQLAlchemy>=3.1.1
mysqlclient>=2.2.0
Flask-Redis>=0.4.0
```

Update database URI in `app.py`:

```python
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv(
    'DATABASE_URL',
    'mysql://root:root@mysql:3306/flask_db'
)
```

Create the database:

```bash
docker exec -it mysql mysql -uroot -proot -e "CREATE DATABASE flask_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

---

**Common Python Configuration Notes:**

1. **Port specification:** Always specify the port your application listens on using the
   `traefik.http.services.<name>.loadbalancer.server.port` label:
    - Django/FastAPI/Gunicorn: Usually 8000
    - Flask: Usually 5000
    - Uvicorn: Configurable (default 8000)

2. **Database connections:**
    - **PostgreSQL**: Use `postgresql://user:password@host:port/database`
    - **MySQL**: Use `mysql://user:password@host:port/database`
    - When connecting to proxy's MySQL: use `mysql` as hostname
    - When using dedicated PostgreSQL: use service name as hostname

3. **Health check endpoints:**
    - Always implement a `/health` endpoint for container health monitoring
    - Return JSON with status information
    - Check database connectivity in health endpoint

4. **Environment variables:**
    - Use environment variables for configuration (12-factor app)
    - Store secrets in `.env` files (git-ignored)
    - Use libraries like `python-dotenv`, `django-environ`, or `pydantic-settings`

5. **Static and media files (Django):**
    - Use volumes for static and media files: `static_volume` and `media_volume`
    - Run `collectstatic` during build or as init command
    - Consider using Nginx for serving static files in production

6. **Multiple workers:**
    - Gunicorn: `-w 4` (4 workers) or `--workers 4`
    - Uvicorn: Use `--workers N` or run behind Gunicorn with uvicorn workers
    - Formula: `(2 × CPU cores) + 1`

7. **Database migrations:**
    - Django: `docker compose exec <service> python manage.py migrate`
    - Flask: `docker compose exec <service> flask db upgrade` (with Flask-Migrate)
    - FastAPI: Use Alembic for migrations

8. **Redis integration:**
    - Connect to proxy's Redis: `REDIS_URL=redis://redis:6379/0`
    - Use for caching, sessions, or Celery task queue
    - Must be on `traefik-proxy` network to access proxy's Redis

9. **Development vs Production:**
    - **Development**: Use framework's built-in server with `--reload`/debug mode
    - **Production**: Use Gunicorn/Uvicorn with multiple workers
    - Mount source code as volume only in development

10. **Network configuration:**
    - Services need `traefik-proxy` for Traefik routing
    - Add private network for app-database communication
    - Use `traefik.docker.network=traefik-proxy` label when on multiple networks

**Example: Django with Proxy's MySQL and Redis:**

```yaml
services:
  django:
    build: .
    container_name: django-app
    restart: unless-stopped
    command: gunicorn myproject.wsgi:application --bind 0.0.0.0:8000 --workers 4
    environment:
      - DATABASE_URL=mysql://root:root@mysql:3306/django_db
      - REDIS_URL=redis://redis:6379/0
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.django.rule=Host(`django.docker.localhost`)"
      - "traefik.http.routers.django.tls=true"
      - "traefik.http.services.django.loadbalancer.server.port=8000"

networks:
  traefik-proxy:
    external: true
```

**Example: FastAPI with Proxy's MySQL and Redis:**

```yaml
services:
  fastapi:
    build: .
    container_name: fastapi-app
    restart: unless-stopped
    command: uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
    environment:
      - DATABASE_URL=mysql://root:root@mysql:3306/fastapi_db
      - REDIS_HOST=redis
      - REDIS_PORT=6379
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.fastapi.rule=Host(`fastapi.docker.localhost`)"
      - "traefik.http.routers.fastapi.tls=true"
      - "traefik.http.services.fastapi.loadbalancer.server.port=8000"

networks:
  traefik-proxy:
    external: true
```

### Static Sites

**TODO:** Add Nginx static site serving example

### Go Applications

Go applications are ideal for containerized deployments due to their compiled nature. Unlike interpreted languages, Go
apps are deployed as single binaries without source code, resulting in minimal, secure container images. The examples
below demonstrate production-ready configurations for popular Go frameworks.

#### Gin Framework Application

Gin is a high-performance HTTP web framework for Go. This example shows a production deployment using multi-stage builds
to create a minimal container image.

**Directory structure:**

```
my-gin-app/
├── compose.yml
├── Dockerfile
├── go.mod
├── go.sum
├── main.go
└── (other application files)
```

**compose.yml:**

```yaml
services:
  gin-app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: gin-app
    restart: unless-stopped
    environment:
      - GIN_MODE=release
      - PORT=8080
    networks:
      - traefik-proxy
    healthcheck:
      test: [ "CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/health" ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.gin-app.rule=Host(`gin-app.docker.localhost`)"
      - "traefik.http.routers.gin-app.tls=true"
      - "traefik.http.services.gin-app.loadbalancer.server.port=8080"

networks:
  traefik-proxy:
    external: true
```

**Dockerfile (Multi-stage build):**

```dockerfile
# Build stage
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Runtime stage
FROM alpine:latest

# Install runtime dependencies
RUN apk --no-cache add ca-certificates wget

WORKDIR /root/

# Copy binary from builder
COPY --from=builder /app/main .

# Expose port
EXPOSE 8080

# Run binary
CMD ["./main"]
```

**main.go (minimal example):**

```go
package main

import (
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
)

func main() {
	// Set Gin mode from environment
	if mode := os.Getenv("GIN_MODE"); mode != "" {
		gin.SetMode(mode)
	}

	router := gin.Default()

	// Health check endpoint (required for healthcheck)
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status": "ok",
		})
	})

	// Main route
	router.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"message": "Hello from Gin!",
			"version": "1.0.0",
		})
	})

	// API routes
	api := router.Group("/api")
	{
		api.GET("/ping", func(c *gin.Context) {
			c.JSON(http.StatusOK, gin.H{
				"message": "pong",
			})
		})
	}

	// Get port from environment or use default
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	router.Run(":" + port)
}
```

**go.mod:**

```go
module gin-app

go 1.21

require github.com/gin-gonic/gin v1.9.1
```

**Usage:**

```bash
docker compose up -d
```

Access your Gin app at: `https://gin-app.docker.localhost`

**Key features:**

- **Multi-stage build**: Reduces final image size from ~800MB to ~15MB
- **Binary-only deployment**: No source code in production container
- **Minimal attack surface**: Alpine-based image with only runtime dependencies
- **Health check**: Built-in endpoint for container health monitoring

---

#### Echo Framework Application

Echo is another high-performance, minimalist Go web framework. This example demonstrates Echo's routing capabilities and
middleware integration.

**Directory structure:**

```
my-echo-app/
├── compose.yml
├── Dockerfile
├── go.mod
├── go.sum
├── main.go
└── (other application files)
```

**compose.yml:**

```yaml
services:
  echo-app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: echo-app
    restart: unless-stopped
    environment:
      - APP_ENV=production
      - PORT=8080
    networks:
      - traefik-proxy
    healthcheck:
      test: [ "CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/health" ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.echo-app.rule=Host(`echo-app.docker.localhost`)"
      - "traefik.http.routers.echo-app.tls=true"
      - "traefik.http.services.echo-app.loadbalancer.server.port=8080"

networks:
  traefik-proxy:
    external: true
```

**Dockerfile:**

```dockerfile
# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy dependency files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o main .

# Runtime stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates wget

WORKDIR /root/

# Copy binary from builder
COPY --from=builder /app/main .

EXPOSE 8080

CMD ["./main"]
```

**main.go:**

```go
package main

import (
	"net/http"
	"os"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
)

func main() {
	e := echo.New()

	// Middleware
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.Use(middleware.CORS())

	// Health check endpoint
	e.GET("/health", func(c echo.Context) error {
		return c.JSON(http.StatusOK, map[string]string{
			"status": "ok",
		})
	})

	// Routes
	e.GET("/", func(c echo.Context) error {
		return c.JSON(http.StatusOK, map[string]string{
			"message": "Hello from Echo!",
			"version": "1.0.0",
		})
	})

	// API group
	api := e.Group("/api")
	api.GET("/ping", func(c echo.Context) error {
		return c.JSON(http.StatusOK, map[string]string{
			"message": "pong",
		})
	})

	api.GET("/users/:id", func(c echo.Context) error {
		id := c.Param("id")
		return c.JSON(http.StatusOK, map[string]string{
			"user_id": id,
			"name":    "John Doe",
		})
	})

	// Get port from environment
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	e.Logger.Fatal(e.Start(":" + port))
}
```

**go.mod:**

```go
module echo-app

go 1.21

require (
	github.com/labstack/echo/v4 v4.11.3
)
```

**Usage:**

```bash
docker compose up -d
```

Access your Echo app at: `https://echo-app.docker.localhost`

**Key features:**

- **Built-in middleware**: Logger, Recover, CORS pre-configured
- **Route groups**: Clean API organization
- **Optimized binary**: Uses `-ldflags="-w -s"` to strip debug symbols
- **Production-ready**: Minimal container with security best practices

---

#### Standard Library (net/http) Application

For applications that don't require a framework, Go's standard library provides robust HTTP handling. This example shows
a production-ready setup using only the standard library.

**Directory structure:**

```
my-go-app/
├── compose.yml
├── Dockerfile
├── go.mod
├── main.go
└── handlers/
    └── handlers.go
```

**compose.yml:**

```yaml
services:
  go-app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: go-app
    restart: unless-stopped
    environment:
      - APP_ENV=production
      - PORT=8080
    networks:
      - traefik-proxy
    healthcheck:
      test: [ "CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/health" ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.go-app.rule=Host(`go-app.docker.localhost`)"
      - "traefik.http.routers.go-app.tls=true"
      - "traefik.http.services.go-app.loadbalancer.server.port=8080"

networks:
  traefik-proxy:
    external: true
```

**Dockerfile:**

```dockerfile
# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go.mod (and go.sum if exists)
COPY go.mod ./

# Download dependencies (if any)
RUN go mod download

# Copy source code
COPY . .

# Build with optimizations
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-w -s" \
    -a -installsuffix cgo \
    -o main .

# Runtime stage - use scratch for minimal image
FROM alpine:latest

# Add CA certificates and wget for healthcheck
RUN apk --no-cache add ca-certificates wget

WORKDIR /root/

# Copy binary from builder
COPY --from=builder /app/main .

EXPOSE 8080

CMD ["./main"]
```

**main.go:**

```go
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	// Get port from environment
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Create router
	mux := http.NewServeMux()

	// Register routes
	mux.HandleFunc("/health", healthHandler)
	mux.HandleFunc("/", homeHandler)
	mux.HandleFunc("/api/ping", pingHandler)

	// Create server with timeouts
	server := &http.Server{
		Addr:         ":" + port,
		Handler:      loggingMiddleware(mux),
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in goroutine
	go func() {
		log.Printf("Server starting on port %s", port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server error: %v", err)
		}
	}()

	// Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Server exited")
}

// Health check handler
func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "ok",
	})
}

// Home handler
func homeHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message": "Hello from Go net/http!",
		"version": "1.0.0",
	})
}

// Ping handler
func pingHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message": "pong",
	})
}

// Logging middleware
func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.Printf(
			"%s %s %s %v",
			r.Method,
			r.RequestURI,
			r.RemoteAddr,
			time.Since(start),
		)
	})
}
```

**go.mod:**

```go
module go-app

go 1.21
```

**Usage:**

```bash
docker compose up -d
```

Access your Go app at: `https://go-app.docker.localhost`

**Key features:**

- **Zero external dependencies**: Uses only Go standard library
- **Graceful shutdown**: Handles SIGTERM/SIGINT signals properly
- **Production timeouts**: Configured read/write/idle timeouts
- **Logging middleware**: Request logging built-in
- **Minimal image**: Can use `scratch` base for <10MB final image

---

#### Binary-Only Deployment Best Practices

Go's compiled nature enables unique deployment advantages. Follow these patterns for optimal container images:

**1. Multi-stage builds (Recommended)**

Always use multi-stage builds to separate build and runtime environments:

```dockerfile
# Build stage - includes Go compiler and tools
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o app .

# Runtime stage - minimal image
FROM alpine:latest
COPY --from=builder /app/app .
CMD ["./app"]
```

**Benefits:**

- **Size reduction**: 800MB → 15MB (98% smaller)
- **Security**: No compiler or source code in production
- **Attack surface**: Minimal packages installed

**2. Static binary compilation**

Build statically-linked binaries for maximum compatibility:

```dockerfile
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-w -s" \
    -a -installsuffix cgo \
    -o main .
```

**Flags explained:**

- `CGO_ENABLED=0`: Disable C dependencies
- `-ldflags="-w -s"`: Strip debug symbols (smaller binary)
- `-a`: Force rebuild of all packages
- `-installsuffix cgo`: Separate output directory

**3. Base image selection**

Choose the right base image for your needs:

```dockerfile
# Option 1: Alpine (15-20MB) - includes shell and basic tools
FROM alpine:latest
RUN apk --no-cache add ca-certificates

# Option 2: Distroless (5-10MB) - no shell, minimal packages
FROM gcr.io/distroless/static-debian11

# Option 3: Scratch (<5MB) - only your binary
FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
```

**When to use each:**

- **Alpine**: Development, debugging, health checks with wget/curl
- **Distroless**: Production with external health checks
- **Scratch**: Maximum security, external monitoring only

**4. No source code mounting**

Unlike Node.js or Python, Go applications should **never** mount source code:

```yaml
# ❌ WRONG - Don't do this with Go
services:
  app:
    volumes:
      - ./:/app  # Unnecessary and insecure

# ✅ CORRECT - Binary-only deployment
services:
  app:
    build:
      context: .
    # No volumes needed
```

**Why?**

- Go compiles to binary - source code not needed at runtime
- Eliminates exposure of proprietary source code
- Prevents accidental modification of running code
- Improves startup time (no file watching overhead)

**5. Development workflow**

For local development with live reload, rebuild containers instead of mounting code:

```yaml
# Development compose override
services:
  app:
    build:
      target: builder  # Stop at builder stage for faster rebuilds
    command: go run main.go
    volumes:
      - ./:/app  # Only for development
```

Or use air for live reload:

```dockerfile
# Development Dockerfile
FROM golang:1.21-alpine
WORKDIR /app
RUN go install github.com/cosmtrek/air@latest
COPY . .
CMD ["air"]
```

**6. Health check considerations**

When using minimal images (distroless/scratch), adjust health checks:

```yaml
# Alpine - can use wget
healthcheck:
  test: [ "CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/health" ]

# Distroless/Scratch - use external checks
healthcheck:
  test: [ "NONE" ]  # Rely on Traefik's health check
```

Or compile a health check binary:

```go
// healthcheck.go
package main

import (
    "net/http"
    "os"
)

func main() {
    resp, err := http.Get("http://localhost:8080/health")
    if err != nil || resp.StatusCode != 200 {
        os.Exit(1)
    }
    os.Exit(0)
}
```

```dockerfile
RUN go build -o healthcheck ./healthcheck.go
COPY --from=builder /app/healthcheck .
HEALTHCHECK CMD ["./healthcheck"]
```

**7. Image optimization checklist**

Before deploying, verify your image follows these practices:

- [ ] Multi-stage build implemented
- [ ] Final image uses Alpine or smaller
- [ ] Static binary (CGO_ENABLED=0)
- [ ] Debug symbols stripped (-ldflags="-w -s")
- [ ] No source code in final image
- [ ] CA certificates included (if making HTTPS requests)
- [ ] Health check uses available tools
- [ ] Image size < 20MB (50MB max)

**Example optimized build:**

```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-w -s" -o app .

FROM alpine:latest
RUN apk --no-cache add ca-certificates wget
COPY --from=builder /app/app .
EXPOSE 8080
HEALTHCHECK CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1
CMD ["./app"]
```

**Result:** Production-ready image with full health checks in 15-20MB.

## Common Scenarios

This section covers real-world scenarios you'll encounter when building multi-service applications with the Docker
Proxy. Each example demonstrates production-ready patterns for common architectural needs.

### Multi-Service Project (Frontend + Backend)

Most modern applications consist of multiple services working together. This scenario shows a React frontend
communicating with an Express API backend, both exposed through the proxy.

**Use case:** Single-page application with a REST API backend.

**Architecture:**

- Frontend: React app (port 3000)
- Backend: Express API (port 4000)
- Both services accessible via custom domains
- Backend can optionally connect to proxy's MySQL/Redis

**Directory structure:**

```
fullstack-app/
├── compose.yml
├── frontend/
│   ├── Dockerfile
│   ├── package.json
│   └── (React app files)
└── backend/
    ├── Dockerfile
    ├── package.json
    └── (Express API files)
```

**compose.yml:**

```yaml
services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: fullstack-frontend
    restart: unless-stopped
    environment:
      - NODE_ENV=production
      - REACT_APP_API_URL=https://api.myapp.docker.localhost
    networks:
      - traefik-proxy
    healthcheck:
      test: [ "CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/" ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp-frontend.rule=Host(`myapp.docker.localhost`)"
      - "traefik.http.routers.myapp-frontend.tls=true"
      - "traefik.http.services.myapp-frontend.loadbalancer.server.port=3000"

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: fullstack-backend
    restart: unless-stopped
    environment:
      - NODE_ENV=production
      - PORT=4000
      - DATABASE_URL=mysql://root:root@mysql:3306/myapp_db
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - CORS_ORIGIN=https://myapp.docker.localhost
    networks:
      - traefik-proxy
      - app-network
    healthcheck:
      test: [ "CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:4000/health" ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp-backend.rule=Host(`api.myapp.docker.localhost`)"
      - "traefik.http.routers.myapp-backend.tls=true"
      - "traefik.http.services.myapp-backend.loadbalancer.server.port=4000"
      - "traefik.docker.network=traefik-proxy"

networks:
  traefik-proxy:
    external: true
  app-network:
    driver: bridge
```

**frontend/Dockerfile:**

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 3000
CMD ["nginx", "-g", "daemon off;"]
```

**frontend/nginx.conf:**

```nginx
server {
    listen 3000;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy API requests to backend (optional if using direct HTTPS)
    location /api/ {
        proxy_pass https://api.myapp.docker.localhost/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**backend/Dockerfile:**

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 4000
CMD ["node", "server.js"]
```

**backend/server.js (CORS configuration example):**

```javascript
const express = require('express');
const cors = require('cors');
const app = express();

// CORS configuration for frontend
app.use(cors({
  origin: process.env.CORS_ORIGIN || 'https://myapp.docker.localhost',
  credentials: true
}));

app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({status: 'ok'});
});

// API routes
app.get('/api/data', (req, res) => {
  res.json({message: 'Hello from backend!'});
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`Backend running on port ${PORT}`);
});
```

**Usage:**

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f

# Access services
# Frontend: https://myapp.docker.localhost
# Backend API: https://api.myapp.docker.localhost
```

**Key points:**

- **Separate domains**: Frontend and backend use different subdomains (cleaner separation)
- **CORS configuration**: Backend allows requests from frontend domain
- **Environment variables**: Frontend knows backend URL via `REACT_APP_API_URL`
- **Network isolation**: Backend on private network for database access
- **Custom ports**: Each service uses its own port, Traefik routes appropriately
- **Health checks**: Both services have health endpoints for monitoring

**Testing the setup:**

```bash
# Test frontend
curl https://myapp.docker.localhost

# Test backend API
curl https://api.myapp.docker.localhost/api/data

# Test from frontend container to backend
docker exec fullstack-frontend wget -qO- https://api.myapp.docker.localhost/health
```

---

### Using Proxy-Provided MySQL and Redis

Instead of running separate database containers for each project, you can use the centralized MySQL and Redis services
provided by the proxy. This approach saves resources and simplifies management.

**Benefits:**

- Single MySQL/Redis instance for all projects
- Reduced memory usage (one container vs. many)
- Centralized database management via phpMyAdmin
- Consistent connection strings across projects

**Prerequisites:**

1. **Enable MySQL and Redis in the proxy:**

   Edit the proxy's `.env` file:
   ```bash
   COMPOSE_PROFILES=redis,mysql,pma
   MYSQL_ROOT_PASSWORD=root
   ```

   Restart the proxy:
   ```bash
   cd /path/to/docker-proxy
   docker compose up -d
   ```

2. **Verify services are running:**
   ```bash
   docker ps | grep -E "mysql|redis"
   ```

   You should see `mysql`, `redis`, and `pma` containers running.

**Scenario: Laravel application using proxy's MySQL and Redis**

**compose.yml:**

```yaml
services:
  laravel:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: laravel-app
    restart: unless-stopped
    working_dir: /var/www
    volumes:
      - ./:/var/www
    environment:
      # Database configuration (proxy's MySQL)
      - DB_CONNECTION=mysql
      - DB_HOST=mysql
      - DB_PORT=3306
      - DB_DATABASE=laravel_app
      - DB_USERNAME=root
      - DB_PASSWORD=root

      # Cache configuration (proxy's Redis)
      - REDIS_HOST=redis
      - REDIS_PASSWORD=null
      - REDIS_PORT=6379
      - CACHE_DRIVER=redis
      - SESSION_DRIVER=redis
      - QUEUE_CONNECTION=redis
    networks:
      - traefik-proxy
    healthcheck:
      test: [ "CMD", "php-fpm", "-t" ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.laravel-app.rule=Host(`laravel-app.docker.localhost`)"
      - "traefik.http.routers.laravel-app.tls=true"
      - "traefik.http.services.laravel-app.loadbalancer.server.port=9000"

  nginx:
    image: nginx:alpine
    container_name: laravel-nginx
    restart: unless-stopped
    volumes:
      - ./:/var/www
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - laravel
    networks:
      - traefik-proxy
    healthcheck:
      test: [ "CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost/" ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.laravel-nginx.rule=Host(`laravel-app.docker.localhost`)"
      - "traefik.http.routers.laravel-nginx.tls=true"
      - "traefik.docker.network=traefik-proxy"

networks:
  traefik-proxy:
    external: true
```

**Setup steps:**

1. **Create the database:**

   Use phpMyAdmin at `https://pma.docker.localhost` or CLI:
   ```bash
   docker exec -it mysql mysql -uroot -proot -e "CREATE DATABASE laravel_app CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
   ```

2. **Start your application:**
   ```bash
   docker compose up -d
   ```

3. **Run migrations:**
   ```bash
   docker compose exec laravel php artisan migrate
   ```

4. **Test database connection:**
   ```bash
   docker compose exec laravel php artisan tinker
   # In tinker:
   DB::connection()->getPdo();
   ```

5. **Test Redis connection:**
   ```bash
   docker compose exec laravel php artisan tinker
   # In tinker:
   Redis::ping();
   ```

**Managing databases:**

**View all databases:**

```bash
docker exec -it mysql mysql -uroot -proot -e "SHOW DATABASES;"
```

**Create a new database:**

```bash
docker exec -it mysql mysql -uroot -proot -e "CREATE DATABASE myapp_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

**Create a database user:**

```bash
docker exec -it mysql mysql -uroot -proot << EOF
CREATE USER 'myapp'@'%' IDENTIFIED BY 'secret';
GRANT ALL PRIVILEGES ON myapp_db.* TO 'myapp'@'%';
FLUSH PRIVILEGES;
EOF
```

**Backup a database:**

```bash
docker exec mysql mysqldump -uroot -proot laravel_app > backup.sql
```

**Restore a database:**

```bash
docker exec -i mysql mysql -uroot -proot laravel_app < backup.sql
```

**Redis operations:**

**Test Redis connection:**

```bash
docker exec -it redis redis-cli ping
```

**View all keys:**

```bash
docker exec -it redis redis-cli KEYS '*'
```

**Clear all cache:**

```bash
docker exec -it redis redis-cli FLUSHDB
```

**Monitor Redis commands:**

```bash
docker exec -it redis redis-cli MONITOR
```

**Important notes:**

1. **Network requirement**: Your services **must** be on the `traefik-proxy` network to access MySQL and Redis.

2. **Connection strings**: Use container names as hostnames:
    - MySQL: `mysql:3306`
    - Redis: `redis:6379`

3. **Security**: The default password is `root`. For production, change `MYSQL_ROOT_PASSWORD` in the proxy's `.env`.

4. **Multiple projects**: All projects share the same MySQL/Redis instances. Use unique database names:
    - Project A: `projecta_db`
    - Project B: `projectb_db`
    - Project C: `projectc_db`

5. **phpMyAdmin access**: Manage all databases via `https://pma.docker.localhost` (login: `root` / `root`).

6. **Data persistence**: MySQL data persists in the `mysql_data` volume. To reset:
   ```bash
   cd /path/to/docker-proxy
   docker compose down -v  # WARNING: Deletes all databases!
   docker compose up -d
   ```

**Example connection strings for different frameworks:**

**Laravel (.env):**

```env
DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=laravel_app
DB_USERNAME=root
DB_PASSWORD=root

REDIS_HOST=redis
REDIS_PORT=6379
```

**Django (settings.py):**

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': 'django_app',
        'USER': 'root',
        'PASSWORD': 'root',
        'HOST': 'mysql',
        'PORT': '3306',
    }
}

CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.redis.RedisCache',
        'LOCATION': 'redis://redis:6379/0',
    }
}
```

**Node.js (Express):**

```javascript
const mysql = require('mysql2');
const redis = require('redis');

// MySQL connection
const db = mysql.createConnection({
  host: 'mysql',
  user: 'root',
  password: 'root',
  database: 'nodejs_app'
});

// Redis client
const redisClient = redis.createClient({
  host: 'redis',
  port: 6379
});
```

**FastAPI (Python):**

```python
# Database URL
DATABASE_URL = "mysql://root:root@mysql:3306/fastapi_app"

# Redis client
import redis
redis_client = redis.Redis(host='redis', port=6379, db=0)
```

---

### Using Proxy-Provided Mailpit Email Testing

Instead of sending real emails during development or configuring external email services, you can use the centralized
Mailpit service provided by the proxy. Mailpit captures all outgoing emails, allowing you to inspect them through a web
interface.

**What is Mailpit?**

Mailpit is a modern email testing tool (successor to MailHog) that:

- Captures all emails sent via SMTP
- Provides a web interface to view emails
- Supports attachments, HTML emails, and multipart messages
- Offers a REST API for automated testing
- Requires zero configuration on the email receiving side

**Benefits:**

- Test email functionality without sending real emails
- View emails in a web interface at `https://mailpit.docker.localhost`
- Single Mailpit instance for all projects
- Inspect HTML rendering, attachments, and headers
- API access for automated testing
- No email deliverability issues or spam concerns

**Prerequisites:**

1. **Enable Mailpit in the proxy:**

   Edit the proxy's `.env` file:
   ```bash
   COMPOSE_PROFILES=mailpit
   # Or combine with other services:
   COMPOSE_PROFILES=redis,mysql,pma,mailpit
   ```

   Restart the proxy:
   ```bash
   cd /path/to/docker-proxy
   docker compose up -d
   ```

2. **Verify Mailpit is running:**
   ```bash
   docker ps | grep mailpit
   ```

   You should see the `mailpit` container running.

3. **Access the Mailpit web interface:**

   Open [https://mailpit.docker.localhost](https://mailpit.docker.localhost) in your browser.

**SMTP Configuration:**

All applications should use these settings to send emails through Mailpit:

- **SMTP Host:** `mailpit`
- **SMTP Port:** `1025`
- **Encryption:** None (not required for local development)
- **Authentication:** None (not required)

**Network Requirement:** Your application must be on the `traefik-proxy` network to access Mailpit.

---

#### Laravel Configuration

Laravel makes email configuration simple with environment variables.

**compose.yml:**

```yaml
services:
  laravel:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: laravel-app
    restart: unless-stopped
    working_dir: /var/www
    volumes:
      - .:/var/www
    environment:
      # Mailpit configuration
      - MAIL_MAILER=smtp
      - MAIL_HOST=mailpit
      - MAIL_PORT=1025
      - MAIL_USERNAME=null
      - MAIL_PASSWORD=null
      - MAIL_ENCRYPTION=null
      - MAIL_FROM_ADDRESS=hello@example.com
      - MAIL_FROM_NAME="${APP_NAME}"
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.laravel.rule=Host(`laravel.docker.localhost`)"
      - "traefik.http.routers.laravel.tls=true"
      - "traefik.http.services.laravel.loadbalancer.server.port=80"

networks:
  traefik-proxy:
    external: true
```

**.env file:**

```dotenv
MAIL_MAILER=smtp
MAIL_HOST=mailpit
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS=hello@example.com
MAIL_FROM_NAME="${APP_NAME}"
```

**Testing email sending:**

```bash
# Enter Laravel container
docker compose exec laravel bash

# Send a test email using Artisan tinker
php artisan tinker
>>> Mail::raw('Test email from Laravel', function($message) {
...     $message->to('test@example.com')->subject('Test');
... });
```

Check [https://mailpit.docker.localhost](https://mailpit.docker.localhost) to see the captured email.

---

#### Symfony Configuration

Symfony uses the Mailer component with DSN configuration.

**compose.yml:**

```yaml
services:
  symfony:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: symfony-app
    restart: unless-stopped
    working_dir: /var/www
    volumes:
      - .:/var/www
    environment:
      - MAILER_DSN=smtp://mailpit:1025
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.symfony.rule=Host(`symfony.docker.localhost`)"
      - "traefik.http.routers.symfony.tls=true"
      - "traefik.http.services.symfony.loadbalancer.server.port=80"

networks:
  traefik-proxy:
    external: true
```

**.env file:**

```dotenv
MAILER_DSN=smtp://mailpit:1025
```

**services.yaml (optional explicit configuration):**

```yaml
framework:
  mailer:
    dsn: '%env(MAILER_DSN)%'
```

---

#### Django Configuration

Django uses the built-in email backend with SMTP settings.

**compose.yml:**

```yaml
services:
  django:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: django-app
    restart: unless-stopped
    working_dir: /app
    volumes:
      - .:/app
    environment:
      - EMAIL_HOST=mailpit
      - EMAIL_PORT=1025
      - EMAIL_USE_TLS=False
      - EMAIL_USE_SSL=False
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.django.rule=Host(`django.docker.localhost`)"
      - "traefik.http.routers.django.tls=true"
      - "traefik.http.services.django.loadbalancer.server.port=8000"

networks:
  traefik-proxy:
    external: true
```

**settings.py:**

```python
import os

# Email configuration for Mailpit
EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = os.getenv('EMAIL_HOST', 'mailpit')
EMAIL_PORT = int(os.getenv('EMAIL_PORT', 1025))
EMAIL_USE_TLS = os.getenv('EMAIL_USE_TLS', 'False').lower() == 'true'
EMAIL_USE_SSL = os.getenv('EMAIL_USE_SSL', 'False').lower() == 'true'
EMAIL_HOST_USER = os.getenv('EMAIL_HOST_USER', '')
EMAIL_HOST_PASSWORD = os.getenv('EMAIL_HOST_PASSWORD', '')
DEFAULT_FROM_EMAIL = os.getenv('DEFAULT_FROM_EMAIL', 'noreply@example.com')
```

**Testing email sending:**

```bash
# Enter Django container
docker compose exec django bash

# Send a test email using Django shell
python manage.py shell
>>> from django.core.mail import send_mail
>>> send_mail('Test Subject', 'Test body', 'from@example.com', ['to@example.com'])
```

---

#### Ruby on Rails Configuration

Rails uses Action Mailer with SMTP configuration.

**compose.yml:**

```yaml
services:
  rails:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: rails-app
    restart: unless-stopped
    working_dir: /app
    volumes:
      - .:/app
    environment:
      - SMTP_ADDRESS=mailpit
      - SMTP_PORT=1025
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.rails.rule=Host(`rails.docker.localhost`)"
      - "traefik.http.routers.rails.tls=true"
      - "traefik.http.services.rails.loadbalancer.server.port=3000"

networks:
  traefik-proxy:
    external: true
```

**config/environments/development.rb:**

```ruby
Rails.application.configure do
  # Mailpit configuration
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV.fetch('SMTP_ADDRESS', 'mailpit'),
    port: ENV.fetch('SMTP_PORT', 1025).to_i
  }

  # Enable email sending in development
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = { host: 'rails.docker.localhost', protocol: 'https' }
end
```

**Testing email sending:**

```bash
# Enter Rails container
docker compose exec rails bash

# Send a test email using Rails console
rails console
irb> ActionMailer::Base.mail(from: 'test@example.com', to: 'user@example.com', subject: 'Test', body: 'Hello!').deliver_now
```

---

#### Node.js (Nodemailer) Configuration

Node.js applications commonly use Nodemailer for sending emails.

**compose.yml:**

```yaml
services:
  nodejs:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: nodejs-app
    restart: unless-stopped
    working_dir: /app
    volumes:
      - .:/app
    environment:
      - SMTP_HOST=mailpit
      - SMTP_PORT=1025
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.nodejs.rule=Host(`nodejs.docker.localhost`)"
      - "traefik.http.routers.nodejs.tls=true"
      - "traefik.http.services.nodejs.loadbalancer.server.port=3000"

networks:
  traefik-proxy:
    external: true
```

**mail.js (Nodemailer configuration):**

```javascript
const nodemailer = require('nodemailer');

// Create Mailpit transporter
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'mailpit',
  port: parseInt(process.env.SMTP_PORT, 10) || 1025,
  secure: false, // No TLS for local development
  tls: {
    rejectUnauthorized: false
  }
});

// Send email function
async function sendEmail(to, subject, html) {
  const info = await transporter.sendMail({
    from: '"My App" <noreply@example.com>',
    to: to,
    subject: subject,
    html: html
  });

  console.log('Message sent: %s', info.messageId);
  return info;
}

module.exports = {sendEmail, transporter};
```

**Testing email sending:**

```javascript
// test-email.js
const {sendEmail} = require('./mail');

sendEmail('user@example.com', 'Test Email', '<h1>Hello!</h1><p>This is a test.</p>')
  .then(() => console.log('Email sent successfully!'))
  .catch(console.error);
```

```bash
# Run the test script
docker compose exec nodejs node test-email.js
```

---

#### Express.js with TypeScript Configuration

For TypeScript Express applications using Nodemailer.

**src/config/mail.ts:**

```typescript
import nodemailer, {Transporter} from 'nodemailer';

interface MailConfig {
  host: string;
  port: number;
  secure: boolean;
}

const mailConfig: MailConfig = {
  host: process.env.SMTP_HOST || 'mailpit',
  port: parseInt(process.env.SMTP_PORT || '1025', 10),
  secure: false
};

export const transporter: Transporter = nodemailer.createTransport(mailConfig);

export async function sendMail(
  to: string,
  subject: string,
  html: string
): Promise<void> {
  await transporter.sendMail({
    from: process.env.MAIL_FROM || 'noreply@example.com',
    to,
    subject,
    html
  });
}
```

---

#### NestJS Configuration

NestJS with the @nestjs-modules/mailer package.

**compose.yml:**

```yaml
services:
  nestjs:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: nestjs-app
    restart: unless-stopped
    working_dir: /app
    volumes:
      - .:/app
    environment:
      - SMTP_HOST=mailpit
      - SMTP_PORT=1025
      - MAIL_FROM=noreply@example.com
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.nestjs.rule=Host(`nestjs.docker.localhost`)"
      - "traefik.http.routers.nestjs.tls=true"
      - "traefik.http.services.nestjs.loadbalancer.server.port=3000"

networks:
  traefik-proxy:
    external: true
```

**app.module.ts:**

```typescript
import {Module} from '@nestjs/common';
import {MailerModule} from '@nestjs-modules/mailer';
import {ConfigModule, ConfigService} from '@nestjs/config';

@Module({
  imports: [
    ConfigModule.forRoot(),
    MailerModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: async (configService: ConfigService) => ({
        transport: {
          host: configService.get('SMTP_HOST', 'mailpit'),
          port: configService.get('SMTP_PORT', 1025),
          secure: false,
        },
        defaults: {
          from: configService.get('MAIL_FROM', 'noreply@example.com'),
        },
      }),
      inject: [ConfigService],
    }),
  ],
})
export class AppModule {
}
```

---

#### FastAPI (Python) Configuration

FastAPI applications using fastapi-mail or aiosmtplib.

**compose.yml:**

```yaml
services:
  fastapi:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: fastapi-app
    restart: unless-stopped
    working_dir: /app
    volumes:
      - .:/app
    environment:
      - SMTP_HOST=mailpit
      - SMTP_PORT=1025
      - MAIL_FROM=noreply@example.com
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.fastapi.rule=Host(`fastapi.docker.localhost`)"
      - "traefik.http.routers.fastapi.tls=true"
      - "traefik.http.services.fastapi.loadbalancer.server.port=8000"

networks:
  traefik-proxy:
    external: true
```

**Using fastapi-mail:**

```python
import os
from fastapi import FastAPI
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig

app = FastAPI()

# Mailpit configuration
mail_config = ConnectionConfig(
    MAIL_USERNAME="",
    MAIL_PASSWORD="",
    MAIL_FROM=os.getenv("MAIL_FROM", "noreply@example.com"),
    MAIL_PORT=int(os.getenv("SMTP_PORT", 1025)),
    MAIL_SERVER=os.getenv("SMTP_HOST", "mailpit"),
    MAIL_STARTTLS=False,
    MAIL_SSL_TLS=False,
    USE_CREDENTIALS=False
)

fm = FastMail(mail_config)

@app.post("/send-email/")
async def send_email(email: str, subject: str, body: str):
    message = MessageSchema(
        subject=subject,
        recipients=[email],
        body=body,
        subtype="html"
    )
    await fm.send_message(message)
    return {"message": "Email sent successfully"}
```

**Using aiosmtplib (lightweight alternative):**

```python
import os
import aiosmtplib
from email.message import EmailMessage

async def send_email(to: str, subject: str, body: str):
    message = EmailMessage()
    message["From"] = os.getenv("MAIL_FROM", "noreply@example.com")
    message["To"] = to
    message["Subject"] = subject
    message.set_content(body, subtype="html")

    await aiosmtplib.send(
        message,
        hostname=os.getenv("SMTP_HOST", "mailpit"),
        port=int(os.getenv("SMTP_PORT", 1025)),
        use_tls=False
    )
```

---

#### Flask Configuration

Flask applications using Flask-Mail.

**compose.yml:**

```yaml
services:
  flask:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: flask-app
    restart: unless-stopped
    working_dir: /app
    volumes:
      - .:/app
    environment:
      - MAIL_SERVER=mailpit
      - MAIL_PORT=1025
      - MAIL_USE_TLS=False
      - MAIL_USE_SSL=False
      - MAIL_DEFAULT_SENDER=noreply@example.com
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.flask.rule=Host(`flask.docker.localhost`)"
      - "traefik.http.routers.flask.tls=true"
      - "traefik.http.services.flask.loadbalancer.server.port=5000"

networks:
  traefik-proxy:
    external: true
```

**app.py:**

```python
import os
from flask import Flask
from flask_mail import Mail, Message

app = Flask(__name__)

# Mailpit configuration
app.config['MAIL_SERVER'] = os.getenv('MAIL_SERVER', 'mailpit')
app.config['MAIL_PORT'] = int(os.getenv('MAIL_PORT', 1025))
app.config['MAIL_USE_TLS'] = os.getenv('MAIL_USE_TLS', 'False').lower() == 'true'
app.config['MAIL_USE_SSL'] = os.getenv('MAIL_USE_SSL', 'False').lower() == 'true'
app.config['MAIL_USERNAME'] = os.getenv('MAIL_USERNAME', '')
app.config['MAIL_PASSWORD'] = os.getenv('MAIL_PASSWORD', '')
app.config['MAIL_DEFAULT_SENDER'] = os.getenv('MAIL_DEFAULT_SENDER', 'noreply@example.com')

mail = Mail(app)

@app.route('/send-test-email')
def send_test_email():
    msg = Message(
        subject='Test Email from Flask',
        recipients=['test@example.com'],
        body='This is a test email sent from Flask via Mailpit.'
    )
    mail.send(msg)
    return 'Email sent! Check Mailpit at https://mailpit.docker.localhost'
```

---

#### Go Application Configuration

Go applications using the standard net/smtp package.

**compose.yml:**

```yaml
services:
  go-app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: go-app
    restart: unless-stopped
    environment:
      - SMTP_HOST=mailpit
      - SMTP_PORT=1025
      - MAIL_FROM=noreply@example.com
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.go-app.rule=Host(`go-app.docker.localhost`)"
      - "traefik.http.routers.go-app.tls=true"
      - "traefik.http.services.go-app.loadbalancer.server.port=8080"

networks:
  traefik-proxy:
    external: true
```

**mail/mail.go:**

```go
package mail

import (
    "fmt"
    "net/smtp"
    "os"
)

func SendEmail(to, subject, body string) error {
    host := os.Getenv("SMTP_HOST")
    if host == "" {
        host = "mailpit"
    }
    port := os.Getenv("SMTP_PORT")
    if port == "" {
        port = "1025"
    }
    from := os.Getenv("MAIL_FROM")
    if from == "" {
        from = "noreply@example.com"
    }

    addr := fmt.Sprintf("%s:%s", host, port)

    msg := []byte(fmt.Sprintf(
        "From: %s\r\nTo: %s\r\nSubject: %s\r\n\r\n%s",
        from, to, subject, body,
    ))

    // Mailpit doesn't require authentication
    return smtp.SendMail(addr, nil, from, []string{to}, msg)
}
```

**Using with gomail (for HTML emails):**

```go
package mail

import (
    "os"
    "strconv"

    "gopkg.in/gomail.v2"
)

func SendHTMLEmail(to, subject, htmlBody string) error {
    host := os.Getenv("SMTP_HOST")
    if host == "" {
        host = "mailpit"
    }
    portStr := os.Getenv("SMTP_PORT")
    if portStr == "" {
        portStr = "1025"
    }
    port, _ := strconv.Atoi(portStr)
    from := os.Getenv("MAIL_FROM")
    if from == "" {
        from = "noreply@example.com"
    }

    m := gomail.NewMessage()
    m.SetHeader("From", from)
    m.SetHeader("To", to)
    m.SetHeader("Subject", subject)
    m.SetBody("text/html", htmlBody)

    d := gomail.NewDialer(host, port, "", "")

    return d.DialAndSend(m)
}
```

---

#### WordPress Configuration

WordPress uses PHPMailer and can be configured to use Mailpit.

**compose.yml:**

```yaml
services:
  wordpress:
    image: wordpress:latest
    container_name: wordpress-app
    restart: unless-stopped
    environment:
      - WORDPRESS_DB_HOST=mysql
      - WORDPRESS_DB_USER=root
      - WORDPRESS_DB_PASSWORD=root
      - WORDPRESS_DB_NAME=wordpress
    volumes:
      - ./wp-content:/var/www/html/wp-content
      - ./smtp-config.php:/var/www/html/wp-content/mu-plugins/smtp-config.php
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.wordpress.rule=Host(`wordpress.docker.localhost`)"
      - "traefik.http.routers.wordpress.tls=true"
      - "traefik.http.services.wordpress.loadbalancer.server.port=80"

networks:
  traefik-proxy:
    external: true
```

**smtp-config.php (must-use plugin):**

```php
<?php
/**
 * Plugin Name: SMTP Configuration for Mailpit
 * Description: Configures WordPress to send emails via Mailpit
 */

add_action('phpmailer_init', function($phpmailer) {
    $phpmailer->isSMTP();
    $phpmailer->Host = 'mailpit';
    $phpmailer->Port = 1025;
    $phpmailer->SMTPAuth = false;
    $phpmailer->SMTPSecure = false;
    $phpmailer->SMTPAutoTLS = false;
});
```

---

#### Mailpit API for Automated Testing

Mailpit provides a REST API for automated email testing in CI/CD pipelines.

**API Endpoints:**

| Endpoint                    | Method | Description             |
|-----------------------------|--------|-------------------------|
| `/api/v1/messages`          | GET    | List all messages       |
| `/api/v1/messages/{id}`     | GET    | Get message details     |
| `/api/v1/messages/{id}/raw` | GET    | Get raw message content |
| `/api/v1/messages`          | DELETE | Delete all messages     |

**Example: Testing with curl:**

```bash
# List all captured emails
curl -sk https://mailpit.docker.localhost/api/v1/messages | jq

# Get the latest email
curl -sk https://mailpit.docker.localhost/api/v1/messages | jq '.messages[0]'

# Clear all emails (useful before test runs)
curl -sk -X DELETE https://mailpit.docker.localhost/api/v1/messages
```

**Example: Automated testing in JavaScript (Jest):**

```javascript
const axios = require('axios');

describe('Email functionality', () => {
  const https = require('https');
  const axios = require('axios');

  const mailpitUrl = 'https://mailpit.docker.localhost';

  const agent = new https.Agent({
    rejectUnauthorized: false
  });

  const mailpitApi = axios.create({
    baseURL: mailpitUrl,
    httpsAgent: agent
  });

  describe('Email functionality', () => {
    beforeEach(async () => {
      // Clear all emails before each test
      await mailpitApi.delete('/api/v1/messages');
    });

    // ... rest of the test
  });

  it('should send welcome email on user registration', async () => {
    // Trigger your application to send an email
    await axios.post('https://myapp.docker.localhost/api/register', {
      email: 'newuser@example.com',
      password: 'password123'
    });

    // Wait a moment for email to be sent
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Check Mailpit for the email
    const response = await axios.get(`${mailpitUrl}/api/v1/messages`);
    const messages = response.data.messages;

    expect(messages.length).toBe(1);
    expect(messages[0].To[0].Address).toBe('newuser@example.com');
    expect(messages[0].Subject).toContain('Welcome');
  });
});
```

**Example: Automated testing in Python (pytest):**

```python
import pytest
import requests
import time

MAILPIT_URL = 'https://mailpit.docker.localhost'
APP_URL = 'https://myapp.docker.localhost'

@pytest.fixture(autouse=True)
def clear_emails():
    """Clear all emails before each test."""
    requests.delete(f'{MAILPIT_URL}/api/v1/messages', verify=True)
    yield

def test_password_reset_email():
    """Test that password reset sends an email."""
    # Request password reset
    response = requests.post(
        f'{APP_URL}/api/password-reset',
        json={'email': 'user@example.com'},
        verify=False
    )
    assert response.status_code == 200

    # Wait for email to be sent
    time.sleep(1)

    # Check Mailpit for the email
    messages = requests.get(
        f'{MAILPIT_URL}/api/v1/messages',
        verify=False
    ).json()

    assert len(messages['messages']) == 1
    email = messages['messages'][0]
    assert email['To'][0]['Address'] == 'user@example.com'
    assert 'Password Reset' in email['Subject']
```

---

#### Quick Reference: Framework Configuration Summary

| Framework     | Environment Variables                    | Configuration File                   |
|---------------|------------------------------------------|--------------------------------------|
| **Laravel**   | `MAIL_HOST=mailpit`, `MAIL_PORT=1025`    | `.env`                               |
| **Symfony**   | `MAILER_DSN=smtp://mailpit:1025`         | `.env`                               |
| **Django**    | `EMAIL_HOST=mailpit`, `EMAIL_PORT=1025`  | `settings.py`                        |
| **Rails**     | `SMTP_ADDRESS=mailpit`, `SMTP_PORT=1025` | `config/environments/development.rb` |
| **Node.js**   | `SMTP_HOST=mailpit`, `SMTP_PORT=1025`    | Application config                   |
| **FastAPI**   | `SMTP_HOST=mailpit`, `SMTP_PORT=1025`    | `ConnectionConfig`                   |
| **Flask**     | `MAIL_SERVER=mailpit`, `MAIL_PORT=1025`  | `app.config`                         |
| **Go**        | `SMTP_HOST=mailpit`, `SMTP_PORT=1025`    | `os.Getenv()`                        |
| **WordPress** | N/A (plugin)                             | `smtp-config.php`                    |

**Important notes:**

1. **Network requirement**: Your services **must** be on the `traefik-proxy` network to access Mailpit.

2. **Connection strings**: Use container name as hostname:
    - SMTP: `mailpit:1025`
    - Web UI: `https://mailpit.docker.localhost`
    - API: `https://mailpit.docker.localhost/api/v1/`

3. **No authentication**: Mailpit doesn't require SMTP authentication for local development.

4. **No encryption**: Disable TLS/SSL when connecting to Mailpit (port 1025).

5. **Viewing emails**: All captured emails are visible
   at [https://mailpit.docker.localhost](https://mailpit.docker.localhost).

6. **Data persistence**: By default, Mailpit stores emails in memory. They are cleared when the container restarts. For
   persistence, see Mailpit's documentation on database storage.

7. **Multiple projects**: All projects share the same Mailpit instance. Emails from all projects appear in the same
   inbox.

8. **Production safety**: Mailpit only runs in your development environment. In production, configure your real email
   service (SendGrid, Mailgun, SES, etc.).

---

### Custom Domain Patterns

While `*.docker.localhost` is convenient for local development, you may want to use custom domain patterns for various
reasons: better mimicking production URLs, organizing projects by client, or testing specific domain behaviors.

**Supported patterns:**

- Standard subdomain: `myapp.docker.localhost`
- Multi-level subdomain: `admin.myapp.docker.localhost`
- Client-specific domains: `client1.docker.localhost`, `client2.docker.localhost`
- Environment-based: `dev.myapp.docker.localhost`, `staging.myapp.docker.localhost`

**Important**: All custom domains must end with `.docker.localhost` to match the wildcard SSL certificate (
`*.docker.localhost`).

**Scenario 1: Multi-environment setup**

Run dev, staging, and production-like environments locally with different domains.

**compose.yml:**

```yaml
services:
  app-dev:
    image: myapp:latest
    container_name: myapp-dev
    restart: unless-stopped
    environment:
      - APP_ENV=development
      - DATABASE_URL=mysql://root:root@mysql:3306/myapp_dev
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp-dev.rule=Host(`dev.myapp.docker.localhost`)"
      - "traefik.http.routers.myapp-dev.tls=true"
      - "traefik.http.services.myapp-dev.loadbalancer.server.port=8000"

  app-staging:
    image: myapp:latest
    container_name: myapp-staging
    restart: unless-stopped
    environment:
      - APP_ENV=staging
      - DATABASE_URL=mysql://root:root@mysql:3306/myapp_staging
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp-staging.rule=Host(`staging.myapp.docker.localhost`)"
      - "traefik.http.routers.myapp-staging.tls=true"
      - "traefik.http.services.myapp-staging.loadbalancer.server.port=8000"

  app-prod:
    image: myapp:latest
    container_name: myapp-prod
    restart: unless-stopped
    environment:
      - APP_ENV=production
      - DATABASE_URL=mysql://root:root@mysql:3306/myapp_prod
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp-prod.rule=Host(`prod.myapp.docker.localhost`)"
      - "traefik.http.routers.myapp-prod.tls=true"
      - "traefik.http.services.myapp-prod.loadbalancer.server.port=8000"

networks:
  traefik-proxy:
    external: true
```

**Access:**

- Development: `https://dev.myapp.docker.localhost`
- Staging: `https://staging.myapp.docker.localhost`
- Production-like: `https://prod.myapp.docker.localhost`

**Scenario 2: Multi-tenant application**

Host multiple client instances with separate domains.

**compose.yml:**

```yaml
services:
  app-client1:
    image: saas-app:latest
    container_name: saas-client1
    restart: unless-stopped
    environment:
      - TENANT_ID=client1
      - DATABASE_URL=mysql://root:root@mysql:3306/client1_db
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.client1.rule=Host(`client1.docker.localhost`)"
      - "traefik.http.routers.client1.tls=true"
      - "traefik.http.services.client1.loadbalancer.server.port=80"

  app-client2:
    image: saas-app:latest
    container_name: saas-client2
    restart: unless-stopped
    environment:
      - TENANT_ID=client2
      - DATABASE_URL=mysql://root:root@mysql:3306/client2_db
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.client2.rule=Host(`client2.docker.localhost`)"
      - "traefik.http.routers.client2.tls=true"
      - "traefik.http.services.client2.loadbalancer.server.port=80"

networks:
  traefik-proxy:
    external: true
```

**Access:**

- Client 1: `https://client1.docker.localhost`
- Client 2: `https://client2.docker.localhost`

**Scenario 3: Application with admin panel**

Separate public and admin interfaces on different subdomains.

**compose.yml:**

```yaml
services:
  public-app:
    image: myapp:latest
    container_name: myapp-public
    restart: unless-stopped
    command: [ "npm", "run", "start:public" ]
    environment:
      - APP_MODE=public
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp-public.rule=Host(`myapp.docker.localhost`)"
      - "traefik.http.routers.myapp-public.tls=true"
      - "traefik.http.services.myapp-public.loadbalancer.server.port=3000"

  admin-app:
    image: myapp:latest
    container_name: myapp-admin
    restart: unless-stopped
    command: [ "npm", "run", "start:admin" ]
    environment:
      - APP_MODE=admin
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp-admin.rule=Host(`admin.myapp.docker.localhost`)"
      - "traefik.http.routers.myapp-admin.tls=true"
      - "traefik.http.services.myapp-admin.loadbalancer.server.port=3001"

networks:
  traefik-proxy:
    external: true
```

**Access:**

- Public site: `https://myapp.docker.localhost`
- Admin panel: `https://admin.myapp.docker.localhost`

**Domain naming best practices:**

1. **Keep it organized**:
    - Project-based: `projectname.docker.localhost`
    - Feature-based: `api.projectname.docker.localhost`, `admin.projectname.docker.localhost`
    - Environment-based: `dev.projectname.docker.localhost`

2. **Use consistent patterns**:
   ```
   Good:
   - myapp.docker.localhost
   - api.myapp.docker.localhost
   - admin.myapp.docker.localhost

   Avoid mixing:
   - myapp.docker.localhost
   - myapp-api.docker.localhost
   - adminmyapp.docker.localhost
   ```

3. **Router naming convention**: Match router names to domains:
   ```yaml
   # ✅ Good: Clear relationship
   - "traefik.http.routers.myapp-admin.rule=Host(`admin.myapp.docker.localhost`)"

   # ❌ Bad: Unclear relationship
   - "traefik.http.routers.router123.rule=Host(`admin.myapp.docker.localhost`)"
   ```

4. **Document your domains**: Keep a list of active domains in your project README:
   ```markdown
   ## Local Development URLs
   - Frontend: https://myapp.docker.localhost
   - API: https://api.myapp.docker.localhost
   - Admin: https://admin.myapp.docker.localhost
   - Docs: https://docs.myapp.docker.localhost
   ```

**Troubleshooting custom domains:**

**Issue: Certificate warning**

- **Cause**: Domain doesn't match wildcard pattern `*.docker.localhost`
- **Solution**: Ensure domain ends with `.docker.localhost`
- **Invalid**: `myapp.local`, `myapp.test`
- **Valid**: `myapp.docker.localhost`, `admin.myapp.docker.localhost`

**Issue: Domain not resolving**

- **Check Traefik dashboard**: `https://traefik.docker.localhost`
- **Verify router rule**: Look for your router in the HTTP section
- **Check service health**: Ensure container is healthy and accessible

**Issue: Wrong service responding**

- **Cause**: Overlapping router rules
- **Solution**: Use unique, specific domain patterns
- **Check rule priority**: More specific rules should have higher priority

---

### Path-Based Routing

Path-based routing directs requests to different services based on the URL path rather than the domain. This is useful
for microservices architectures where you want a single domain with multiple backend services.

**Use case:** Single domain (`app.docker.localhost`) routing to different services:

- `/` → Frontend
- `/api` → Backend API
- `/admin` → Admin panel
- `/docs` → Documentation

**Scenario: Microservices application with path-based routing**

**compose.yml:**

```yaml
services:
  frontend:
    image: nginx:alpine
    container_name: app-frontend
    restart: unless-stopped
    volumes:
      - ./frontend:/usr/share/nginx/html
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      # Route root path to frontend
      - "traefik.http.routers.app-frontend.rule=Host(`app.docker.localhost`) && PathPrefix(`/`)"
      - "traefik.http.routers.app-frontend.tls=true"
      - "traefik.http.routers.app-frontend.priority=1"
      - "traefik.http.services.app-frontend.loadbalancer.server.port=80"

  api:
    image: node:20-alpine
    container_name: app-api
    restart: unless-stopped
    working_dir: /app
    command: node server.js
    volumes:
      - ./api:/app
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      # Route /api/* to API service
      - "traefik.http.routers.app-api.rule=Host(`app.docker.localhost`) && PathPrefix(`/api`)"
      - "traefik.http.routers.app-api.tls=true"
      - "traefik.http.routers.app-api.priority=10"
      # Strip /api prefix before forwarding to service
      - "traefik.http.routers.app-api.middlewares=api-stripprefix"
      - "traefik.http.middlewares.api-stripprefix.stripprefix.prefixes=/api"
      - "traefik.http.services.app-api.loadbalancer.server.port=4000"

  admin:
    image: node:20-alpine
    container_name: app-admin
    restart: unless-stopped
    working_dir: /app
    command: node server.js
    volumes:
      - ./admin:/app
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      # Route /admin/* to admin service
      - "traefik.http.routers.app-admin.rule=Host(`app.docker.localhost`) && PathPrefix(`/admin`)"
      - "traefik.http.routers.app-admin.tls=true"
      - "traefik.http.routers.app-admin.priority=10"
      # Strip /admin prefix
      - "traefik.http.routers.app-admin.middlewares=admin-stripprefix"
      - "traefik.http.middlewares.admin-stripprefix.stripprefix.prefixes=/admin"
      - "traefik.http.services.app-admin.loadbalancer.server.port=5000"

  docs:
    image: nginx:alpine
    container_name: app-docs
    restart: unless-stopped
    volumes:
      - ./docs:/usr/share/nginx/html
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      # Route /docs/* to documentation
      - "traefik.http.routers.app-docs.rule=Host(`app.docker.localhost`) && PathPrefix(`/docs`)"
      - "traefik.http.routers.app-docs.tls=true"
      - "traefik.http.routers.app-docs.priority=10"
      - "traefik.http.services.app-docs.loadbalancer.server.port=80"

networks:
  traefik-proxy:
    external: true
```

**How it works:**

1. **Priority system**: Higher priority rules are evaluated first
    - Specific paths (`/api`, `/admin`, `/docs`): `priority=10`
    - Root path (`/`): `priority=1`
    - This ensures `/api` matches before `/` (which matches everything)

2. **Path matching**: `PathPrefix()` matches URL paths starting with the specified prefix
    - `PathPrefix(/api)` matches: `/api`, `/api/users`, `/api/products/123`
    - `PathPrefix(/)` matches: Everything (catch-all)

3. **Middleware - StripPrefix**: Removes the path prefix before forwarding
    - Request: `https://app.docker.localhost/api/users`
    - Traefik forwards to service: `http://api:4000/users` (without `/api`)
    - Service sees: `GET /users` (not `GET /api/users`)

**Access URLs:**

- Frontend: `https://app.docker.localhost/`
- API: `https://app.docker.localhost/api/users`
- Admin: `https://app.docker.localhost/admin/dashboard`
- Docs: `https://app.docker.localhost/docs/getting-started`

**Example API service (api/server.js):**

```javascript
const express = require('express');
const app = express();

// Note: No /api prefix needed in routes (StripPrefix removes it)
app.get('/users', (req, res) => {
  res.json({users: ['Alice', 'Bob']});
});

app.get('/products', (req, res) => {
  res.json({products: ['Product 1', 'Product 2']});
});

app.listen(4000, () => {
  console.log('API running on port 4000');
});
```

**When NOT to strip prefix:**

If your service expects the full path, omit the StripPrefix middleware:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.app-api.rule=Host(`app.docker.localhost`) && PathPrefix(`/api`)"
  - "traefik.http.routers.app-api.tls=true"
  - "traefik.http.routers.app-api.priority=10"
  # No StripPrefix middleware
  - "traefik.http.services.app-api.loadbalancer.server.port=4000"
```

Then in your service:

```javascript
// Service handles full path
app.get('/api/users', (req, res) => {
  res.json({users: ['Alice', 'Bob']});
});
```

**Advanced path patterns:**

**1. Exact path match:**

```yaml
- "traefik.http.routers.api-health.rule=Host(`app.docker.localhost`) && Path(`/api/health`)"
```

**2. Path with regex:**

```yaml
- "traefik.http.routers.api-v1.rule=Host(`app.docker.localhost`) && PathPrefix(`/api/v1`)"
- "traefik.http.routers.api-v2.rule=Host(`app.docker.localhost`) && PathPrefix(`/api/v2`)"
```

**3. Multiple path prefixes:**

```yaml
- "traefik.http.routers.static.rule=Host(`app.docker.localhost`) && (PathPrefix(`/static`) || PathPrefix(`/media`))"
```

**4. Combining Host and Path with priority:**

```yaml
services:
  service-a:
    labels:
      - "traefik.http.routers.service-a.rule=Host(`app.docker.localhost`) && PathPrefix(`/service-a`)"
      - "traefik.http.routers.service-a.priority=20"

  service-b:
    labels:
      - "traefik.http.routers.service-b.rule=Host(`app.docker.localhost`) && PathPrefix(`/service-b`)"
      - "traefik.http.routers.service-b.priority=20"

  catch-all:
    labels:
      - "traefik.http.routers.catch-all.rule=Host(`app.docker.localhost`)"
      - "traefik.http.routers.catch-all.priority=1"
```

**Path-based routing best practices:**

1. **Use priorities**: Always set explicit priorities for overlapping paths
   ```yaml
   # Specific paths: high priority (10-20)
   - "traefik.http.routers.api.priority=10"

   # Root/catch-all: low priority (1)
   - "traefik.http.routers.frontend.priority=1"
   ```

2. **Document path structure**: Maintain a routing map in your README:
   ```markdown
   ## API Routes
   | Path | Service | Description |
   |------|---------|-------------|
   | / | frontend | Main application |
   | /api/* | api | REST API |
   | /admin/* | admin | Admin panel |
   | /docs/* | docs | Documentation |
   ```

3. **Test routing**: Verify each path routes to the correct service:
   ```bash
   curl -k https://app.docker.localhost/
   curl -k https://app.docker.localhost/api/users
   curl -k https://app.docker.localhost/admin/dashboard
   ```

4. **Consider using subdomains instead**: For clear service separation, subdomains are often cleaner:
    - Path-based: `app.docker.localhost/api`, `app.docker.localhost/admin`
    - Subdomain-based: `api.app.docker.localhost`, `admin.app.docker.localhost`

---

### Multiple Domains for One Service

Sometimes you need a single service to be accessible via multiple domains. This is useful for:

- Supporting multiple brand domains pointing to the same application
- Providing both a primary and fallback domain
- Testing domain-specific behavior in the same service
- Supporting legacy domain names during migration

**Scenario 1: Multiple domains routing to the same service**

**Use case:** SaaS application accessible via multiple brand domains.

**compose.yml:**

```yaml
services:
  web:
    image: myapp:latest
    container_name: multi-domain-app
    restart: unless-stopped
    networks:
      - traefik-proxy
    healthcheck:
      test: [ "CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8000/health" ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "traefik.enable=true"
      # Multiple domains using OR operator
      - "traefik.http.routers.multi-domain.rule=Host(`brand1.docker.localhost`) || Host(`brand2.docker.localhost`) || Host(`brand3.docker.localhost`)"
      - "traefik.http.routers.multi-domain.tls=true"
      - "traefik.http.services.multi-domain.loadbalancer.server.port=8000"

networks:
  traefik-proxy:
    external: true
```

**Access:**

- `https://brand1.docker.localhost` → Same application
- `https://brand2.docker.localhost` → Same application
- `https://brand3.docker.localhost` → Same application

**Application code** can detect which domain was used:

**Express.js example:**

```javascript
const express = require('express');
const app = express();

app.get('/', (req, res) => {
  const domain = req.hostname;

  // Customize response based on domain
  const brandConfig = {
    'brand1.docker.localhost': {
      name: 'Brand One',
      theme: 'blue',
      logo: '/logos/brand1.png'
    },
    'brand2.docker.localhost': {
      name: 'Brand Two',
      theme: 'red',
      logo: '/logos/brand2.png'
    },
    'brand3.docker.localhost': {
      name: 'Brand Three',
      theme: 'green',
      logo: '/logos/brand3.png'
    }
  };

  const brand = brandConfig[domain] || brandConfig['brand1.docker.localhost'];

  res.json({
    message: `Welcome to ${brand.name}!`,
    domain: domain,
    config: brand
  });
});

app.listen(8000);
```

**Scenario 2: Primary and fallback domains**

**Use case:** Provide a short primary domain and a descriptive fallback.

**compose.yml:**

```yaml
services:
  web:
    image: myapp:latest
    container_name: myapp-web
    restart: unless-stopped
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      # Short primary domain + descriptive fallback
      - "traefik.http.routers.myapp.rule=Host(`app.docker.localhost`) || Host(`myapplication.docker.localhost`)"
      - "traefik.http.routers.myapp.tls=true"
      - "traefik.http.services.myapp.loadbalancer.server.port=8000"

networks:
  traefik-proxy:
    external: true
```

**Access:**

- Primary: `https://app.docker.localhost`
- Fallback: `https://myapplication.docker.localhost`

**Scenario 3: Multiple domains with different paths**

**Use case:** Route different domain+path combinations to the same service with custom handling.

**compose.yml:**

```yaml
services:
  web:
    image: myapp:latest
    container_name: advanced-routing
    restart: unless-stopped
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"

      # Router 1: brand1.docker.localhost/* (all paths)
      - "traefik.http.routers.brand1.rule=Host(`brand1.docker.localhost`)"
      - "traefik.http.routers.brand1.tls=true"
      - "traefik.http.routers.brand1.service=web-service"

      # Router 2: brand2.docker.localhost/* (all paths)
      - "traefik.http.routers.brand2.rule=Host(`brand2.docker.localhost`)"
      - "traefik.http.routers.brand2.tls=true"
      - "traefik.http.routers.brand2.service=web-service"

      # Router 3: app.docker.localhost/brand3/* (specific path)
      - "traefik.http.routers.brand3.rule=Host(`app.docker.localhost`) && PathPrefix(`/brand3`)"
      - "traefik.http.routers.brand3.tls=true"
      - "traefik.http.routers.brand3.priority=10"
      - "traefik.http.routers.brand3.middlewares=brand3-stripprefix"
      - "traefik.http.middlewares.brand3-stripprefix.stripprefix.prefixes=/brand3"
      - "traefik.http.routers.brand3.service=web-service"

      # Shared service definition
      - "traefik.http.services.web-service.loadbalancer.server.port=8000"

networks:
  traefik-proxy:
    external: true
```

**Access:**

- `https://brand1.docker.localhost/` → Service
- `https://brand2.docker.localhost/` → Same service
- `https://app.docker.localhost/brand3/` → Same service (path stripped)

**Scenario 4: Regex-based domain matching**

**Use case:** Match multiple domains with a pattern (e.g., `*.example.docker.localhost`).

**Note:** Traefik supports regex rules for advanced matching.

**compose.yml:**

```yaml
services:
  web:
    image: myapp:latest
    container_name: regex-domain
    restart: unless-stopped
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      # Match any subdomain of example.docker.localhost
      - "traefik.http.routers.wildcard.rule=HostRegexp(`{subdomain:[a-z]+}.example.docker.localhost`)"
      - "traefik.http.routers.wildcard.tls=true"
      - "traefik.http.services.wildcard.loadbalancer.server.port=8000"

networks:
  traefik-proxy:
    external: true
```

**Matches:**

- `https://client1.example.docker.localhost`
- `https://client2.example.docker.localhost`
- `https://any.example.docker.localhost`

**Application can extract subdomain:**

```javascript
app.get('/', (req, res) => {
  const hostname = req.hostname;
  const subdomain = hostname.split('.')[0];

  res.json({
    message: `Welcome to ${subdomain}'s page`,
    subdomain: subdomain
  });
});
```

**Best practices for multiple domains:**

1. **Consolidate rules when possible**: Use OR operator for simple cases:
   ```yaml
   # ✅ Good: Single rule for multiple domains
   - "traefik.http.routers.app.rule=Host(`domain1.docker.localhost`) || Host(`domain2.docker.localhost`)"

   # ❌ Avoid: Multiple routers for the same service (unless you need different middleware)
   ```

2. **Use separate routers for different middleware**:
   ```yaml
   # Router 1: domain1 with authentication
   - "traefik.http.routers.app-auth.rule=Host(`admin.docker.localhost`)"
   - "traefik.http.routers.app-auth.middlewares=auth"

   # Router 2: domain2 without authentication
   - "traefik.http.routers.app-public.rule=Host(`public.docker.localhost`)"
   ```

3. **Document all domains**: Keep a clear list in your project:
   ```markdown
   ## Available Domains
   - https://brand1.docker.localhost (Primary brand)
   - https://brand2.docker.localhost (Secondary brand)
   - https://app.docker.localhost (Admin access)
   ```

4. **Test all domains**:
   ```bash
   for domain in brand1 brand2 brand3; do
     echo "Testing $domain.docker.localhost"
     curl -k https://$domain.docker.localhost
   done
   ```

5. **Consider canonical URLs**: In your application, implement canonical URL handling to avoid duplicate content issues:
   ```javascript
   // Redirect all domains to primary domain
   app.use((req, res, next) => {
     const PRIMARY_DOMAIN = 'app.docker.localhost';
     if (req.hostname !== PRIMARY_DOMAIN) {
       return res.redirect(`https://${PRIMARY_DOMAIN}${req.originalUrl}`);
     }
     next();
   });
   ```

**Verification:**

Check Traefik dashboard to see all routers:

1. Open `https://traefik.docker.localhost`
2. Navigate to **HTTP** → **Routers**
3. Find your router and verify all domains are listed in the **Rule** column

**Troubleshooting:**

**Issue: One domain works, others don't**

- **Check rule syntax**: Ensure proper OR operators (`||`)
- **Verify certificate coverage**: All domains must end with `.docker.localhost`
- **Check Traefik logs**: `docker logs traefik`

**Issue: Domains conflict with other services**

- **Use unique router names**: Each router must have a unique name
- **Check priorities**: Ensure no overlapping rules with different priorities

---

## Advanced Configuration

### Custom Port Mapping

**TODO:** Document how to configure services running on non-standard ports

### Multiple Services per Project

**TODO:** Show how to expose multiple containers from one project

### Custom Domain Configuration

**TODO:** Explain how to use custom domains beyond *.docker.localhost

### Middleware Configuration

Traefik middleware allows you to modify requests and responses as they pass through the proxy. This proxy includes
pre-configured security headers middleware to protect against common web vulnerabilities.

#### Security Headers Middleware

The proxy includes a **security headers middleware** (`security-headers`) that automatically applies essential security
headers to HTTP responses. These headers protect against common attacks like clickjacking, MIME-type sniffing, and
protocol downgrade attacks.

**Included Headers:**

| Header                      | Value                                                        | Purpose                                                       |
|-----------------------------|--------------------------------------------------------------|---------------------------------------------------------------|
| `X-Frame-Options`           | `DENY`                                                       | Prevents clickjacking by blocking iframe embedding            |
| `X-Content-Type-Options`    | `nosniff`                                                    | Prevents MIME-type sniffing attacks                           |
| `Referrer-Policy`           | `strict-origin-when-cross-origin`                            | Controls referrer information sent with requests              |
| `X-XSS-Protection`          | `0`                                                          | Disables browser XSS protection (legacy; CSP is used instead) |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains`                        | Forces HTTPS for 1 year on all subdomains                     |
| `Content-Security-Policy`   | `default-src 'self'; script-src 'self'; style-src 'self'; ...` | Restricts resource loading to prevent XSS                     |

**Applying to Your Services:**

To apply security headers to your custom services, add the middleware to your router labels:

```yaml
services:
  app:
    image: your-app:latest
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app.rule=Host(`app.docker.localhost`)"
      - "traefik.http.routers.app.tls=true"
      # Apply security headers middleware
      - "traefik.http.routers.app.middlewares=security-headers@file"

networks:
  traefik-proxy:
    external: true
```

**Key Points:**

- The `@file` suffix tells Traefik to use middleware defined in the dynamic configuration file (`config/dynamic.yml`)
- Security headers are applied automatically to the Traefik dashboard
- You can chain multiple middlewares by separating them with commas:
  `middlewares=security-headers@file,other-middleware`

**Verification:**

After starting your service, verify the headers are present:

```bash
curl -I https://app.docker.localhost 2>/dev/null | grep -E '(X-Frame-Options|X-Content-Type-Options|Strict-Transport-Security)'
```

**Expected output:**

```
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

**Customizing Security Headers:**

If you need different security header values for a specific service, you can define a custom middleware in your
project's compose file:

```yaml
services:
  app:
    image: your-app:latest
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app.rule=Host(`app.docker.localhost`)"
      - "traefik.http.routers.app.tls=true"
      # Define custom middleware inline
      - "traefik.http.middlewares.custom-headers.headers.customResponseHeaders.X-Frame-Options=SAMEORIGIN"
      - "traefik.http.middlewares.custom-headers.headers.customResponseHeaders.X-Content-Type-Options=nosniff"
      # Apply custom middleware
      - "traefik.http.routers.app.middlewares=custom-headers"

networks:
  traefik-proxy:
    external: true
```

**Common Use Cases:**

1. **Allow iframe embedding (for apps with widgets):**
   ```yaml
   - "traefik.http.middlewares.app-headers.headers.customResponseHeaders.X-Frame-Options=SAMEORIGIN"
   - "traefik.http.routers.app.middlewares=app-headers"
   ```

2. **Custom Content Security Policy (for specific frontend frameworks):**
   ```yaml
   - "traefik.http.middlewares.app-csp.headers.customResponseHeaders.Content-Security-Policy=default-src 'self' https://cdn.example.com"
   - "traefik.http.routers.app.middlewares=app-csp"
   ```

3. **Combine security headers with other middleware:**
   ```yaml
   - "traefik.http.routers.app.middlewares=security-headers@file,compress,ratelimit"
   ```

**For More Information:**

- Traefik Headers Middleware: https://doc.traefik.io/traefik/middlewares/http/headers/
- OWASP Secure Headers Project: https://owasp.org/www-project-secure-headers/

## Troubleshooting

This section covers common integration issues and their solutions. For each problem, we provide diagnostic steps and
fixes.

### Service Not Appearing in Traefik Dashboard

**Symptoms:**

- Your service is running (`docker compose ps` shows "Up")
- Traefik dashboard shows no router for your service
- Accessing your domain returns "404 page not found"

**Diagnostic Steps:**

1. **Verify Traefik labels are present:**

   ```bash
   docker inspect <container_name> --format='{{json .Config.Labels}}' | jq
   ```

   **Expected output:** You should see labels like `traefik.enable`, `traefik.http.routers.*`, etc.

   **If labels are missing:** Check your `compose.yml` syntax. Labels must be under the service definition, not at the
   root level.

2. **Check if service is on the traefik-proxy network:**

   ```bash
   docker inspect <container_name> --format='{{json .NetworkSettings.Networks}}' | jq
   ```

   **Expected output:** You should see `traefik-proxy` in the networks list.

   **If network is missing:** Verify your `compose.yml` includes:
   ```yaml
   services:
     your-service:
       networks:
         - traefik-proxy

   networks:
     traefik-proxy:
       external: true
   ```

3. **Restart the service to re-register with Traefik:**

   ```bash
   docker compose restart
   ```

   Wait 5-10 seconds, then refresh the Traefik dashboard.

**Common Causes:**

- **Label typos:** Ensure label names are exactly as shown (e.g., `traefik.enable`, not `traefik.enabled`)
- **Indentation errors:** YAML is sensitive to indentation. Labels must be at the same level as `image`, `networks`,
  etc.
- **Service not connected to network:** Missing `networks: - traefik-proxy` in service definition
- **External network not declared:** Missing `networks: traefik-proxy: external: true` at compose file root

---

### 502 Bad Gateway Errors

**Symptoms:**

- Service appears in Traefik dashboard
- Accessing the domain returns "502 Bad Gateway"
- Browser shows "upstream connect error or disconnect/reset before headers"

**Diagnostic Steps:**

1. **Check if the container is actually running:**

   ```bash
   docker compose ps
   ```

   **Expected:** Service shows "Up" status.

   **If stopped:** Check container logs for crash reasons:
   ```bash
   docker compose logs <service_name>
   ```

2. **Verify the container is listening on the expected port:**

   ```bash
   docker exec <container_name> netstat -tlnp
   # or for Alpine-based images:
   docker exec <container_name> ss -tlnp
   ```

   **Expected output:** You should see your application listening on the port (e.g., `0.0.0.0:80` or `0.0.0.0:3000`)

   **If not listening:** Your application hasn't started correctly. Check application logs.

3. **Verify Traefik is targeting the correct port:**

   If your application runs on a port other than 80, you must specify it:

   ```yaml
   labels:
     - "traefik.http.services.my-app.loadbalancer.server.port=3000"
   ```

   Check current configuration:
   ```bash
   docker inspect <container_name> --format='{{range $k, $v := .Config.Labels}}{{$k}}={{$v}}{{"\n"}}{{end}}' | grep port
   ```

4. **Test direct container connectivity:**

   From another container on the same network:
   ```bash
   docker run --rm --network traefik-proxy nicolaka/netshoot curl http://<container_name>:<port>
   ```

   **Expected:** HTML response from your application.

   **If fails:** Issue is with your application, not Traefik routing.

**Solutions:**

- **Wrong port configured:** Add or fix the `loadbalancer.server.port` label
- **Application not binding to 0.0.0.0:** Ensure app listens on `0.0.0.0` (all interfaces), not just `127.0.0.1`
- **Application crashed:** Check logs and fix application errors
- **Health check failing:** If you have health checks configured, ensure they pass

---

### Certificate Warnings in Browser

**Symptoms:**

- Browser shows "Your connection is not private" or "NET::ERR_CERT_AUTHORITY_INVALID"
- Certificate error for `*.docker.localhost` domains
- HTTPS connection marked as insecure

**Solution Steps:**

1. **Install the local Certificate Authority:**

   ```bash
   mkcert -install
   ```

   **Expected output:**
   ```
   The local CA is now installed in the system trust store!
   ```

2. **Verify mkcert CA is trusted:**

   ```bash
   mkcert -CAROOT
   ```

   This shows the directory where the CA certificates are stored.

   **On Linux:** Check if CA is in NSS database:
   ```bash
   certutil -d sql:$HOME/.pki/nssdb -L | grep mkcert
   ```

3. **Restart your browser completely:**

    - Close all browser windows and tabs
    - On Linux, ensure all browser processes are stopped:
      ```bash
      pkill -f firefox
      # or
      pkill -f chrome
      ```
    - Reopen the browser and test again

4. **Verify certificate files exist and are readable:**

   ```bash
   ls -l certs/
   ```

   **Expected output:**
   ```
   -rw-r--r-- 1 user user 1234 ... local-cert.pem
   -rw-r--r-- 1 user user 5678 ... local-key.pem
   ```

   **If missing:** Regenerate certificates:
   ```bash
   mkcert -key-file certs/local-key.pem \
     -cert-file certs/local-cert.pem \
     "localhost" "*.docker.localhost" "127.0.0.1" "::1"
   chmod 644 certs/local-cert.pem
   chmod 600 certs/local-key.pem
   docker compose restart traefik
   ```

**Special Cases:**

- **Firefox:** May require additional steps. Go to `about:preferences#privacy`, scroll to "Certificates", click "View
  Certificates", then "Authorities" tab. Import the mkcert CA manually if needed.
- **Chrome/Chromium:** Uses system trust store. Ensure `libnss3-tools` is installed.
- **Private/Incognito mode:** Some browsers don't trust local CAs in private mode. Use normal browsing mode for
  development.

---

### Network traefik-proxy Not Found

**Symptoms:**

- `docker compose up` fails with error: `network traefik-proxy declared as external, but could not be found`
- Container won't start due to missing network

**Solution:**

1. **Create the network:**

   ```bash
   docker network create traefik-proxy
   ```

   **Expected output:**
   ```
   <network_id>
   ```

2. **Verify network exists:**

   ```bash
   docker network ls | grep traefik-proxy
   ```

   **Expected output:**
   ```
   <id>  traefik-proxy  bridge  local
   ```

3. **Restart your project:**

   ```bash
   docker compose up -d
   ```

**Prevention:**

This network is created automatically by the `setup.sh` script. If you performed manual installation, ensure this step
is included in your setup process.

**Note:** This network persists even after stopping containers. You only need to create it once per Docker host.

---

### Port Conflicts (80/443 Already in Use)

**Symptoms:**

- Traefik container fails to start
- Error message: `Bind for 0.0.0.0:80 failed: port is already allocated`
- Docker logs show port binding errors

**Diagnostic Steps:**

1. **Identify what's using the ports:**

   ```bash
   sudo lsof -i :80
   sudo lsof -i :443
   ```

   **or:**

   ```bash
   sudo netstat -tlnp | grep ':80\|:443'
   ```

   **Common culprits:**
    - Apache (`apache2`, `httpd`)
    - Nginx
    - Another Traefik instance
    - Other Docker containers with port mappings

2. **Check for other Traefik instances:**

   ```bash
   docker ps -a | grep traefik
   ```

   If you see multiple Traefik containers, stop the unwanted ones:
   ```bash
   docker stop <container_id>
   docker rm <container_id>
   ```

3. **Check for conflicting Docker containers:**

   ```bash
   docker ps --filter "publish=80" --filter "publish=443"
   ```

**Solutions:**

- **System web server running:** Stop it temporarily:
  ```bash
  sudo systemctl stop apache2
  # or
  sudo systemctl stop nginx
  ```

  To disable permanently:
  ```bash
  sudo systemctl disable apache2
  ```

- **Another Docker container:** Stop the conflicting container or remove its port mapping (it can use Traefik instead!)

- **Multiple Traefik instances:** Keep only one Traefik instance. This proxy is designed to be a single shared reverse
  proxy for all projects.

- **Port forwarding rules:** Check if you have custom iptables rules or Docker networks with conflicting port mappings

**Alternative Solution (Advanced):**

If you must keep another service on 80/443, you can modify Traefik to use different ports in `docker-compose.yml`:

```yaml
services:
  traefik:
    ports:
      - "8080:80"
      - "8443:443"
```

However, this defeats the purpose of using standard HTTP/HTTPS ports and is not recommended.

---

### Checking Traefik Logs

Traefik logs are essential for diagnosing routing and connectivity issues.

**View Real-Time Logs:**

```bash
docker logs -f traefik
```

Press `Ctrl+C` to stop following.

**View Last 50 Lines:**

```bash
docker logs traefik --tail 50
```

**View Logs Since Specific Time:**

```bash
docker logs traefik --since 30m  # Last 30 minutes
docker logs traefik --since 2024-01-15T10:00:00
```

**Search Logs for Specific Service:**

```bash
docker logs traefik 2>&1 | grep "my-app"
```

**Common Log Patterns:**

- **Successful registration:**
  ```
  Router my-app@docker registered
  ```

- **Service discovery:**
  ```
  Adding route for service-name
  ```

- **Connection errors:**
  ```
  error: dial tcp <ip>:<port>: connect: connection refused
  ```

- **Certificate issues:**
  ```
  error: tls: failed to verify certificate
  ```

**Enable Debug Logging (if needed):**

Edit `docker-compose.yml` and add to Traefik command:

```yaml
services:
  traefik:
    command:
      # ... existing commands ...
      - "--log.level=DEBUG"
```

Then restart Traefik:

```bash
docker compose restart traefik
```

**Warning:** Debug logging is very verbose. Only enable temporarily for troubleshooting, then revert to `INFO` or
`ERROR` level.

---

### Quick Diagnostic Checklist

When facing integration issues, run through this checklist:

- [ ] Is Traefik running? (`docker ps | grep traefik`)
- [ ] Does `traefik-proxy` network exist? (`docker network ls`)
- [ ] Is your service running? (`docker compose ps`)
- [ ] Is your service on the `traefik-proxy` network? (`docker inspect <container>`)
- [ ] Are Traefik labels present and correctly spelled? (`docker inspect <container>`)
- [ ] Does the service appear in Traefik dashboard? (Visit `https://traefik.docker.localhost`)
- [ ] Is your application listening on the correct port inside the container?
- [ ] Are there any errors in Traefik logs? (`docker logs traefik`)
- [ ] Are there any errors in your service logs? (`docker compose logs`)
- [ ] Is mkcert CA installed? (`mkcert -CAROOT`)

**Still having issues?**

1. Compare your configuration against the [Quick Start](#quick-start) example
2. Test with a minimal Nginx container first to isolate the issue
3. Check Traefik's official documentation for label syntax: https://doc.traefik.io/traefik/routing/routers/
4. Review your specific framework's requirements in [Framework-Specific Examples](#framework-specific-examples)

## Best Practices

### Naming Conventions

**TODO:** Document recommended naming patterns for routers and services

### Security Considerations

**TODO:** Document security best practices

### Performance Optimization

**TODO:** Add performance tuning tips

---

## FAQ

### When should I use ports vs no ports in my compose.yml?

**Short answer:** For services proxied through Traefik, **do not** use a `ports:` section.

**Detailed explanation:**

When a service is connected to the `traefik-proxy` network and has proper Traefik labels:

- ❌ **Don't use `ports:`** - Traefik handles all routing internally
- ✅ **Use labels** - Define routing rules via Traefik labels
- ✅ **Access via domain** - Use `https://your-app.docker.localhost`

```yaml
# ✅ CORRECT - No ports section
services:
  web:
    image: nginx:alpine
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.web.rule=Host(`web.docker.localhost`)"
      - "traefik.http.routers.web.tls=true"
```

```yaml
# ❌ INCORRECT - Ports section conflicts with proxy
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"  # Don't do this!
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.web.rule=Host(`web.docker.localhost`)"
      - "traefik.http.routers.web.tls=true"
```

**Exceptions - When to use `ports:`:**

1. **Development tools not accessed via browser:**
   ```yaml
   services:
     database:
       image: postgres:15
       ports:
         - "5432:5432"  # OK - For direct database client connections
   ```

2. **Services with non-HTTP protocols:**
   ```yaml
   services:
     ssh-server:
       image: linuxserver/openssh-server
       ports:
         - "2222:2222"  # OK - SSH is not HTTP
   ```

3. **Services not using the proxy at all:**
   ```yaml
   services:
     background-worker:
       image: my-worker:latest
       ports:
         - "9090:9090"  # OK - Not connected to traefik-proxy
   ```

**Why avoid ports with Traefik?**

- **Port conflicts:** Multiple projects can't use the same port
- **No HTTPS:** Direct port access bypasses SSL certificates
- **Manual management:** You lose automatic routing benefits

---

### Can I use custom domains (not .docker.localhost)?

**Yes**, but with limitations and additional configuration.

#### Option 1: Custom .localhost Subdomain (Recommended)

You can use **any subdomain** under `.localhost`:

```yaml
labels:
  - "traefik.http.routers.app.rule=Host(`my-custom-app.localhost`)"
```

**Advantages:**

- ✅ No additional DNS configuration needed
- ✅ Works out of the box on all platforms
- ✅ Existing SSL certificate covers `*.localhost` (if configured)

**Requirement:**
Regenerate certificates to include your custom pattern:

```bash
mkcert -key-file certs/local-key.pem \
  -cert-file certs/local-cert.pem \
  "localhost" "*.localhost" "*.docker.localhost" "127.0.0.1" "::1"
chmod 644 certs/local-cert.pem
chmod 600 certs/local-key.pem
docker compose restart traefik
```

#### Option 2: Custom Top-Level Domain (Advanced)

Use completely custom domains like `my-app.local` or `project.dev`:

**Requirements:**

1. **DNS Resolution:** Add entries to `/etc/hosts` or use dnsmasq
2. **SSL Certificate:** Generate certificates for your custom domain
3. **Traefik Configuration:** Update labels accordingly

**Example `/etc/hosts` entry:**

```
127.0.0.1 my-app.local
127.0.0.1 api.my-app.local
```

**Generate custom certificate:**

```bash
mkcert -key-file certs/custom-key.pem \
  -cert-file certs/custom-cert.pem \
  "*.my-app.local" "my-app.local"
```

**Update Traefik dynamic config** (`config/dynamic.yml`):

```yaml
tls:
  certificates:
    - certFile: /certs/local-cert.pem
      keyFile: /certs/local-key.pem
    - certFile: /certs/custom-cert.pem
      keyFile: /certs/custom-key.pem
```

**Use in your project:**

```yaml
labels:
  - "traefik.http.routers.app.rule=Host(`my-app.local`)"
  - "traefik.http.routers.app.tls=true"
```

**Limitations:**

- ❌ Requires manual `/etc/hosts` management per domain
- ❌ More complex certificate management
- ❌ Team members need the same setup

**Recommendation:** Stick with `.docker.localhost` or `.localhost` for simplicity.

---

### What is the performance impact of using this proxy?

**Short answer:** Minimal overhead (<5ms latency per request) for local development.

#### Performance Characteristics

**Latency:**

- **Direct access (localhost:8080):** ~0.5ms
- **Via Traefik proxy:** ~2-5ms
- **Overhead:** 1.5-4.5ms per request

**Throughput:**

- Traefik is a production-grade proxy handling 10k+ req/sec
- Local development rarely exceeds 100 req/sec
- **No noticeable impact** in typical development scenarios

#### What Adds Overhead?

1. **TLS Termination:** ~1-2ms per request
2. **Docker Network Bridge:** ~0.5-1ms
3. **Routing Logic:** <0.5ms

#### Performance Benefits

Despite minimal overhead, the proxy provides:

- ✅ **Faster project switching** - No port reconfiguration
- ✅ **Parallel development** - Run multiple projects simultaneously
- ✅ **Caching (if configured)** - Can reduce backend load
- ✅ **HTTP/2 support** - Better resource loading

#### Benchmarking Your Setup

Test direct vs proxied access:

```bash
# Direct container access (if port exposed)
ab -n 1000 -c 10 http://localhost:8080/

# Via proxy
ab -n 1000 -c 10 https://my-app.docker.localhost/
```

**Typical results:**

- Direct: ~950 req/sec
- Proxied: ~920 req/sec (~3% difference)

#### When Performance Matters

**Proxy overhead is negligible** for:

- Web application development
- API development
- Frontend development
- Database-backed applications

**Consider direct access** for:

- High-frequency API load testing (>5000 req/sec)
- Profiling/benchmarking scenarios
- WebSocket-heavy applications (though Traefik handles these well)

**Bottom line:** For 99% of local development use cases, the convenience far outweighs the minimal performance cost.

---

### Can I run multiple Traefik instances?

**Not recommended, but possible with careful configuration.**

#### Why You Shouldn't

Running multiple Traefik instances creates:

- ❌ **Port conflicts** - Both need ports 80/443
- ❌ **Network confusion** - Which proxy handles which service?
- ❌ **Certificate management overhead** - Multiple CA setups
- ❌ **Dashboard conflicts** - Both want `traefik.docker.localhost`

#### Valid Use Cases

Multiple instances may be needed for:

1. **Isolated environments** (e.g., work vs personal projects)
2. **Testing different Traefik versions**
3. **Separate network security boundaries**

#### How to Run Multiple Instances

If you must run multiple instances, configure them as follows:

**Instance 1 (Primary - ports 80/443):**

```yaml
# docker-compose.yml
services:
  traefik:
    ports:
      - "80:80"
      - "443:443"
    labels:
      - "traefik.http.routers.dashboard.rule=Host(`traefik.docker.localhost`)"
networks:
  traefik-proxy:
    external: true
```

**Instance 2 (Secondary - different ports):**

```yaml
# docker-compose-alt.yml
services:
  traefik-alt:
    image: traefik:v3.2
    ports:
      - "8080:80"    # Different host port
      - "8443:443"   # Different host port
    command:
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
    labels:
      - "traefik.http.routers.dashboard-alt.rule=Host(`traefik-alt.docker.localhost`)"
networks:
  traefik-proxy-alt: # Different network name
    external: true
```

**Create the second network:**

```bash
docker network create traefik-proxy-alt
```

**Access secondary instance:**

- HTTP: `http://localhost:8080` → Routes to secondary Traefik
- HTTPS: `https://localhost:8443` → Routes to secondary Traefik
- Must specify port in URL: `https://app.docker.localhost:8443`

#### Better Alternative: Single Instance with Priorities

Instead of multiple instances, use **priority-based routing** for different project groups:

```yaml
# High-priority project
labels:
  - "traefik.http.routers.prod-app.rule=Host(`app.docker.localhost`)"
  - "traefik.http.routers.prod-app.priority=100"

# Low-priority fallback
labels:
  - "traefik.http.routers.test-app.rule=Host(`app.docker.localhost`)"
  - "traefik.http.routers.test-app.priority=50"
```

**Recommendation:** Use a single Traefik instance for all local projects. If you need isolation, use different **domains
** (e.g., `work-project.docker.localhost` vs `personal-project.docker.localhost`), not multiple proxies.

---

### Should I use this proxy in production?

**No. This project is designed exclusively for local development.**

#### Why Not Production?

This setup includes development-focused configurations that are **not production-ready:**

1. **⚠️ Self-signed certificates**
    - mkcert generates locally-trusted CA
    - Not trusted by public browsers/clients
    - Only works on machines where CA is installed

2. **⚠️ Localhost-only domains**
    - `.docker.localhost` only resolves locally
    - No public DNS resolution

3. **⚠️ Docker socket exposure**
    - Traefik has access to `/var/run/docker.sock`
    - Security risk in multi-tenant environments

4. **⚠️ Dashboard exposed**
    - API dashboard is enabled without authentication
    - Exposes routing configuration

5. **⚠️ No high-availability setup**
    - Single container (no redundancy)
    - Not suitable for uptime requirements

#### Production-Ready Alternatives

For production deployments, use:

**1. Traefik with Let's Encrypt:**

```yaml
services:
  traefik:
    image: traefik:v3.2
    command:
      - "--certificatesresolvers.letsencrypt.acme.email=admin@example.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
    labels:
      - "traefik.http.routers.app.tls.certresolver=letsencrypt"
```

**2. Cloud Load Balancers:**

- AWS Application Load Balancer (ALB)
- Google Cloud Load Balancing
- Azure Application Gateway

**3. Managed Reverse Proxies:**

- Cloudflare (with origin certificates)
- AWS CloudFront
- Fastly

**4. Enterprise Solutions:**

- Nginx Ingress Controller (Kubernetes)
- HAProxy
- Istio Service Mesh

#### Adapting This Setup for Production

If you want to use Traefik in production, you need to:

1. **✅ Replace mkcert with Let's Encrypt**
2. **✅ Use real domain names with DNS**
3. **✅ Remove Docker socket access (use file provider)**
4. **✅ Enable authentication on dashboard**
5. **✅ Implement monitoring and logging**
6. **✅ Add rate limiting and security middleware**
7. **✅ Use Docker Swarm or Kubernetes for HA**

**Reference:**
See [Traefik's production documentation](https://doc.traefik.io/traefik/user-guides/docker-compose/acme-http/)

**Final word:** Use this proxy to streamline your **local development workflow**. For production, design a proper
infrastructure with public CAs, monitoring, and high availability.

---

### Does this work on Windows and macOS?

**Yes!** The automated `setup.sh` script now supports Linux, macOS, and Windows WSL2.

#### Platform Compatibility Matrix

| Feature             | Linux | macOS | Windows (WSL2) | Windows (Native) |
|---------------------|-------|-------|----------------|------------------|
| Automated setup.sh  | ✅     | ✅     | ✅              | ⚠️ Manual        |
| mkcert auto-install | ✅     | ✅     | ✅              | ⚠️ Manual        |
| Traefik proxy       | ✅     | ✅     | ✅              | ✅                |
| HTTPS certificates  | ✅     | ✅     | ✅              | ✅                |

#### Setup Instructions by Platform

**Linux (Ubuntu/Debian/Fedora/Arch):**

```bash
chmod +x setup.sh
./setup.sh
```

That's it! The script automatically detects your package manager and installs everything.

**macOS:**

```bash
chmod +x setup.sh
./setup.sh
```

- If Homebrew is installed, the script uses it to install mkcert (preferred)
- If Homebrew is not available, downloads mkcert binary directly
- Certificates are automatically trusted in macOS Keychain
- Requires Docker Desktop for Mac to be running

**Windows WSL2 (Recommended):**

```bash
chmod +x setup.sh
./setup.sh
```

- Works in any WSL2 distribution (Ubuntu, Debian, etc.)
- Automatically detects WSL2 environment
- Certificates trusted in WSL2 browsers automatically
- Additional step: Import CA to Windows certificate store for Windows browsers (instructions displayed after setup)
- Requires Docker Desktop with WSL2 integration

**Windows (Native Docker Desktop):**
Manual setup required - follow the manual installation steps in the main README.

#### Platform-Specific Notes

**macOS:**

- Docker Desktop must be installed and running before running setup.sh
- Script checks for Docker Desktop availability and provides helpful error messages
- Homebrew is preferred but not required

**WSL2:**

- After setup completes, additional instructions are displayed for trusting certificates in Windows browsers
- Copy the mkcert root CA to Windows and import to "Trusted Root Certification Authorities"
- Linux browsers (Firefox, Chrome in WSL2) trust certificates automatically

**Cross-platform development:**
If your team uses mixed platforms, everyone can now use the same setup.sh script!

- ✅ All platforms use the same setup command
- ✅ Script automatically detects platform and adjusts accordingly
- ✅ Clear error messages if Docker or dependencies are missing

#### Platform Recommendation

| Scenario          | Recommended Platform  | Setup Experience |
|-------------------|-----------------------|------------------|
| Linux development | Native Linux          | ⭐⭐⭐⭐⭐ Best       |
| macOS required    | Docker Desktop        | ⭐⭐⭐⭐ Great       |
| Windows required  | WSL2 + Docker Desktop | ⭐⭐⭐⭐ Great       |
| Native Windows    | Manual setup          | ⭐⭐⭐ Good         |

**Bottom line:** The proxy works on all platforms, and setup.sh now automates installation for Linux, macOS, and WSL2!

---

**Have more questions?** Check the [Troubleshooting](#troubleshooting) section or refer to
the [main README](../README.md) for additional resources.

*This guide is under active development. Sections marked with TODO will be completed in upcoming updates.*
