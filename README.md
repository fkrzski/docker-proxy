# Local Docker Proxy with Traefik & HTTPS

A fully configurable, local reverse proxy for Docker development. This project eliminates port conflicts (e.g., "Port 8080 is already in use") and provides trusted SSL certificates for local domains.

It runs a single Traefik container handling routing for all local projects via custom domains (e.g., `https://my-app.docker.localhost`). Additionally, it includes optional, pre-configured services like Redis, MySQL, and phpMyAdmin.

## Prerequisites

- **OS:** Linux, macOS, or Windows WSL2
  - Linux: Tested on Debian/Ubuntu derivatives (also supports Fedora, Arch, Alpine)
  - macOS: Requires Docker Desktop for Mac
  - Windows: Requires WSL2 with Docker Desktop integration
- **Architecture:** Both x86_64 (amd64) and ARM64 (aarch64) platforms
  - **Apple Silicon Macs:** Full support for M1, M2, and M3 chips
  - **ARM-based Linux:** Compatible with Raspberry Pi, AWS Graviton, and other ARM64 systems
  - **Auto-detection:** The `setup.sh` script automatically detects your system architecture and pulls the correct multi-arch container images
- **Software:**
  - Docker Engine & Docker Compose
  - `curl`
  - Package manager: apt, dnf, yum, pacman, brew, or apk
  - (NSS tools and mkcert will be installed automatically by setup.sh)

## Supported Platforms

This project has been tested and verified on the following platform combinations:

| Platform | Architecture | Status | Notes |
|----------|-------------|--------|-------|
| **Linux (Debian/Ubuntu)** | AMD64 (x86_64) | ✅ Fully Tested | Primary development platform |
| **Linux (Debian/Ubuntu)** | ARM64 (aarch64) | ✅ Fully Tested | Includes Raspberry Pi, AWS Graviton |
| **Linux (Fedora/RHEL)** | AMD64 (x86_64) | ✅ Supported | Uses `dnf`/`yum` package manager |
| **Linux (Fedora/RHEL)** | ARM64 (aarch64) | ✅ Supported | Multi-arch container images |
| **Linux (Arch)** | AMD64 (x86_64) | ✅ Supported | Uses `pacman` package manager |
| **Linux (Arch)** | ARM64 (aarch64) | ✅ Supported | Multi-arch container images |
| **Linux (Alpine)** | AMD64 (x86_64) | ✅ Supported | Uses `apk` package manager |
| **Linux (Alpine)** | ARM64 (aarch64) | ✅ Supported | Multi-arch container images |
| **macOS (Intel)** | AMD64 (x86_64) | ✅ Fully Tested | Requires Docker Desktop for Mac |
| **macOS (Apple Silicon)** | ARM64 (M1/M2/M3) | ✅ Fully Tested | Native ARM64 support |
| **Windows (WSL2)** | AMD64 (x86_64) | ✅ Fully Tested | Requires Docker Desktop with WSL2 |
| **Windows (WSL2)** | ARM64 (aarch64) | ✅ Supported | ARM64 Windows devices |

**Key Features:**
- 🔄 **Automatic Architecture Detection**: The `setup.sh` script detects your system architecture and pulls the correct multi-arch container images
- 🐳 **Multi-Arch Images**: All containers (Traefik, Redis, MySQL, phpMyAdmin) support both AMD64 and ARM64
- 🍎 **Apple Silicon Optimized**: Native performance on M1, M2, and M3 Macs without Rosetta emulation
- 🌐 **Cross-Platform**: Single codebase works across all supported platforms

## Installation

### Automated Setup (Recommended)

The provided script installs necessary dependencies (`mkcert`), generates a local Certificate Authority, creates the Docker network, and starts the proxy.

```bash
chmod +x setup.sh
./setup.sh
```

### Manual Installation

If you prefer to configure the environment manually or are using a non-Debian distribution:

1.  **Install `mkcert`**
    Follow the official instructions for your OS: [mkcert documentation](https://github.com/FiloSottile/mkcert).
    Ensure you run `mkcert -install` to generate the local Root CA.

2.  **Create Docker Network**
    ```bash
    docker network create traefik-proxy
    ```

3.  **Generate SSL Certificates**
    ```bash
    mkcert -key-file certs/local-key.pem \
      -cert-file certs/local-cert.pem \
      "localhost" "*.docker.localhost" "127.0.0.1" "::1"
    
    chmod 644 certs/local-cert.pem certs/local-key.pem
    ```

4.  **Start Proxy**
    ```bash
    docker compose up -d
    ```

Access the Traefik dashboard at [https://traefik.docker.localhost](https://traefik.docker.localhost).

## Configuration

The project is configured via a `.env` file, which is automatically created from `.env.example` during setup.

### Enabling/Disabling Services

You can control which services start by editing the `COMPOSE_PROFILES` variable in your `.env` file.

```dotenv
# Enable all services (default)
COMPOSE_PROFILES=redis,mysql,pma

# Enable only Redis
COMPOSE_PROFILES=redis

# Enable only Traefik (leave empty or remove other profiles)
COMPOSE_PROFILES=
```

**Available Profiles:**
- `redis`: Starts a Redis container.
- `mysql`: Starts a MySQL 8.0 container.
- `pma`: Starts phpMyAdmin (available at [https://pma.docker.localhost](https://pma.docker.localhost)).

### Database Configuration

- **Root Password:** Controlled by `MYSQL_ROOT_PASSWORD` in `.env`. Default is `root`.

## Usage in Projects

📖 **For comprehensive integration guides, framework-specific examples, and troubleshooting, see the [Integration Guide](docs/INTEGRATION_GUIDE.md).**

### Quick Start Example

To expose a container via this proxy, configure your project's `compose.yml` as follows:

1.  **Network:** Connect to the external `traefik-proxy` network.
2.  **Labels:** Add Traefik labels to define the router and domain.
3.  **Ports:** Do not map ports to the host (remove `ports` section unless specifically needed for other tools).

**Example Configuration:**

```yaml
services:
  web:
    image: nginx:alpine
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      # Router configuration
      - "traefik.http.routers.my-app.rule=Host(`project.docker.localhost`)"
      - "traefik.http.routers.my-app.tls=true"
      # Internal service port (if different from 80)
      # - "traefik.http.services.my-app.loadbalancer.server.port=3000"

networks:
  traefik-proxy:
    external: true
```

## Logging

📖 **For detailed logging configuration, viewing logs, and troubleshooting, see the [Logging Documentation](docs/LOGGING.md).**

### Overview

The proxy implements automatic log rotation for all containers to prevent disk space issues:

- **Container Logs**: All services use Docker's `json-file` logging driver with rotation (10 MB per file, 3 files max)
- **Traefik Access Logs**: Optional HTTP request tracing for debugging (disabled by default)

### Quick Commands

```bash
# View Traefik logs
docker logs traefik

# Follow logs in real-time
docker logs traefik --follow

# View logs from all services
docker compose logs --follow

# Enable access logs (edit .env)
TRAEFIK_ACCESS_LOG_ENABLED=true
```

**Key Features:**
- ✅ Automatic rotation prevents disk exhaustion (~30 MB per container)
- ✅ Structured JSON format for easy parsing
- ✅ Built-in Docker tooling for log access
- ✅ Optional detailed request tracing for debugging

## Testing

The project includes a comprehensive test suite for the `setup.sh` script to ensure reliability across different platforms and configurations.

### Test Framework

Tests are written using **[bats-core](https://github.com/bats-core/bats-core)**, a Bash Automated Testing System that provides:
- TAP (Test Anything Protocol) compliant output
- Isolated test execution with setup/teardown hooks
- Cross-platform compatibility (Linux, macOS, WSL2)
- Simple, readable test syntax

### Installing bats-core

**macOS (Homebrew):**
```bash
brew install bats-core
```

**Ubuntu/Debian:**
```bash
sudo apt install bats-core
```

**Fedora/RHEL:**
```bash
sudo dnf install bats
```

**Arch Linux:**
```bash
sudo pacman -S bats
```

**Manual Installation (All Platforms):**
```bash
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

### Running Tests

**Run all tests:**
```bash
bats tests/
```

**Run specific test file:**
```bash
bats tests/setup.bats
bats tests/os-detection.bats
bats tests/package-manager.bats
bats tests/mkcert.bats
```

**Run with verbose output:**
```bash
bats --verbose-run tests/
```

**Run with TAP output:**
```bash
bats --tap tests/
```

### Test Coverage

The test suite covers:

- **OS Detection** (`tests/os-detection.bats`)
  - Linux, macOS, and WSL2 detection
  - Architecture detection (AMD64, ARM64, ARMv7)
  - Edge cases and error handling

- **Package Manager Detection** (`tests/package-manager.bats`)
  - apt, dnf, yum, pacman, brew, apk
  - Package name resolution
  - Command configuration

- **mkcert Integration** (`tests/mkcert.bats`)
  - URL generation for different platforms
  - Binary download and installation
  - Certificate generation

- **End-to-End Workflows** (`tests/setup.bats`)
  - Complete setup flow validation
  - Multi-step integration tests
  - Platform-specific validation

### Continuous Integration

Tests run automatically on every push and pull request via **GitHub Actions**. The CI pipeline:
- Tests on multiple platforms (Linux, macOS)
- Tests on multiple architectures (AMD64, ARM64)
- Ensures backward compatibility
- Validates PRs before merge

You can view test results in the [Actions tab](../../actions) of the repository.

### Contributing Tests

When contributing to the setup script:
1. **Add tests** for new functionality
2. **Run tests locally** before submitting PR
3. **Ensure CI passes** on all platforms
4. **Follow existing test patterns** for consistency

Example test structure:
```bash
@test "Description of what is being tested" {
    run bash -c '
        # Setup test environment
        # Execute function being tested
        # Validate results
    '
    [ "$status" -eq 0 ]
}
```

## Uninstallation

To remove the proxy and clean up system changes:

1.  Stop the container: `docker compose down`
2.  Remove the network: `docker network rm traefik-proxy`
3.  Uninstall local CA (optional): `mkcert -uninstall`
4.  Remove this directory.
