#!/bin/bash

# Automated macOS Setup Testing Script
# This script validates that setup.sh works correctly on macOS
# Run this on a macOS system with Docker Desktop installed

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

test_passed=0
test_failed=0
test_warnings=0

log_test() {
    echo -e "\n${BLUE}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((test_passed++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((test_failed++))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((test_warnings++))
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Verify running on macOS
check_macos() {
    log_test "Checking if running on macOS..."
    if [[ "$(uname -s)" != "Darwin" ]]; then
        log_fail "Not running on macOS (detected: $(uname -s))"
        echo "This test script must be run on macOS"
        exit 1
    fi
    log_pass "Running on macOS"
}

# Display system info
show_system_info() {
    log_info "System Information:"
    echo "  macOS Version: $(sw_vers -productVersion)"
    echo "  Architecture: $(uname -m)"
    echo "  Homebrew: $(command -v brew &>/dev/null && brew --version | head -n1 || echo 'Not installed')"
    echo "  Docker: $(docker --version 2>/dev/null || echo 'Not found')"
}

# Test 1: OS Detection
test_os_detection() {
    log_test "Testing OS detection..."

    if ! bash -c 'source ./setup.sh 2>/dev/null; detect_os; [[ "$OS_TYPE" == "macos" ]]'; then
        log_fail "OS not detected as macOS"
        return 1
    fi

    log_pass "OS correctly detected as macOS"
}

# Test 2: Architecture Detection
test_arch_detection() {
    log_test "Testing architecture detection..."

    EXPECTED_ARCH=$(uname -m)
    case "$EXPECTED_ARCH" in
        x86_64) EXPECTED_ARCH="amd64" ;;
        aarch64|arm64) EXPECTED_ARCH="arm64" ;;
    esac

    DETECTED_ARCH=$(bash -c 'source ./setup.sh 2>/dev/null; detect_os; echo $ARCH')

    if [[ "$DETECTED_ARCH" != "$EXPECTED_ARCH" ]]; then
        log_fail "Architecture detection incorrect (expected: $EXPECTED_ARCH, got: $DETECTED_ARCH)"
        return 1
    fi

    log_pass "Architecture correctly detected as $EXPECTED_ARCH"
}

# Test 3: mkcert URL Generation
test_mkcert_url() {
    log_test "Testing mkcert URL generation..."

    MKCERT_URL=$(bash -c 'source ./setup.sh 2>/dev/null; detect_os; get_mkcert_download_url; echo $MKCERT_URL')

    if [[ ! "$MKCERT_URL" =~ ^https://dl.filippo.io/mkcert/latest\?for=darwin/ ]]; then
        log_fail "mkcert URL incorrect (got: $MKCERT_URL)"
        return 1
    fi

    log_pass "mkcert URL generated correctly: $MKCERT_URL"
}

# Test 4: Docker Desktop Check
test_docker_available() {
    log_test "Checking Docker Desktop availability..."

    if ! command -v docker &> /dev/null; then
        log_fail "Docker command not found"
        log_warn "Please install Docker Desktop for Mac"
        return 1
    fi

    if ! docker info &> /dev/null; then
        log_fail "Docker daemon not running"
        log_warn "Please start Docker Desktop"
        return 1
    fi

    log_pass "Docker Desktop is available and running"
}

# Test 5: Homebrew Detection
test_homebrew_detection() {
    log_test "Checking Homebrew detection..."

    if command -v brew &> /dev/null; then
        PKG_MANAGER=$(bash -c 'source ./setup.sh 2>/dev/null; detect_package_manager; echo $PKG_MANAGER')
        if [[ "$PKG_MANAGER" == "brew" ]]; then
            log_pass "Homebrew correctly detected"
        else
            log_warn "Homebrew installed but not detected (got: $PKG_MANAGER)"
        fi
    else
        log_info "Homebrew not installed (fallback method will be used)"
    fi
}

# Test 6: mkcert Installation
test_mkcert_installation() {
    log_test "Checking mkcert installation..."

    if ! command -v mkcert &> /dev/null; then
        log_warn "mkcert not found - run ./setup.sh to install"
        return 0
    fi

    MKCERT_VERSION=$(mkcert -version 2>&1)
    log_pass "mkcert installed: $MKCERT_VERSION"
}

# Test 7: Certificate Files
test_certificates() {
    log_test "Checking certificate files..."

    if [[ ! -f ./certs/local-cert.pem ]]; then
        log_warn "Certificate file not found: ./certs/local-cert.pem"
        log_info "Run ./setup.sh to generate certificates"
        return 0
    fi

    if [[ ! -f ./certs/local-key.pem ]]; then
        log_warn "Key file not found: ./certs/local-key.pem"
        log_info "Run ./setup.sh to generate certificates"
        return 0
    fi

    # Check certificate details
    if openssl x509 -in ./certs/local-cert.pem -text -noout | grep -q "docker.localhost"; then
        log_pass "Certificate files exist and contain correct domains"
    else
        log_fail "Certificate exists but doesn't contain expected domains"
        return 1
    fi
}

# Test 8: Docker Network
test_docker_network() {
    log_test "Checking Docker network..."

    if ! docker network inspect traefik-proxy &> /dev/null; then
        log_warn "Docker network 'traefik-proxy' not found"
        log_info "Run ./setup.sh to create network"
        return 0
    fi

    log_pass "Docker network 'traefik-proxy' exists"
}

# Test 9: Traefik Container
test_traefik_container() {
    log_test "Checking Traefik container..."

    if ! docker ps | grep -q traefik; then
        log_warn "Traefik container not running"
        log_info "Run ./setup.sh and 'docker compose up -d' to start"
        return 0
    fi

    # Check container health
    CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' traefik 2>/dev/null || echo "not_found")
    if [[ "$CONTAINER_STATUS" == "running" ]]; then
        log_pass "Traefik container is running"
    else
        log_fail "Traefik container exists but not running (status: $CONTAINER_STATUS)"
        return 1
    fi
}

# Test 10: Traefik Dashboard Access
test_traefik_dashboard() {
    log_test "Checking Traefik dashboard accessibility..."

    if ! docker ps | grep -q traefik; then
        log_warn "Traefik not running - skipping dashboard test"
        return 0
    fi

    # Test HTTP redirect
    HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://traefik.docker.localhost 2>/dev/null || echo "000")
    if [[ "$HTTP_RESPONSE" =~ ^(301|302|307|308)$ ]]; then
        log_pass "HTTP correctly redirects to HTTPS (status: $HTTP_RESPONSE)"
    else
        log_warn "HTTP redirect unexpected (status: $HTTP_RESPONSE)"
    fi

    # Test HTTPS access
    HTTPS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" https://traefik.docker.localhost 2>/dev/null || echo "000")
    if [[ "$HTTPS_RESPONSE" == "200" ]]; then
        log_pass "HTTPS dashboard accessible (status: 200)"
    elif [[ "$HTTPS_RESPONSE" == "000" ]]; then
        log_warn "Cannot connect to HTTPS dashboard (SSL verification might fail without trusted CA)"
        log_info "This is expected if mkcert -install hasn't been run"
    else
        log_fail "HTTPS dashboard returned unexpected status: $HTTPS_RESPONSE"
        return 1
    fi
}

# Test 11: CA Trust Check
test_ca_trust() {
    log_test "Checking mkcert CA trust in Keychain..."

    if ! command -v mkcert &> /dev/null; then
        log_warn "mkcert not installed - skipping CA trust check"
        return 0
    fi

    CAROOT=$(mkcert -CAROOT 2>/dev/null || echo "")
    if [[ -z "$CAROOT" ]]; then
        log_warn "Cannot determine mkcert CA root"
        return 0
    fi

    if [[ ! -f "$CAROOT/rootCA.pem" ]]; then
        log_warn "mkcert CA not initialized (run: mkcert -install)"
        return 0
    fi

    # Check if CA is in system keychain or user login keychain
    FOUND_IN_SYSTEM=false
    FOUND_IN_LOGIN=false

    if security find-certificate -c "mkcert" -a /Library/Keychains/System.keychain &>/dev/null; then
        FOUND_IN_SYSTEM=true
        log_pass "mkcert CA found in System Keychain"
    fi

    if security find-certificate -c "mkcert" -a ~/Library/Keychains/login.keychain-db &>/dev/null; then
        FOUND_IN_LOGIN=true
        log_pass "mkcert CA found in login keychain"
    fi

    if [ "$FOUND_IN_SYSTEM" = false ] && [ "$FOUND_IN_LOGIN" = false ]; then
        log_warn "mkcert CA not found in System Keychain or login keychain"
        log_info "Run 'mkcert -install' to install the CA certificate"
    fi
}

# Main test execution
main() {
    echo "========================================"
    echo "   macOS Setup Testing Script"
    echo "========================================"
    echo ""

    check_macos
    show_system_info

    echo ""
    echo "Running tests..."
    echo "========================================"

    # Run all tests (continue on failure)
    test_os_detection || true
    test_arch_detection || true
    test_mkcert_url || true
    test_docker_available || true
    test_homebrew_detection || true
    test_mkcert_installation || true
    test_certificates || true
    test_docker_network || true
    test_traefik_container || true
    test_traefik_dashboard || true
    test_ca_trust || true

    echo ""
    echo "========================================"
    echo "   Test Summary"
    echo "========================================"
    echo -e "${GREEN}Passed:${NC}   $test_passed"
    echo -e "${RED}Failed:${NC}   $test_failed"
    echo -e "${YELLOW}Warnings:${NC} $test_warnings"
    echo ""

    if [ $test_failed -eq 0 ]; then
        echo -e "${GREEN}✅ All critical tests passed!${NC}"
        if [ $test_warnings -gt 0 ]; then
            echo -e "${YELLOW}⚠️  There are $test_warnings warnings - review above${NC}"
        fi
        exit 0
    else
        echo -e "${RED}❌ Some tests failed - review above${NC}"
        exit 1
    fi
}

# Run main function
main
