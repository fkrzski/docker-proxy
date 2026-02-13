#!/usr/bin/env bats
# End-to-End Setup Flow Tests for setup.sh

# Load test helpers
load helpers/test-helpers
load helpers/mocks

# Setup and teardown functions run before/after each test
setup() {
    save_environment_state
    # Extract functions from setup.sh
    eval "$(sed -n '/^detect_os()/,/^}/p' ./setup.sh)"
    eval "$(sed -n '/^get_mkcert_download_url()/,/^}/p' ./setup.sh)"
    eval "$(sed -n '/^detect_package_manager()/,/^}/p' ./setup.sh)"
    eval "$(sed -n '/^check_nss_installed()/,/^}/p' ./setup.sh)"
    eval "$(sed -n '/^get_windows_username()/,/^}/p' ./setup.sh)"
}

teardown() {
    restore_environment_state
    # Reset mocks
    reset_mocks
}

# ============================================================================
# Complete Setup Flow Tests
# ============================================================================

@test "Complete setup flow: Linux with apt" {
    # Test the complete workflow for Linux with apt package manager
    run bash -c '
        eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
        eval "$(sed -n "/^get_mkcert_download_url()/,/^}/p" ./setup.sh)"
        eval "$(sed -n "/^detect_package_manager()/,/^}/p" ./setup.sh)"

        # Step 1: Detect OS
        detect_os
        [[ -n "$OS_TYPE" ]] || exit 1
        [[ -n "$ARCH" ]] || exit 1

        # Step 2: Detect package manager
        detect_package_manager
        [[ -n "$PKG_MANAGER" ]] || exit 1

        # Step 3: Generate mkcert URL
        get_mkcert_download_url
        [[ -n "$MKCERT_URL" ]] || exit 1
        [[ "$MKCERT_URL" =~ ^https:// ]] || exit 1

        exit 0
    '
    [ "$status" -eq 0 ]
}

@test "Complete setup flow: macOS with brew" {
    # This test uses actual system detection if on macOS
    if [[ "$(uname -s)" == "Darwin" ]]; then
        run bash -c '
            eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
            eval "$(sed -n "/^get_mkcert_download_url()/,/^}/p" ./setup.sh)"
            eval "$(sed -n "/^detect_package_manager()/,/^}/p" ./setup.sh)"

            detect_os
            [[ "$OS_TYPE" == "macos" ]] || exit 1

            detect_package_manager
            get_mkcert_download_url

            [[ "$MKCERT_URL" =~ ^https://dl.filippo.io/mkcert/latest\?for=darwin/ ]] || exit 1

            exit 0
        '
        [ "$status" -eq 0 ]
    else
        skip "Not running on macOS"
    fi
}

@test "Complete setup flow: WSL2 detection and URL generation" {
    # This test uses actual system detection if on WSL2
    if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
        run bash -c '
            eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
            eval "$(sed -n "/^get_mkcert_download_url()/,/^}/p" ./setup.sh)"

            detect_os
            [[ "$OS_TYPE" == "wsl2" ]] || exit 1

            get_mkcert_download_url
            [[ "$MKCERT_OS" == "linux" ]] || exit 1
            [[ "$MKCERT_URL" =~ ^https://dl.filippo.io/mkcert/latest\?for=linux/ ]] || exit 1

            exit 0
        '
        [ "$status" -eq 0 ]
    else
        skip "Not running on WSL2"
    fi
}

# ============================================================================
# Integration Tests: Multi-Step Workflows
# ============================================================================

@test "Integration: OS detection -> Package manager -> mkcert URL" {
    run bash -c '
        eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
        eval "$(sed -n "/^get_mkcert_download_url()/,/^}/p" ./setup.sh)"
        eval "$(sed -n "/^detect_package_manager()/,/^}/p" ./setup.sh)"

        # Step 1: Detect OS and architecture
        detect_os
        echo "OS_TYPE=$OS_TYPE, ARCH=$ARCH"

        # Step 2: Detect package manager
        detect_package_manager
        echo "PKG_MANAGER=$PKG_MANAGER"

        # Step 3: Generate mkcert URL
        get_mkcert_download_url
        echo "MKCERT_URL=$MKCERT_URL"

        # Verify all critical variables are set
        [[ -n "$OS_TYPE" ]] || exit 1
        [[ -n "$ARCH" ]] || exit 1
        [[ -n "$PKG_MANAGER" ]] || exit 1
        [[ -n "$MKCERT_URL" ]] || exit 1

        exit 0
    '
    [ "$status" -eq 0 ]
}

@test "Integration: Linux system produces linux mkcert URL" {
    if [[ "$(uname -s)" == "Linux" ]] && ! grep -qi microsoft /proc/version 2>/dev/null; then
        run bash -c '
            eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
            eval "$(sed -n "/^get_mkcert_download_url()/,/^}/p" ./setup.sh)"

            detect_os
            get_mkcert_download_url

            [[ "$OS_TYPE" == "linux" ]] || exit 1
            [[ "$MKCERT_OS" == "linux" ]] || exit 1
            [[ "$MKCERT_URL" =~ ^https://dl.filippo.io/mkcert/latest\?for=linux/ ]] || exit 1

            exit 0
        '
        [ "$status" -eq 0 ]
    else
        skip "Not running on native Linux"
    fi
}

@test "Integration: macOS system produces darwin mkcert URL" {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        run bash -c '
            eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
            eval "$(sed -n "/^get_mkcert_download_url()/,/^}/p" ./setup.sh)"

            detect_os
            get_mkcert_download_url

            [[ "$OS_TYPE" == "macos" ]] || exit 1
            [[ "$MKCERT_OS" == "darwin" ]] || exit 1
            [[ "$MKCERT_URL" =~ ^https://dl.filippo.io/mkcert/latest\?for=darwin/ ]] || exit 1

            exit 0
        '
        [ "$status" -eq 0 ]
    else
        skip "Not running on macOS"
    fi
}

@test "Integration: WSL2 system produces linux mkcert URL" {
    if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
        run bash -c '
            eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
            eval "$(sed -n "/^get_mkcert_download_url()/,/^}/p" ./setup.sh)"

            detect_os
            get_mkcert_download_url

            [[ "$OS_TYPE" == "wsl2" ]] || exit 1
            [[ "$MKCERT_OS" == "linux" ]] || exit 1
            [[ "$MKCERT_URL" =~ ^https://dl.filippo.io/mkcert/latest\?for=linux/ ]] || exit 1

            exit 0
        '
        [ "$status" -eq 0 ]
    else
        skip "Not running on WSL2"
    fi
}

# ============================================================================
# NSS Tools Detection Tests
# ============================================================================

@test "Setup flow: NSS tools check function exists" {
    run bash -c '
        eval "$(sed -n "/^check_nss_installed()/,/^}/p" ./setup.sh)"
        eval "$(sed -n "/^detect_package_manager()/,/^}/p" ./setup.sh)"

        detect_package_manager

        # Function should execute without errors (may return 0 or 1)
        check_nss_installed || true

        exit 0
    '
    [ "$status" -eq 0 ]
}

@test "Setup flow: NSS tools check handles unknown package manager" {
    run bash -c '
        eval "$(sed -n "/^check_nss_installed()/,/^}/p" ./setup.sh)"

        PKG_MANAGER="unknown"

        # Should return non-zero for unknown package manager
        if check_nss_installed; then
            exit 1
        else
            exit 0
        fi
    '
    [ "$status" -eq 0 ]
}

# ============================================================================
# WSL2 Windows Username Detection Tests
# ============================================================================

@test "Setup flow: get_windows_username function exists" {
    run bash -c '
        eval "$(sed -n "/^get_windows_username()/,/^}/p" ./setup.sh)"
        eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"

        detect_os

        # Function should execute without errors
        get_windows_username || true

        exit 0
    '
    [ "$status" -eq 0 ]
}

@test "Setup flow: get_windows_username returns empty for non-WSL2" {
    if [[ "$(uname -s)" != "Linux" ]] || ! grep -qi microsoft /proc/version 2>/dev/null; then
        run bash -c '
            eval "$(sed -n "/^get_windows_username()/,/^}/p" ./setup.sh)"
            eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"

            detect_os

            # Should return non-zero (no username) for non-WSL2
            if get_windows_username; then
                exit 1
            else
                exit 0
            fi
        '
        [ "$status" -eq 0 ]
    else
        skip "Running on WSL2"
    fi
}

@test "Setup flow: get_windows_username attempts detection on WSL2" {
    if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
        run bash -c '
            eval "$(sed -n "/^get_windows_username()/,/^}/p" ./setup.sh)"
            eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"

            detect_os
            [[ "$OS_TYPE" == "wsl2" ]] || exit 1

            # Function should execute (may or may not find username)
            get_windows_username || true

            exit 0
        '
        [ "$status" -eq 0 ]
    else
        skip "Not running on WSL2"
    fi
}

# ============================================================================
# Error Handling Tests
# ============================================================================

@test "Setup flow: Functions handle missing prerequisites gracefully" {
    run bash -c '
        eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
        eval "$(sed -n "/^detect_package_manager()/,/^}/p" ./setup.sh)"

        # These should not crash even in unusual environments
        detect_os
        detect_package_manager

        exit 0
    '
    [ "$status" -eq 0 ]
}

@test "Setup flow: mkcert URL generation fails for unsupported OS" {
    run bash -c '
        eval "$(sed -n "/^get_mkcert_download_url()/,/^}/p" ./setup.sh)"

        OS_TYPE="unknown"
        ARCH="amd64"

        # Should fail for unknown OS
        if get_mkcert_download_url; then
            exit 1
        else
            exit 0
        fi
    '
    [ "$status" -eq 0 ]
}

# ============================================================================
# Platform-Specific Validation Tests
# ============================================================================

@test "Setup flow: Debian/Ubuntu systems detect apt correctly" {
    if command -v apt &> /dev/null; then
        run bash -c '
            eval "$(sed -n "/^detect_package_manager()/,/^}/p" ./setup.sh)"
            detect_package_manager

            [[ "$PKG_MANAGER" == "apt" ]] || exit 1
            [[ "$NSS_PACKAGE" == "libnss3-tools" ]] || exit 1
            [[ "$CHECK_CMD" == "dpkg -s" ]] || exit 1

            exit 0
        '
        [ "$status" -eq 0 ]
    else
        skip "apt not available on this system"
    fi
}

@test "Setup flow: Fedora systems detect dnf correctly" {
    if command -v dnf &> /dev/null && ! command -v apt &> /dev/null; then
        run bash -c '
            eval "$(sed -n "/^detect_package_manager()/,/^}/p" ./setup.sh)"
            detect_package_manager

            [[ "$PKG_MANAGER" == "dnf" ]] || exit 1
            [[ "$NSS_PACKAGE" == "nss-tools" ]] || exit 1
            [[ "$CHECK_CMD" == "rpm -q" ]] || exit 1

            exit 0
        '
        [ "$status" -eq 0 ]
    else
        skip "dnf not available or not primary package manager"
    fi
}

@test "Setup flow: macOS systems detect brew correctly" {
    if command -v brew &> /dev/null; then
        run bash -c '
            eval "$(sed -n "/^detect_package_manager()/,/^}/p" ./setup.sh)"
            detect_package_manager

            [[ "$PKG_MANAGER" == "brew" ]] || exit 1
            [[ "$NSS_PACKAGE" == "nss" ]] || exit 1
            [[ "$CHECK_CMD" == "brew list" ]] || exit 1

            exit 0
        '
        [ "$status" -eq 0 ]
    else
        skip "brew not available on this system"
    fi
}

# ============================================================================
# Comprehensive System Validation Tests
# ============================================================================

@test "Setup flow: All detection steps complete successfully" {
    run bash -c '
        eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
        eval "$(sed -n "/^get_mkcert_download_url()/,/^}/p" ./setup.sh)"
        eval "$(sed -n "/^detect_package_manager()/,/^}/p" ./setup.sh)"

        # Complete detection workflow
        detect_os || exit 1
        detect_package_manager || exit 1
        get_mkcert_download_url || exit 1

        # All critical variables should be set
        [[ -n "$OS_TYPE" ]] || exit 1
        [[ -n "$ARCH" ]] || exit 1
        [[ -n "$PKG_MANAGER" ]] || exit 1
        [[ -n "$MKCERT_URL" ]] || exit 1
        [[ -n "$MKCERT_OS" ]] || exit 1
        [[ -n "$MKCERT_ARCH" ]] || exit 1

        exit 0
    '
    [ "$status" -eq 0 ]
}

@test "Setup flow: Generated mkcert URL is well-formed" {
    run bash -c '
        eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
        eval "$(sed -n "/^get_mkcert_download_url()/,/^}/p" ./setup.sh)"

        detect_os
        get_mkcert_download_url

        # Validate URL structure
        [[ "$MKCERT_URL" =~ ^https:// ]] || exit 1
        [[ "$MKCERT_URL" =~ dl\.filippo\.io ]] || exit 1
        [[ "$MKCERT_URL" =~ /mkcert/latest ]] || exit 1
        [[ "$MKCERT_URL" =~ \?for= ]] || exit 1

        exit 0
    '
    [ "$status" -eq 0 ]
}

@test "Setup flow: System environment is suitable for setup" {
    run bash -c '
        eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
        eval "$(sed -n "/^detect_package_manager()/,/^}/p" ./setup.sh)"

        detect_os
        detect_package_manager

        # Verify we have a supported OS and architecture
        case "$OS_TYPE" in
            linux|macos|wsl2)
                # Supported OS
                ;;
            *)
                echo "Unsupported OS: $OS_TYPE"
                exit 1
                ;;
        esac

        case "$ARCH" in
            amd64|arm64|armv7)
                # Supported architecture
                ;;
            *)
                echo "Unsupported architecture: $ARCH"
                exit 1
                ;;
        esac

        exit 0
    '
    [ "$status" -eq 0 ]
}
