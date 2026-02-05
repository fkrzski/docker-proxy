# Logging Documentation

This guide explains how to manage, view, and troubleshoot logs in the Local Docker Proxy. It covers both container logs (via Docker's logging driver) and optional Traefik access logs for request tracing.

## Table of Contents

- [Overview](#overview)
- [Log Rotation Configuration](#log-rotation-configuration)
  - [How It Works](#how-it-works)
  - [Configuration Details](#configuration-details)
  - [Disk Space Management](#disk-space-management)
- [Viewing Container Logs](#viewing-container-logs)
  - [Basic Commands](#basic-commands)
  - [Filtering and Searching](#filtering-and-searching)
  - [Continuous Monitoring](#continuous-monitoring)
- [Traefik Access Logs](#traefik-access-logs)
  - [Enabling Access Logs](#enabling-access-logs)
  - [Viewing Access Logs](#viewing-access-logs)
  - [Parsing JSON Logs](#parsing-json-logs)
  - [Common Use Cases](#common-use-cases)
- [Log File Locations](#log-file-locations)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Overview

The Local Docker Proxy implements a two-tier logging strategy:

1. **Container Logs**: All containers (Traefik, Redis, MySQL, phpMyAdmin) use Docker's `json-file` logging driver with automatic rotation. These logs capture stdout/stderr from each service.

2. **Traefik Access Logs** (Optional): Detailed HTTP request logs written to a file, useful for debugging routing issues and monitoring traffic patterns.

**Key Benefits:**
- ✅ Automatic log rotation prevents disk space exhaustion
- ✅ Structured JSON format for easy parsing
- ✅ Built-in Docker tooling for log access
- ✅ Optional detailed request tracing without performance impact

## Log Rotation Configuration

### How It Works

All services in the proxy use Docker's `json-file` logging driver with rotation configured to:

- **Max File Size**: 10 MB per file
- **Max Files**: 3 files retained
- **Total Space**: ~30 MB per container maximum

When a log file reaches 10 MB, Docker automatically:
1. Rotates the current log to a numbered file (e.g., `container.log.1`)
2. Compresses older logs (e.g., `container.log.2.gz`)
3. Deletes the oldest file when the limit is reached
4. Starts a new log file

This happens **transparently** without interrupting the container or requiring configuration changes.

### Configuration Details

The logging configuration is defined in `docker-compose.yml`:

```yaml
services:
  traefik:
    # ... other configuration ...
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

**Configuration Options:**
- `driver: "json-file"`: Uses Docker's default JSON logging driver
- `max-size: "10m"`: Rotates when file reaches 10 megabytes
- `max-file: "3"`: Keeps up to 3 log files (current + 2 rotated)

This configuration is applied to all four services: `traefik`, `redis`, `mysql`, and `pma`.

### Disk Space Management

**Per-Service Limits:**
- Traefik: ~30 MB maximum
- Redis: ~30 MB maximum
- MySQL: ~30 MB maximum
- phpMyAdmin: ~30 MB maximum

**Total Proxy Logs**: ~120 MB maximum for all container logs combined.

**Traefik Access Logs** (if enabled): Not automatically rotated by Docker. See [Traefik Access Logs](#traefik-access-logs) for manual rotation strategies.

## Viewing Container Logs

### Basic Commands

View logs from any service using the `docker logs` command:

```bash
# View all Traefik logs
docker logs traefik

# View last 50 lines
docker logs traefik --tail 50

# View logs from the last hour
docker logs traefik --since 1h

# View logs from a specific timestamp
docker logs traefik --since 2024-01-28T10:00:00

# View logs for other services
docker logs redis
docker logs mysql
docker logs pma
```

**Tip:** Use the container name defined in `docker-compose.yml` (traefik, redis, mysql, pma).

### Filtering and Searching

Combine `docker logs` with standard Unix tools for powerful filtering:

```bash
# Search for errors
docker logs traefik | grep -i error

# Search for a specific domain
docker logs traefik | grep "my-app.docker.localhost"

# Count occurrences of a pattern
docker logs traefik | grep -c "404"

# View context around a match (3 lines before and after)
docker logs traefik | grep -C 3 "connection refused"

# Search with case-insensitive matching
docker logs traefik | grep -i "timeout"

# Search for multiple patterns
docker logs traefik | grep -E "error|warning|fail"
```

### Continuous Monitoring

Follow logs in real-time:

```bash
# Follow Traefik logs (like tail -f)
docker logs traefik --follow

# Follow with timestamp
docker logs traefik --follow --timestamps

# Follow last 20 lines and continue
docker logs traefik --follow --tail 20

# Follow and filter
docker logs traefik --follow | grep -i error
```

**Tip:** Press `Ctrl+C` to stop following logs.

### Multi-Service Monitoring

View logs from all running services:

```bash
# Using docker compose
docker compose logs

# Follow all services
docker compose logs --follow

# Specific services only
docker compose logs traefik mysql --follow

# With timestamps and tail limit
docker compose logs --follow --timestamps --tail 50
```

## Traefik Access Logs

Traefik access logs provide detailed information about every HTTP request routed through the proxy. They are **disabled by default** to minimize disk usage and improve performance.

### Enabling Access Logs

1. **Edit your `.env` file:**

   ```bash
   # Enable access logs
   TRAEFIK_ACCESS_LOG_ENABLED=true

   # Choose format: json (recommended) or common
   TRAEFIK_ACCESS_LOG_FORMAT=json
   ```

2. **Restart the Traefik container:**

   ```bash
   docker compose up -d traefik
   ```

3. **Verify logs are being written:**

   ```bash
   ls -lh logs/access.log
   ```

   You should see the `access.log` file growing as requests come in.

### Viewing Access Logs

Access logs are stored in the `logs/` directory:

```bash
# View entire access log
cat logs/access.log

# View last 50 entries
tail -50 logs/access.log

# Follow in real-time
tail -f logs/access.log

# View with timestamps (already included in JSON format)
cat logs/access.log | head -10
```

### Parsing JSON Logs

When using `TRAEFIK_ACCESS_LOG_FORMAT=json` (recommended), logs are structured JSON objects. Use `jq` for powerful parsing:

**Installing jq:**
```bash
# Debian/Ubuntu
sudo apt install jq

# macOS
brew install jq
```

**Common jq Queries:**

```bash
# Pretty-print the last log entry
tail -1 logs/access.log | jq '.'

# Extract only the request path and status code
cat logs/access.log | jq '{path: .RequestPath, status: .DownstreamStatus}'

# Filter only 404 errors
cat logs/access.log | jq 'select(.DownstreamStatus == 404)'

# Count requests by status code
cat logs/access.log | jq -r '.DownstreamStatus' | sort | uniq -c | sort -rn

# Find requests to a specific domain
cat logs/access.log | jq 'select(.RequestHost == "my-app.docker.localhost")'

# Show requests with duration > 1 second
cat logs/access.log | jq 'select(.Duration > 1000000000)'

# Extract client IPs
cat logs/access.log | jq -r '.ClientHost' | sort | uniq -c | sort -rn

# Show all backend servers used
cat logs/access.log | jq -r '.DownstreamServer' | sort | uniq
```

**Example JSON Log Entry:**
```json
{
  "ClientAddr": "172.20.0.1:54321",
  "ClientHost": "172.20.0.1",
  "ClientPort": "54321",
  "ClientUsername": "-",
  "DownstreamContentSize": 1234,
  "DownstreamStatus": 200,
  "Duration": 12345678,
  "OriginContentSize": 1234,
  "OriginDuration": 12000000,
  "OriginStatus": 200,
  "Overhead": 345678,
  "RequestAddr": "my-app.docker.localhost",
  "RequestHost": "my-app.docker.localhost",
  "RequestMethod": "GET",
  "RequestPath": "/api/users",
  "RequestPort": "443",
  "RequestProtocol": "HTTP/2.0",
  "RequestScheme": "https",
  "RouterName": "my-app@docker",
  "ServiceName": "my-app@docker",
  "StartUTC": "2024-01-28T10:15:30.123456789Z",
  "entryPointName": "websecure"
}
```

**Key Fields:**
- `RequestHost`: Domain name requested
- `RequestPath`: URL path
- `RequestMethod`: HTTP method (GET, POST, etc.)
- `DownstreamStatus`: HTTP response status code
- `Duration`: Total request time in nanoseconds (1s = 1,000,000,000ns)
- `ClientHost`: IP address of the client
- `RouterName`: Traefik router that handled the request
- `DownstreamServer`: Backend container that served the request

### Common Use Cases

**Debugging Routing Issues:**
```bash
# Check if requests are reaching Traefik
tail -f logs/access.log | jq '{host: .RequestHost, path: .RequestPath, status: .DownstreamStatus}'

# Find which backend served a request
cat logs/access.log | jq 'select(.RequestPath == "/api/users") | .DownstreamServer'

# Check for routing errors (502, 503, 504)
cat logs/access.log | jq 'select(.DownstreamStatus >= 502 and .DownstreamStatus <= 504)'
```

**Performance Analysis:**
```bash
# Find slow requests (> 5 seconds)
cat logs/access.log | jq 'select(.Duration > 5000000000) | {host: .RequestHost, path: .RequestPath, duration_s: (.Duration / 1000000000)}'

# Average response time by endpoint
cat logs/access.log | jq -r '"\(.RequestPath) \(.Duration)"' | awk '{sum[$1]+=$2; count[$1]++} END {for (path in sum) print path, sum[path]/count[path]/1000000000 "s"}'
```

**Security Monitoring:**
```bash
# List all unique client IPs
cat logs/access.log | jq -r '.ClientHost' | sort | uniq

# Find requests with authentication errors (401)
cat logs/access.log | jq 'select(.DownstreamStatus == 401)'

# Check for suspicious paths
cat logs/access.log | jq 'select(.RequestPath | test("admin|config|env|\\.\\."))'
```

### Access Log Rotation

**Important:** Traefik access logs in the `logs/` directory are **NOT automatically rotated** by Docker. For long-running installations with access logs enabled, consider:

**Option 1: Manual Rotation**
```bash
# Stop Traefik
docker compose stop traefik

# Rotate the log file
mv logs/access.log logs/access.log.$(date +%Y%m%d-%H%M%S)

# Optionally compress old logs
gzip logs/access.log.*

# Start Traefik (will create a new access.log)
docker compose start traefik
```

**Option 2: Logrotate (Linux)**

Create `/etc/logrotate.d/traefik-proxy`:

```
/path/to/docker-proxy/logs/access.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    postrotate
        docker compose -f /path/to/docker-proxy/docker-compose.yml restart traefik
    endscript
}
```

**Option 3: Disable When Not Needed**

Set `TRAEFIK_ACCESS_LOG_ENABLED=false` in `.env` and restart:

```bash
docker compose up -d traefik
```

Access logs are typically only needed during active debugging.

## Log File Locations

**Container Logs:**
- Managed by Docker daemon
- Location: `/var/lib/docker/containers/<container-id>/<container-id>-json.log`
- Access via: `docker logs <container-name>` (recommended)
- Rotation: Automatic (configured in docker-compose.yml)

**Traefik Access Logs:**
- Location: `./logs/access.log` (relative to project root)
- Access via: Standard file tools (`cat`, `tail`, `less`)
- Rotation: Manual (see [Access Log Rotation](#access-log-rotation))

**Note:** The `logs/` directory is git-ignored. Only `logs/.gitkeep` is tracked to preserve the directory structure.

## Troubleshooting

### Logs Not Appearing

**Symptom:** `docker logs` returns no output or very little output.

**Possible Causes:**
1. Container recently restarted (logs are lost on restart unless using external logging drivers)
2. Container is not producing any log output
3. Log rotation removed old logs

**Solutions:**
```bash
# Check container status
docker ps -a | grep traefik

# Verify logging configuration
docker inspect traefik | grep -A 10 "LogConfig"

# Check if container is running
docker compose ps

# Force container restart to see startup logs
docker compose restart traefik && docker logs traefik --follow
```

### Access Logs Not Created

**Symptom:** `logs/access.log` does not exist after enabling.

**Solutions:**
```bash
# Verify environment variable
docker exec traefik env | grep TRAEFIK_ACCESSLOG

# Check Traefik is using the correct configuration
docker logs traefik | grep -i "access log"

# Verify volume mount
docker inspect traefik | grep -A 5 "Mounts"

# Restart Traefik
docker compose up -d traefik

# Generate traffic to trigger log creation
curl -k https://traefik.docker.localhost
```

### Disk Space Warnings

**Symptom:** System warns about disk space despite log rotation.

**Investigation:**
```bash
# Check size of all container logs
sudo du -sh /var/lib/docker/containers/*/

# Check Traefik access log size
du -sh logs/access.log

# Check total Docker disk usage
docker system df -v
```

**Solutions:**
```bash
# Clean up old Docker resources
docker system prune -a

# Reduce log retention (edit docker-compose.yml)
# Change max-size to "5m" or max-file to "2"

# Disable Traefik access logs
# Set TRAEFIK_ACCESS_LOG_ENABLED=false in .env

# Manually rotate access logs (if enabled)
mv logs/access.log logs/access.log.old && gzip logs/access.log.old
docker compose restart traefik
```

### JSON Parsing Errors

**Symptom:** `jq` fails with "parse error" when reading access logs.

**Causes:**
1. Log file is incomplete (currently being written)
2. Mixed format logs (changed format while Traefik was running)
3. Corrupted log entry

**Solutions:**
```bash
# Check if file is still being written
lsof logs/access.log

# Validate JSON structure
cat logs/access.log | jq empty

# Find the problematic line
cat logs/access.log | jq -c . 2>&1 | grep "parse error" -B 1

# Skip invalid lines
cat logs/access.log | while read line; do echo "$line" | jq . 2>/dev/null; done
```

### Logs Contain Sensitive Data

**Symptom:** Logs include passwords, tokens, or other sensitive information.

**Prevention:**
```bash
# For Traefik access logs: Use filters to exclude headers
# (Requires custom Traefik configuration beyond this guide)

# For container logs: Ensure applications don't log secrets
# Review application logging configuration
```

**Remediation:**
```bash
# Rotate logs immediately
docker compose stop traefik
rm logs/access.log
docker compose start traefik

# For container logs, prune and recreate
docker compose down
docker system prune -a
docker compose up -d
```

## Best Practices

### 1. Use Access Logs Sparingly

**Recommendation:** Only enable Traefik access logs when actively debugging.

```bash
# Enable for debugging
TRAEFIK_ACCESS_LOG_ENABLED=true

# Disable after resolving issues
TRAEFIK_ACCESS_LOG_ENABLED=false
```

**Reason:** Access logs grow quickly in production and can fill disks despite container log rotation.

### 2. Monitor Disk Usage Regularly

**Recommendation:** Periodically check Docker's disk usage:

```bash
# Quick check
docker system df

# Detailed view
docker system df -v

# Check access log size
du -sh logs/
```

### 3. Use Structured JSON Format

**Recommendation:** Keep `TRAEFIK_ACCESS_LOG_FORMAT=json` for easier parsing.

**Example:**
```bash
# JSON format enables powerful queries
cat logs/access.log | jq 'select(.DownstreamStatus >= 500)'

# Common format is harder to parse
cat logs/access.log | awk '$9 >= 500'
```

### 4. Leverage Filtering Instead of Full Logs

**Recommendation:** Use `docker logs` with filters instead of viewing full logs:

```bash
# Instead of: docker logs traefik | less
# Use targeted queries:
docker logs traefik --since 1h | grep error
docker logs traefik --tail 100 | grep "my-app"
```

### 5. Automate Log Rotation for Access Logs

**Recommendation:** If you keep access logs enabled long-term, set up logrotate or a cron job.

**Example cron job (runs daily):**
```bash
# Add to crontab: crontab -e
0 0 * * * cd /path/to/docker-proxy && mv logs/access.log logs/access.log.$(date +\%Y\%m\%d) && docker compose restart traefik && gzip logs/access.log.*
```

### 6. Correlate Logs Across Services

**Recommendation:** Use timestamps to correlate events across services:

```bash
# View logs from multiple services with timestamps
docker compose logs --timestamps traefik mysql | sort

# Find events around a specific time
docker logs traefik --since "2024-01-28T10:00:00" --until "2024-01-28T10:05:00"
```

### 7. Preserve Logs for Debugging

**Recommendation:** Before restarting containers during troubleshooting, save logs:

```bash
# Save logs before restart
docker logs traefik > traefik-debug-$(date +%Y%m%d-%H%M%S).log
docker compose restart traefik
```

**Reason:** Container logs are lost when a container is removed (but not on restart).

### 8. Use Log Levels Appropriately

**Recommendation:** Configure application log levels based on environment:

- **Development**: INFO or DEBUG
- **Production**: WARNING or ERROR

For Traefik, log level is controlled via command flags (not currently configured in this setup).

### 9. Avoid Logging Sensitive Information

**Recommendation:** Never log:
- Passwords or API keys
- Personally identifiable information (PII)
- Financial data
- Session tokens

**Implementation:** Review application code and configuration to ensure sensitive data is redacted or excluded from logs.

### 10. Document Custom Logging Setups

**Recommendation:** If you customize logging (e.g., add external logging drivers, change rotation settings), document changes in your project's README.

**Example:**
```markdown
## Custom Logging Configuration

This project uses a custom log rotation policy:
- max-size: 5m (reduced from 10m)
- max-file: 5 (increased from 3)
- Access logs enabled by default for monitoring
```

---

## Additional Resources

- [Docker Logging Documentation](https://docs.docker.com/config/containers/logging/)
- [Traefik Access Logs](https://doc.traefik.io/traefik/observability/access-logs/)
- [jq Manual](https://stedolan.github.io/jq/manual/)
- [Logrotate Tutorial](https://www.digitalocean.com/community/tutorials/how-to-manage-logfiles-with-logrotate-on-ubuntu-20-04)

---

**Have questions or suggestions?** Open an issue in the GitHub repository or check the [Integration Guide](INTEGRATION_GUIDE.md) for related topics.
