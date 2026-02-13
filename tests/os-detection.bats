#!/usr/bin/env bats
# OS Detection Tests for setup.sh

# Load test helpers
load helpers/test-helpers
load helpers/mocks

# Setup and teardown functions run before/after each test
setup() {
    save_environment_state
    # Extract just the functions we need from setup.sh
    eval "$(sed -n '/^detect_os()/,/^}/p' ./setup.sh)"
    eval "$(sed -n '/^get_mkcert_download_url()/,/^}/p' ./setup.sh)"
}

teardown() {
    restore_environment_state
}

# ============================================================================
# Basic OS Detection Tests
# ============================================================================

@test "detect_os sets OS_TYPE variable" {
    run bash -c 'log_error() { echo "$@" >&2; }; export -f log_error; eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"; detect_os; [[ -n "$OS_TYPE" ]]'
    [ "$status" -eq 0 ]
}

@test "detect_os sets ARCH variable" {
    run bash -c 'log_error() { echo "$@" >&2; }; export -f log_error; eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"; detect_os; [[ -n "$ARCH" ]]'
    [ "$status" -eq 0 ]
}

@test "detect_os detects Linux on Linux system" {
    # Test on actual Linux system (not WSL2)
    if [[ "$(uname -s)" == "Linux" ]] && ! grep -qi microsoft /proc/version 2>/dev/null; then
        run bash -c 'log_error() { echo "$@" >&2; }; export -f log_error; eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"; detect_os; [[ "$OS_TYPE" == "linux" ]]'
        [ "$status" -eq 0 ]
    else
        skip "Cannot test Linux detection on non-Linux or WSL2 system"
    fi
}

@test "detect_os detects macOS on macOS system" {
    # Test on actual macOS system
    if [[ "$(uname -s)" == "Darwin" ]]; then
        run bash -c 'log_error() { echo "$@" >&2; }; export -f log_error; eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"; detect_os; [[ "$OS_TYPE" == "macos" ]]'
        [ "$status" -eq 0 ]
    else
        skip "Not running on macOS"
    fi
}

@test "detect_os detects WSL2 on WSL2 system" {
    # WSL2 detection requires /proc/version with 'microsoft'
    if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
        run bash -c 'log_error() { echo "$@" >&2; }; export -f log_error; eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"; detect_os; [[ "$OS_TYPE" == "wsl2" ]]'
        [ "$status" -eq 0 ]
    else
        skip "Cannot test WSL2 detection on non-WSL2 system"
    fi
}

# ============================================================================
# Architecture Detection Tests - Testing normalization logic
# ============================================================================

@test "detect_os normalizes x86_64 to amd64" {
    # Mock uname to return x86_64
    run bash -c '
        log_error() { echo "$@" >&2; }
        export -f log_error
        source tests/helpers/mocks.bash
        mock_uname "-m" "Linux" "x86_64"
        eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
        detect_os
        echo "$ARCH"
    '
    [ "$status" -eq 0 ]
    [ "$output" = "amd64" ]
}

@test "detect_os normalizes aarch64 to arm64" {
    # Mock uname to return aarch64
    run bash -c '
        log_error() { echo "$@" >&2; }
        export -f log_error
        source tests/helpers/mocks.bash
        mock_uname "-m" "Linux" "aarch64"
        eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
        detect_os
        echo "$ARCH"
    '
    [ "$status" -eq 0 ]
    [ "$output" = "arm64" ]
}

@test "detect_os normalizes arm64 to arm64" {
    # Mock uname to return arm64
    run bash -c '
        log_error() { echo "$@" >&2; }
        export -f log_error
        source tests/helpers/mocks.bash
        mock_uname "-m" "Darwin" "arm64"
        eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
        detect_os
        echo "$ARCH"
    '
    [ "$status" -eq 0 ]
    [ "$output" = "arm64" ]
}

@test "detect_os normalizes armv7l to armv7" {
    # Mock uname to return armv7l
    run bash -c '
        log_error() { echo "$@" >&2; }
        export -f log_error
        source tests/helpers/mocks.bash
        mock_uname "-m" "Linux" "armv7l"
        eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
        detect_os
        echo "$ARCH"
    '
    [ "$status" -eq 0 ]
    [ "$output" = "armv7" ]
}

@test "detect_os handles unsupported architecture" {
    # Mock uname to return unsupported architecture
    run bash -c '
        log_error() { echo "$@" >&2; }
        export -f log_error
        source tests/helpers/mocks.bash
        mock_uname "-m" "Linux" "mips64"
        eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
        detect_os 2>&1
    '
    # The script should exit with error code 1 for unsupported architecture
    [ "$status" -eq 1 ]
}

# ============================================================================
# Integration Tests (combining detect_os and get_mkcert_download_url)
# ============================================================================

@test "Full workflow: detect OS and generate mkcert URL" {
    run bash -c '
        log_error() { echo "$@" >&2; }
        export -f log_error
        eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
        eval "$(sed -n "/^get_mkcert_download_url()/,/^}/p" ./setup.sh)"
        detect_os
        get_mkcert_download_url
        [[ -n "$OS_TYPE" && -n "$ARCH" && -n "$MKCERT_URL" ]]
    '
    [ "$status" -eq 0 ]
}

@test "Full workflow: Linux x86_64 system produces valid URL" {
    # This test uses actual system detection if on Linux
    if [[ "$(uname -s)" == "Linux" ]] && ! grep -qi microsoft /proc/version 2>/dev/null; then
        run bash -c '
            log_error() { echo "$@" >&2; }
            export -f log_error
            eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
            eval "$(sed -n "/^get_mkcert_download_url()/,/^}/p" ./setup.sh)"
            detect_os
            get_mkcert_download_url
            [[ "$OS_TYPE" == "linux" && "$MKCERT_URL" =~ ^https://dl.filippo.io/mkcert/latest\?for=linux/ ]]
        '
        [ "$status" -eq 0 ]
    else
        skip "Not running on native Linux"
    fi
}

@test "Full workflow: macOS system produces valid URL" {
    # This test uses actual system detection if on macOS
    if [[ "$(uname -s)" == "Darwin" ]]; then
        run bash -c '
            log_error() { echo "$@" >&2; }
            export -f log_error
            eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
            eval "$(sed -n "/^get_mkcert_download_url()/,/^}/p" ./setup.sh)"
            detect_os
            get_mkcert_download_url
            [[ "$OS_TYPE" == "macos" && "$MKCERT_URL" =~ ^https://dl.filippo.io/mkcert/latest\?for=darwin/ ]]
        '
        [ "$status" -eq 0 ]
    else
        skip "Not running on macOS"
    fi
}

@test "Full workflow: WSL2 system produces valid Linux URL" {
    # This test uses actual system detection if on WSL2
    if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
        run bash -c '
            log_error() { echo "$@" >&2; }
            export -f log_error
            eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
            eval "$(sed -n "/^get_mkcert_download_url()/,/^}/p" ./setup.sh)"
            detect_os
            get_mkcert_download_url
            [[ "$OS_TYPE" == "wsl2" && "$MKCERT_URL" =~ ^https://dl.filippo.io/mkcert/latest\?for=linux/ && "$MKCERT_OS" == "linux" ]]
        '
        [ "$status" -eq 0 ]
    else
        skip "Not running on WSL2"
    fi
}

# ============================================================================
# Edge Cases and Error Handling
# ============================================================================

@test "get_mkcert_download_url URL format is valid" {
    OS_TYPE="linux"
    ARCH="amd64"
    get_mkcert_download_url

    # Verify URL structure
    [[ "$MKCERT_URL" =~ ^https:// ]]
    [[ "$MKCERT_URL" =~ dl\.filippo\.io/mkcert/latest ]]
    [[ "$MKCERT_URL" =~ \?for= ]]
}

@test "Current system architecture is supported" {
    local current_arch=$(uname -m)
    case "$current_arch" in
        x86_64|aarch64|arm64|armv7l)
            # Supported architecture
            true
            ;;
        *)
            fail "Current architecture ($current_arch) is not supported"
            ;;
    esac
}

@test "Detected OS_TYPE is a valid value" {
    run bash -c '
        log_error() { echo "$@" >&2; }
        export -f log_error
        eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
        detect_os
        case "$OS_TYPE" in
            linux|macos|wsl2|unknown)
                exit 0
                ;;
            *)
                echo "Invalid OS_TYPE: $OS_TYPE"
                exit 1
                ;;
        esac
    '
    [ "$status" -eq 0 ]
}

@test "armv7 architecture maps to arm in mkcert URL" {
    OS_TYPE="linux"
    ARCH="armv7"
    get_mkcert_download_url

    # armv7 should be mapped to "arm" in the URL
    [[ "$MKCERT_URL" =~ linux/arm$ ]]
    [ "$MKCERT_ARCH" = "arm" ]
}

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
