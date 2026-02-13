#!/bin/bash
# Mock utilities for external commands used in setup.sh testing
# Compatible with bash 3.2+ (macOS default)

# Mock state storage - using simple variables instead of associative arrays
# for bash 3.2 compatibility

# Initialize mock tracking
init_mocks() {
    # Reset all mock tracking variables
    # We use dynamic variable names like MOCK_CALL_COUNT_<cmd>
    # to simulate associative array behavior in bash 3.2
    :
}

# Reset all mocks
reset_mocks() {
    init_mocks
    # Restore original commands by unsetting mock functions
    unset -f uname grep curl docker
    unset -f apt dpkg dnf yum rpm pacman brew apk
    unset -f mkcert command sudo mkdir cp chmod mktemp mv

    # Clear mock tracking variables (including MOCK_COMMAND_EXISTS and MOCK_UNAME_*)
    unset $(set | grep '^MOCK_' | cut -d= -f1)
}

# Record mock call
record_mock_call() {
    local cmd="$1"
    shift
    local args="$*"

    # Sanitize command name for use in variable names
    local var_suffix=$(echo "$cmd" | tr '[:lower:]' '[:upper:]' | tr -c '[:alnum:]' '_')
    local count_var="MOCK_CALL_COUNT_${var_suffix}"
    local args_var="MOCK_CALL_ARGS_${var_suffix}"

    # Get current count
    local current_count=$(eval "echo \${${count_var}:-0}")

    # Increment call count
    eval "${count_var}=$((current_count + 1))"

    # Store arguments (using \x1f as separator - less likely to appear in arguments)
    eval "${args_var}=\"\${${args_var}}\$'\\x1f'\$args\""
}

# Get mock call count
get_mock_call_count() {
    local cmd="$1"
    local var_suffix=$(echo "$cmd" | tr '[:lower:]' '[:upper:]' | tr -c '[:alnum:]' '_')
    local count_var="MOCK_CALL_COUNT_${var_suffix}"
    eval "echo \${${count_var}:-0}"
}

# Get mock call arguments
get_mock_call_args() {
    local cmd="$1"
    local var_suffix=$(echo "$cmd" | tr '[:lower:]' '[:upper:]' | tr -c '[:alnum:]' '_')
    local args_var="MOCK_CALL_ARGS_${var_suffix}"
    eval "echo \"\${${args_var}}\""
}

# Set mock return value
set_mock_return() {
    local cmd="$1"
    local return_value="$2"
    local exit_code="${3:-0}"

    local var_suffix=$(echo "$cmd" | tr '[:lower:]' '[:upper:]' | tr -c '[:alnum:]' '_')
    local return_var="MOCK_RETURN_VALUES_${var_suffix}"
    local exit_var="MOCK_EXIT_CODES_${var_suffix}"

    eval "${return_var}=\"\${return_value}\""
    eval "${exit_var}=\${exit_code}"
}

# Mock: uname
mock_uname() {
    local flag="$1"
    # Store in global variables so the exported uname function can access them
    MOCK_UNAME_OS="${2:-Linux}"
    MOCK_UNAME_ARCH="${3:-x86_64}"
    export MOCK_UNAME_OS
    export MOCK_UNAME_ARCH

    uname() {
        record_mock_call "uname" "$@"
        case "$1" in
            -s)
                echo "$MOCK_UNAME_OS"
                ;;
            -m)
                echo "$MOCK_UNAME_ARCH"
                ;;
            *)
                echo "$MOCK_UNAME_OS"
                ;;
        esac
        return 0
    }
    export -f uname
}

# Mock: grep
mock_grep() {
    local pattern="$1"
    local match="${2:-true}"
    local exit_code=0

    if [[ "$match" == "false" ]]; then
        exit_code=1
    fi

    grep() {
        record_mock_call "grep" "$@"

        # Handle common grep flags
        local quiet=false
        local invert=false
        local case_insensitive=false

        while [[ "$1" == -* ]]; do
            case "$1" in
                -q|-qi) quiet=true ;;
                -i) case_insensitive=true ;;
                -v) invert=true ;;
            esac
            shift
        done

        if [[ "$quiet" == "false" ]]; then
            eval "echo \"\${MOCK_RETURN_VALUES_GREP}\""
        fi

        eval "return \${MOCK_EXIT_CODES_GREP:-$exit_code}"
    }
    export -f grep
}

# Mock: curl
mock_curl() {
    local success="${1:-true}"

    curl() {
        record_mock_call "curl" "$@"

        if [[ "$success" == "true" ]]; then
            eval "echo \"\${MOCK_RETURN_VALUES_CURL:-mocked curl output}\""
            return 0
        else
            echo "curl: error" >&2
            eval "return \${MOCK_EXIT_CODES_CURL:-1}"
        fi
    }
    export -f curl
}

# Mock: docker
mock_docker() {
    local subcommand="$1"
    local success="${2:-true}"

    docker() {
        record_mock_call "docker" "$@"

        local cmd="$1"

        case "$cmd" in
            info)
                if [[ "$success" == "true" ]]; then
                    echo "Mocked docker info"
                    return 0
                else
                    return 1
                fi
                ;;
            network)
                if [[ "$2" == "inspect" ]]; then
                    if [[ "$success" == "true" ]]; then
                        echo '[{"Name": "traefik-proxy"}]'
                        return 0
                    else
                        return 1
                    fi
                elif [[ "$2" == "create" ]]; then
                    echo "traefik-proxy"
                    return 0
                fi
                ;;
            compose|ps|logs)
                eval "echo \"\${MOCK_RETURN_VALUES_DOCKER}\""
                eval "return \${MOCK_EXIT_CODES_DOCKER:-0}"
                ;;
            *)
                eval "echo \"\${MOCK_RETURN_VALUES_DOCKER}\""
                eval "return \${MOCK_EXIT_CODES_DOCKER:-0}"
                ;;
        esac
    }
    export -f docker
}

# Mock: command (used for checking if commands exist)
mock_command() {
    # Store as a global variable so the exported command function can access it
    # Using space-separated string instead of array for bash 3.2 compatibility
    MOCK_COMMAND_EXISTS="$*"
    export MOCK_COMMAND_EXISTS

    command() {
        record_mock_call "command" "$@"

        if [[ "$1" == "-v" ]]; then
            local check_cmd="$2"
            # Iterate over space-separated commands
            for existing_cmd in $MOCK_COMMAND_EXISTS; do
                if [[ "$check_cmd" == "$existing_cmd" ]]; then
                    echo "/usr/bin/$check_cmd"
                    return 0
                fi
            done
            return 1
        fi

        # Default: execute the command
        builtin command "$@"
    }
    export -f command
}

# Mock: apt (Debian/Ubuntu package manager)
mock_apt() {
    local success="${1:-true}"

    apt() {
        record_mock_call "apt" "$@"
        if [[ "$success" == "true" ]]; then
            echo "Mocked apt $*"
            return 0
        else
            return 1
        fi
    }
    export -f apt
}

# Mock: dpkg (Debian package query)
mock_dpkg() {
    local package_installed="${1:-true}"

    dpkg() {
        record_mock_call "dpkg" "$@"
        if [[ "$1" == "-s" ]]; then
            if [[ "$package_installed" == "true" ]]; then
                echo "Status: install ok installed"
                return 0
            else
                return 1
            fi
        fi
        return 0
    }
    export -f dpkg
}

# Mock: dnf (Fedora package manager)
mock_dnf() {
    local success="${1:-true}"

    dnf() {
        record_mock_call "dnf" "$@"
        if [[ "$success" == "true" ]]; then
            echo "Mocked dnf $*"
            return 0
        else
            return 1
        fi
    }
    export -f dnf
}

# Mock: yum (RHEL/CentOS package manager)
mock_yum() {
    local success="${1:-true}"

    yum() {
        record_mock_call "yum" "$@"
        if [[ "$success" == "true" ]]; then
            echo "Mocked yum $*"
            return 0
        else
            return 1
        fi
    }
    export -f yum
}

# Mock: rpm (RPM package query)
mock_rpm() {
    local package_installed="${1:-true}"

    rpm() {
        record_mock_call "rpm" "$@"
        if [[ "$1" == "-q" ]]; then
            if [[ "$package_installed" == "true" ]]; then
                echo "nss-tools-1.0.0"
                return 0
            else
                return 1
            fi
        fi
        return 0
    }
    export -f rpm
}

# Mock: pacman (Arch Linux package manager)
mock_pacman() {
    local success="${1:-true}"

    pacman() {
        record_mock_call "pacman" "$@"
        if [[ "$1" == "-Q" ]]; then
            if [[ "$success" == "true" ]]; then
                echo "nss 1.0.0"
                return 0
            else
                return 1
            fi
        else
            if [[ "$success" == "true" ]]; then
                echo "Mocked pacman $*"
                return 0
            else
                return 1
            fi
        fi
    }
    export -f pacman
}

# Mock: brew (macOS Homebrew)
mock_brew() {
    local success="${1:-true}"

    brew() {
        record_mock_call "brew" "$@"
        if [[ "$1" == "list" ]]; then
            if [[ "$success" == "true" ]]; then
                echo "nss"
                return 0
            else
                return 1
            fi
        else
            if [[ "$success" == "true" ]]; then
                echo "Mocked brew $*"
                return 0
            else
                return 1
            fi
        fi
    }
    export -f brew
}

# Mock: apk (Alpine Linux package manager)
mock_apk() {
    local success="${1:-true}"

    apk() {
        record_mock_call "apk" "$@"
        if [[ "$1" == "info" ]]; then
            if [[ "$success" == "true" ]]; then
                echo "nss-tools-1.0.0"
                return 0
            else
                return 1
            fi
        else
            if [[ "$success" == "true" ]]; then
                echo "Mocked apk $*"
                return 0
            else
                return 1
            fi
        fi
    }
    export -f apk
}

# Mock: mkcert
mock_mkcert() {
    local success="${1:-true}"

    mkcert() {
        record_mock_call "mkcert" "$@"

        if [[ "$1" == "-install" ]]; then
            echo "The local CA is now installed in the system trust store!"
            return 0
        elif [[ "$1" == "-CAROOT" ]]; then
            echo "/home/user/.local/share/mkcert"
            return 0
        else
            if [[ "$success" == "true" ]]; then
                echo "Created a new certificate valid for the following names:"
                echo " - localhost"
                echo " - *.docker.localhost"
                return 0
            else
                return 1
            fi
        fi
    }
    export -f mkcert
}

# Mock: sudo (for commands that need elevated privileges)
mock_sudo() {
    sudo() {
        record_mock_call "sudo" "$@"
        # Execute the command without actually using sudo
        "$@"
    }
    export -f sudo
}

# Mock: mkdir
mock_mkdir() {
    mkdir() {
        record_mock_call "mkdir" "$@"
        # Don't actually create directories in tests
        return 0
    }
    export -f mkdir
}

# Mock: cp
mock_cp() {
    cp() {
        record_mock_call "cp" "$@"
        # Don't actually copy files in tests
        return 0
    }
    export -f cp
}

# Mock: chmod
mock_chmod() {
    chmod() {
        record_mock_call "chmod" "$@"
        # Don't actually change permissions in tests
        return 0
    }
    export -f chmod
}

# Mock: mktemp
mock_mktemp() {
    mktemp() {
        record_mock_call "mktemp" "$@"
        echo "/tmp/mock-temp-file-$$"
        return 0
    }
    export -f mktemp
}

# Mock: mv
mock_mv() {
    mv() {
        record_mock_call "mv" "$@"
        # Don't actually move files in tests
        return 0
    }
    export -f mv
}

# Convenience function: Setup complete mock environment for setup.sh testing
setup_mock_environment() {
    local os_type="${1:-linux}"
    local arch="${2:-x86_64}"
    local pkg_manager="${3:-apt}"

    init_mocks

    # Mock uname based on OS type
    case "$os_type" in
        linux)
            mock_uname "-s" "Linux" "$arch"
            ;;
        macos)
            mock_uname "-s" "Darwin" "$arch"
            ;;
        wsl2)
            mock_uname "-s" "Linux" "$arch"
            # Mock grep to detect WSL2 in /proc/version
            set_mock_return "grep" "microsoft" 0
            mock_grep "microsoft" "true"
            ;;
    esac

    # Mock package manager detection
    case "$pkg_manager" in
        apt)
            mock_command "apt" "dpkg" "docker" "curl"
            mock_apt "true"
            mock_dpkg "false"  # NSS tools not installed by default
            ;;
        dnf)
            mock_command "dnf" "rpm" "docker" "curl"
            mock_dnf "true"
            mock_rpm "false"
            ;;
        yum)
            mock_command "yum" "rpm" "docker" "curl"
            mock_yum "true"
            mock_rpm "false"
            ;;
        pacman)
            mock_command "pacman" "docker" "curl"
            mock_pacman "false"
            ;;
        brew)
            mock_command "brew" "docker" "curl"
            mock_brew "false"
            ;;
        apk)
            mock_command "apk" "docker" "curl"
            mock_apk "false"
            ;;
    esac

    # Mock Docker as available and running
    mock_docker "all" "true"

    # Mock mkcert
    mock_mkcert "true"

    # Mock file operations
    mock_sudo
    mock_mkdir
    mock_cp
    mock_chmod
    mock_mktemp
    mock_mv
    mock_curl "true"
}

# Export all mock functions
export -f init_mocks
export -f reset_mocks
export -f record_mock_call
export -f get_mock_call_count
export -f get_mock_call_args
export -f set_mock_return
export -f mock_uname
export -f mock_grep
export -f mock_curl
export -f mock_docker
export -f mock_command
export -f mock_apt
export -f mock_dpkg
export -f mock_dnf
export -f mock_yum
export -f mock_rpm
export -f mock_pacman
export -f mock_brew
export -f mock_apk
export -f mock_mkcert
export -f mock_sudo
export -f mock_mkdir
export -f mock_cp
export -f mock_chmod
export -f mock_mktemp
export -f mock_mv
export -f setup_mock_environment
