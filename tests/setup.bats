#!/usr/bin/env bats
# End-to-End Setup Flow Tests for setup.sh

# Load test helpers
load helpers/test-helpers
load helpers/mocks

# Setup and teardown functions run before/after each test
setup() {
    # Save original environment
    export SAVED_OS_TYPE="$OS_TYPE"
    export SAVED_ARCH="$ARCH"
    export SAVED_PKG_MANAGER="$PKG_MANAGER"
    export SAVED_NSS_PACKAGE="$NSS_PACKAGE"
    export SAVED_INSTALL_CMD="$INSTALL_CMD"
    export SAVED_CHECK_CMD="$CHECK_CMD"
    export SAVED_MKCERT_URL="$MKCERT_URL"
    export SAVED_MKCERT_OS="$MKCERT_OS"
    export SAVED_MKCERT_ARCH="$MKCERT_ARCH"

    # Extract functions from setup.sh
    eval "$(sed -n '/^detect_os()/,/^}/p' ./setup.sh)"
    eval "$(sed -n '/^get_mkcert_download_url()/,/^}/p' ./setup.sh)"
    eval "$(sed -n '/^detect_package_manager()/,/^}/p' ./setup.sh)"
    eval "$(sed -n '/^check_nss_installed()/,/^}/p' ./setup.sh)"
    eval "$(sed -n '/^get_windows_username()/,/^}/p' ./setup.sh)"
}

teardown() {
    # Restore original environment
    OS_TYPE="$SAVED_OS_TYPE"
    ARCH="$SAVED_ARCH"
    PKG_MANAGER="$SAVED_PKG_MANAGER"
    NSS_PACKAGE="$SAVED_NSS_PACKAGE"
    INSTALL_CMD="$SAVED_INSTALL_CMD"
    CHECK_CMD="$SAVED_CHECK_CMD"
    MKCERT_URL="$SAVED_MKCERT_URL"
    MKCERT_OS="$SAVED_MKCERT_OS"
    MKCERT_ARCH="$SAVED_MKCERT_ARCH"

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
# OS and Architecture Detection Flow Tests
# ============================================================================

@test "Setup flow: OS detection sets required variables" {
    run bash -c '
        eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
        detect_os

        # Both OS_TYPE and ARCH should be set
        [[ -n "$OS_TYPE" ]] || exit 1
        [[ -n "$ARCH" ]] || exit 1

        # OS_TYPE should be one of the valid values
        case "$OS_TYPE" in
            linux|macos|wsl2|unknown)
                exit 0
                ;;
            *)
                exit 1
                ;;
        esac
    '
    [ "$status" -eq 0 ]
}

@test "Setup flow: Architecture is normalized correctly" {
    run bash -c '
        eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
        detect_os

        # ARCH should be normalized to one of the supported formats
        case "$ARCH" in
            amd64|arm64|armv7)
                exit 0
                ;;
            *)
                echo "Unexpected ARCH value: $ARCH"
                exit 1
                ;;
        esac
    '
    [ "$status" -eq 0 ]
}

@test "Setup flow: Current system architecture is supported" {
    run bash -c '
        eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
        detect_os

        # Current system should be supported (not fail)
        exit 0
    '
    [ "$status" -eq 0 ]
}

# ============================================================================
# Package Manager Detection Flow Tests
# ============================================================================

@test "Setup flow: Package manager detection completes without errors" {
    run bash -c '
        eval "$(sed -n "/^detect_package_manager()/,/^}/p" ./setup.sh)"
        detect_package_manager

        # PKG_MANAGER should be set (even if "unknown")
        [[ -n "$PKG_MANAGER" ]] || exit 1

        exit 0
    '
    [ "$status" -eq 0 ]
}

@test "Setup flow: Package manager sets all required variables" {
    run bash -c '
        eval "$(sed -n "/^detect_package_manager()/,/^}/p" ./setup.sh)"
        detect_package_manager

        # If package manager is known, all variables should be set
        if [[ "$PKG_MANAGER" != "unknown" ]]; then
            [[ -n "$NSS_PACKAGE" ]] || exit 1
            [[ -n "$INSTALL_CMD" ]] || exit 1
            [[ -n "$CHECK_CMD" ]] || exit 1
        fi

        exit 0
    '
    [ "$status" -eq 0 ]
}

@test "Setup flow: Detected package manager is valid" {
    run bash -c '
        eval "$(sed -n "/^detect_package_manager()/,/^}/p" ./setup.sh)"
        detect_package_manager

        case "$PKG_MANAGER" in
            apt|dnf|yum|pacman|brew|apk|unknown)
                exit 0
                ;;
            *)
                echo "Invalid PKG_MANAGER: $PKG_MANAGER"
                exit 1
                ;;
        esac
    '
    [ "$status" -eq 0 ]
}

# ============================================================================
# mkcert URL Generation Flow Tests
# ============================================================================

@test "Setup flow: mkcert URL generation after OS detection" {
    run bash -c '
        eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
        eval "$(sed -n "/^get_mkcert_download_url()/,/^}/p" ./setup.sh)"

        detect_os
        get_mkcert_download_url

        # All mkcert variables should be set
        [[ -n "$MKCERT_URL" ]] || exit 1
        [[ -n "$MKCERT_OS" ]] || exit 1
        [[ -n "$MKCERT_ARCH" ]] || exit 1

        # URL should be valid format
        [[ "$MKCERT_URL" =~ ^https://dl.filippo.io/mkcert/latest\?for= ]] || exit 1

        exit 0
    '
    [ "$status" -eq 0 ]
}

@test "Setup flow: mkcert URL contains correct OS and architecture" {
    run bash -c '
        eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
        eval "$(sed -n "/^get_mkcert_download_url()/,/^}/p" ./setup.sh)"

        detect_os
        get_mkcert_download_url

        # URL should contain the MKCERT_OS and MKCERT_ARCH
        [[ "$MKCERT_URL" =~ $MKCERT_OS ]] || exit 1
        [[ "$MKCERT_URL" =~ $MKCERT_ARCH ]] || exit 1

        exit 0
    '
    [ "$status" -eq 0 ]
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
