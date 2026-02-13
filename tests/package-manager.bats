#!/usr/bin/env bats
# Package Manager Detection Tests for setup.sh

# Load test helpers
load helpers/test-helpers
load helpers/mocks

# Setup and teardown functions run before/after each test
setup() {
    save_environment_state
    # Extract just the functions we need from setup.sh
    eval "$(sed -n '/^detect_package_manager()/,/^}/p' ./setup.sh)"
}

teardown() {
    restore_environment_state
    # Reset mocks
    reset_mocks
}

# ============================================================================
# Basic Package Manager Detection Tests
# ============================================================================

@test "detect_package_manager detects apt" {
    mock_command "apt"
    detect_package_manager
    [ "$PKG_MANAGER" = "apt" ]
}

@test "detect_package_manager detects dnf" {
    mock_command "dnf"
    detect_package_manager
    [ "$PKG_MANAGER" = "dnf" ]
}

@test "detect_package_manager detects yum" {
    mock_command "yum"
    detect_package_manager
    [ "$PKG_MANAGER" = "yum" ]
}

@test "detect_package_manager detects pacman" {
    mock_command "pacman"
    detect_package_manager
    [ "$PKG_MANAGER" = "pacman" ]
}

@test "detect_package_manager detects brew" {
    mock_command "brew"
    detect_package_manager
    [ "$PKG_MANAGER" = "brew" ]
}

@test "detect_package_manager detects apk" {
    mock_command "apk"
    detect_package_manager
    [ "$PKG_MANAGER" = "apk" ]
}

@test "detect_package_manager sets unknown when no package manager found" {
    mock_command ""
    detect_package_manager
    [ "$PKG_MANAGER" = "unknown" ]
}

# ============================================================================
# NSS Package Name Tests
# ============================================================================

@test "detect_package_manager sets correct NSS package for apt" {
    mock_command "apt"
    detect_package_manager
    [ "$NSS_PACKAGE" = "libnss3-tools" ]
}

@test "detect_package_manager sets correct NSS package for dnf" {
    mock_command "dnf"
    detect_package_manager
    [ "$NSS_PACKAGE" = "nss-tools" ]
}

@test "detect_package_manager sets correct NSS package for yum" {
    mock_command "yum"
    detect_package_manager
    [ "$NSS_PACKAGE" = "nss-tools" ]
}

@test "detect_package_manager sets correct NSS package for pacman" {
    mock_command "pacman"
    detect_package_manager
    [ "$NSS_PACKAGE" = "nss" ]
}

@test "detect_package_manager sets correct NSS package for brew" {
    mock_command "brew"
    detect_package_manager
    [ "$NSS_PACKAGE" = "nss" ]
}

@test "detect_package_manager sets correct NSS package for apk" {
    mock_command "apk"
    detect_package_manager
    [ "$NSS_PACKAGE" = "nss-tools" ]
}

@test "detect_package_manager sets empty NSS package for unknown manager" {
    mock_command ""
    detect_package_manager
    [ "$NSS_PACKAGE" = "" ]
}

# ============================================================================
# Install Command Tests
# ============================================================================

@test "detect_package_manager sets correct install command for apt" {
    mock_command "apt"
    detect_package_manager
    [ "$INSTALL_CMD" = "sudo apt update && sudo apt install -y" ]
}

@test "detect_package_manager sets correct install command for dnf" {
    mock_command "dnf"
    detect_package_manager
    [ "$INSTALL_CMD" = "sudo dnf install -y" ]
}

@test "detect_package_manager sets correct install command for yum" {
    mock_command "yum"
    detect_package_manager
    [ "$INSTALL_CMD" = "sudo yum install -y" ]
}

@test "detect_package_manager sets correct install command for pacman" {
    mock_command "pacman"
    detect_package_manager
    [ "$INSTALL_CMD" = "sudo pacman -S --noconfirm" ]
}

@test "detect_package_manager sets correct install command for brew" {
    mock_command "brew"
    detect_package_manager
    [ "$INSTALL_CMD" = "brew install" ]
}

@test "detect_package_manager sets correct install command for apk" {
    mock_command "apk"
    detect_package_manager
    [ "$INSTALL_CMD" = "sudo apk add" ]
}

@test "detect_package_manager sets empty install command for unknown manager" {
    mock_command ""
    detect_package_manager
    [ "$INSTALL_CMD" = "" ]
}

# ============================================================================
# Check Command Tests
# ============================================================================

@test "detect_package_manager sets correct check command for apt" {
    mock_command "apt"
    detect_package_manager
    [ "$CHECK_CMD" = "dpkg -s" ]
}

@test "detect_package_manager sets correct check command for dnf" {
    mock_command "dnf"
    detect_package_manager
    [ "$CHECK_CMD" = "rpm -q" ]
}

@test "detect_package_manager sets correct check command for yum" {
    mock_command "yum"
    detect_package_manager
    [ "$CHECK_CMD" = "rpm -q" ]
}

@test "detect_package_manager sets correct check command for pacman" {
    mock_command "pacman"
    detect_package_manager
    [ "$CHECK_CMD" = "pacman -Q" ]
}

@test "detect_package_manager sets correct check command for brew" {
    mock_command "brew"
    detect_package_manager
    [ "$CHECK_CMD" = "brew list" ]
}

@test "detect_package_manager sets correct check command for apk" {
    mock_command "apk"
    detect_package_manager
    [ "$CHECK_CMD" = "apk info -e" ]
}

@test "detect_package_manager sets empty check command for unknown manager" {
    mock_command ""
    detect_package_manager
    [ "$CHECK_CMD" = "" ]
}

# ============================================================================
# All Variables Set Tests
# ============================================================================

@test "detect_package_manager sets all variables for apt" {
    mock_command "apt"
    detect_package_manager

    [ "$PKG_MANAGER" = "apt" ]
    [ "$NSS_PACKAGE" = "libnss3-tools" ]
    [ "$INSTALL_CMD" = "sudo apt update && sudo apt install -y" ]
    [ "$CHECK_CMD" = "dpkg -s" ]
}

@test "detect_package_manager sets all variables for dnf" {
    mock_command "dnf"
    detect_package_manager

    [ "$PKG_MANAGER" = "dnf" ]
    [ "$NSS_PACKAGE" = "nss-tools" ]
    [ "$INSTALL_CMD" = "sudo dnf install -y" ]
    [ "$CHECK_CMD" = "rpm -q" ]
}

@test "detect_package_manager sets all variables for yum" {
    mock_command "yum"
    detect_package_manager

    [ "$PKG_MANAGER" = "yum" ]
    [ "$NSS_PACKAGE" = "nss-tools" ]
    [ "$INSTALL_CMD" = "sudo yum install -y" ]
    [ "$CHECK_CMD" = "rpm -q" ]
}

@test "detect_package_manager sets all variables for pacman" {
    mock_command "pacman"
    detect_package_manager

    [ "$PKG_MANAGER" = "pacman" ]
    [ "$NSS_PACKAGE" = "nss" ]
    [ "$INSTALL_CMD" = "sudo pacman -S --noconfirm" ]
    [ "$CHECK_CMD" = "pacman -Q" ]
}

@test "detect_package_manager sets all variables for brew" {
    mock_command "brew"
    detect_package_manager

    [ "$PKG_MANAGER" = "brew" ]
    [ "$NSS_PACKAGE" = "nss" ]
    [ "$INSTALL_CMD" = "brew install" ]
    [ "$CHECK_CMD" = "brew list" ]
}

@test "detect_package_manager sets all variables for apk" {
    mock_command "apk"
    detect_package_manager

    [ "$PKG_MANAGER" = "apk" ]
    [ "$NSS_PACKAGE" = "nss-tools" ]
    [ "$INSTALL_CMD" = "sudo apk add" ]
    [ "$CHECK_CMD" = "apk info -e" ]
}

@test "detect_package_manager sets all variables to empty for unknown manager" {
    mock_command ""
    detect_package_manager

    [ "$PKG_MANAGER" = "unknown" ]
    [ "$NSS_PACKAGE" = "" ]
    [ "$INSTALL_CMD" = "" ]
    [ "$CHECK_CMD" = "" ]
}

# ============================================================================
# Priority Order Tests (apt has highest priority)
# ============================================================================

@test "detect_package_manager prefers apt over other package managers" {
    # Mock multiple package managers available
    mock_command "apt" "dnf" "yum"
    detect_package_manager
    [ "$PKG_MANAGER" = "apt" ]
}

@test "detect_package_manager prefers dnf over yum when apt not available" {
    # Mock dnf and yum available (but not apt)
    mock_command "dnf" "yum"
    detect_package_manager
    [ "$PKG_MANAGER" = "dnf" ]
}

@test "detect_package_manager prefers yum over pacman when apt/dnf not available" {
    # Mock yum and pacman available (but not apt/dnf)
    mock_command "yum" "pacman"
    detect_package_manager
    [ "$PKG_MANAGER" = "yum" ]
}

@test "detect_package_manager prefers pacman over brew when apt/dnf/yum not available" {
    # Mock pacman and brew available (but not apt/dnf/yum)
    mock_command "pacman" "brew"
    detect_package_manager
    [ "$PKG_MANAGER" = "pacman" ]
}

@test "detect_package_manager prefers brew over apk when apt/dnf/yum/pacman not available" {
    # Mock brew and apk available (but not apt/dnf/yum/pacman)
    mock_command "brew" "apk"
    detect_package_manager
    [ "$PKG_MANAGER" = "brew" ]
}

# ============================================================================
# Real System Detection Tests (conditional on actual environment)
# ============================================================================

@test "detect_package_manager detects actual system package manager" {
    # This test runs on the actual system and verifies detection works
    run bash -c '
        eval "$(sed -n "/^detect_package_manager()/,/^}/p" ./setup.sh)"
        detect_package_manager
        [[ -n "$PKG_MANAGER" ]]
    '
    [ "$status" -eq 0 ]
}

@test "detect_package_manager detected package manager is valid" {
    # This test verifies the detected package manager is one of the supported ones
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
# Edge Cases and Consistency Tests
# ============================================================================

@test "detect_package_manager variables are non-null for supported package managers" {
    # Test each supported package manager has all variables set
    local managers=("apt" "dnf" "yum" "pacman" "brew" "apk")

    for mgr in "${managers[@]}"; do
        mock_command "$mgr"
        detect_package_manager

        [[ -n "$PKG_MANAGER" ]] || fail "PKG_MANAGER not set for $mgr"
        [[ -n "$NSS_PACKAGE" ]] || fail "NSS_PACKAGE not set for $mgr"
        [[ -n "$INSTALL_CMD" ]] || fail "INSTALL_CMD not set for $mgr"
        [[ -n "$CHECK_CMD" ]] || fail "CHECK_CMD not set for $mgr"
    done
}

@test "detect_package_manager RPM-based systems use rpm for checking" {
    # Both dnf and yum should use rpm -q for checking packages
    mock_command "dnf"
    detect_package_manager
    [ "$CHECK_CMD" = "rpm -q" ]

    mock_command "yum"
    detect_package_manager
    [ "$CHECK_CMD" = "rpm -q" ]
}

@test "detect_package_manager RPM-based systems use nss-tools package" {
    # Both dnf and yum should use nss-tools (not libnss3-tools)
    mock_command "dnf"
    detect_package_manager
    [ "$NSS_PACKAGE" = "nss-tools" ]

    mock_command "yum"
    detect_package_manager
    [ "$NSS_PACKAGE" = "nss-tools" ]
}

@test "detect_package_manager brew does not use sudo" {
    mock_command "brew"
    detect_package_manager

    # brew commands should not have sudo prefix
    [[ ! "$INSTALL_CMD" =~ sudo ]]
}

@test "detect_package_manager non-brew package managers use sudo" {
    local managers=("apt" "dnf" "yum" "pacman" "apk")

    for mgr in "${managers[@]}"; do
        mock_command "$mgr"
        detect_package_manager

        # Non-brew commands should have sudo prefix
        [[ "$INSTALL_CMD" =~ sudo ]] || fail "INSTALL_CMD for $mgr should contain sudo"
    done
}

@test "detect_package_manager apt includes update command" {
    mock_command "apt"
    detect_package_manager

    # apt should include 'apt update' in install command
    [[ "$INSTALL_CMD" =~ "apt update" ]]
}

@test "detect_package_manager pacman uses noconfirm flag" {
    mock_command "pacman"
    detect_package_manager

    # pacman should use --noconfirm flag
    [[ "$INSTALL_CMD" =~ "--noconfirm" ]]
}

# ============================================================================
# Integration with Actual System Commands
# ============================================================================

@test "detect_package_manager detects Debian/Ubuntu systems with apt" {
    # Only run on systems with apt
    if command -v apt &> /dev/null; then
        run bash -c '
            eval "$(sed -n "/^detect_package_manager()/,/^}/p" ./setup.sh)"
            detect_package_manager
            [[ "$PKG_MANAGER" == "apt" ]]
        '
        [ "$status" -eq 0 ]
    else
        skip "apt not available on this system"
    fi
}

@test "detect_package_manager detects Fedora systems with dnf" {
    # Only run on systems with dnf
    if command -v dnf &> /dev/null && ! command -v apt &> /dev/null; then
        run bash -c '
            eval "$(sed -n "/^detect_package_manager()/,/^}/p" ./setup.sh)"
            detect_package_manager
            [[ "$PKG_MANAGER" == "dnf" ]]
        '
        [ "$status" -eq 0 ]
    else
        skip "dnf not available or not primary package manager on this system"
    fi
}

@test "detect_package_manager detects RHEL/CentOS systems with yum" {
    # Only run on systems with yum (and no dnf or apt)
    if command -v yum &> /dev/null && ! command -v dnf &> /dev/null && ! command -v apt &> /dev/null; then
        run bash -c '
            eval "$(sed -n "/^detect_package_manager()/,/^}/p" ./setup.sh)"
            detect_package_manager
            [[ "$PKG_MANAGER" == "yum" ]]
        '
        [ "$status" -eq 0 ]
    else
        skip "yum not available or not primary package manager on this system"
    fi
}

@test "detect_package_manager detects Arch Linux systems with pacman" {
    # Only run on systems with pacman
    if command -v pacman &> /dev/null && ! command -v apt &> /dev/null; then
        run bash -c '
            eval "$(sed -n "/^detect_package_manager()/,/^}/p" ./setup.sh)"
            detect_package_manager
            [[ "$PKG_MANAGER" == "pacman" ]]
        '
        [ "$status" -eq 0 ]
    else
        skip "pacman not available or not primary package manager on this system"
    fi
}

@test "detect_package_manager detects macOS systems with brew" {
    # Only run on systems with brew
    if command -v brew &> /dev/null; then
        run bash -c '
            eval "$(sed -n "/^detect_package_manager()/,/^}/p" ./setup.sh)"
            detect_package_manager
            [[ "$PKG_MANAGER" == "brew" ]]
        '
        [ "$status" -eq 0 ]
    else
        skip "brew not available on this system"
    fi
}

@test "detect_package_manager detects Alpine Linux systems with apk" {
    # Only run on systems with apk
    if command -v apk &> /dev/null && ! command -v apt &> /dev/null; then
        run bash -c '
            eval "$(sed -n "/^detect_package_manager()/,/^}/p" ./setup.sh)"
            detect_package_manager
            [[ "$PKG_MANAGER" == "apk" ]]
        '
        [ "$status" -eq 0 ]
    else
        skip "apk not available or not primary package manager on this system"
    fi
}
