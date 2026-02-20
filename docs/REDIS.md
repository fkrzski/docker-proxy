# Redis Documentation

This guide covers Redis configuration, password authentication, and connection management in the Local Docker Proxy. It includes client configuration examples for various programming languages and frameworks, along with troubleshooting tips and best practices.

## Table of Contents

- [Overview](#overview)
- [Authentication Configuration](#authentication-configuration)
  - [Password Setup](#password-setup)
  - [How Authentication Works](#how-authentication-works)
- [Connecting to Redis](#connecting-to-redis)
  - [From Docker Containers](#from-docker-containers)
  - [From Host Machine](#from-host-machine)
  - [Connection Examples](#connection-examples)
- [CLI Usage](#cli-usage)
  - [Interactive Shell](#interactive-shell)
  - [Common Commands](#common-commands)
- [Client Configuration](#client-configuration)
  - [PHP / Predis](#php--predis)
  - [PHP / phpredis](#php--phpredis)
  - [Node.js / ioredis](#nodejs--ioredis)
  - [Node.js / redis](#nodejs--redis)
  - [Python / redis-py](#python--redis-py)
  - [Laravel](#laravel)
  - [Django](#django)
  - [Ruby on Rails](#ruby-on-rails)
  - [Prisma (with Redis cache)](#prisma-with-redis-cache)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Overview

The Local Docker Proxy includes Redis as an optional service, using Docker's profile system for on-demand activation. Redis is an in-memory data structure store used as a database, cache, message broker, and streaming engine.

**Key Features:**
- ✅ Redis Alpine-based image for minimal footprint
- ✅ Password authentication enabled by default via `REDIS_PASSWORD`
- ✅ Automatic healthchecks for container reliability
- ✅ No exposed ports (accessed via Docker network only)
- ✅ Lightweight and fast in-memory data store

**Service Configuration:**
- **Image**: `redis:8.6.0-alpine`
- **Container Name**: `redis`
- **Profile**: `redis` (must be enabled in `COMPOSE_PROFILES`)
- **Default Port**: `6379` (internal to Docker network)
- **Network**: `traefik-proxy` (shared with other services)

**Environment Variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_PASSWORD` | `redis` | Password for Redis authentication (required) |

## Authentication Configuration

### Password Setup

Redis password authentication is configured via the `REDIS_PASSWORD` environment variable in your `.env` file:

```bash
# In .env
REDIS_PASSWORD=redis
```

The password is passed to Redis via the `--requirepass` flag in the container's command. The `REDIS_PASSWORD` variable is **required** — if not set, the container will fail to start with an error message.

**Changing the Password:**

1. Update the `REDIS_PASSWORD` value in `.env`:
   ```bash
   REDIS_PASSWORD=your_new_secure_password
   ```

2. Restart the Redis container:
   ```bash
   docker compose up -d redis
   ```

3. Update all applications that connect to Redis with the new password.

**Generating a Strong Password:**
```bash
openssl rand -base64 24
```

### How Authentication Works

Redis uses a simple password-based authentication mechanism:

1. Clients connect to Redis on port `6379`
2. Before executing any command, clients must authenticate using the `AUTH` command
3. Most client libraries handle authentication automatically when provided a password
4. The `REDISCLI_AUTH` environment variable is set inside the container, allowing `redis-cli` to authenticate automatically

**Security Note:** Redis password authentication is suitable for local development environments. For production, consider using Redis ACLs (Access Control Lists) for fine-grained user permissions.

## Connecting to Redis

### From Docker Containers

Containers on the `traefik-proxy` network can connect to Redis using the container name as hostname:

```yaml
# In your application's docker-compose.yml
services:
  app:
    image: your-app
    environment:
      REDIS_HOST: redis
      REDIS_PORT: 6379
      REDIS_PASSWORD: ${REDIS_PASSWORD}
    networks:
      - traefik-proxy

networks:
  traefik-proxy:
    external: true
```

**Connection String:**
```
redis://:${REDIS_PASSWORD}@redis:6379
```

### From Host Machine

Redis is not exposed to the host by default for security. To connect from your host machine, you have several options:

**Option 1: Use `docker exec` (Recommended)**
```bash
# Interactive Redis CLI (password is auto-provided via REDISCLI_AUTH)
docker exec -it redis redis-cli

# Execute a single command
docker exec redis redis-cli PING

# Execute with explicit authentication
docker exec redis redis-cli -a "${REDIS_PASSWORD}" PING
```

**Option 2: Expose Port (Less Secure)**

Add port mapping to `docker-compose.yml`:
```yaml
redis:
  # ... existing configuration ...
  ports:
    - "6379:6379"  # Expose to host
```

Then connect:
```bash
redis-cli -h 127.0.0.1 -p 6379 -a "${REDIS_PASSWORD}"
```

### Connection Examples

**Basic Connection Test:**
```bash
# Test from within the container
docker exec redis redis-cli PING
# Expected: PONG

# Check Redis version
docker exec redis redis-cli INFO server | grep redis_version

# Check memory usage
docker exec redis redis-cli INFO memory | grep used_memory_human
```

**Key Operations:**
```bash
# Set a key
docker exec redis redis-cli SET mykey "Hello World"

# Get a key
docker exec redis redis-cli GET mykey

# List all keys (use with caution in production)
docker exec redis redis-cli KEYS "*"

# Check number of keys
docker exec redis redis-cli DBSIZE
```

## CLI Usage

### Interactive Shell

The Redis container has `REDISCLI_AUTH` set, so `redis-cli` authenticates automatically:

```bash
# Start interactive session
docker exec -it redis redis-cli

# You can immediately run commands without AUTH
127.0.0.1:6379> PING
PONG
127.0.0.1:6379> SET greeting "Hello"
OK
127.0.0.1:6379> GET greeting
"Hello"
127.0.0.1:6379> EXIT
```

### Common Commands

**Data Operations:**
```bash
# Strings
docker exec redis redis-cli SET user:1:name "John"
docker exec redis redis-cli GET user:1:name
docker exec redis redis-cli INCR counter
docker exec redis redis-cli EXPIRE mykey 3600  # TTL in seconds

# Hashes
docker exec redis redis-cli HSET user:1 name "John" email "john@example.com"
docker exec redis redis-cli HGETALL user:1

# Lists
docker exec redis redis-cli LPUSH queue "task1" "task2"
docker exec redis redis-cli RPOP queue

# Sets
docker exec redis redis-cli SADD tags "redis" "docker" "cache"
docker exec redis redis-cli SMEMBERS tags
```

**Administrative Commands:**
```bash
# Server info
docker exec redis redis-cli INFO

# Connected clients
docker exec redis redis-cli CLIENT LIST

# Flush all data (use with caution)
docker exec redis redis-cli FLUSHALL

# Monitor commands in real-time
docker exec -it redis redis-cli MONITOR

# Check configuration
docker exec redis redis-cli CONFIG GET requirepass
docker exec redis redis-cli CONFIG GET maxmemory
```

## Client Configuration

### PHP / Predis

```php
<?php
require 'vendor/autoload.php';

$client = new Predis\Client([
    'scheme' => 'tcp',
    'host'   => 'redis',
    'port'   => 6379,
    'password' => getenv('REDIS_PASSWORD'),
]);

$client->set('key', 'value');
echo $client->get('key'); // "value"
```

### PHP / phpredis

```php
<?php
$redis = new Redis();
$redis->connect('redis', 6379);
$redis->auth(getenv('REDIS_PASSWORD'));

$redis->set('key', 'value');
echo $redis->get('key'); // "value"
```

**Required Extension:** Ensure the `redis` PHP extension is installed and enabled.

### Node.js / ioredis

The `ioredis` package is a robust Redis client for Node.js:

```javascript
const Redis = require('ioredis');

const redis = new Redis({
  host: 'redis',
  port: 6379,
  password: process.env.REDIS_PASSWORD,
});

await redis.set('key', 'value');
const value = await redis.get('key');
console.log(value); // "value"

// Or using a connection string
const redis = new Redis(`redis://:${process.env.REDIS_PASSWORD}@redis:6379`);
```

### Node.js / redis

The official `redis` package (v4+):

```javascript
const { createClient } = require('redis');

const client = createClient({
  url: `redis://:${process.env.REDIS_PASSWORD}@redis:6379`,
});

client.on('error', (err) => console.log('Redis Client Error', err));

await client.connect();
await client.set('key', 'value');
const value = await client.get('key');
console.log(value); // "value"
await client.disconnect();
```

### Python / redis-py

```python
import os
import redis

r = redis.Redis(
    host='redis',
    port=6379,
    password=os.environ.get('REDIS_PASSWORD'),
    decode_responses=True,
)

r.set('key', 'value')
print(r.get('key'))  # "value"

# Or using a connection URL
r = redis.from_url(f"redis://:{os.environ.get('REDIS_PASSWORD')}@redis:6379/0")
```

**Using Connection Pool:**
```python
pool = redis.ConnectionPool(
    host='redis',
    port=6379,
    password=os.environ.get('REDIS_PASSWORD'),
    max_connections=10,
    decode_responses=True,
)

r = redis.Redis(connection_pool=pool)
```

### Laravel

Laravel's Redis configuration in `config/database.php`:

```php
'redis' => [
    'client' => env('REDIS_CLIENT', 'phpredis'),

    'default' => [
        'host' => env('REDIS_HOST', 'redis'),
        'password' => env('REDIS_PASSWORD'),
        'port' => env('REDIS_PORT', '6379'),
        'database' => env('REDIS_DB', '0'),
    ],

    'cache' => [
        'host' => env('REDIS_HOST', 'redis'),
        'password' => env('REDIS_PASSWORD'),
        'port' => env('REDIS_PORT', '6379'),
        'database' => env('REDIS_CACHE_DB', '1'),
    ],
],
```

**Docker Compose environment:**
```yaml
services:
  laravel:
    environment:
      REDIS_HOST: redis
      REDIS_PORT: 6379
      REDIS_PASSWORD: ${REDIS_PASSWORD}
```

### Django

Django's cache configuration in `settings.py` using `django-redis`:

```python
CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': f"redis://:{os.environ.get('REDIS_PASSWORD')}@redis:6379/0",
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
        },
    }
}

# Optional: Use Redis for session storage
SESSION_ENGINE = 'django.contrib.sessions.backends.cache'
SESSION_CACHE_ALIAS = 'default'
```

### Ruby on Rails

Rails Redis configuration for caching and Action Cable:

```ruby
# config/initializers/redis.rb
$redis = Redis.new(
  host: ENV.fetch('REDIS_HOST', 'redis'),
  port: ENV.fetch('REDIS_PORT', 6379),
  password: ENV['REDIS_PASSWORD']
)

# config/cable.yml
production:
  adapter: redis
  url: <%= "redis://:#{ENV['REDIS_PASSWORD']}@redis:6379/1" %>

# config/environments/development.rb
config.cache_store = :redis_cache_store, {
  url: "redis://:#{ENV['REDIS_PASSWORD']}@redis:6379/0"
}
```

### Prisma (with Redis cache)

Prisma doesn't directly use Redis, but you can use Redis for caching alongside Prisma:

```javascript
const { createClient } = require('redis');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();
const redis = createClient({
  url: `redis://:${process.env.REDIS_PASSWORD}@redis:6379`,
});

// Cache-aside pattern
async function getUser(id) {
  const cached = await redis.get(`user:${id}`);
  if (cached) return JSON.parse(cached);

  const user = await prisma.user.findUnique({ where: { id } });
  await redis.set(`user:${id}`, JSON.stringify(user), { EX: 3600 });
  return user;
}
```

## Troubleshooting

### NOAUTH Authentication Required

**Error:** `NOAUTH Authentication required`

**Cause:** Client is not providing the Redis password.

**Solutions:**

```bash
# Verify password in .env
grep REDIS_PASSWORD .env

# Test authentication manually
docker exec redis redis-cli AUTH "${REDIS_PASSWORD}"

# When using redis-cli from host, always provide password
redis-cli -h 127.0.0.1 -a "${REDIS_PASSWORD}"
```

### Connection Refused

**Error:** `Connection refused` or `Could not connect to Redis`

**Solutions:**

```bash
# Check if Redis is running
docker compose ps redis

# Check Redis logs
docker logs redis --tail 50

# Verify Redis is healthy
docker exec redis redis-cli PING

# Ensure profile is enabled in .env
grep COMPOSE_PROFILES .env
# Should include: redis
```

### WRONGPASS Invalid Password

**Error:** `WRONGPASS invalid username-password pair`

**Cause:** The password provided by the client doesn't match `REDIS_PASSWORD`.

**Solutions:**

```bash
# Verify the password in .env
grep REDIS_PASSWORD .env

# Ensure application environment matches .env
docker exec your-app-container env | grep REDIS

# Restart Redis after password change
docker compose up -d redis
```

### Container Won't Start

**Error:** Redis container fails to start or keeps restarting

**Solutions:**

```bash
# Check logs for specific error
docker logs redis

# Most common cause: REDIS_PASSWORD not set in .env
# The container requires REDIS_PASSWORD to be defined
grep REDIS_PASSWORD .env

# If missing, add it to .env
echo 'REDIS_PASSWORD=redis' >> .env

# Restart
docker compose up -d redis
```

### High Memory Usage

**Error:** Redis consuming too much memory

**Solutions:**

```bash
# Check memory usage
docker exec redis redis-cli INFO memory

# Set a memory limit (add to docker-compose.yml command)
# command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 256mb --maxmemory-policy allkeys-lru

# Flush unused data
docker exec redis redis-cli FLUSHDB

# Check key count and sizes
docker exec redis redis-cli DBSIZE
docker exec redis redis-cli --bigkeys
```

### Slow Performance

**Symptom:** Redis responses are slow

**Solutions:**

```bash
# Check for slow commands
docker exec redis redis-cli SLOWLOG GET 10

# Check connected clients
docker exec redis redis-cli CLIENT LIST

# Check if persistence is causing latency
docker exec redis redis-cli CONFIG GET save

# Disable persistence for pure caching (add to command)
# command: redis-server --requirepass ${REDIS_PASSWORD} --save "" --appendonly no
```

## Best Practices

### 1. Use Strong Passwords

**Recommendation:** Use strong, unique passwords for Redis authentication.

```bash
# Generate a random password
openssl rand -base64 24
```

Update `.env` with a strong password:
```bash
REDIS_PASSWORD=your_generated_strong_password
```

### 2. Don't Expose Redis Externally

**Recommendation:** Keep Redis internal to the Docker network.

```yaml
# Good: No ports exposed
redis:
  image: redis:8.6.0-alpine
  networks:
    - traefik-proxy
```

```yaml
# Avoid: Direct port exposure
redis:
  ports:
    - "6379:6379"  # Security risk
```

### 3. Set Memory Limits

**Recommendation:** Configure `maxmemory` to prevent Redis from consuming all available memory.

```bash
# Add to docker-compose.yml command
command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 256mb --maxmemory-policy allkeys-lru
```

**Eviction Policies:**
- `allkeys-lru` — Evict least recently used keys (recommended for caching)
- `volatile-lru` — Evict LRU keys with TTL set
- `allkeys-random` — Evict random keys
- `noeviction` — Return error when memory limit reached

### 4. Use Key Namespacing

**Recommendation:** Prefix keys with application or module name to avoid collisions.

```bash
# Good: Namespaced keys
SET myapp:user:1:name "John"
SET myapp:cache:homepage "..."
SET myapp:session:abc123 "..."

# Bad: Generic keys
SET name "John"
SET cache "..."
```

### 5. Set TTL on Keys

**Recommendation:** Always set expiration on cache keys to prevent unbounded memory growth.

```bash
# Set key with TTL
SET session:abc123 "data" EX 3600  # Expires in 1 hour
SETEX cache:page:home 300 "html"   # Expires in 5 minutes
```

### 6. Use Connection Pooling

**Recommendation:** Use connection pools in applications for better performance.

```python
# Python example
pool = redis.ConnectionPool(
    host='redis',
    port=6379,
    password=os.environ.get('REDIS_PASSWORD'),
    max_connections=10,
)
r = redis.Redis(connection_pool=pool)
```

### 7. Avoid Expensive Commands

**Recommendation:** Avoid commands like `KEYS *` in production; use `SCAN` instead.

```bash
# Bad: Blocks the server
KEYS *

# Good: Non-blocking iteration
SCAN 0 MATCH "myapp:*" COUNT 100
```

### 8. Monitor with INFO

**Recommendation:** Regularly monitor Redis health and performance.

```bash
# Quick health check
docker exec redis redis-cli INFO stats | grep -E "(connected_clients|used_memory_human|total_commands)"

# Monitor in real-time
docker exec -it redis redis-cli MONITOR
```

---

## Additional Resources

- [Redis Documentation](https://redis.io/docs/)
- [Redis Commands Reference](https://redis.io/commands/)
- [Redis Docker Official Image](https://hub.docker.com/_/redis)
- [ioredis (Node.js)](https://github.com/redis/ioredis)
- [redis-py (Python)](https://redis-py.readthedocs.io/)

---

**Have questions or suggestions?** Open an issue in the GitHub repository or check the [Integration Guide](INTEGRATION_GUIDE.md) for related topics.
