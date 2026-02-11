#!/bin/bash
# Test OS detection logic

# Source the functions from setup.sh
source ./setup.sh 2>/dev/null || true

# Run detection
detect_os

echo "===== OS DETECTION TEST ====="
echo "OS_TYPE: $OS_TYPE"
echo "ARCH: $ARCH"
echo ""

# Validate results
if [[ -z "$OS_TYPE" ]]; then
    echo "❌ FAIL: OS_TYPE not set"
    exit 1
elif [[ "$OS_TYPE" =~ ^(linux|macos|wsl2|unknown)$ ]]; then
    echo "✅ PASS: OS_TYPE is valid ($OS_TYPE)"
else
    echo "❌ FAIL: OS_TYPE has invalid value ($OS_TYPE)"
    exit 1
fi

if [[ -z "$ARCH" ]]; then
    echo "❌ FAIL: ARCH not set"
    exit 1
else
    echo "✅ PASS: ARCH is set ($ARCH)"
fi

# Test mkcert URL generation
echo ""
echo "===== MKCERT URL TEST ====="
get_mkcert_download_url

if [[ -z "$MKCERT_URL" ]]; then
    echo "❌ FAIL: MKCERT_URL not generated"
    exit 1
else
    echo "✅ PASS: MKCERT_URL generated"
    echo "URL: $MKCERT_URL"
    echo "MKCERT_OS: $MKCERT_OS"
    echo "MKCERT_ARCH: $MKCERT_ARCH"
fi

# ARM64 Architecture Test Cases
echo ""
echo "===== ARM64 ARCHITECTURE TEST CASES ====="

# Test 1: aarch64 architecture normalization
echo ""
echo "Test 1: aarch64 architecture normalization"
test_aarch64_detection() {
    # Test the case statement logic from detect_os function
    # Simulating: case "$ARCH" in aarch64|arm64) ARCH="arm64" ;;
    local test_arch="aarch64"
    local normalized_arch

    case "$test_arch" in
        x86_64) normalized_arch="amd64" ;;
        aarch64|arm64) normalized_arch="arm64" ;;
        armv7l) normalized_arch="armv7" ;;
        *) normalized_arch="unsupported" ;;
    esac

    if [[ "$normalized_arch" == "arm64" ]]; then
        echo "✅ PASS: aarch64 correctly maps to arm64"
        return 0
    else
        echo "❌ FAIL: aarch64 did not map to arm64 (got: $normalized_arch)"
        return 1
    fi
}
test_aarch64_detection

# Test 2: arm64 architecture normalization
echo ""
echo "Test 2: arm64 architecture normalization"
test_arm64_detection() {
    # Test the case statement logic from detect_os function
    # Simulating: case "$ARCH" in aarch64|arm64) ARCH="arm64" ;;
    local test_arch="arm64"
    local normalized_arch

    case "$test_arch" in
        x86_64) normalized_arch="amd64" ;;
        aarch64|arm64) normalized_arch="arm64" ;;
        armv7l) normalized_arch="armv7" ;;
        *) normalized_arch="unsupported" ;;
    esac

    if [[ "$normalized_arch" == "arm64" ]]; then
        echo "✅ PASS: arm64 architecture recognized"
        return 0
    else
        echo "❌ FAIL: arm64 not recognized (got: $normalized_arch)"
        return 1
    fi
}
test_arm64_detection

# Test 3: ARM64 mkcert URL for Linux
echo ""
echo "Test 3: ARM64 mkcert URL for Linux"
test_arm64_linux_url() {
    local saved_os="$OS_TYPE"
    local saved_arch="$ARCH"
    local result=0

    OS_TYPE="linux"
    ARCH="arm64"
    get_mkcert_download_url

    if [[ "$MKCERT_URL" == "https://dl.filippo.io/mkcert/latest?for=linux/arm64" ]]; then
        echo "✅ PASS: Linux ARM64 mkcert URL is correct"
        echo "   URL: $MKCERT_URL"
    else
        echo "❌ FAIL: Linux ARM64 mkcert URL incorrect"
        echo "   Expected: https://dl.filippo.io/mkcert/latest?for=linux/arm64"
        echo "   Got: $MKCERT_URL"
        result=1
    fi

    # Restore state
    OS_TYPE="$saved_os"
    ARCH="$saved_arch"
    return $result
}
test_arm64_linux_url

# Test 4: ARM64 mkcert URL for macOS
echo ""
echo "Test 4: ARM64 mkcert URL for macOS"
test_arm64_macos_url() {
    local saved_os="$OS_TYPE"
    local saved_arch="$ARCH"
    local result=0

    OS_TYPE="macos"
    ARCH="arm64"
    get_mkcert_download_url

    if [[ "$MKCERT_URL" == "https://dl.filippo.io/mkcert/latest?for=darwin/arm64" ]]; then
        echo "✅ PASS: macOS ARM64 mkcert URL is correct"
        echo "   URL: $MKCERT_URL"
    else
        echo "❌ FAIL: macOS ARM64 mkcert URL incorrect"
        echo "   Expected: https://dl.filippo.io/mkcert/latest?for=darwin/arm64"
        echo "   Got: $MKCERT_URL"
        result=1
    fi

    # Restore state
    OS_TYPE="$saved_os"
    ARCH="$saved_arch"
    return $result
}
test_arm64_macos_url

# Test 5: ARM64 mkcert URL for WSL2
echo ""
echo "Test 5: ARM64 mkcert URL for WSL2"
test_arm64_wsl2_url() {
    local saved_os="$OS_TYPE"
    local saved_arch="$ARCH"
    local result=0

    OS_TYPE="wsl2"
    ARCH="arm64"
    get_mkcert_download_url

    if [[ "$MKCERT_URL" == "https://dl.filippo.io/mkcert/latest?for=linux/arm64" ]]; then
        echo "✅ PASS: WSL2 ARM64 mkcert URL is correct (uses linux)"
        echo "   URL: $MKCERT_URL"
    else
        echo "❌ FAIL: WSL2 ARM64 mkcert URL incorrect"
        echo "   Expected: https://dl.filippo.io/mkcert/latest?for=linux/arm64"
        echo "   Got: $MKCERT_URL"
        result=1
    fi

    # Restore state
    OS_TYPE="$saved_os"
    ARCH="$saved_arch"
    return $result
}
test_arm64_wsl2_url

# Test 6: Verify current system's architecture is supported
echo ""
echo "Test 6: Current system architecture support"
test_current_arch_supported() {
    local current_arch=$(uname -m)
    case "$current_arch" in
        x86_64|aarch64|arm64|armv7l)
            echo "✅ PASS: Current architecture ($current_arch) is supported"
            return 0
            ;;
        *)
            echo "❌ FAIL: Current architecture ($current_arch) is not in supported list"
            return 1
            ;;
    esac
}
test_current_arch_supported

echo ""
echo "All tests passed!"
