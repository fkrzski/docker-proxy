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

echo ""
echo "All tests passed!"
