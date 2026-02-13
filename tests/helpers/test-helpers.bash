#!/bin/bash
# Bats test helper functions for docker-proxy setup testing

# Load setup.sh functions
load_setup_functions() {
    # Source the functions from setup.sh
    # Using 2>/dev/null to suppress errors if already loaded
    source ./setup.sh 2>/dev/null || true
}

# State management helpers
save_environment_state() {
    export SAVED_OS_TYPE="$OS_TYPE"
    export SAVED_ARCH="$ARCH"
    export SAVED_MKCERT_URL="$MKCERT_URL"
    export SAVED_MKCERT_OS="$MKCERT_OS"
    export SAVED_MKCERT_ARCH="$MKCERT_ARCH"
    export SAVED_PKG_MANAGER="$PKG_MANAGER"
    export SAVED_NSS_PACKAGE="$NSS_PACKAGE"
    export SAVED_INSTALL_CMD="$INSTALL_CMD"
    export SAVED_CHECK_CMD="$CHECK_CMD"
}

restore_environment_state() {
    OS_TYPE="$SAVED_OS_TYPE"
    ARCH="$SAVED_ARCH"
    MKCERT_URL="$SAVED_MKCERT_URL"
    MKCERT_OS="$SAVED_MKCERT_OS"
    MKCERT_ARCH="$SAVED_MKCERT_ARCH"
    PKG_MANAGER="$SAVED_PKG_MANAGER"
    NSS_PACKAGE="$SAVED_NSS_PACKAGE"
    INSTALL_CMD="$SAVED_INSTALL_CMD"
    CHECK_CMD="$SAVED_CHECK_CMD"
}

# Assertion helpers
fail() {
    local message="$1"
    echo "FAIL: $message" >&2
    return 1
}

assert_variable_set() {
    local var_name="$1"
    local var_value="${!var_name}"

    if [[ -z "$var_value" ]]; then
        echo "❌ FAIL: $var_name not set"
        return 1
    else
        echo "✅ PASS: $var_name is set ($var_value)"
        return 0
    fi
}

assert_variable_equals() {
    local var_name="$1"
    local expected="$2"
    local var_value="${!var_name}"

    if [[ "$var_value" == "$expected" ]]; then
        echo "✅ PASS: $var_name equals expected value ($expected)"
        return 0
    else
        echo "❌ FAIL: $var_name does not equal expected value"
        echo "   Expected: $expected"
        echo "   Got: $var_value"
        return 1
    fi
}

assert_variable_matches() {
    local var_name="$1"
    local pattern="$2"
    local var_value="${!var_name}"

    if [[ "$var_value" =~ $pattern ]]; then
        echo "✅ PASS: $var_name matches pattern ($var_value)"
        return 0
    else
        echo "❌ FAIL: $var_name does not match pattern"
        echo "   Pattern: $pattern"
        echo "   Got: $var_value"
        return 1
    fi
}

assert_command_exists() {
    local cmd="$1"

    if command -v "$cmd" &>/dev/null; then
        echo "✅ PASS: Command '$cmd' exists"
        return 0
    else
        echo "❌ FAIL: Command '$cmd' not found"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"

    if [[ -f "$file" ]]; then
        echo "✅ PASS: File '$file' exists"
        return 0
    else
        echo "❌ FAIL: File '$file' does not exist"
        return 1
    fi
}

assert_directory_exists() {
    local dir="$1"

    if [[ -d "$dir" ]]; then
        echo "✅ PASS: Directory '$dir' exists"
        return 0
    else
        echo "❌ FAIL: Directory '$dir' does not exist"
        return 1
    fi
}

# Mock/stub helpers
mock_command() {
    local cmd="$1"
    local output="$2"
    local exit_code="${3:-0}"

    eval "$cmd() { echo '$output'; return $exit_code; }"
}

stub_uname() {
    local flag="$1"
    local output="$2"

    uname() {
        if [[ "$1" == "$flag" ]]; then
            echo "$output"
        fi
    }
}

# Docker helpers
assert_docker_network_exists() {
    local network_name="$1"

    if docker network inspect "$network_name" &>/dev/null; then
        echo "✅ PASS: Docker network '$network_name' exists"
        return 0
    else
        echo "❌ FAIL: Docker network '$network_name' does not exist"
        return 1
    fi
}

assert_docker_container_running() {
    local container_name="$1"

    if docker ps --filter "name=$container_name" --filter "status=running" | grep -q "$container_name"; then
        echo "✅ PASS: Docker container '$container_name' is running"
        return 0
    else
        echo "❌ FAIL: Docker container '$container_name' is not running"
        return 1
    fi
}

# File content helpers
assert_file_contains() {
    local file="$1"
    local pattern="$2"

    if [[ ! -f "$file" ]]; then
        echo "❌ FAIL: File '$file' does not exist"
        return 1
    fi

    if grep -q "$pattern" "$file"; then
        echo "✅ PASS: File '$file' contains pattern '$pattern'"
        return 0
    else
        echo "❌ FAIL: File '$file' does not contain pattern '$pattern'"
        return 1
    fi
}

# Cleanup helpers
cleanup_test_files() {
    local test_dir="${1:-.}"

    # Remove common test artifacts
    rm -f "$test_dir"/*.test
    rm -f "$test_dir"/*.tmp
    rm -rf "$test_dir"/test-*
}

# Logging helpers for tests
test_section() {
    local section_name="$1"
    echo ""
    echo "===== $section_name ====="
}

test_case() {
    local test_name="$1"
    echo ""
    echo "Test: $test_name"
}

# Export functions for use in bats tests
export -f fail
export -f load_setup_functions
export -f save_environment_state
export -f restore_environment_state
export -f assert_variable_set
export -f assert_variable_equals
export -f assert_variable_matches
export -f assert_command_exists
export -f assert_file_exists
export -f assert_directory_exists
export -f mock_command
export -f stub_uname
export -f assert_docker_network_exists
export -f assert_docker_container_running
export -f assert_file_contains
export -f cleanup_test_files
export -f test_section
export -f test_case
