#!/bin/bash

# Automated WSL2 Setup Testing Script
# This script validates that setup.sh works correctly on WSL2
# Run this in a WSL2 environment with Docker Desktop integration

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

# Verify running on WSL2
check_wsl2() {
    log_test "Checking if running on WSL2..."

    if [[ ! -f /proc/version ]]; then
        log_fail "No /proc/version found - not a Linux environment"
        exit 1
    fi

    if ! grep -qi microsoft /proc/version; then
        log_fail "Not running on WSL2 (no 'microsoft' in /proc/version)"
        echo "Detected: $(cat /proc/version | head -c 100)..."
        echo ""
        log_info "This test script must be run on WSL2"
        exit 1
    fi

    log_pass "Running on WSL2"
}

# Display system info
show_system_info() {
    log_info "System Information:"
    echo "  OS Release: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "  Kernel: $(uname -r)"
    echo "  Architecture: $(uname -m)"
    echo "  Docker: $(docker --version 2>/dev/null || echo 'Not found')"

    # Check if Docker Desktop integration
    if docker info 2>/dev/null | grep -q "Operating System.*Docker Desktop"; then
        echo "  Docker Desktop: Detected (WSL2 integration enabled)"
    elif docker info &>/dev/null; then
        echo "  Docker: Running (may be native Docker, not Docker Desktop)"
    else
        echo "  Docker: Not running or not accessible"
    fi
}

# Test 1: OS Detection
test_os_detection() {
    log_test "Testing OS detection..."

    if ! bash -c 'source ./setup.sh 2>/dev/null; detect_os; [[ "$OS_TYPE" == "wsl2" ]]'; then
        log_fail "OS not detected as WSL2"
        return 1
    fi

    log_pass "OS correctly detected as WSL2"
}

# Test 2: Architecture Detection
test_arch_detection() {
    log_test "Testing architecture detection..."

    EXPECTED_ARCH=$(uname -m)
    case "$EXPECTED_ARCH" in
        x86_64) EXPECTED_ARCH="amd64" ;;
        aarch64|arm64) EXPECTED_ARCH="arm64" ;;
        armv7l) EXPECTED_ARCH="armv7" ;;
    esac

    DETECTED_ARCH=$(bash -c 'source ./setup.sh 2>/dev/null; detect_os; echo $ARCH')

    if [[ "$DETECTED_ARCH" != "$EXPECTED_ARCH" ]]; then
        log_fail "Architecture detection incorrect (expected: $EXPECTED_ARCH, got: $DETECTED_ARCH)"
        return 1
    fi

    log_pass "Architecture correctly detected as $EXPECTED_ARCH"
}

# Test 3: mkcert URL Generation (should use Linux binary)
test_mkcert_url() {
    log_test "Testing mkcert URL generation..."

    MKCERT_URL=$(bash -c 'source ./setup.sh 2>/dev/null; detect_os; get_mkcert_download_url; echo $MKCERT_URL')

    if [[ ! "$MKCERT_URL" =~ ^https://dl.filippo.io/mkcert/latest\?for=linux/ ]]; then
        log_fail "mkcert URL should use Linux binary for WSL2 (got: $MKCERT_URL)"
        return 1
    fi

    log_pass "mkcert URL correctly uses Linux binary: $MKCERT_URL"
}

# Test 4: mkcert OS Variable (should be 'linux', not 'windows')
test_mkcert_os_variable() {
    log_test "Testing mkcert OS variable..."

    MKCERT_OS=$(bash -c 'source ./setup.sh 2>/dev/null; detect_os; get_mkcert_download_url; echo $MKCERT_OS')

    if [[ "$MKCERT_OS" != "linux" ]]; then
        log_fail "MKCERT_OS should be 'linux' for WSL2 (got: $MKCERT_OS)"
        return 1
    fi

    log_pass "MKCERT_OS correctly set to 'linux'"
}

# Test 5: Docker Available
test_docker_available() {
    log_test "Checking Docker availability..."

    if ! command -v docker &> /dev/null; then
        log_fail "Docker command not found"
        log_warn "Please ensure Docker Desktop for Windows with WSL2 integration is enabled"
        return 1
    fi

    if ! docker info &> /dev/null; then
        log_fail "Docker daemon not accessible"
        log_warn "Please start Docker Desktop for Windows"
        return 1
    fi

    log_pass "Docker is available and accessible"
}

# Test 6: Package Manager Detection (should be apt for Ubuntu/Debian WSL2)
test_package_manager() {
    log_test "Checking package manager detection..."

    PKG_MANAGER=$(bash -c 'source ./setup.sh 2>/dev/null; detect_package_manager; echo $PKG_MANAGER')

    if [[ -z "$PKG_MANAGER" ]]; then
        log_warn "Package manager not detected"
        return 0
    fi

    log_pass "Package manager detected: $PKG_MANAGER"
}

# Test 7: mkcert Installation
test_mkcert_installation() {
    log_test "Checking mkcert installation..."

    if ! command -v mkcert &> /dev/null; then
        log_warn "mkcert not found - run ./setup.sh to install"
        return 0
    fi

    MKCERT_VERSION=$(mkcert -version 2>&1)
    log_pass "mkcert installed: $MKCERT_VERSION"

    # Verify it's a Linux binary
    if file $(which mkcert) | grep -q "ELF.*executable"; then
        log_pass "mkcert is a Linux ELF binary (correct for WSL2)"
    else
        log_warn "mkcert binary type: $(file $(which mkcert))"
    fi
}

# Test 8: Certificate Files
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

# Test 9: Docker Network
test_docker_network() {
    log_test "Checking Docker network..."

    if ! docker network inspect traefik-proxy &> /dev/null; then
        log_warn "Docker network 'traefik-proxy' not found"
        log_info "Run ./setup.sh to create network"
        return 0
    fi

    log_pass "Docker network 'traefik-proxy' exists"
}

# Test 10: Traefik Container
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

# Test 11: Traefik Dashboard Access
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

    # Test HTTPS access (may fail if CA not trusted)
    HTTPS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" https://traefik.docker.localhost 2>/dev/null || echo "000")
    if [[ "$HTTPS_RESPONSE" == "200" ]]; then
        log_pass "HTTPS dashboard accessible (status: 200)"
    elif [[ "$HTTPS_RESPONSE" == "000" ]]; then
        log_warn "Cannot verify HTTPS dashboard (SSL verification may fail without trusted CA)"
        log_info "This is expected if mkcert -install hasn't been run"
    else
        log_warn "HTTPS dashboard returned status: $HTTPS_RESPONSE"
    fi
}

# Test 12: WSL2-Specific Instructions Check
test_wsl2_instructions() {
    log_test "Checking WSL2-specific setup instructions in script..."

    # Check if setup.sh contains WSL2-specific instructions
    if grep -q "WSL2 ADDITIONAL STEP REQUIRED" ./setup.sh; then
        log_pass "WSL2 Windows certificate instructions found in setup.sh"
    else
        log_fail "WSL2 Windows certificate instructions missing from setup.sh"
        return 1
    fi

    # Check if instructions mention Windows certificate installation
    if grep -q "Trusted Root Certification Authorities" ./setup.sh; then
        log_pass "Instructions mention Windows certificate store"
    else
        log_fail "Instructions don't mention Windows certificate store"
        return 1
    fi
}

# Test 13: mkcert CA Root Check
test_ca_root() {
    log_test "Checking mkcert CA root..."

    if ! command -v mkcert &> /dev/null; then
        log_warn "mkcert not installed - skipping CA root check"
        return 0
    fi

    CAROOT=$(mkcert -CAROOT 2>/dev/null || echo "")
    if [[ -z "$CAROOT" ]]; then
        log_warn "Cannot determine mkcert CA root"
        return 0
    fi

    log_info "mkcert CA root: $CAROOT"

    if [[ ! -f "$CAROOT/rootCA.pem" ]]; then
        log_warn "mkcert CA not initialized (run: mkcert -install)"
        return 0
    fi

    log_pass "mkcert CA initialized at $CAROOT"

    # Check if CA root is in WSL2 filesystem (not Windows)
    if [[ "$CAROOT" == /mnt/c/* ]] || [[ "$CAROOT" == /mnt/*/* ]]; then
        log_warn "CA root is in Windows filesystem - should be in WSL2 Linux filesystem"
        log_info "Expected location: /home/<user>/.local/share/mkcert"
    else
        log_pass "CA root correctly in WSL2 Linux filesystem"
    fi
}

# Test 14: Check Windows Path Accessibility
test_windows_path() {
    log_test "Checking Windows filesystem accessibility..."

    if [[ -d /mnt/c/Users ]]; then
        log_pass "Windows C: drive accessible at /mnt/c"
        log_info "This allows copying CA certificate to Windows"
    else
        log_warn "Windows C: drive not accessible at /mnt/c"
        log_info "May need to adjust certificate copy instructions"
    fi
}

# Main test execution
main() {
    echo "========================================"
    echo "   WSL2 Setup Testing Script"
    echo "========================================"
    echo ""

    check_wsl2
    show_system_info

    echo ""
    echo "Running tests..."
    echo "========================================"

    # Run all tests (continue on failure)
    test_os_detection || true
    test_arch_detection || true
    test_mkcert_url || true
    test_mkcert_os_variable || true
    test_docker_available || true
    test_package_manager || true
    test_mkcert_installation || true
    test_certificates || true
    test_docker_network || true
    test_traefik_container || true
    test_traefik_dashboard || true
    test_wsl2_instructions || true
    test_ca_root || true
    test_windows_path || true

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

        echo ""
        echo "========================================"
        echo "   Next Steps"
        echo "========================================"
        echo "1. If setup.sh hasn't been run yet, run: ./setup.sh"
        echo "2. After setup completes, follow the WSL2 ADDITIONAL STEP"
        echo "   to install the CA certificate in Windows"
        echo "3. Copy CA to Windows: cp \$(mkcert -CAROOT)/rootCA.pem /mnt/c/Users/\$USER/Downloads/"
        echo "4. In Windows, double-click rootCA.pem and install to"
        echo "   'Trusted Root Certification Authorities'"
        echo "5. Test in Windows browser: https://traefik.docker.localhost"
        echo ""

        exit 0
    else
        echo -e "${RED}❌ Some tests failed - review above${NC}"
        exit 1
    fi
}

# Run main function
main
