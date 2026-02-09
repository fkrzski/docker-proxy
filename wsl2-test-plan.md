# WSL2 Testing Plan - Setup.sh Cross-Platform Support

## Test Environment
- **Platform**: Windows Subsystem for Linux 2 (WSL2)
- **Required**: Windows 10/11 with WSL2 enabled
- **Required**: Docker Desktop for Windows with WSL2 integration
- **Distribution**: Ubuntu, Debian, or other supported Linux distros

## Pre-Test Requirements

### 1. Verify WSL2 Environment
```bash
# Check if running in WSL2
cat /proc/version
# Expected: Should contain "microsoft" or "WSL" string

# Check WSL version (run in PowerShell/CMD on Windows)
wsl --list --verbose
# Expected: VERSION should be 2 for your distribution
```

### 2. Clean Environment Setup
Before testing, ensure a clean state:
```bash
# Remove any existing mkcert installation
which mkcert && sudo rm -f $(which mkcert)

# Remove any existing certificates
rm -rf ./certs/local-*.pem

# Remove mkcert CA (if testing from scratch)
rm -rf "$(mkcert -CAROOT)" 2>/dev/null || true

# Remove Docker network
docker network rm traefik-proxy 2>/dev/null || true

# Remove .env file
rm -f .env

# Stop any running containers
docker compose down
```

### 3. Verify Docker Desktop Integration
```bash
# Check Docker is available in WSL2
which docker

# Check Docker daemon is accessible
docker info
# Expected: Should show Docker Desktop info

# Verify Docker Desktop WSL2 integration is enabled
# In Windows: Docker Desktop → Settings → Resources → WSL Integration
# Ensure your WSL2 distribution is enabled
```

## Test Case 1: WSL2 Detection (Primary Test)

### Prerequisites
- WSL2 environment with Ubuntu/Debian
- Docker Desktop for Windows running with WSL2 integration enabled

### Test Steps

1. **Run setup script:**
   ```bash
   ./setup.sh
   ```

2. **Expected Output - OS Detection:**
   ```
   [INFO] Starting Local Docker Proxy setup...
   [INFO] Detected OS: wsl2, Architecture: amd64
   ```

3. **Expected Output - Package Manager:**
   ```
   [INFO] Detected package manager: apt
   ```

4. **Expected Output - mkcert Installation:**
   ```
   [INFO] Installing dependencies (libnss3-tools, curl) via apt...
   [INFO] Installing mkcert via direct download...
   [INFO] Downloading mkcert from: https://dl.filippo.io/mkcert/latest?for=linux/amd64
   [OK] mkcert installed via direct download.
   [INFO] Initializing local CA...
   ```

5. **Verify mkcert installation:**
   ```bash
   # Check mkcert is installed
   which mkcert
   # Expected: /usr/local/bin/mkcert

   # Check version
   mkcert -version
   # Expected: v1.x.x

   # Verify Linux binary was used
   file $(which mkcert)
   # Expected: Should show "ELF 64-bit LSB executable" (Linux binary)
   ```

6. **Verify Linux binary used (not Windows):**
   ```bash
   # The downloaded binary should be linux/amd64, not windows
   ldd $(which mkcert) 2>&1 | head -n1
   # Expected: Should show Linux library info, not "not a dynamic executable"
   ```

7. **Verify CA installation:**
   ```bash
   # Check mkcert root CA location
   mkcert -CAROOT
   # Expected: /home/<username>/.local/share/mkcert

   # Verify CA files exist
   ls -la $(mkcert -CAROOT)
   # Expected: rootCA.pem and rootCA-key.pem exist
   ```

8. **Verify certificate generation:**
   ```bash
   ls -la ./certs/
   # Expected files:
   # - local-cert.pem (readable, 644 permissions)
   # - local-key.pem (readable, 644 permissions)

   # Check certificate details
   openssl x509 -in ./certs/local-cert.pem -text -noout | grep -A 2 "Subject Alternative Name"
   # Expected: DNS:localhost, DNS:*.docker.localhost, IP:127.0.0.1, IP:::1
   ```

9. **Verify Docker network:**
   ```bash
   docker network inspect traefik-proxy
   # Expected: Network exists with bridge driver
   ```

10. **Verify Traefik container:**
    ```bash
    docker ps | grep traefik
    # Expected: Container running, ports 80:80 and 443:443

    docker logs traefik | head -n 20
    # Expected: No errors, should show startup logs
    ```

11. **Expected Output - WSL2 Certificate Instructions:**
    After setup completes, you should see:
    ```
    [OK] Setup complete.
    Dashboard available at: https://traefik.docker.localhost

    [WARN] WSL2 ADDITIONAL STEP REQUIRED:
    [WARN] To trust certificates in Windows browsers (Edge, Chrome, Firefox on Windows),
    [WARN] you need to install the mkcert root CA certificate in Windows:

    [INFO] 1. Find the mkcert root CA certificate location:
    [INFO]    Run: mkcert -CAROOT

    [INFO] 2. Copy the rootCA.pem file to Windows:
    [INFO]    Example: cp $(mkcert -CAROOT)/rootCA.pem /mnt/c/Users/YourUsername/Downloads/

    [INFO] 3. In Windows, double-click the rootCA.pem file
    [INFO]    - Click 'Install Certificate'
    [INFO]    - Select 'Local Machine' and click Next
    [INFO]    - Select 'Place all certificates in the following store'
    [INFO]    - Click 'Browse' and select 'Trusted Root Certification Authorities'
    [INFO]    - Click Next, then Finish

    [INFO] 4. Restart your Windows browsers for changes to take effect

    [WARN] Note: Certificates in WSL2 Linux are automatically trusted,
    [WARN] but Windows browsers need the separate installation step above.
    ```

12. **Verify Traefik Dashboard Access from WSL2:**
    ```bash
    # Test HTTP (should redirect to HTTPS)
    curl -I http://traefik.docker.localhost
    # Expected: 301 or 302 redirect to https://

    # Test HTTPS (may show certificate error if CA not trusted in curl)
    curl -I https://traefik.docker.localhost 2>&1
    # Expected: Should connect, may show certificate warning if CA not in system store
    ```

## Test Case 2: Windows Browser Certificate Trust (Critical for WSL2)

### Prerequisites
- Test Case 1 completed successfully
- Access to Windows browser (Edge, Chrome, or Firefox)

### Test Steps

1. **Copy CA certificate to Windows:**
   ```bash
   # Find CA root location
   CAROOT=$(mkcert -CAROOT)
   echo "CA Root: $CAROOT"

   # Copy to Windows Downloads folder (adjust username)
   cp "$CAROOT/rootCA.pem" /mnt/c/Users/$USER/Downloads/
   ```

2. **Install certificate in Windows:**
   - Open File Explorer in Windows
   - Navigate to Downloads folder
   - Double-click `rootCA.pem`
   - Click "Install Certificate"
   - Select "Local Machine" → Next (requires admin)
   - Select "Place all certificates in the following store"
   - Click "Browse" → Select "Trusted Root Certification Authorities"
   - Click Next → Finish
   - You should see "The import was successful"

3. **Restart Windows browsers:**
   - Close all browser windows
   - Restart browser

4. **Test in Windows browsers:**
   - Open Edge: `https://traefik.docker.localhost`
   - Open Chrome: `https://traefik.docker.localhost`
   - Open Firefox: `https://traefik.docker.localhost`

   **Expected for all browsers:**
   - ✅ No certificate warnings
   - ✅ Green padlock/secure icon
   - ✅ Traefik dashboard loads
   - ✅ No console errors (F12 developer tools)

## Test Case 3: Linux Tools in WSL2 (curl, wget)

### Test Steps

1. **Test with curl (Linux tool in WSL2):**
   ```bash
   # curl should trust the mkcert CA
   curl -v https://traefik.docker.localhost 2>&1 | grep -i certificate
   # Expected: "SSL certificate verify ok" if CA is trusted in NSS tools
   ```

2. **Test with wget:**
   ```bash
   wget --spider https://traefik.docker.localhost 2>&1 | grep -i certificate
   # Expected: Should succeed or show certificate info
   ```

## Test Case 4: Docker Network Accessibility from WSL2

### Test Steps

1. **Verify containers on traefik-proxy network can communicate:**
   ```bash
   # Check network details
   docker network inspect traefik-proxy | grep -A 5 "Containers"
   # Expected: Should show traefik container

   # Test container can reach Traefik
   docker run --rm --network traefik-proxy alpine wget -O- http://traefik 2>/dev/null | head
   # Expected: Should get response from Traefik
   ```

## Test Case 5: Error Handling - Docker Desktop Not Running

### Test Steps

1. **Stop Docker Desktop in Windows:**
   - Right-click Docker Desktop icon in system tray
   - Select "Quit Docker Desktop"

2. **Run setup script:**
   ```bash
   ./setup.sh
   ```

3. **Expected Output:**
   ```
   [ERROR] Docker daemon is not running.
   [ERROR] Please start the Docker service.
   ```

4. **Expected Behavior:**
   - Script exits with non-zero status
   - No containers or networks created

5. **Restart Docker Desktop and verify recovery:**
   - Start Docker Desktop in Windows
   - Wait for Docker to be ready
   - Run `./setup.sh` again
   - Expected: Should complete successfully

## Test Case 6: Idempotency Test

### Test Steps

1. **Run setup script first time:**
   ```bash
   ./setup.sh
   ```

2. **Run setup script again (should be idempotent):**
   ```bash
   ./setup.sh
   ```

3. **Expected Output:**
   ```
   [INFO] Detected OS: wsl2, Architecture: amd64
   [INFO] NSS tools dependency is already installed.
   [INFO] mkcert is already installed.
   [INFO] Docker is available and running.
   [INFO] Docker network 'traefik-proxy' already exists.
   [INFO] Certificates already exist. Skipping generation.
   [INFO] .env configuration file already exists.
   [OK] Setup complete.
   ```

4. **Verify:**
   - No errors
   - No duplicate resources created
   - Traefik still accessible
   - No WSL2 instructions shown second time? (Check if this is desired behavior)

## Test Case 7: Multiple WSL2 Distributions

### Test Steps (if you have multiple WSL2 distros)

1. **Test in Ubuntu WSL2:**
   ```bash
   # In Ubuntu WSL2
   ./setup.sh
   # Verify: Detects wsl2, uses apt
   ```

2. **Test in Debian WSL2:**
   ```bash
   # In Debian WSL2
   ./setup.sh
   # Verify: Detects wsl2, uses apt
   ```

3. **Test in other distributions (if available):**
   - Should work with any WSL2 Linux distribution
   - Package manager detection should work appropriately

## Test Case 8: Architecture Detection (if ARM64 WSL2 available)

### Test Steps

1. **On ARM64 Windows with WSL2:**
   ```bash
   uname -m
   # Expected: aarch64

   ./setup.sh
   # Expected: "Detected OS: wsl2, Architecture: arm64"
   # mkcert URL should be: https://dl.filippo.io/mkcert/latest?for=linux/arm64
   ```

## Success Criteria

All test cases must pass:

- ✅ **Test Case 1**: WSL2 correctly detected
  - OS_TYPE set to "wsl2"
  - Linux binary used for mkcert (linux/amd64)
  - mkcert installs successfully
  - CA initialized in WSL2 Linux
  - Certificates generated
  - Traefik starts
  - Dashboard accessible from WSL2
  - **WSL2 Windows certificate instructions displayed**

- ✅ **Test Case 2**: Windows browser certificate trust
  - Instructions clear and accurate
  - CA certificate can be copied to Windows
  - Installation in Windows works
  - Browsers trust the certificates

- ✅ **Test Case 3**: Linux tools trust certificates
  - curl/wget work with mkcert CA
  - No certificate errors in WSL2 Linux

- ✅ **Test Case 4**: Docker networking works
  - Containers can communicate
  - Network properly configured

- ✅ **Test Case 5**: Appropriate error when Docker not running
  - Clear error message
  - Script exits gracefully

- ✅ **Test Case 6**: Script is idempotent
  - Can run multiple times safely
  - No duplicate resources

- ✅ **Test Case 7**: Works across different WSL2 distributions
  - Ubuntu, Debian, etc.

- ✅ **Test Case 8**: Works on different architectures
  - amd64 (Intel/AMD)
  - arm64 (ARM) if available

## Known Issues / Expected Behavior

1. **Linux Binary for mkcert**: WSL2 should use the Linux binary (`linux/amd64`), NOT the Windows binary. This is correct behavior.

2. **Dual Certificate Trust**: The mkcert CA needs to be trusted in BOTH:
   - WSL2 Linux (for Linux tools like curl)
   - Windows (for Windows browsers)

   This is why the additional Windows installation step is required.

3. **Certificate Location**: Certificates are stored in the WSL2 filesystem (e.g., `/home/user/.local/share/mkcert`), NOT in Windows filesystem. This is correct.

4. **Docker Desktop Dependency**: WSL2 setup requires Docker Desktop for Windows with WSL2 integration enabled. Native Docker in WSL2 is not supported by this setup script.

5. **Network Accessibility**: The `traefik-proxy` network is accessible from both WSL2 and other containers, but Traefik dashboard at `https://traefik.docker.localhost` is accessible from Windows browsers thanks to Docker Desktop port forwarding.

## Reporting Results

After testing, document:

1. **Windows Version**: Run in PowerShell: `winver`
2. **WSL2 Distribution**: `lsb_release -a` or `cat /etc/os-release`
3. **WSL2 Version**: Run in PowerShell: `wsl --version`
4. **Docker Desktop Version**: Check "About Docker Desktop" in Windows
5. **Architecture**: `uname -m`
6. **Test Results**: Pass/Fail for each test case
7. **Screenshots**:
   - Traefik dashboard in Windows browser (showing secure connection)
   - Windows certificate store showing mkcert CA
   - WSL2 terminal showing setup.sh output with Windows instructions
8. **Logs**: Any errors or unexpected output from setup.sh

## Automated Testing Script

See `./test-wsl2-setup.sh` for an automated test runner that executes most of these checks.

## Integration Testing

After setup completes, test with a real application:

```bash
# Create a test app with Traefik labels
cat > test-compose.yml << 'EOF'
services:
  whoami:
    image: traefik/whoami
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.whoami.rule=Host(`whoami.docker.localhost`)"
      - "traefik.http.routers.whoami.tls=true"

networks:
  traefik-proxy:
    external: true
EOF

# Start test app
docker compose -f test-compose.yml up -d

# Test from WSL2
curl https://whoami.docker.localhost

# Test from Windows browser
# Open: https://whoami.docker.localhost
# Expected: See "whoami" output with secure connection

# Cleanup
docker compose -f test-compose.yml down
rm test-compose.yml
```
