# PostgreSQL Documentation

This guide covers PostgreSQL configuration, connection management, and integration with pgAdmin in the Local Docker Proxy. It includes client configuration examples for various programming languages and frameworks, along with troubleshooting tips and best practices.

## Table of Contents

- [Overview](#overview)
- [Connecting to PostgreSQL](#connecting-to-postgresql)
  - [From Docker Containers](#from-docker-containers)
  - [From Host Machine](#from-host-machine)
  - [Connection Examples](#connection-examples)
- [Client Configuration](#client-configuration)
  - [PHP / PDO](#php--pdo)
  - [Node.js / pg](#nodejs--pg)
  - [Python / psycopg2](#python--psycopg2)
  - [Django](#django)
  - [Ruby on Rails](#ruby-on-rails)
  - [Prisma](#prisma)
- [pgAdmin Integration](#pgadmin-integration)
  - [Enabling pgAdmin](#enabling-pgadmin)
  - [Initial Setup](#initial-setup)
  - [Adding Server Connection](#adding-server-connection)
- [Database Management](#database-management)
  - [Creating Databases](#creating-databases)
  - [Creating Users](#creating-users)
  - [Backup and Restore](#backup-and-restore)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Overview

The Local Docker Proxy includes PostgreSQL 16 as an optional service, using Docker's profile system for on-demand activation. PostgreSQL is a powerful, open-source object-relational database system known for its reliability, feature robustness, and performance.

**Key Features:**
- ✅ PostgreSQL 16 Alpine-based image for minimal footprint
- ✅ Configurable user, password, and database via environment variables
- ✅ Persistent data storage via Docker volumes
- ✅ Automatic healthchecks for container reliability
- ✅ pgAdmin web interface available as optional companion service
- ✅ Full ACID compliance and advanced SQL support

**Service Configuration:**
- **Image**: `postgres:16-alpine`
- **Container Name**: `postgres`
- **Profile**: `postgres` (must be enabled in `COMPOSE_PROFILES`)
- **Data Volume**: `postgres_data` (persistent across restarts)
- **Network**: `traefik-proxy` (shared with other services)

**Environment Variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_USER` | `postgres` | Database superuser name |
| `POSTGRES_PASSWORD` | (required) | Superuser password |
| `POSTGRES_DB` | `postgres` | Default database name |

## Connecting to PostgreSQL

### From Docker Containers

Containers on the `traefik-proxy` network can connect to PostgreSQL using the container name as hostname:

```yaml
# In your application's docker-compose.yml
services:
  app:
    image: your-app
    environment:
      DB_HOST: postgres
      DB_PORT: 5432
      DB_USER: ${POSTGRES_USER:-postgres}
      DB_PASSWORD: ${POSTGRES_PASSWORD}
      DB_NAME: ${POSTGRES_DB:-postgres}
    networks:
      - traefik-proxy

networks:
  traefik-proxy:
    external: true
```

**Connection String:**
```
postgresql://postgres:<password>@postgres:5432/database_name
```

### From Host Machine

PostgreSQL is not exposed to the host by default for security. To connect from your host machine, you have several options:

**Option 1: Use `docker exec` (Recommended)**
```bash
# Interactive PostgreSQL shell
docker exec -it postgres psql -U postgres

# Execute a single command
docker exec postgres psql -U postgres -c "SELECT version();"

# Connect to a specific database
docker exec -it postgres psql -U postgres -d myapp
```

**Option 2: Expose Port (Less Secure)**

Add port mapping to `docker-compose.yml`:
```yaml
postgres:
  # ... existing configuration ...
  ports:
    - "5432:5432"  # Expose to host
```

Then connect:
```bash
psql -h 127.0.0.1 -p 5432 -U postgres
```

**Option 3: Use pgAdmin**

Enable the `pgadmin` profile and access via browser:
```bash
# In .env
COMPOSE_PROFILES=postgres,pgadmin

# Access at
https://pgadmin.docker.localhost
```

### Connection Examples

**Basic Connection Test:**
```bash
# Test from within the container
docker exec postgres pg_isready

# Check PostgreSQL version
docker exec postgres psql -U postgres -c "SELECT version();"

# List databases
docker exec postgres psql -U postgres -c "\l"

# List tables in a database
docker exec postgres psql -U postgres -d myapp -c "\dt"
```

**Create a Database and User:**
```bash
docker exec postgres psql -U postgres <<EOF
CREATE DATABASE myapp;
CREATE USER myapp_user WITH ENCRYPTED PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE myapp TO myapp_user;
\c myapp
GRANT ALL ON SCHEMA public TO myapp_user;
EOF
```

## Client Configuration

### PHP / PDO

```php
<?php
$host = 'postgres';
$port = '5432';
$dbname = 'myapp';
$user = 'postgres';
$password = getenv('POSTGRES_PASSWORD');

$dsn = "pgsql:host=$host;port=$port;dbname=$dbname";

try {
    $pdo = new PDO($dsn, $user, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    echo "Connected successfully";
} catch (PDOException $e) {
    die("Connection failed: " . $e->getMessage());
}
```

**Required Extension:** Ensure `pdo_pgsql` extension is enabled in your PHP configuration.

### Node.js / pg

The `pg` package is the standard PostgreSQL client for Node.js:

```javascript
const { Pool, Client } = require('pg');

// Using a connection pool (recommended)
const pool = new Pool({
  host: 'postgres',
  port: 5432,
  user: 'postgres',
  password: process.env.POSTGRES_PASSWORD,
  database: 'myapp',
  max: 20,
  idleTimeoutMillis: 30000,
});

// Query example
const result = await pool.query('SELECT NOW()');
console.log(result.rows[0]);

// Or using a single client
const client = new Client({
  connectionString: `postgresql://postgres:${process.env.POSTGRES_PASSWORD}@postgres:5432/myapp`
});

await client.connect();
const res = await client.query('SELECT $1::text as message', ['Hello PostgreSQL']);
console.log(res.rows[0].message);
await client.end();
```

### Python / psycopg2

Use `psycopg2` or `psycopg` (version 3) for Python:

```python
import os
import psycopg2
from psycopg2 import pool

# Simple connection
conn = psycopg2.connect(
    host='postgres',
    port=5432,
    user='postgres',
    password=os.environ.get('POSTGRES_PASSWORD'),
    database='myapp'
)

cursor = conn.cursor()
cursor.execute('SELECT version()')
print(cursor.fetchone())
cursor.close()
conn.close()

# Using connection pool
connection_pool = psycopg2.pool.SimpleConnectionPool(
    1, 20,
    host='postgres',
    port=5432,
    user='postgres',
    password=os.environ.get('POSTGRES_PASSWORD'),
    database='myapp'
)

conn = connection_pool.getconn()
# ... use connection
connection_pool.putconn(conn)
```

**Alternative with psycopg3:**
```python
import psycopg

with psycopg.connect(
    "postgresql://postgres:password@postgres:5432/myapp"
) as conn:
    with conn.cursor() as cur:
        cur.execute("SELECT version()")
        print(cur.fetchone())
```

### Django

Django's database configuration in `settings.py`:

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('DB_NAME', 'myapp'),
        'USER': os.environ.get('DB_USER', 'postgres'),
        'PASSWORD': os.environ.get('POSTGRES_PASSWORD'),
        'HOST': os.environ.get('DB_HOST', 'postgres'),
        'PORT': os.environ.get('DB_PORT', '5432'),
        'CONN_MAX_AGE': 60,  # Connection pooling
        'OPTIONS': {
            'connect_timeout': 10,
        },
    }
}
```

**Environment Variables in Docker Compose:**
```yaml
services:
  django:
    environment:
      DB_HOST: postgres
      DB_PORT: 5432
      DB_NAME: myapp
      DB_USER: postgres
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
```

### Ruby on Rails

Rails `config/database.yml`:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  host: <%= ENV.fetch("DB_HOST", "postgres") %>
  port: <%= ENV.fetch("DB_PORT", 5432) %>
  username: <%= ENV.fetch("DB_USER", "postgres") %>
  password: <%= ENV["POSTGRES_PASSWORD"] %>
  pool: <%= ENV.fetch("RAILS_MAX_THREADS", 5) %>
  timeout: 5000

development:
  <<: *default
  database: myapp_development

test:
  <<: *default
  database: myapp_test

production:
  <<: *default
  database: myapp_production
```

### Prisma

In your `schema.prisma`:

```prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}
```

Environment variable:
```bash
DATABASE_URL="postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/myapp?schema=public"
```

**Docker Compose:**
```yaml
services:
  app:
    environment:
      DATABASE_URL: postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/myapp?schema=public
```

## pgAdmin Integration

pgAdmin is a feature-rich web-based administration tool for PostgreSQL.

### Enabling pgAdmin

**Edit `.env`:**
```bash
COMPOSE_PROFILES=postgres,pgadmin
PGADMIN_DEFAULT_EMAIL=admin@local.dev
PGADMIN_DEFAULT_PASSWORD=admin
```

**Start Services:**
```bash
docker compose up -d
```

### Initial Setup

**Access pgAdmin:**
```
https://pgadmin.docker.localhost
```

**Login Credentials:**
- **Email**: Value of `PGADMIN_DEFAULT_EMAIL` (default: `admin@local.dev`)
- **Password**: Value of `PGADMIN_DEFAULT_PASSWORD`

### Adding Server Connection

After logging in, add the PostgreSQL server:

1. Right-click **"Servers"** → **"Register"** → **"Server..."**
2. Fill in the **General** tab:
   - **Name**: `Local PostgreSQL` (or any descriptive name)
3. Fill in the **Connection** tab:
   - **Host name/address**: `postgres`
   - **Port**: `5432`
   - **Maintenance database**: `postgres`
   - **Username**: Value of `POSTGRES_USER` (default: `postgres`)
   - **Password**: Value of `POSTGRES_PASSWORD`
   - **Save password?**: Yes (for convenience)
4. Click **"Save"**

**Alternative: Import Server Configuration**

Create a `servers.json` file and mount it:
```json
{
  "Servers": {
    "1": {
      "Name": "Local PostgreSQL",
      "Group": "Servers",
      "Host": "postgres",
      "Port": 5432,
      "MaintenanceDB": "postgres",
      "Username": "postgres",
      "SSLMode": "prefer"
    }
  }
}
```

## Database Management

### Creating Databases

```bash
# Create a database
docker exec postgres psql -U postgres -c "CREATE DATABASE myapp;"

# Create with specific owner
docker exec postgres psql -U postgres -c "CREATE DATABASE myapp OWNER myapp_user;"

# Create with specific encoding and locale
docker exec postgres psql -U postgres -c "CREATE DATABASE myapp WITH ENCODING 'UTF8' LC_COLLATE='en_US.utf8' LC_CTYPE='en_US.utf8';"

# List all databases
docker exec postgres psql -U postgres -c "\l"
```

### Creating Users

```bash
# Create a user with password
docker exec postgres psql -U postgres -c "CREATE USER myapp_user WITH ENCRYPTED PASSWORD 'secure_password';"

# Grant database access
docker exec postgres psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE myapp TO myapp_user;"

# Grant schema permissions (required for PostgreSQL 15+)
docker exec postgres psql -U postgres -d myapp -c "GRANT ALL ON SCHEMA public TO myapp_user;"

# Create user with specific roles
docker exec postgres psql -U postgres -c "CREATE USER readonly_user WITH ENCRYPTED PASSWORD 'password';"
docker exec postgres psql -U postgres -d myapp -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;"

# List all users
docker exec postgres psql -U postgres -c "\du"
```

### Backup and Restore

**Backup a Database:**
```bash
# Plain SQL backup
docker exec postgres pg_dump -U postgres myapp > myapp_backup_$(date +%Y%m%d_%H%M%S).sql

# Custom format (recommended for large databases)
docker exec postgres pg_dump -U postgres -Fc myapp > myapp_backup.dump

# Backup all databases
docker exec postgres pg_dumpall -U postgres > all_databases_backup.sql

# Backup with compression
docker exec postgres pg_dump -U postgres -Z9 myapp > myapp_backup.sql.gz
```

**Restore from Backup:**
```bash
# Restore plain SQL backup
cat myapp_backup.sql | docker exec -i postgres psql -U postgres -d myapp

# Restore custom format backup
cat myapp_backup.dump | docker exec -i postgres pg_restore -U postgres -d myapp

# Restore to a new database
docker exec postgres psql -U postgres -c "CREATE DATABASE myapp_restored;"
cat myapp_backup.sql | docker exec -i postgres psql -U postgres -d myapp_restored
```

## Troubleshooting

### Connection Refused

**Error:** `Connection refused` or `could not connect to server`

**Solutions:**

```bash
# Check if PostgreSQL is running
docker compose ps postgres

# Check PostgreSQL logs
docker logs postgres --tail 50

# Verify PostgreSQL is ready
docker exec postgres pg_isready

# Ensure profile is enabled in .env
grep COMPOSE_PROFILES .env
# Should include: postgres
```

### Authentication Failed

**Error:** `password authentication failed for user "postgres"`

**Solutions:**

```bash
# Verify password matches .env
echo $POSTGRES_PASSWORD
grep POSTGRES_PASSWORD .env

# Reset password (requires volume reset for first-time setup issues)
docker compose down
docker volume rm <project_name>_postgres_data
# Update .env with correct password
docker compose up -d postgres
```

**Note:** PostgreSQL only sets the password on initial database creation. If the volume already exists, changing `POSTGRES_PASSWORD` in `.env` won't update the actual password. You must either reset the volume or manually change the password:

```bash
docker exec -it postgres psql -U postgres -c "ALTER USER postgres WITH PASSWORD 'new_password';"
```

### Permission Denied on Tables

**Error:** `permission denied for table` or `permission denied for schema public`

**Solutions (PostgreSQL 15+):**

```sql
-- Grant schema permissions
GRANT ALL ON SCHEMA public TO myapp_user;

-- Grant permissions on existing tables
GRANT ALL ON ALL TABLES IN SCHEMA public TO myapp_user;

-- Grant permissions on future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO myapp_user;
```

### Container Won't Start

**Error:** PostgreSQL container keeps restarting

**Solutions:**

```bash
# Check logs for specific error
docker logs postgres

# Common issues:
# 1. Invalid POSTGRES_PASSWORD (empty or contains special characters)
# 2. Corrupted data volume

# Reset data volume if corrupted
docker compose down
docker volume rm <project_name>_postgres_data
docker compose up -d postgres

# Check disk space
df -h
```

### Locale/Encoding Issues

**Error:** `encoding "UTF8" does not match locale "C"`

**Solutions:**

```bash
# Reset volume and recreate with correct locale
docker compose down
docker volume rm <project_name>_postgres_data
docker compose up -d postgres
```

### pgAdmin Cannot Connect to Server

**Error:** `Unable to connect to server` in pgAdmin

**Solutions:**

1. Verify container name: Use `postgres` as hostname, not `localhost`
2. Check both containers are on the same network:
   ```bash
   docker network inspect traefik-proxy | grep -E "(postgres|pgadmin)"
   ```
3. Verify PostgreSQL is accepting connections:
   ```bash
   docker exec postgres pg_isready -h localhost
   ```
4. Check `pg_hba.conf` settings (default Docker image allows connections)

## Best Practices

### 1. Use Strong Passwords

**Recommendation:** Use strong, unique passwords for all PostgreSQL users.

```bash
# Generate a random password
openssl rand -base64 24
```

Update `.env` with a strong password:
```bash
POSTGRES_PASSWORD=your_generated_strong_password
```

### 2. Create Application-Specific Users

**Recommendation:** Don't use the superuser account for applications.

```sql
-- Create dedicated user for each application
CREATE USER myapp WITH ENCRYPTED PASSWORD 'app_specific_password';
CREATE DATABASE myapp_db OWNER myapp;

-- Grant minimal required permissions
GRANT CONNECT ON DATABASE myapp_db TO myapp;
GRANT USAGE ON SCHEMA public TO myapp;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO myapp;
```

### 3. Regular Backups

**Recommendation:** Schedule regular database backups.

```bash
# Create backup script
#!/bin/bash
BACKUP_DIR="/path/to/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

docker exec postgres pg_dumpall -U postgres > "${BACKUP_DIR}/pg_backup_${TIMESTAMP}.sql"

# Keep only last 7 days of backups
find "${BACKUP_DIR}" -name "pg_backup_*.sql" -mtime +7 -delete
```

### 4. Use Connection Pooling

**Recommendation:** Use connection pools in applications for better performance.

PostgreSQL has limited connections (default: 100). Use connection pooling:

```javascript
// Node.js example with pg
const pool = new Pool({
  host: 'postgres',
  max: 20,  // Maximum connections in pool
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

For production workloads, consider using **PgBouncer** as a connection pooler.

### 5. Don't Expose PostgreSQL Externally

**Recommendation:** Keep PostgreSQL internal to the Docker network.

```yaml
# Good: No ports exposed
postgres:
  image: postgres:16-alpine
  networks:
    - traefik-proxy
```

```yaml
# Avoid: Direct port exposure
postgres:
  ports:
    - "5432:5432"  # Security risk
```

### 6. Monitor Disk Usage

**Recommendation:** PostgreSQL data volumes can grow large; monitor disk usage.

```bash
# Check PostgreSQL data volume size
docker system df -v | grep postgres_data

# Check within container
docker exec postgres du -sh /var/lib/postgresql/data

# Check database sizes
docker exec postgres psql -U postgres -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) AS size FROM pg_database ORDER BY pg_database_size(pg_database.datname) DESC;"
```

### 7. Keep Drivers Updated

**Recommendation:** Use the latest versions of PostgreSQL drivers in your applications.

| Language | Recommended Package | Min Version |
|----------|---------------------|-------------|
| PHP | pdo_pgsql | 7.4+ |
| Node.js | pg | 8.0+ |
| Python | psycopg2/psycopg3 | 2.9+/3.0+ |
| Ruby | pg gem | 1.2+ |
| Go | pgx | 4.0+ |
| Java | PostgreSQL JDBC | 42.0+ |

### 8. Use SSL in Production

**Recommendation:** Enable SSL for secure connections in production environments.

```python
# Python example with SSL
conn = psycopg2.connect(
    host='postgres',
    sslmode='require',
    # ... other options
)
```

For local development, SSL is optional but the connection remains secure within the Docker network.

---

## Additional Resources

- [PostgreSQL 16 Documentation](https://www.postgresql.org/docs/16/index.html)
- [PostgreSQL Docker Official Image](https://hub.docker.com/_/postgres)
- [pgAdmin Documentation](https://www.pgadmin.org/docs/)
- [psycopg2 Documentation](https://www.psycopg.org/docs/)
- [node-postgres (pg) Documentation](https://node-postgres.com/)

---

**Have questions or suggestions?** Open an issue in the GitHub repository or check the [Integration Guide](INTEGRATION_GUIDE.md) for related topics.
