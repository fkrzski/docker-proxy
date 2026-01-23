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

log_info "Starting Local Docker Proxy setup..."

# Pre-check for apt (Debian/Ubuntu based systems)
if ! command -v apt &> /dev/null;
    then
    log_warn "This script relies on 'apt' for dependency management."
    log_warn "Please ensure you have equivalent dependencies installed manually if you are not on a Debian-based system."
fi

# 1. Install libnss3-tools
if ! dpkg -s libnss3-tools >/dev/null 2>&1;
    then
    log_info "Installing dependencies (libnss3-tools)..."
    sudo apt update && sudo apt install -y libnss3-tools curl
else
    log_info "Dependency 'libnss3-tools' is already installed."
fi

# 2. Install mkcert
if ! command -v mkcert &> /dev/null;
    then
    log_info "Installing mkcert..."
    curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
    chmod +x mkcert-v*-linux-amd64
    sudo mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert
    
    log_info "Initializing local CA..."
    mkcert -install
else
    log_info "mkcert is already installed."
    # Ensure it's installed in the trust store
    mkcert -install
fi

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