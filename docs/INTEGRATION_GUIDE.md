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

Python applications can be served using various WSGI/ASGI servers like Gunicorn, Uvicorn, or directly with built-in development servers. The examples below cover popular frameworks with production-ready configurations.

#### Django with Gunicorn

Django applications are best served with Gunicorn in production environments. This example includes PostgreSQL database integration.

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
      test: ["CMD", "curl", "-f", "http://localhost:8000/health/"]
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
      test: ["CMD", "pg_isready", "-U", "django"]
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

FastAPI is a modern, async Python framework that's perfect for building APIs. This example shows FastAPI with Uvicorn ASGI server.

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
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
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
      test: ["CMD", "pg_isready", "-U", "fastapi"]
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
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
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
      test: ["CMD", "pg_isready", "-U", "flask"]
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

1. **Port specification:** Always specify the port your application listens on using the `traefik.http.services.<name>.loadbalancer.server.port` label:
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
