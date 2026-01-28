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

Node.js applications can run directly with Node or through process managers like PM2. The examples below cover popular frameworks with both development and production configurations.

#### Express.js Application

Express.js applications typically run on port 3000 by default. This example shows a simple Express app with custom port configuration.

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
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/health"]
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
  res.status(200).json({ status: 'ok' });
});

// Main route
app.get('/', (req, res) => {
  res.json({ message: 'Hello from Express!' });
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

Next.js applications require special consideration for hot reload and development server configuration. This example includes both development and production setups.

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
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/"]
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

NestJS applications follow a modular architecture and work well with Docker. This example includes development and production configurations.

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
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/health"]
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
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

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
import { Controller, Get } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  check() {
    return { status: 'ok', timestamp: new Date().toISOString() };
  }
}
```

**Usage:**
```bash
docker compose up -d
```

Access your NestJS app at: `https://nestjs.docker.localhost`

**Development with hot reload:**
The Dockerfile.dev configuration automatically enables hot reload through NestJS's watch mode. Changes to TypeScript files will trigger automatic recompilation.

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

1. **Port configuration:** Always use the `traefik.http.services.<name>.loadbalancer.server.port` label to specify the port your Node.js app listens on. This is crucial when your app doesn't use port 80.

2. **Hot reload in Docker:**
   - For Next.js: Use `WATCHPACK_POLLING=true` and configure webpack dev middleware
   - For NestJS: Use `--watch` flag in development
   - For Express/custom apps: Use `nodemon` with polling enabled
   - Always mount source code as volumes for development

3. **node_modules handling:** Use a separate volume for `node_modules` to prevent host files from overwriting container dependencies:
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

6. **Multi-stage builds:** For production, use multi-stage Dockerfiles to reduce final image size and include only necessary files.

7. **Custom ports examples:**
   - Port 8080: `traefik.http.services.myapp.loadbalancer.server.port=8080`
   - Port 4000: `traefik.http.services.myapp.loadbalancer.server.port=4000`
   - Port 5000: `traefik.http.services.myapp.loadbalancer.server.port=5000`

8. **Database connections:** When connecting to the proxy's MySQL service, use `mysql` as the hostname (not `localhost` or `127.0.0.1`).

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
