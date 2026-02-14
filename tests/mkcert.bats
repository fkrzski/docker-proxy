#!/usr/bin/env bats
# mkcert URL Generation Tests for setup.sh

# Load test helpers
load helpers/test-helpers
load helpers/mocks

# Setup and teardown functions run before/after each test
setup() {
    save_environment_state
    # Extract just the functions we need from setup.sh
    load_setup_function get_mkcert_download_url
}

teardown() {
    restore_environment_state
}

# ============================================================================
# Basic mkcert URL Generation Tests
# ============================================================================

@test "get_mkcert_download_url generates URL for Linux amd64" {
    OS_TYPE="linux"
    ARCH="amd64"
    get_mkcert_download_url
    [ "$MKCERT_URL" = "https://dl.filippo.io/mkcert/latest?for=linux/amd64" ]
}

@test "get_mkcert_download_url generates URL for Linux arm64" {
    OS_TYPE="linux"
    ARCH="arm64"
    get_mkcert_download_url
    [ "$MKCERT_URL" = "https://dl.filippo.io/mkcert/latest?for=linux/arm64" ]
}

@test "get_mkcert_download_url generates URL for Linux armv7" {
    OS_TYPE="linux"
    ARCH="armv7"
    get_mkcert_download_url
    [ "$MKCERT_URL" = "https://dl.filippo.io/mkcert/latest?for=linux/arm" ]
}

@test "get_mkcert_download_url generates URL for macOS amd64" {
    OS_TYPE="macos"
    ARCH="amd64"
    get_mkcert_download_url
    [ "$MKCERT_URL" = "https://dl.filippo.io/mkcert/latest?for=darwin/amd64" ]
}

@test "get_mkcert_download_url generates URL for macOS arm64" {
    OS_TYPE="macos"
    ARCH="arm64"
    get_mkcert_download_url
    [ "$MKCERT_URL" = "https://dl.filippo.io/mkcert/latest?for=darwin/arm64" ]
}

@test "get_mkcert_download_url generates URL for WSL2 amd64 (uses linux)" {
    OS_TYPE="wsl2"
    ARCH="amd64"
    get_mkcert_download_url
    [ "$MKCERT_URL" = "https://dl.filippo.io/mkcert/latest?for=linux/amd64" ]
}

@test "get_mkcert_download_url generates URL for WSL2 arm64 (uses linux)" {
    OS_TYPE="wsl2"
    ARCH="arm64"
    get_mkcert_download_url
    [ "$MKCERT_URL" = "https://dl.filippo.io/mkcert/latest?for=linux/arm64" ]
}

# ============================================================================
# MKCERT_OS Variable Tests
# ============================================================================

@test "get_mkcert_download_url sets MKCERT_OS to darwin for macOS" {
    OS_TYPE="macos"
    ARCH="amd64"
    get_mkcert_download_url
    [ "$MKCERT_OS" = "darwin" ]
}

@test "get_mkcert_download_url sets MKCERT_OS to linux for Linux" {
    OS_TYPE="linux"
    ARCH="amd64"
    get_mkcert_download_url
    [ "$MKCERT_OS" = "linux" ]
}

@test "get_mkcert_download_url sets MKCERT_OS to linux for WSL2" {
    OS_TYPE="wsl2"
    ARCH="amd64"
    get_mkcert_download_url
    [ "$MKCERT_OS" = "linux" ]
}

# ============================================================================
# MKCERT_ARCH Variable Tests
# ============================================================================

@test "get_mkcert_download_url sets MKCERT_ARCH correctly for amd64" {
    OS_TYPE="linux"
    ARCH="amd64"
    get_mkcert_download_url
    [ "$MKCERT_ARCH" = "amd64" ]
}

@test "get_mkcert_download_url sets MKCERT_ARCH correctly for arm64" {
    OS_TYPE="linux"
    ARCH="arm64"
    get_mkcert_download_url
    [ "$MKCERT_ARCH" = "arm64" ]
}

@test "get_mkcert_download_url sets MKCERT_ARCH to arm for armv7" {
    OS_TYPE="linux"
    ARCH="armv7"
    get_mkcert_download_url
    [ "$MKCERT_ARCH" = "arm" ]
}

# ============================================================================
# Architecture Mapping Tests
# ============================================================================

@test "armv7 architecture maps to arm in mkcert URL" {
    OS_TYPE="linux"
    ARCH="armv7"
    get_mkcert_download_url

    # armv7 should be mapped to "arm" in the URL
    [[ "$MKCERT_URL" =~ linux/arm$ ]]
    [ "$MKCERT_ARCH" = "arm" ]
}

@test "amd64 architecture remains amd64 in mkcert URL" {
    OS_TYPE="linux"
    ARCH="amd64"
    get_mkcert_download_url

    [[ "$MKCERT_URL" =~ linux/amd64$ ]]
    [ "$MKCERT_ARCH" = "amd64" ]
}

@test "arm64 architecture remains arm64 in mkcert URL" {
    OS_TYPE="macos"
    ARCH="arm64"
    get_mkcert_download_url

    [[ "$MKCERT_URL" =~ darwin/arm64$ ]]
    [ "$MKCERT_ARCH" = "arm64" ]
}

# ============================================================================
# URL Format Validation Tests
# ============================================================================

@test "get_mkcert_download_url URL format starts with https" {
    OS_TYPE="linux"
    ARCH="amd64"
    get_mkcert_download_url

    [[ "$MKCERT_URL" =~ ^https:// ]]
}

@test "get_mkcert_download_url URL format contains filippo.io domain" {
    OS_TYPE="linux"
    ARCH="amd64"
    get_mkcert_download_url

    [[ "$MKCERT_URL" =~ dl\.filippo\.io ]]
}

@test "get_mkcert_download_url URL format contains mkcert path" {
    OS_TYPE="linux"
    ARCH="amd64"
    get_mkcert_download_url

    [[ "$MKCERT_URL" =~ /mkcert/latest ]]
}

@test "get_mkcert_download_url URL format contains for parameter" {
    OS_TYPE="linux"
    ARCH="amd64"
    get_mkcert_download_url

    [[ "$MKCERT_URL" =~ \?for= ]]
}

@test "get_mkcert_download_url URL format is complete and valid" {
    OS_TYPE="linux"
    ARCH="amd64"
    get_mkcert_download_url

    # Full URL validation
    [[ "$MKCERT_URL" =~ ^https://dl\.filippo\.io/mkcert/latest\?for=linux/amd64$ ]]
}

# ============================================================================
# Error Handling Tests
# ============================================================================

@test "get_mkcert_download_url fails for unsupported OS" {
    OS_TYPE="unknown"
    ARCH="amd64"
    run get_mkcert_download_url
    [ "$status" -eq 1 ]
}

@test "get_mkcert_download_url fails for invalid OS type" {
    OS_TYPE="windows"
    ARCH="amd64"
    run get_mkcert_download_url
    [ "$status" -eq 1 ]
}

@test "get_mkcert_download_url fails for empty OS_TYPE" {
    OS_TYPE=""
    ARCH="amd64"
    run get_mkcert_download_url
    [ "$status" -eq 1 ]
}

# ============================================================================
# Comprehensive Platform Matrix Tests
# ============================================================================

@test "All supported OS and arch combinations produce valid URLs" {
    # Test matrix of supported combinations
    local os_types=("linux" "macos" "wsl2")
    local archs=("amd64" "arm64" "armv7")

    for os in "${os_types[@]}"; do
        for arch in "${archs[@]}"; do
            OS_TYPE="$os"
            ARCH="$arch"
            get_mkcert_download_url

            # Verify URL was generated
            [[ -n "$MKCERT_URL" ]] || fail "No URL generated for $os/$arch"
            [[ "$MKCERT_URL" =~ ^https://dl.filippo.io/mkcert/latest ]] || fail "Invalid URL for $os/$arch"
        done
    done
}

@test "Linux with all supported architectures generates correct URLs" {
    OS_TYPE="linux"

    # Test amd64
    ARCH="amd64"
    get_mkcert_download_url
    [ "$MKCERT_URL" = "https://dl.filippo.io/mkcert/latest?for=linux/amd64" ]

    # Test arm64
    ARCH="arm64"
    get_mkcert_download_url
    [ "$MKCERT_URL" = "https://dl.filippo.io/mkcert/latest?for=linux/arm64" ]

    # Test armv7
    ARCH="armv7"
    get_mkcert_download_url
    [ "$MKCERT_URL" = "https://dl.filippo.io/mkcert/latest?for=linux/arm" ]
}

@test "macOS with all supported architectures generates correct URLs" {
    OS_TYPE="macos"

    # Test amd64 (Intel)
    ARCH="amd64"
    get_mkcert_download_url
    [ "$MKCERT_URL" = "https://dl.filippo.io/mkcert/latest?for=darwin/amd64" ]

    # Test arm64 (Apple Silicon)
    ARCH="arm64"
    get_mkcert_download_url
    [ "$MKCERT_URL" = "https://dl.filippo.io/mkcert/latest?for=darwin/arm64" ]
}

@test "WSL2 with all supported architectures generates linux URLs" {
    OS_TYPE="wsl2"

    # Test amd64
    ARCH="amd64"
    get_mkcert_download_url
    [ "$MKCERT_URL" = "https://dl.filippo.io/mkcert/latest?for=linux/amd64" ]
    [ "$MKCERT_OS" = "linux" ]

    # Test arm64
    ARCH="arm64"
    get_mkcert_download_url
    [ "$MKCERT_URL" = "https://dl.filippo.io/mkcert/latest?for=linux/arm64" ]
    [ "$MKCERT_OS" = "linux" ]

    # Test armv7
    ARCH="armv7"
    get_mkcert_download_url
    [ "$MKCERT_URL" = "https://dl.filippo.io/mkcert/latest?for=linux/arm" ]
    [ "$MKCERT_OS" = "linux" ]
}

# ============================================================================
# Variable State Tests
# ============================================================================

@test "get_mkcert_download_url sets all required variables" {
    OS_TYPE="linux"
    ARCH="amd64"
    get_mkcert_download_url

    # All three variables should be set
    [[ -n "$MKCERT_URL" ]] || fail "MKCERT_URL not set"
    [[ -n "$MKCERT_OS" ]] || fail "MKCERT_OS not set"
    [[ -n "$MKCERT_ARCH" ]] || fail "MKCERT_ARCH not set"
}

@test "get_mkcert_download_url variables are consistent" {
    OS_TYPE="macos"
    ARCH="arm64"
    get_mkcert_download_url

    # Verify consistency between variables and URL
    [[ "$MKCERT_URL" =~ $MKCERT_OS ]] || fail "MKCERT_OS not in URL"
    [[ "$MKCERT_URL" =~ $MKCERT_ARCH ]] || fail "MKCERT_ARCH not in URL"
}

# ============================================================================
# Edge Cases and Special Scenarios
# ============================================================================

@test "get_mkcert_download_url handles WSL2 as Linux variant" {
    OS_TYPE="wsl2"
    ARCH="amd64"
    get_mkcert_download_url

    # WSL2 should use linux in URL, not wsl2
    [[ "$MKCERT_URL" =~ linux ]]
    [[ ! "$MKCERT_URL" =~ wsl2 ]]
    [ "$MKCERT_OS" = "linux" ]
}

@test "get_mkcert_download_url macOS uses darwin naming" {
    OS_TYPE="macos"
    ARCH="amd64"
    get_mkcert_download_url

    # macOS should use darwin in URL
    [[ "$MKCERT_URL" =~ darwin ]]
    [[ ! "$MKCERT_URL" =~ macos ]]
    [ "$MKCERT_OS" = "darwin" ]
}

@test "get_mkcert_download_url preserves architecture values" {
    # Test that ARCH input is not modified (only MKCERT_ARCH changes for armv7)
    OS_TYPE="linux"
    ARCH="armv7"
    get_mkcert_download_url

    # ARCH should still be armv7
    [ "$ARCH" = "armv7" ]
    # MKCERT_ARCH should be arm
    [ "$MKCERT_ARCH" = "arm" ]
}
