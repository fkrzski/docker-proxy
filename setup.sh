#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect operating system and architecture
detect_os() {
    # Detect architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        *) ARCH="$ARCH" ;;
    esac

    # Detect OS type
    if [[ "$(uname -s)" == "Darwin" ]]; then
        OS_TYPE="macos"
    elif [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
        OS_TYPE="wsl2"
    elif [[ "$(uname -s)" == "Linux" ]]; then
        OS_TYPE="linux"
    else
        OS_TYPE="unknown"
    fi
}

# Get mkcert download URL based on OS and architecture
get_mkcert_download_url() {
    local url_arch="$ARCH"

    # Map OS_TYPE to mkcert URL format
    case "$OS_TYPE" in
        macos)
            MKCERT_OS="darwin"
            ;;
        wsl2|linux)
            MKCERT_OS="linux"
            ;;
        *)
            log_error "Unsupported OS type: $OS_TYPE"
            return 1
            ;;
    esac

    # Map architecture to mkcert URL format
    case "$url_arch" in
        armv7)
            url_arch="arm"
            ;;
    esac

    MKCERT_ARCH="$url_arch"
    MKCERT_URL="https://dl.filippo.io/mkcert/latest?for=${MKCERT_OS}/${MKCERT_ARCH}"
}

log_info "Starting Local Docker Proxy setup..."

# Detect OS and architecture
detect_os
log_info "Detected OS: $OS_TYPE, Architecture: $ARCH"

# Display macOS-specific notes
if [ "$OS_TYPE" = "macos" ]; then
    log_info "Running on macOS - Docker Desktop is required for this setup."
    log_warn "Please ensure Docker Desktop is installed and running before proceeding."
    log_warn "Download from: https://www.docker.com/products/docker-desktop"
fi

# Detect package manager and set appropriate commands
detect_package_manager() {
    if command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
        NSS_PACKAGE="libnss3-tools"
        INSTALL_CMD="sudo apt update && sudo apt install -y"
        CHECK_CMD="dpkg -s"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        NSS_PACKAGE="nss-tools"
        INSTALL_CMD="sudo dnf install -y"
        CHECK_CMD="rpm -q"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        NSS_PACKAGE="nss-tools"
        INSTALL_CMD="sudo yum install -y"
        CHECK_CMD="rpm -q"
    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
        NSS_PACKAGE="nss"
        INSTALL_CMD="sudo pacman -S --noconfirm"
        CHECK_CMD="pacman -Q"
    elif command -v brew &> /dev/null; then
        PKG_MANAGER="brew"
        NSS_PACKAGE="nss"
        INSTALL_CMD="brew install"
        CHECK_CMD="brew list"
    elif command -v apk &> /dev/null; then
        PKG_MANAGER="apk"
        NSS_PACKAGE="nss-tools"
        INSTALL_CMD="sudo apk add"
        CHECK_CMD="apk info -e"
    else
        PKG_MANAGER="unknown"
        NSS_PACKAGE=""
        INSTALL_CMD=""
        CHECK_CMD=""
    fi
}

# Check if NSS tools are installed
check_nss_installed() {
    case "$PKG_MANAGER" in
        apt) dpkg -s libnss3-tools >/dev/null 2>&1 ;;
        dnf|yum) rpm -q nss-tools >/dev/null 2>&1 ;;
        pacman) pacman -Q nss >/dev/null 2>&1 ;;
        brew) brew list nss >/dev/null 2>&1 ;;
        apk) apk info -e nss-tools >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

# Install NSS tools using detected package manager
install_nss_tools() {
    case "$PKG_MANAGER" in
        apt)
            log_info "Installing dependencies (libnss3-tools, curl) via apt..."
            sudo apt update && sudo apt install -y libnss3-tools curl
            ;;
        dnf)
            log_info "Installing dependencies (nss-tools, curl) via dnf..."
            sudo dnf install -y nss-tools curl
            ;;
        yum)
            log_info "Installing dependencies (nss-tools, curl) via yum..."
            sudo yum install -y nss-tools curl
            ;;
        pacman)
            log_info "Installing dependencies (nss, curl) via pacman..."
            sudo pacman -S --noconfirm nss curl
            ;;
        brew)
            log_info "Installing dependencies (nss, curl) via brew..."
            brew install nss curl
            ;;
        apk)
            log_info "Installing dependencies (nss-tools, curl) via apk..."
            sudo apk add nss-tools curl
            ;;
        *)
            log_error "Unsupported package manager. Please install the following manually:"
            log_warn "  - NSS tools (libnss3-tools on Debian/Ubuntu, nss-tools on Fedora/RHEL, nss on Arch)"
            log_warn "  - curl"
            log_warn "Then re-run this script."
            exit 1
            ;;
    esac
}

# Detect package manager
detect_package_manager
log_info "Detected package manager: ${PKG_MANAGER:-unknown}"

if [ "$PKG_MANAGER" = "unknown" ]; then
    log_warn "Could not detect a supported package manager (apt, dnf, yum, pacman, brew, apk)."
    log_warn "Please ensure you have the following dependencies installed manually:"
    log_warn "  - NSS tools (libnss3-tools on Debian/Ubuntu, nss-tools on Fedora/RHEL, nss on Arch)"
    log_warn "  - curl"
    log_warn "  - mkcert (https://github.com/FiloSottile/mkcert)"
    log_warn "Continuing with setup - some steps may fail if dependencies are missing."
fi

# 1. Install NSS tools (required for mkcert)
if ! check_nss_installed; then
    install_nss_tools
else
    log_info "NSS tools dependency is already installed."
fi

# Install mkcert using appropriate method
install_mkcert() {
    # On macOS with Homebrew, prefer brew installation
    if [ "$OS_TYPE" = "macos" ] && [ "$PKG_MANAGER" = "brew" ]; then
        log_info "Installing mkcert via Homebrew..."
        if brew install mkcert; then
            log_success "mkcert installed via Homebrew."
            return 0
        else
            log_warn "Homebrew installation failed. Falling back to direct download..."
        fi
    fi

    # Fallback: Direct download method
    log_info "Installing mkcert via direct download..."

    # Get platform-specific download URL
    if ! get_mkcert_download_url; then
        log_error "Failed to determine mkcert download URL for this platform."
        return 1
    fi

    log_info "Downloading mkcert from: $MKCERT_URL"
    curl -JLO "$MKCERT_URL"
    chmod +x mkcert-v*-${MKCERT_OS}-${MKCERT_ARCH}
    sudo mv mkcert-v*-${MKCERT_OS}-${MKCERT_ARCH} /usr/local/bin/mkcert

    log_success "mkcert installed via direct download."
}

# 2. Install mkcert
if ! command -v mkcert &> /dev/null; then
    install_mkcert
    log_info "Initializing local CA..."
    mkcert -install
else
    log_info "mkcert is already installed."
    # Ensure it's installed in the trust store
    mkcert -install
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed or not in PATH."
    if [ "$OS_TYPE" = "macos" ]; then
        log_error "Please install Docker Desktop for Mac:"
        log_error "  https://www.docker.com/products/docker-desktop"
    else
        log_error "Please install Docker for your platform."
    fi
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    log_error "Docker daemon is not running."
    if [ "$OS_TYPE" = "macos" ]; then
        log_error "Please start Docker Desktop application and wait for it to be ready."
        log_warn "You can start Docker Desktop from Applications or the menu bar."
    else
        log_error "Please start the Docker service."
    fi
    exit 1
fi

log_info "Docker is available and running."

# 3. Create network
if ! docker network inspect traefik-proxy &> /dev/null;
    then
    log_info "Creating Docker network 'traefik-proxy'..."
    docker network create traefik-proxy
else
    log_info "Docker network 'traefik-proxy' already exists."
fi

# 4. Generate certificates
mkdir -p certs
if [ ! -f certs/local-cert.pem ] || [ ! -f certs/local-key.pem ];
    then
    log_info "Generating SSL certificates for localhost domain..."
    mkcert -key-file certs/local-key.pem \
      -cert-file certs/local-cert.pem \
      "localhost" "*.docker.localhost" "127.0.0.1" "::1"
    
    # Set permissions
    chmod 644 certs/local-cert.pem certs/local-key.pem
    log_success "Certificates generated in ./certs"
else
    log_info "Certificates already exist. Skipping generation."
fi

# 5. Configure Environment
if [ ! -f .env ]; then
    log_info "Creating .env configuration file from template..."
    cp .env.example .env
    log_success "Created .env file with default settings."
else
    log_info ".env configuration file already exists."
fi

# 6. Start Docker Compose
log_info "Starting Traefik proxy container..."
docker compose up -d

log_success "Setup complete."
echo -e "Dashboard available at: https://traefik.docker.localhost"