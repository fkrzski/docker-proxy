# MySQL Documentation

This guide covers MySQL configuration, authentication methods, and connection management in the Local Docker Proxy. It includes migration instructions for upgrading from older authentication plugins and troubleshooting common connection issues.

## Table of Contents

- [Overview](#overview)
- [Authentication Methods](#authentication-methods)
  - [caching_sha2_password (Default)](#caching_sha2_password-default)
  - [mysql_native_password (Legacy)](#mysql_native_password-legacy)
- [Connecting to MySQL](#connecting-to-mysql)
  - [From Docker Containers](#from-docker-containers)
  - [From Host Machine](#from-host-machine)
  - [Connection Examples](#connection-examples)
- [Migration Guide](#migration-guide)
  - [Upgrading from mysql_native_password](#upgrading-from-mysql_native_password)
  - [User Migration Steps](#user-migration-steps)
  - [Data Backup Before Migration](#data-backup-before-migration)
- [Using Legacy Authentication](#using-legacy-authentication)
  - [When to Use mysql_native_password](#when-to-use-mysql_native_password)
  - [Per-User Configuration](#per-user-configuration)
  - [Server-Wide Configuration](#server-wide-configuration)
- [Client Configuration](#client-configuration)
  - [PHP / PDO](#php--pdo)
  - [Node.js / mysql2](#nodejs--mysql2)
  - [Python / mysql-connector](#python--mysql-connector)
  - [Laravel](#laravel)
  - [Prisma](#prisma)
- [phpMyAdmin Integration](#phpmyadmin-integration)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Overview

The Local Docker Proxy includes MySQL 8.0 as an optional service, using Docker's profile system for on-demand activation. MySQL 8.0 uses `caching_sha2_password` as the default authentication plugin, providing improved security over the legacy `mysql_native_password` method.

**Key Features:**
- ✅ Modern `caching_sha2_password` authentication by default
- ✅ Improved security with SHA-256 based password hashing
- ✅ Support for RSA key exchange for secure password transmission
- ✅ Backward compatibility with legacy authentication when needed
- ✅ Persistent data storage via Docker volumes
- ✅ Automatic healthchecks for container reliability

**Service Configuration:**
- **Image**: `mysql:8.0`
- **Container Name**: `mysql`
- **Profile**: `mysql` (must be enabled in `COMPOSE_PROFILES`)
- **Data Volume**: `mysql_data` (persistent across restarts)
- **Network**: `traefik-proxy` (shared with other services)

## Authentication Methods

### caching_sha2_password (Default)

MySQL 8.0's default authentication plugin provides enhanced security:

**How It Works:**
1. Uses SHA-256 based password hashing (vs SHA-1 in mysql_native_password)
2. Implements challenge-response authentication with caching
3. Supports RSA key pair for secure password exchange over unencrypted connections
4. Caches authentication data for improved performance on repeated connections

**Benefits:**
- Stronger password hashing algorithm
- Protection against password capture attacks
- Performance optimization through authentication caching
- Future-proof (MySQL's recommended standard)

**Requirements:**
- MySQL client 8.0+ (native support)
- Older clients need RSA public key or SSL/TLS connection
- Most modern ORMs and drivers support it out of the box

**Example Connection:**
```bash
# MySQL 8.0 client connects seamlessly
mysql -h mysql -u root -p

# Verify authentication plugin in use
SELECT user, host, plugin FROM mysql.user;
```

### mysql_native_password (Legacy)

The legacy authentication plugin is still supported for backward compatibility:

**Characteristics:**
- Uses SHA-1 based password hashing
- Simpler challenge-response mechanism
- No RSA key exchange required
- Widely supported by older clients and tools

**When Used:**
- Legacy applications that cannot be updated
- Older MySQL clients (< 8.0)
- Third-party tools without caching_sha2_password support
- Development environments mimicking legacy production systems

**Security Note:** While `mysql_native_password` is less secure than `caching_sha2_password`, it's acceptable for local development environments isolated from public networks.

## Connecting to MySQL

### From Docker Containers

Containers on the `traefik-proxy` network can connect to MySQL using the container name as hostname:

```yaml
# In your application's docker-compose.yml
services:
  app:
    image: your-app
    environment:
      DB_HOST: mysql
      DB_PORT: 3306
      DB_USER: root
      DB_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    networks:
      - traefik-proxy

networks:
  traefik-proxy:
    external: true
```

**Connection String:**
```
mysql://root:<password>@mysql:3306/database_name
```

### From Host Machine

MySQL is not exposed to the host by default for security. To connect from your host machine, you have several options:

**Option 1: Use `docker exec` (Recommended)**
```bash
# Interactive MySQL shell
docker exec -it mysql mysql -u root -p

# Execute a single command
docker exec -e MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysql mysql -u root -e "SHOW DATABASES;"
```

**Option 2: Expose Port (Less Secure)**

Add port mapping to `docker-compose.yml`:
```yaml
mysql:
  # ... existing configuration ...
  ports:
    - "3306:3306"  # Expose to host
```

Then connect:
```bash
mysql -h 127.0.0.1 -P 3306 -u root -p
```

**Option 3: Use phpMyAdmin**

Enable the `pma` profile and access via browser:
```bash
# In .env
COMPOSE_PROFILES=mysql,pma

# Access at
https://pma.docker.localhost
```

### Connection Examples

**Basic Connection Test:**
```bash
# Test from within the container
docker exec mysql mysqladmin ping -h localhost

# Check MySQL version
docker exec mysql mysql -V

# List databases
docker exec -e MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysql mysql -u root -e "SHOW DATABASES;"
```

**Create a Database and User:**
```bash
docker exec -e MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysql mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS myapp;
CREATE USER IF NOT EXISTS 'myapp_user'@'%' IDENTIFIED BY 'secure_password';
GRANT ALL PRIVILEGES ON myapp.* TO 'myapp_user'@'%';
FLUSH PRIVILEGES;
EOF
```

## Migration Guide

### Upgrading from mysql_native_password

If you're upgrading from a configuration that used `mysql_native_password` as the default authentication plugin, follow these steps to migrate smoothly.

**Background:**

Previous versions of this Local Docker Proxy configured MySQL to use `mysql_native_password` via:
```yaml
command:
  - "--default-authentication-plugin=mysql_native_password"
```

This has been removed to use MySQL 8.0's secure default (`caching_sha2_password`).

**Impact:**
- New users will use `caching_sha2_password` by default
- Existing users retain their current authentication plugin
- Applications may need driver updates or configuration changes

### User Migration Steps

**Step 1: Check Existing Users**

Review which authentication plugin each user currently uses:
```bash
docker exec -e MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysql mysql -u root -e \
  "SELECT user, host, plugin FROM mysql.user;"
```

**Step 2: Identify Applications**

List applications connecting to MySQL and verify their driver compatibility:
- PHP: mysqli/PDO with MySQL Native Driver (mysqlnd) 7.4+ supports caching_sha2_password
- Node.js: mysql2 package supports caching_sha2_password
- Python: mysql-connector-python 8.0+ supports caching_sha2_password

**Step 3: Migrate Users (Optional)**

To upgrade an existing user to `caching_sha2_password`:
```sql
-- Backup: Note current user settings first
SHOW CREATE USER 'username'@'host';

-- Migrate user to new authentication
ALTER USER 'username'@'host' IDENTIFIED WITH caching_sha2_password BY 'new_password';

-- Verify change
SELECT user, host, plugin FROM mysql.user WHERE user = 'username';
```

**Step 4: Update Application Connections**

After migrating users, update your application's database driver or connection settings if needed (see [Client Configuration](#client-configuration)).

### Data Backup Before Migration

Always backup your data before making authentication changes:

```bash
# Backup all databases
docker exec -e MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysql mysqldump -u root \
  --all-databases > backup_$(date +%Y%m%d_%H%M%S).sql

# Backup a specific database
docker exec -e MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysql mysqldump -u root \
  myapp > myapp_backup_$(date +%Y%m%d_%H%M%S).sql

# Backup with routines and triggers
docker exec -e MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysql mysqldump -u root \
  --routines --triggers --all-databases > full_backup.sql
```

**Restore from Backup:**
```bash
# Restore all databases
docker exec -e MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysql mysql -u root < backup.sql

# Restore specific database
docker exec -e MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysql mysql -u root myapp < myapp_backup.sql
```

## Using Legacy Authentication

### When to Use mysql_native_password

Use the legacy authentication plugin only when necessary:

- **Legacy Applications**: Older codebases that cannot be updated
- **Incompatible Drivers**: Third-party tools without caching_sha2_password support
- **Testing**: Replicating production environments that use legacy auth
- **Transitional Period**: While updating applications to support modern auth

### Per-User Configuration

Create specific users with legacy authentication while keeping the secure default for others:

```sql
-- Create a user with legacy authentication
CREATE USER 'legacy_app'@'%'
  IDENTIFIED WITH mysql_native_password BY 'password';

-- Grant permissions
GRANT ALL PRIVILEGES ON legacy_db.* TO 'legacy_app'@'%';
FLUSH PRIVILEGES;

-- Convert existing user to legacy auth (if needed)
ALTER USER 'existing_user'@'%'
  IDENTIFIED WITH mysql_native_password BY 'password';
```

**Verification:**
```sql
SELECT user, host, plugin FROM mysql.user WHERE user IN ('legacy_app', 'existing_user');
```

### Server-Wide Configuration

If you must use `mysql_native_password` as the server default (not recommended), modify your `docker-compose.yml`:

```yaml
mysql:
  image: mysql:8.0
  container_name: mysql
  # ... other configuration ...
  command:
    - "--default-authentication-plugin=mysql_native_password"
```

**Warning:** This approach is deprecated and may be removed in future MySQL versions. Prefer per-user configuration instead.

After changing, restart the MySQL container:
```bash
docker compose up -d mysql
```

## Client Configuration

### PHP / PDO

**Modern PHP (7.4+)** with mysqlnd supports `caching_sha2_password` natively:

```php
<?php
$dsn = 'mysql:host=mysql;dbname=myapp;charset=utf8mb4';
$username = 'root';
$password = getenv('MYSQL_ROOT_PASSWORD');

try {
    $pdo = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    echo "Connected successfully";
} catch (PDOException $e) {
    die("Connection failed: " . $e->getMessage());
}
```

**Older PHP**: Upgrade to PHP 7.4+ or use a user with `mysql_native_password`.

### Node.js / mysql2

The `mysql2` package supports `caching_sha2_password`:

```javascript
const mysql = require('mysql2/promise');

const connection = await mysql.createConnection({
  host: 'mysql',
  user: 'root',
  password: process.env.MYSQL_ROOT_PASSWORD,
  database: 'myapp',
});

// Or with connection pool
const pool = mysql.createPool({
  host: 'mysql',
  user: 'root',
  password: process.env.MYSQL_ROOT_PASSWORD,
  database: 'myapp',
  waitForConnections: true,
  connectionLimit: 10,
});
```

**Note:** The original `mysql` package does NOT support `caching_sha2_password`. Use `mysql2` instead.

### Python / mysql-connector

Use `mysql-connector-python` 8.0+:

```python
import os
import mysql.connector

config = {
    'host': 'mysql',
    'user': 'root',
    'password': os.environ.get('MYSQL_ROOT_PASSWORD'),
    'database': 'myapp',
}

connection = mysql.connector.connect(**config)
cursor = connection.cursor()
cursor.execute("SELECT VERSION()")
print(cursor.fetchone())
cursor.close()
connection.close()
```

**Alternative with pymysql:**
```python
import os
import pymysql

connection = pymysql.connect(
    host='mysql',
    user='root',
    password=os.environ.get('MYSQL_ROOT_PASSWORD'),
    database='myapp',
    cursorclass=pymysql.cursors.DictCursor
)
```

### Laravel

Laravel's database configuration in `config/database.php`:

```php
'mysql' => [
    'driver' => 'mysql',
    'host' => env('DB_HOST', 'mysql'),
    'port' => env('DB_PORT', '3306'),
    'database' => env('DB_DATABASE', 'laravel'),
    'username' => env('DB_USERNAME', 'root'),
    'password' => env('DB_PASSWORD', ''),
    'charset' => 'utf8mb4',
    'collation' => 'utf8mb4_unicode_ci',
    'prefix' => '',
    'strict' => true,
    'engine' => null,
],
```

Laravel 8+ with PHP 7.4+ supports `caching_sha2_password` out of the box.

### Prisma

In your `schema.prisma`:

```prisma
datasource db {
  provider = "mysql"
  url      = env("DATABASE_URL")
}
```

Environment variable:
```bash
DATABASE_URL="mysql://root:${MYSQL_ROOT_PASSWORD}@mysql:3306/myapp"
```

Prisma supports `caching_sha2_password` natively.

## phpMyAdmin Integration

phpMyAdmin is configured to connect to MySQL automatically using the root credentials.

**Enable phpMyAdmin:**
```bash
# Edit .env
COMPOSE_PROFILES=mysql,pma
```

**Start Services:**
```bash
docker compose up -d
```

**Access phpMyAdmin:**
```
https://pma.docker.localhost
```

**Authentication Notes:**
- phpMyAdmin connects using credentials from environment variables
- It supports `caching_sha2_password` authentication
- If you see authentication errors, verify `MYSQL_ROOT_PASSWORD` matches in `.env`

## Troubleshooting

### Authentication Plugin Errors

**Error:** `Authentication plugin 'caching_sha2_password' cannot be loaded`

**Cause:** Client doesn't support the modern authentication plugin.

**Solutions:**

1. **Update the client/driver:**
   ```bash
   # For Node.js, switch to mysql2
   npm uninstall mysql
   npm install mysql2
   ```

2. **Use legacy authentication for the user:**
   ```sql
   ALTER USER 'user'@'%' IDENTIFIED WITH mysql_native_password BY 'password';
   ```

3. **Update your PHP installation:**
   ```bash
   # Ubuntu/Debian
   sudo apt update
   sudo apt install php-mysql
   ```

### Connection Refused

**Error:** `Connection refused` or `Can't connect to MySQL server`

**Solutions:**

```bash
# Check if MySQL is running
docker compose ps mysql

# Check MySQL logs
docker logs mysql --tail 50

# Verify MySQL is healthy
docker exec mysql mysqladmin ping -h localhost

# Ensure profile is enabled in .env
grep COMPOSE_PROFILES .env
# Should include: mysql
```

### Access Denied Errors

**Error:** `Access denied for user 'root'@'172.x.x.x'`

**Solutions:**

```bash
# Verify password matches .env
echo $MYSQL_ROOT_PASSWORD
grep MYSQL_ROOT_PASSWORD .env

# Check user privileges
docker exec -e MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysql mysql -u root -e \
  "SELECT user, host FROM mysql.user;"

# Create user with correct host pattern
docker exec -e MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysql mysql -u root -e \
  "CREATE USER 'myuser'@'%' IDENTIFIED BY 'password';"
```

### SSL/TLS Connection Issues

**Error:** `SSL connection error` or `caching_sha2_password requires secure connection`

**Solutions:**

1. **Use SSL connection:**
   ```bash
   mysql -h mysql -u root -p --ssl-mode=REQUIRED
   ```

2. **Get RSA public key:**
   ```bash
   mysql -h mysql -u root -p --get-server-public-key
   ```

3. **Allow insecure connections (development only):**
   ```bash
   mysql -h mysql -u root -p --ssl-mode=DISABLED
   ```

### Container Won't Start

**Error:** MySQL container keeps restarting

**Solutions:**

```bash
# Check logs for specific error
docker logs mysql

# Common fix: Reset data volume if corrupted
docker compose down
docker volume rm <project_directory>_mysql_data
docker compose up -d

# Check disk space
df -h
```

### Slow Initial Connection

**Symptom:** First connection takes several seconds

**Explanation:** `caching_sha2_password` may perform RSA key exchange on first connection.

**Solution:** This is normal; subsequent connections are cached and fast.

## Best Practices

### 1. Use Modern Authentication

**Recommendation:** Keep `caching_sha2_password` as default and only use `mysql_native_password` for specific users that require it.

```sql
-- Modern auth for most users
CREATE USER 'app'@'%' IDENTIFIED BY 'secure_password';

-- Legacy auth only when necessary
CREATE USER 'legacy'@'%' IDENTIFIED WITH mysql_native_password BY 'password';
```

### 2. Use Strong Passwords

**Recommendation:** Use strong, unique passwords for all MySQL users.

```bash
# Generate a random password
openssl rand -base64 24
```

Update `.env` with a strong password:
```bash
MYSQL_ROOT_PASSWORD=your_generated_strong_password
```

### 3. Create Application-Specific Users

**Recommendation:** Don't use the root account for applications.

```sql
-- Create dedicated user for each application
CREATE USER 'myapp'@'%' IDENTIFIED BY 'app_specific_password';
GRANT ALL PRIVILEGES ON myapp_db.* TO 'myapp'@'%';
FLUSH PRIVILEGES;
```

### 4. Regular Backups

**Recommendation:** Schedule regular database backups.

```bash
# Create backup script
#!/bin/bash
docker exec -e MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysql mysqldump -u root \
  --all-databases > mysql_backup_$(date +%Y%m%d_%H%M%S).sql
```

### 5. Monitor Disk Usage

**Recommendation:** MySQL data volumes can grow large; monitor disk usage.

```bash
# Check MySQL data volume size
docker system df -v | grep mysql_data

# Check within container
docker exec mysql du -sh /var/lib/mysql
```

### 6. Keep Drivers Updated

**Recommendation:** Use the latest versions of MySQL drivers in your applications.

| Language | Recommended Package | Min Version |
|----------|---------------------|-------------|
| PHP | mysqlnd (built-in) | 7.4+ |
| Node.js | mysql2 | 2.0+ |
| Python | mysql-connector-python | 8.0+ |
| Go | go-sql-driver/mysql | 1.5+ |
| Ruby | mysql2 gem | 0.5+ |

### 7. Don't Expose MySQL Externally

**Recommendation:** Keep MySQL internal to the Docker network.

```yaml
# Good: No ports exposed
mysql:
  image: mysql:8.0
  networks:
    - traefik-proxy
```

```yaml
# Avoid: Direct port exposure
mysql:
  ports:
    - "3306:3306"  # Security risk
```

### 8. Use Connection Pooling

**Recommendation:** Use connection pools in applications for better performance.

```javascript
// Node.js example with mysql2
const pool = mysql.createPool({
  host: 'mysql',
  connectionLimit: 10,
  // ... other options
});
```

---

## Additional Resources

- [MySQL 8.0 Authentication Documentation](https://dev.mysql.com/doc/refman/8.0/en/authentication-plugins.html)
- [caching_sha2_password Plugin Reference](https://dev.mysql.com/doc/refman/8.0/en/caching-sha2-pluggable-authentication.html)
- [MySQL Client Libraries](https://dev.mysql.com/doc/refman/8.0/en/connectors-apis.html)
- [Docker MySQL Official Image](https://hub.docker.com/_/mysql)

---

**Have questions or suggestions?** Open an issue in the GitHub repository or check the [Integration Guide](INTEGRATION_GUIDE.md) for related topics.
