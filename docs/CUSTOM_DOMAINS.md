# Custom Domains Documentation

This guide covers using custom top-level domains (TLDs) beyond the default `docker.localhost` in the Local Docker Proxy. It includes DNS configuration methods, certificate generation, platform-specific instructions, and troubleshooting for custom domain setups.

## Table of Contents

- [Overview](#overview)
- [Why Use Custom Domains](#why-use-custom-domains)
- [Quick Start](#quick-start)
- [DNS Resolution Methods](#dns-resolution-methods)
  - [Method 1: /etc/hosts (Simple)](#method-1-etchosts-simple)
  - [Method 2: dnsmasq (Wildcard Support)](#method-2-dnsmasq-wildcard-support)
  - [Method 3: systemd-resolved (Linux)](#method-3-systemd-resolved-linux)
  - [Method 4: macOS DNS Resolvers](#method-4-macos-dns-resolvers)
- [Certificate Generation](#certificate-generation)
  - [Configuring Custom Domains](#configuring-custom-domains)
  - [Regenerating Certificates](#regenerating-certificates)
  - [Wildcard Certificates](#wildcard-certificates)
- [Platform-Specific Guides](#platform-specific-guides)
  - [Linux (Debian/Ubuntu)](#linux-debianubuntu)
  - [Linux (Fedora/RHEL)](#linux-fedorarhel)
  - [Linux (Arch)](#linux-arch)
  - [macOS](#macos)
  - [Windows (WSL2)](#windows-wsl2)
- [Using Custom Domains in Projects](#using-custom-domains-in-projects)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Common Patterns](#common-patterns)

## Overview

By default, the Local Docker Proxy uses `*.docker.localhost` domains for routing local services. This works out-of-the-box on most systems, but you may want to use custom domains that:

- Match your production environment (e.g., `*.mycompany.local`)
- Follow organizational standards (e.g., `*.dev`, `*.test`)
- Provide clearer service naming (e.g., `api.myapp.local`, `admin.myapp.local`)
- Support multiple projects with different domain patterns

**Key Features:**
- ✅ Support for any custom TLD (`.local`, `.test`, `.dev`, etc.)
- ✅ Wildcard domain support with proper DNS configuration
- ✅ Automatic SSL certificate generation for custom domains
- ✅ Multiple domain patterns in a single setup
- ✅ Platform-specific configuration guides
- ✅ No changes to Traefik configuration required

**Default Configuration:**
- **Default Domain**: `*.docker.localhost`
- **Default Certificate**: Covers `localhost`, `*.docker.localhost`, `127.0.0.1`, `::1`
- **No DNS Setup**: `docker.localhost` resolves to `127.0.0.1` automatically

## Why Use Custom Domains

### Match Production Environment

**Scenario:** Your production app uses `api.mycompany.com` and `admin.mycompany.com`.

**Solution:** Use `api.mycompany.local` and `admin.mycompany.local` in development.

**Benefits:**
- Consistent URL structure between environments
- Easier testing of environment-specific code
- Cookie and CORS configurations work the same way
- Less configuration changes when deploying

### Organizational Standards

**Scenario:** Your team standardizes on `.test` domains for all local development.

**Solution:** Configure `*.test` as a custom domain.

**Benefits:**
- Team-wide consistency
- Easier onboarding for new developers
- Documentation applies to everyone
- Reduced confusion about which URLs to use

### Better Service Organization

**Scenario:** You have multiple microservices for a single application.

**Solution:** Use `*.myapp.local` pattern for all services.

**Benefits:**
- Clear namespace separation
- Professional-looking URLs
- Easier to remember service addresses
- Better than numbered ports (`:8001`, `:8002`, etc.)

### Reserved TLDs for Testing

Certain TLDs are reserved for testing and will never be registered as real domains:

- `.test` - [RFC 6761](https://tools.ietf.org/html/rfc6761) reserved for testing
- `.localhost` - [RFC 6761](https://tools.ietf.org/html/rfc6761) reserved for localhost
- `.local` - Used for mDNS/Bonjour (requires DNS configuration to override)
- `.invalid` - [RFC 6761](https://tools.ietf.org/html/rfc6761) reserved (guaranteed invalid)
- `.example` - [RFC 6761](https://tools.ietf.org/html/rfc6761) reserved for examples

**Recommendation:** Use `.test` for custom development domains as it's specifically reserved for testing purposes.

## Quick Start

**1. Add custom domains to `.env`:**
```dotenv
CUSTOM_DOMAINS=*.local,*.test
```

**2. Regenerate certificates:**
```bash
./setup.sh
```

**3. Configure DNS (choose one method):**

**Simple (one domain):**
```bash
# Add to /etc/hosts
echo "127.0.0.1 myapp.local" | sudo tee -a /etc/hosts
```

**Wildcard (recommended):**
```bash
# Install dnsmasq (Linux)
sudo apt install dnsmasq
echo "address=/.local/127.0.0.1" | sudo tee /etc/dnsmasq.d/local-dev.conf
sudo systemctl restart dnsmasq
```

**4. Update your project labels:**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myapp.rule=Host(`myapp.local`)"
  - "traefik.http.routers.myapp.tls=true"
```

**5. Access your service:**
```
https://myapp.local
```

## DNS Resolution Methods

Custom domains require DNS resolution to point to `127.0.0.1` (localhost). Choose the method that best fits your needs.

### Method 1: /etc/hosts (Simple)

**Best for:** Single domains or small number of services.

**Pros:**
- ✅ No additional software required
- ✅ Works on all platforms
- ✅ Simple to understand
- ✅ No system service dependencies

**Cons:**
- ❌ No wildcard support (must add each subdomain)
- ❌ Requires sudo/admin access
- ❌ Manual updates for each service

**Configuration:**

Edit `/etc/hosts` (Linux/macOS) or `C:\Windows\System32\drivers\etc\hosts` (Windows):

```bash
# Linux/macOS
sudo nano /etc/hosts

# Add your domains
127.0.0.1 myapp.local
127.0.0.1 api.myapp.local
127.0.0.1 admin.myapp.local
127.0.0.1 app.test
```

**Windows (WSL2):**

You need to add entries in **both** WSL2 and Windows:

```bash
# Inside WSL2
echo "127.0.0.1 myapp.local" | sudo tee -a /etc/hosts

# In Windows PowerShell (Run as Administrator)
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "127.0.0.1 myapp.local"
```

**Verification:**
```bash
# Test DNS resolution
ping myapp.local

# Should show: PING myapp.local (127.0.0.1) ...
```

### Method 2: dnsmasq (Wildcard Support)

**Best for:** Multiple subdomains, development environments with many services.

**Pros:**
- ✅ Wildcard domain support (e.g., `*.local` → `127.0.0.1`)
- ✅ One-time configuration
- ✅ Professional development setup
- ✅ No manual updates per service

**Cons:**
- ❌ Requires additional software
- ❌ Slight complexity in setup
- ❌ May conflict with existing DNS configurations

**Installation:**

**Debian/Ubuntu:**
```bash
sudo apt update
sudo apt install dnsmasq
```

**Fedora/RHEL:**
```bash
sudo dnf install dnsmasq
```

**Arch Linux:**
```bash
sudo pacman -S dnsmasq
```

**macOS:**
```bash
brew install dnsmasq
```

**Configuration:**

**Linux:**
```bash
# Create configuration for .local domains
echo "address=/.local/127.0.0.1" | sudo tee /etc/dnsmasq.d/local-dev.conf

# Create configuration for .test domains
echo "address=/.test/127.0.0.1" | sudo tee /etc/dnsmasq.d/test-dev.conf

# Restart dnsmasq
sudo systemctl restart dnsmasq
sudo systemctl enable dnsmasq

# Configure system to use dnsmasq
# Edit /etc/resolv.conf or NetworkManager configuration
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf.d/head
```

**macOS:**
```bash
# Start dnsmasq
sudo brew services start dnsmasq

# Configure for .local domains
echo "address=/.local/127.0.0.1" >> $(brew --prefix)/etc/dnsmasq.conf

# Configure for .test domains
echo "address=/.test/127.0.0.1" >> $(brew --prefix)/etc/dnsmasq.conf

# Restart dnsmasq
sudo brew services restart dnsmasq

# Create resolver (see Method 4 for details)
sudo mkdir -p /etc/resolver
echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/local
echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/test
```

**NetworkManager Integration (Modern Linux):**

If your system uses NetworkManager, configure it to use dnsmasq:

```bash
# Create NetworkManager dnsmasq configuration
sudo tee /etc/NetworkManager/conf.d/dnsmasq.conf > /dev/null <<EOF
[main]
dns=dnsmasq
EOF

# Create dnsmasq configuration for custom domains
sudo tee /etc/NetworkManager/dnsmasq.d/local-dev.conf > /dev/null <<EOF
address=/.local/127.0.0.1
address=/.test/127.0.0.1
EOF

# Restart NetworkManager
sudo systemctl restart NetworkManager
```

**Verification:**
```bash
# Test wildcard resolution
ping random-subdomain.local
ping another-service.test

# All should resolve to 127.0.0.1
```

### Method 3: systemd-resolved (Linux)

**Best for:** Modern Linux distributions using systemd-resolved.

**Pros:**
- ✅ Native to systemd-based distributions
- ✅ No additional software needed
- ✅ Integrates with system DNS
- ✅ Per-domain DNS configuration

**Cons:**
- ❌ Only available on systemd distributions
- ❌ Slightly complex configuration
- ❌ May conflict with other DNS managers

**Check if systemd-resolved is active:**
```bash
systemctl status systemd-resolved
```

**Configuration:**
```bash
# Create a resolved configuration for .local domain
sudo tee /etc/systemd/resolved.conf.d/local-dev.conf > /dev/null <<EOF
[Resolve]
DNS=127.0.0.1
Domains=~local ~test
EOF

# Restart systemd-resolved
sudo systemctl restart systemd-resolved

# Verify configuration
resolvectl status
```

**Alternative: Using resolvectl directly:**
```bash
# Configure per-interface (replace eth0 with your interface)
sudo resolvectl dns eth0 127.0.0.1
sudo resolvectl domain eth0 '~local' '~test'
```

**Note:** The `~` prefix means "use this DNS server for this domain only."

### Method 4: macOS DNS Resolvers

**Best for:** macOS users wanting clean, native DNS resolution.

**Pros:**
- ✅ Native macOS feature
- ✅ Per-domain configuration
- ✅ Works with any DNS server
- ✅ No additional software (if not using dnsmasq)

**Cons:**
- ❌ macOS only
- ❌ Requires manual file creation

**Configuration:**

**Option A: Using dnsmasq (recommended):**
```bash
# Install dnsmasq
brew install dnsmasq

# Configure dnsmasq
echo "address=/.local/127.0.0.1" >> $(brew --prefix)/etc/dnsmasq.conf
echo "address=/.test/127.0.0.1" >> $(brew --prefix)/etc/dnsmasq.conf

# Start dnsmasq
sudo brew services start dnsmasq

# Create resolver configurations
sudo mkdir -p /etc/resolver

# For .local domains
sudo tee /etc/resolver/local > /dev/null <<EOF
nameserver 127.0.0.1
EOF

# For .test domains
sudo tee /etc/resolver/test > /dev/null <<EOF
nameserver 127.0.0.1
EOF
```

**Option B: Direct hosts file (no dnsmasq):**

For each domain you want to resolve:
```bash
# Edit hosts file
sudo nano /etc/hosts

# Add entries
127.0.0.1 myapp.local
127.0.0.1 api.myapp.local
```

**Verification:**
```bash
# Test resolution
scutil --dns
ping myapp.local

# Check specific resolver
scutil --dns | grep -A 5 "resolver #"
```

**Flush DNS cache after changes:**
```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

## Certificate Generation

The Local Docker Proxy uses `mkcert` to generate trusted SSL certificates for all configured domains.

### Configuring Custom Domains

Custom domains are configured via the `CUSTOM_DOMAINS` environment variable in `.env`:

**Format:**
```dotenv
# Comma-separated list of domains (wildcards supported)
CUSTOM_DOMAINS=*.local,*.test,myapp.dev
```

**Examples:**

**Single custom TLD:**
```dotenv
CUSTOM_DOMAINS=*.local
```

**Multiple custom TLDs:**
```dotenv
CUSTOM_DOMAINS=*.local,*.test,*.dev
```

**Mix of wildcards and specific domains:**
```dotenv
CUSTOM_DOMAINS=*.local,api.myapp.com,admin.myapp.com
```

**No custom domains (default):**
```dotenv
CUSTOM_DOMAINS=
```

### Regenerating Certificates

When you add or change `CUSTOM_DOMAINS`, you need to regenerate the SSL certificates.

**Method 1: Run setup script (recommended):**
```bash
./setup.sh
```

The script will:
1. Read `CUSTOM_DOMAINS` from `.env`
2. Generate new certificates including custom domains
3. Restart Traefik to load new certificates

**Method 2: Manual regeneration:**
```bash
# Remove old certificates
rm certs/local-*.pem

# Generate new certificates with custom domains
mkcert -key-file certs/local-key.pem \
  -cert-file certs/local-cert.pem \
  "localhost" "*.docker.localhost" "127.0.0.1" "::1" \
  "*.local" "*.test"

# Set proper permissions
chmod 644 certs/local-cert.pem
chmod 600 certs/local-key.pem

# Restart Traefik
docker compose restart traefik
```

**Verification:**
```bash
# Check certificate domains
openssl x509 -in certs/local-cert.pem -text -noout | grep DNS

# Output should include:
# DNS:localhost, DNS:*.docker.localhost, DNS:*.local, DNS:*.test, ...
```

### Wildcard Certificates

Wildcard certificates (e.g., `*.local`) cover all subdomains but **not** the root domain.

**What's covered by `*.local`:**
- ✅ `myapp.local`
- ✅ `api.local`
- ✅ `admin.myapp.local` (Note: Only one level deep!)
- ❌ `local` (root domain not covered)
- ❌ `deep.subdomain.myapp.local` (too many levels)

**Best practice:**

If you need the root domain, add it explicitly:
```dotenv
# Covers *.local AND local
CUSTOM_DOMAINS=*.local,local
```

For multi-level subdomains, add them explicitly or use multiple wildcards:
```dotenv
# Cover both levels
CUSTOM_DOMAINS=*.local,*.myapp.local
```

**mkcert limitation:**

`mkcert` supports wildcards, but they only cover **one level** of subdomains. For complex domain structures, list specific domains.

## Platform-Specific Guides

### Linux (Debian/Ubuntu)

**Complete setup for `.local` and `.test` domains:**

```bash
# 1. Configure custom domains in .env
cat >> .env <<EOF
CUSTOM_DOMAINS=*.local,*.test
EOF

# 2. Run setup to generate certificates
./setup.sh

# 3. Install dnsmasq
sudo apt update
sudo apt install dnsmasq

# 4. Configure wildcard DNS resolution
echo "address=/.local/127.0.0.1" | sudo tee /etc/dnsmasq.d/local-dev.conf
echo "address=/.test/127.0.0.1" | sudo tee /etc/dnsmasq.d/test-dev.conf

# 5. Restart dnsmasq
sudo systemctl restart dnsmasq
sudo systemctl enable dnsmasq

# 6. Configure NetworkManager to use dnsmasq (if applicable)
if systemctl is-active NetworkManager > /dev/null; then
    sudo tee /etc/NetworkManager/conf.d/dnsmasq.conf > /dev/null <<EOF
[main]
dns=dnsmasq
EOF
    sudo systemctl restart NetworkManager
fi

# 7. Test resolution
ping myapp.local
```

**Alternative: Using systemd-resolved:**
```bash
# 1. Configure custom domains and run setup
cat >> .env <<EOF
CUSTOM_DOMAINS=*.local,*.test
EOF
./setup.sh

# 2. Install dnsmasq
sudo apt install dnsmasq

# 3. Configure dnsmasq
echo "address=/.local/127.0.0.1" | sudo tee /etc/dnsmasq.d/local-dev.conf
echo "address=/.test/127.0.0.1" | sudo tee /etc/dnsmasq.d/test-dev.conf
sudo systemctl restart dnsmasq

# 4. Configure systemd-resolved to use dnsmasq for specific domains
sudo tee /etc/systemd/resolved.conf.d/local-dev.conf > /dev/null <<EOF
[Resolve]
DNS=127.0.0.1
Domains=~local ~test
EOF

# 5. Restart systemd-resolved
sudo systemctl restart systemd-resolved

# 6. Verify
resolvectl status
```

### Linux (Fedora/RHEL)

**Complete setup:**

```bash
# 1. Configure custom domains
cat >> .env <<EOF
CUSTOM_DOMAINS=*.local,*.test
EOF

# 2. Run setup
./setup.sh

# 3. Install dnsmasq
sudo dnf install dnsmasq

# 4. Configure dnsmasq
echo "address=/.local/127.0.0.1" | sudo tee /etc/dnsmasq.d/local-dev.conf
echo "address=/.test/127.0.0.1" | sudo tee /etc/dnsmasq.d/test-dev.conf

# 5. Configure NetworkManager
sudo tee /etc/NetworkManager/conf.d/dnsmasq.conf > /dev/null <<EOF
[main]
dns=dnsmasq
EOF

# 6. Restart services
sudo systemctl restart dnsmasq
sudo systemctl enable dnsmasq
sudo systemctl restart NetworkManager

# 7. Test
ping myapp.local
```

### Linux (Arch)

**Complete setup:**

```bash
# 1. Configure custom domains
cat >> .env <<EOF
CUSTOM_DOMAINS=*.local,*.test
EOF

# 2. Run setup
./setup.sh

# 3. Install dnsmasq
sudo pacman -S dnsmasq

# 4. Configure dnsmasq
echo "address=/.local/127.0.0.1" | sudo tee /etc/dnsmasq.d/local-dev.conf
echo "address=/.test/127.0.0.1" | sudo tee /etc/dnsmasq.d/test-dev.conf

# 5. Start and enable dnsmasq
sudo systemctl start dnsmasq
sudo systemctl enable dnsmasq

# 6. Configure NetworkManager (if used)
if systemctl is-active NetworkManager > /dev/null; then
    sudo tee /etc/NetworkManager/conf.d/dnsmasq.conf > /dev/null <<EOF
[main]
dns=dnsmasq
EOF
    sudo systemctl restart NetworkManager
fi

# 7. Test
ping myapp.local
```

### macOS

**Complete setup:**

```bash
# 1. Configure custom domains
cat >> .env <<EOF
CUSTOM_DOMAINS=*.local,*.test
EOF

# 2. Run setup
./setup.sh

# 3. Install dnsmasq
brew install dnsmasq

# 4. Configure dnsmasq for wildcards
echo "address=/.local/127.0.0.1" >> $(brew --prefix)/etc/dnsmasq.conf
echo "address=/.test/127.0.0.1" >> $(brew --prefix)/etc/dnsmasq.conf

# 5. Start dnsmasq service
sudo brew services start dnsmasq

# 6. Create DNS resolver configurations
sudo mkdir -p /etc/resolver

sudo tee /etc/resolver/local > /dev/null <<EOF
nameserver 127.0.0.1
EOF

sudo tee /etc/resolver/test > /dev/null <<EOF
nameserver 127.0.0.1
EOF

# 7. Flush DNS cache
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# 8. Test
ping myapp.local
scutil --dns | grep -A 5 "resolver #"
```

**Note:** macOS uses `.local` for Bonjour/mDNS by default. Using dnsmasq overrides this behavior for development purposes.

### Windows (WSL2)

**Complete setup:**

Windows WSL2 requires configuration in both WSL2 and Windows for proper DNS resolution.

**Inside WSL2:**
```bash
# 1. Configure custom domains
cat >> .env <<EOF
CUSTOM_DOMAINS=*.local,*.test
EOF

# 2. Run setup
./setup.sh

# 3. Install dnsmasq
sudo apt update
sudo apt install dnsmasq

# 4. Configure dnsmasq
echo "address=/.local/127.0.0.1" | sudo tee /etc/dnsmasq.d/local-dev.conf
echo "address=/.test/127.0.0.1" | sudo tee /etc/dnsmasq.d/test-dev.conf

# 5. Restart dnsmasq
sudo systemctl restart dnsmasq
sudo systemctl enable dnsmasq

# 6. Add to /etc/hosts for simple domains
sudo tee -a /etc/hosts > /dev/null <<EOF
127.0.0.1 myapp.local
127.0.0.1 api.myapp.local
EOF
```

**In Windows (PowerShell as Administrator):**
```powershell
# Add entries to Windows hosts file
$hostsPath = "C:\Windows\System32\drivers\etc\hosts"
Add-Content -Path $hostsPath -Value "`n127.0.0.1 myapp.local"
Add-Content -Path $hostsPath -Value "127.0.0.1 api.myapp.local"

# Flush DNS cache
ipconfig /flushdns
```

**Test from both environments:**
```bash
# Inside WSL2
ping myapp.local

# In Windows PowerShell
ping myapp.local
```

**Access from Windows browser:**

Your custom domains should work in Windows browsers if:
1. Entries exist in Windows `hosts` file
2. Docker Desktop is running with WSL2 integration
3. Port forwarding is enabled (Docker Desktop handles this)

## Using Custom Domains in Projects

Once DNS and certificates are configured, using custom domains in your projects is straightforward.

**Update your `docker-compose.yml`:**

```yaml
services:
  web:
    image: nginx:alpine
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      # Use your custom domain
      - "traefik.http.routers.myapp.rule=Host(`myapp.local`)"
      - "traefik.http.routers.myapp.tls=true"

networks:
  traefik-proxy:
    external: true
```

**Multiple services with subdomains:**

```yaml
services:
  api:
    image: my-api:latest
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.api.rule=Host(`api.myapp.local`)"
      - "traefik.http.routers.api.tls=true"

  admin:
    image: my-admin:latest
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.admin.rule=Host(`admin.myapp.local`)"
      - "traefik.http.routers.admin.tls=true"

  frontend:
    image: my-frontend:latest
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.frontend.rule=Host(`myapp.local`)"
      - "traefik.http.routers.frontend.tls=true"

networks:
  traefik-proxy:
    external: true
```

**Start your services:**
```bash
docker compose up -d
```

**Access your services:**
- Frontend: `https://myapp.local`
- API: `https://api.myapp.local`
- Admin: `https://admin.myapp.local`

## Troubleshooting

### Domain Not Resolving

**Error:** `ping: cannot resolve myapp.local: Unknown host`

**Causes & Solutions:**

**1. DNS not configured:**
```bash
# Check if domain is in /etc/hosts
grep myapp.local /etc/hosts

# If not found, add it
echo "127.0.0.1 myapp.local" | sudo tee -a /etc/hosts
```

**2. dnsmasq not running:**
```bash
# Check dnsmasq status
sudo systemctl status dnsmasq

# If not running, start it
sudo systemctl start dnsmasq
sudo systemctl enable dnsmasq
```

**3. dnsmasq not configured for the domain:**
```bash
# Check dnsmasq configuration
cat /etc/dnsmasq.d/local-dev.conf

# Should contain: address=/.local/127.0.0.1
```

**4. System not using dnsmasq for DNS:**
```bash
# Check DNS servers
cat /etc/resolv.conf

# Should include: nameserver 127.0.0.1

# If NetworkManager is used
sudo tee /etc/NetworkManager/conf.d/dnsmasq.conf > /dev/null <<EOF
[main]
dns=dnsmasq
EOF
sudo systemctl restart NetworkManager
```

### SSL Certificate Not Trusted

**Error:** Browser shows "Your connection is not private" or "NET::ERR_CERT_AUTHORITY_INVALID"

**Causes & Solutions:**

**1. mkcert CA not installed:**
```bash
# Install the local CA
mkcert -install

# Restart browser
```

**2. Custom domain not in certificate:**
```bash
# Check certificate domains
openssl x509 -in certs/local-cert.pem -text -noout | grep DNS

# If custom domain is missing, regenerate:
./setup.sh
```

**3. Certificate not regenerated after adding custom domain:**
```bash
# Remove old certificates
rm certs/local-*.pem

# Regenerate with custom domains
./setup.sh

# Restart Traefik
docker compose restart traefik
```

**4. Browser cache:**
```bash
# Clear browser cache and SSL state
# Chrome: Settings > Privacy > Clear browsing data > Cached images and files
# Firefox: Settings > Privacy > Clear Data > Cached Web Content

# Hard refresh the page
# Ctrl+Shift+R (Linux/Windows) or Cmd+Shift+R (macOS)
```

### Traefik Not Routing to Service

**Error:** 404 Not Found or "Service Unavailable"

**Causes & Solutions:**

**1. Service not on traefik-proxy network:**
```bash
# Check service networks
docker inspect <container_name> | grep NetworkMode

# Should show: traefik-proxy
```

**2. Missing or incorrect Traefik labels:**
```bash
# Check service labels
docker inspect <container_name> | grep -A 10 Labels

# Required labels:
# - traefik.enable=true
# - traefik.http.routers.<name>.rule=Host(`domain.local`)
# - traefik.http.routers.<name>.tls=true
```

**3. Check Traefik dashboard:**
```bash
# Open Traefik dashboard
open https://traefik.docker.localhost

# Look for your router under HTTP > Routers
# Check for errors or warnings
```

**4. Check Traefik logs:**
```bash
# View logs for routing errors
docker logs traefik --tail 100

# Look for errors related to your service
docker logs traefik | grep myapp
```

### Wildcard Domain Not Working

**Error:** Subdomains don't resolve (e.g., `api.myapp.local` doesn't work)

**Causes & Solutions:**

**1. Using /etc/hosts instead of dnsmasq:**
```bash
# /etc/hosts doesn't support wildcards
# Solution: Install and configure dnsmasq (see Method 2)

sudo apt install dnsmasq
echo "address=/.local/127.0.0.1" | sudo tee /etc/dnsmasq.d/local-dev.conf
sudo systemctl restart dnsmasq
```

**2. dnsmasq wildcard not configured:**
```bash
# Check for wildcard configuration
grep "address=/.local" /etc/dnsmasq.d/*

# If missing, add it
echo "address=/.local/127.0.0.1" | sudo tee /etc/dnsmasq.d/local-dev.conf
sudo systemctl restart dnsmasq
```

**3. Certificate doesn't include wildcard:**
```bash
# Check certificate
openssl x509 -in certs/local-cert.pem -text -noout | grep DNS

# Should include: DNS:*.local

# If missing, add to .env
echo "CUSTOM_DOMAINS=*.local" >> .env
./setup.sh
```

### macOS .local Domain Conflicts

**Error:** `.local` domains resolve incorrectly or timeout

**Cause:** macOS uses `.local` for Bonjour/mDNS by default.

**Solutions:**

**Option 1: Use a different TLD (recommended):**
```dotenv
# In .env, use .test instead
CUSTOM_DOMAINS=*.test
```

**Option 2: Override with dnsmasq resolver:**
```bash
# Create resolver to prioritize dnsmasq
sudo tee /etc/resolver/local > /dev/null <<EOF
nameserver 127.0.0.1
order 1
EOF

# Flush DNS cache
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

**Option 3: Disable mDNS for specific domains:**
```bash
# This is advanced and may affect other services
# Generally not recommended
```

### Windows WSL2 DNS Issues

**Error:** Custom domains work in WSL2 but not in Windows browser

**Causes & Solutions:**

**1. Windows hosts file not updated:**
```powershell
# In PowerShell (as Administrator)
Add-Content C:\Windows\System32\drivers\etc\hosts "`n127.0.0.1 myapp.local"
ipconfig /flushdns
```

**2. WSL2 IP changed:**
```bash
# WSL2 IP may change on restart
# Check WSL2 IP
ip addr show eth0

# From Windows, check WSL2 IP
wsl hostname -I
```

**3. Port forwarding not working:**
```bash
# Docker Desktop should handle this
# Check Docker Desktop settings:
# Settings > Resources > WSL Integration
# Ensure integration is enabled for your distro
```

### Permission Denied on Certificate Files

**Error:** "Permission denied" when accessing certificate files

**Solution:**
```bash
# Fix certificate permissions
chmod 644 certs/local-cert.pem
chmod 600 certs/local-key.pem

# Restart Traefik
docker compose restart traefik
```

### dnsmasq Conflicts with Existing DNS

**Error:** "Address already in use" when starting dnsmasq

**Cause:** Another service is using port 53.

**Solution:**

**Check what's using port 53:**
```bash
sudo lsof -i :53
```

**Common conflicts:**

**1. systemd-resolved:**
```bash
# Option A: Configure systemd-resolved to not use port 53
sudo tee -a /etc/systemd/resolved.conf > /dev/null <<EOF
[Resolve]
DNSStubListener=no
EOF

sudo systemctl restart systemd-resolved

# Option B: Use systemd-resolved instead of dnsmasq
# See Method 3: systemd-resolved
```

**2. Another DNS server:**
```bash
# Stop conflicting service
sudo systemctl stop <service-name>

# Disable if not needed
sudo systemctl disable <service-name>
```

## Best Practices

### 1. Use Reserved TLDs

**Recommendation:** Use `.test` for development as it's officially reserved for testing.

```dotenv
# Recommended
CUSTOM_DOMAINS=*.test

# Also good
CUSTOM_DOMAINS=*.localhost

# Avoid
CUSTOM_DOMAINS=*.dev  # .dev requires HTTPS everywhere (owned by Google)
CUSTOM_DOMAINS=*.com  # Real TLD, may cause conflicts
```

### 2. Use Wildcards for Flexibility

**Recommendation:** Use wildcard domains to avoid updating DNS for every new service.

```dotenv
# Good: One wildcard covers all subdomains
CUSTOM_DOMAINS=*.myapp.test

# Less flexible: Must add each subdomain to /etc/hosts
# (No CUSTOM_DOMAINS, manual /etc/hosts entries)
```

### 3. Match Production Patterns

**Recommendation:** Mirror your production domain structure in local development.

**Production:**
- `api.mycompany.com`
- `admin.mycompany.com`
- `www.mycompany.com`

**Local:**
```dotenv
CUSTOM_DOMAINS=*.mycompany.test
```

**Services:**
- `api.mycompany.test`
- `admin.mycompany.test`
- `www.mycompany.test`

### 4. Document Team Configuration

**Recommendation:** Add a `docs/LOCAL_SETUP.md` to your project repository.

**Example:**
```markdown
# Local Development Setup

## Custom Domains

This project uses `*.myapp.test` domains.

### DNS Setup

**Linux/macOS:**
```bash
# Install dnsmasq
sudo apt install dnsmasq  # or brew install dnsmasq

# Configure
echo "address=/.test/127.0.0.1" | sudo tee /etc/dnsmasq.d/test-dev.conf
sudo systemctl restart dnsmasq
```

**Windows:**
Add to `C:\Windows\System32\drivers\etc\hosts`:
```
127.0.0.1 myapp.test
127.0.0.1 api.myapp.test
```

### Access

- Frontend: https://myapp.test
- API: https://api.myapp.test
```

### 5. Keep Certificates Updated

**Recommendation:** Regenerate certificates when adding new domains.

```bash
# Add to .env
CUSTOM_DOMAINS=*.test,*.myapp.local

# Regenerate
./setup.sh

# Verify
openssl x509 -in certs/local-cert.pem -text -noout | grep DNS
```

### 6. Use Consistent Naming

**Recommendation:** Establish a naming convention for your team.

**Good patterns:**
- `<service>.<project>.test` (e.g., `api.myapp.test`, `admin.myapp.test`)
- `<project>-<service>.test` (e.g., `myapp-api.test`, `myapp-admin.test`)
- `<environment>.<project>.test` (e.g., `dev.myapp.test`, `staging.myapp.test`)

### 7. Avoid Real TLDs

**Recommendation:** Never use real TLDs for local development.

**Problems with real TLDs:**
- DNS queries may leak to the internet
- May conflict with real domains
- Can cause confusion
- Security and privacy concerns

**Bad examples:**
```dotenv
# Don't use these
CUSTOM_DOMAINS=*.com
CUSTOM_DOMAINS=*.net
CUSTOM_DOMAINS=*.org
CUSTOM_DOMAINS=mycompany.com  # Even if you own it
```

### 8. Platform-Specific Considerations

**Linux:**
- Prefer dnsmasq with NetworkManager integration
- Use systemd-resolved if your distribution uses it
- Keep dnsmasq configurations in `/etc/dnsmasq.d/`

**macOS:**
- Use `/etc/resolver/` for per-domain DNS configuration
- Flush DNS cache after changes
- Avoid `.local` due to Bonjour conflicts

**Windows/WSL2:**
- Update hosts file in both WSL2 and Windows
- Use Docker Desktop WSL2 integration
- Test in both WSL2 terminal and Windows browser

## Common Patterns

### Pattern 1: Single Project, Multiple Services

**Scenario:** One application with microservices.

**Configuration:**
```dotenv
CUSTOM_DOMAINS=*.myapp.test
```

**Services:**
```yaml
# docker-compose.yml
services:
  frontend:
    labels:
      - "traefik.http.routers.frontend.rule=Host(`myapp.test`)"
  
  api:
    labels:
      - "traefik.http.routers.api.rule=Host(`api.myapp.test`)"
  
  admin:
    labels:
      - "traefik.http.routers.admin.rule=Host(`admin.myapp.test`)"
```

**Access:**
- https://myapp.test
- https://api.myapp.test
- https://admin.myapp.test

### Pattern 2: Multiple Projects, Different TLDs

**Scenario:** Multiple independent projects.

**Configuration:**
```dotenv
CUSTOM_DOMAINS=*.projecta.test,*.projectb.test,*.projectc.test
```

**Projects:**
- Project A: `projecta.test`, `api.projecta.test`
- Project B: `projectb.test`, `api.projectb.test`
- Project C: `projectc.test`, `api.projectc.test`

### Pattern 3: Environment Simulation

**Scenario:** Simulate different environments locally.

**Configuration:**
```dotenv
CUSTOM_DOMAINS=*.dev.local,*.staging.local,*.prod.local
```

**Usage:**
```yaml
# Development environment
services:
  app:
    labels:
      - "traefik.http.routers.app-dev.rule=Host(`app.dev.local`)"

# Staging environment (different compose file)
services:
  app:
    labels:
      - "traefik.http.routers.app-staging.rule=Host(`app.staging.local`)"
```

### Pattern 4: Team Standardization

**Scenario:** Entire team uses consistent domain pattern.

**Configuration:**
```dotenv
# company-wide standard
CUSTOM_DOMAINS=*.company.test
```

**Team guidelines:**
- Frontend: `<project>.company.test`
- API: `<project>-api.company.test`
- Admin: `<project>-admin.company.test`
- Database tools: `<project>-db.company.test`

**Example:**
- `shop.company.test`
- `shop-api.company.test`
- `shop-admin.company.test`
- `blog.company.test`
- `blog-api.company.test`

---

## Additional Resources

- [RFC 6761 - Special-Use Domain Names](https://tools.ietf.org/html/rfc6761)
- [mkcert Documentation](https://github.com/FiloSottile/mkcert)
- [dnsmasq Documentation](http://www.thekelleys.org.uk/dnsmasq/doc.html)
- [Traefik Routing Documentation](https://doc.traefik.io/traefik/routing/routers/)
- [Integration Guide](INTEGRATION_GUIDE.md) - Using custom domains in frameworks

---

**Have questions or suggestions?** Open an issue in the GitHub repository or check the [Integration Guide](INTEGRATION_GUIDE.md) for framework-specific examples.
