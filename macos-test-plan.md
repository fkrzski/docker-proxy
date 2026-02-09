# macOS Testing Plan - Setup.sh Cross-Platform Support

## Test Environment
- **Platform**: macOS (Darwin)
- **Required**: Docker Desktop for Mac
- **Optional**: Homebrew package manager

## Pre-Test Requirements

### 1. Clean Environment Setup
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
```

### 2. Verify Docker Desktop
```bash
# Check Docker Desktop is installed
which docker

# Check Docker Desktop is running
docker info
```

## Test Case 1: macOS with Homebrew (Preferred Path)

### Prerequisites
- macOS system
- Homebrew installed (`/opt/homebrew/bin/brew` or `/usr/local/bin/brew`)
- Docker Desktop running

### Test Steps

1. **Run setup script:**
   ```bash
   ./setup.sh
   ```

2. **Expected Output - OS Detection:**
   ```
   [INFO] Detected OS: macos, Architecture: amd64 (or arm64)
   [INFO] Running on macOS - Docker Desktop is required for this setup.
   [WARN] Please ensure Docker Desktop is installed and running before proceeding.
   ```

3. **Expected Output - Package Manager:**
   ```
   [INFO] Detected package manager: brew
   ```

4. **Expected Output - mkcert Installation:**
   ```
   [INFO] Installing mkcert via Homebrew...
   [OK] mkcert installed via Homebrew.
   [INFO] Initializing local CA...
   ```

5. **Verify mkcert installation:**
   ```bash
   # Check mkcert is installed
   which mkcert
   # Expected: /opt/homebrew/bin/mkcert or /usr/local/bin/mkcert

   # Check version
   mkcert -version
   # Expected: v1.x.x
   ```

6. **Verify CA installation in Keychain:**
   ```bash
   # Check mkcert root CA
   mkcert -CAROOT
   # Expected: /Users/<username>/Library/Application Support/mkcert

   # Verify CA is trusted (manual check)
   # Open Keychain Access app
   # Go to System > Certificates
   # Look for "mkcert <username>" certificate
   # Should show "This certificate is marked as trusted for all users"
   ```

7. **Verify certificate generation:**
   ```bash
   ls -la ./certs/
   # Expected files:
   # - local-cert.pem (readable, 644 permissions)
   # - local-key.pem (readable, 644 permissions)

   # Check certificate details
   openssl x509 -in ./certs/local-cert.pem -text -noout | grep -A 2 "Subject Alternative Name"
   # Expected: DNS:localhost, DNS:*.docker.localhost, IP:127.0.0.1, IP:::1
   ```

8. **Verify Docker network:**
   ```bash
   docker network inspect traefik-proxy
   # Expected: Network exists with bridge driver
   ```

9. **Verify Traefik container:**
   ```bash
   docker ps | grep traefik
   # Expected: Container running, ports 80:80 and 443:443

   docker logs traefik
   # Expected: No errors, should show startup logs
   ```

10. **Verify Traefik Dashboard Access:**
    ```bash
    # Test HTTP (should redirect to HTTPS)
    curl -I http://traefik.docker.localhost
    # Expected: 301 or 302 redirect to https://

    # Test HTTPS with certificate validation
    curl -v https://traefik.docker.localhost 2>&1 | grep "SSL certificate verify"
    # Expected: "SSL certificate verify ok" (if CA trusted)
    ```

11. **Browser Verification:**
    - Open Safari: `https://traefik.docker.localhost`
    - Open Chrome: `https://traefik.docker.localhost`
    - Open Firefox: `https://traefik.docker.localhost`

    **Expected for all browsers:**
    - ✅ No certificate warnings
    - ✅ Green padlock/secure icon
    - ✅ Traefik dashboard loads
    - ✅ No console errors

## Test Case 2: macOS without Homebrew (Fallback Path)

### Prerequisites
- macOS system
- Homebrew NOT installed
- Docker Desktop running

### Test Steps

1. **Temporarily hide Homebrew (if installed):**
   ```bash
   alias brew='echo "brew: command not found" && false'
   ```

2. **Run setup script:**
   ```bash
   ./setup.sh
   ```

3. **Expected Output - Package Manager:**
   ```
   [INFO] Detected package manager: unknown
   [WARN] Could not detect a supported package manager...
   [WARN] Continuing with setup - some steps may fail if dependencies are missing.
   ```

4. **Expected Output - mkcert Installation:**
   ```
   [INFO] Installing mkcert via direct download...
   [INFO] Downloading mkcert from: https://dl.filippo.io/mkcert/latest?for=darwin/amd64
   [OK] mkcert installed via direct download.
   ```

5. **Verify mkcert installation:**
   ```bash
   which mkcert
   # Expected: /usr/local/bin/mkcert

   mkcert -version
   # Expected: v1.x.x
   ```

6. **Complete remaining verifications from Test Case 1 (steps 6-11)**

## Test Case 3: Error Handling - Docker Desktop Not Running

### Test Steps

1. **Stop Docker Desktop:**
   - Quit Docker Desktop application

2. **Run setup script:**
   ```bash
   ./setup.sh
   ```

3. **Expected Output:**
   ```
   [ERROR] Docker daemon is not running.
   [ERROR] Please start Docker Desktop application and wait for it to be ready.
   [WARN] You can start Docker Desktop from Applications or the menu bar.
   ```

4. **Expected Behavior:**
   - Script exits with non-zero status
   - No containers or networks created

## Test Case 4: Error Handling - Docker Desktop Not Installed

### Test Steps

1. **Temporarily hide Docker (testing only):**
   ```bash
   alias docker='echo "docker: command not found" && false'
   ```

2. **Run setup script:**
   ```bash
   ./setup.sh
   ```

3. **Expected Output:**
   ```
   [ERROR] Docker is not installed or not in PATH.
   [ERROR] Please install Docker Desktop for Mac:
   [ERROR]   https://www.docker.com/products/docker-desktop
   ```

4. **Expected Behavior:**
   - Script exits with non-zero status

## Test Case 5: Idempotency Test

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
   [INFO] NSS tools dependency is already installed.
   [INFO] mkcert is already installed.
   [INFO] Docker network 'traefik-proxy' already exists.
   [INFO] Certificates already exist. Skipping generation.
   [INFO] .env configuration file already exists.
   ```

4. **Verify:**
   - No errors
   - No duplicate resources created
   - Traefik still accessible

## Test Case 6: Architecture-Specific Tests

### Intel Mac (amd64)
```bash
uname -m
# Expected: x86_64

./setup.sh
# Expected: "Detected OS: macos, Architecture: amd64"
# mkcert URL should be: https://dl.filippo.io/mkcert/latest?for=darwin/amd64
```

### Apple Silicon Mac (arm64)
```bash
uname -m
# Expected: arm64

./setup.sh
# Expected: "Detected OS: macos, Architecture: arm64"
# mkcert URL should be: https://dl.filippo.io/mkcert/latest?for=darwin/arm64
```

## Success Criteria

All test cases must pass:

- ✅ **Test Case 1**: Homebrew path works correctly
  - mkcert installed via brew
  - CA trusted in System Keychain
  - Certificates generated
  - Traefik starts
  - Dashboard accessible in all browsers without warnings

- ✅ **Test Case 2**: Fallback path works without Homebrew
  - mkcert installed via direct download
  - All other steps work as expected

- ✅ **Test Case 3**: Appropriate error when Docker not running
  - Clear error message
  - macOS-specific instructions shown

- ✅ **Test Case 4**: Appropriate error when Docker not installed
  - Clear error message
  - macOS-specific installation link shown

- ✅ **Test Case 5**: Script is idempotent
  - Can run multiple times safely
  - No duplicate resources

- ✅ **Test Case 6**: Works on both Intel and Apple Silicon
  - Correct architecture detected
  - Appropriate binary downloaded

## Known Issues / Expected Behavior

1. **NSS Tools Warning**: On macOS without Homebrew, you may see warnings about NSS tools package manager not found. This is expected as macOS handles certificate trust differently through Keychain.

2. **Certificate Trust**: macOS uses Keychain for certificate trust. The `mkcert -install` command automatically adds the CA to the system keychain.

3. **Firefox**: Firefox uses its own certificate store. The `mkcert -install` command should handle Firefox automatically, but if issues occur, verify Firefox certificate store separately.

## Reporting Results

After testing, document:

1. **macOS Version**: `sw_vers`
2. **Architecture**: `uname -m`
3. **Docker Desktop Version**: Check "About Docker Desktop"
4. **Homebrew Installed**: `brew --version` or "Not installed"
5. **Test Results**: Pass/Fail for each test case
6. **Screenshots**: Traefik dashboard in browser (showing secure connection)
7. **Logs**: Any errors or unexpected output from setup.sh

## Automated Testing Script

See `./test-macos-setup.sh` for an automated test runner that executes most of these checks.
