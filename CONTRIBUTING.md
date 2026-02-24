# Contributing to Local Docker Proxy

Thank you for your interest in contributing to the Local Docker Proxy project! This guide will help you get started with contributing code, documentation, tests, and bug reports.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Enhancements](#suggesting-enhancements)
  - [Submitting Pull Requests](#submitting-pull-requests)
- [Development Setup](#development-setup)
  - [Prerequisites](#prerequisites)
  - [Setting Up Your Environment](#setting-up-your-environment)
  - [Running the Proxy Locally](#running-the-proxy-locally)
- [Development Guidelines](#development-guidelines)
  - [Shell Script Style Guide](#shell-script-style-guide)
  - [YAML Configuration Style](#yaml-configuration-style)
  - [Markdown Documentation Style](#markdown-documentation-style)
- [Testing](#testing)
  - [Running Tests](#running-tests)
  - [Writing New Tests](#writing-new-tests)
  - [Test Coverage Requirements](#test-coverage-requirements)
- [Commit Message Guidelines](#commit-message-guidelines)
- [Pull Request Process](#pull-request-process)
- [Documentation Updates](#documentation-updates)
- [Platform-Specific Considerations](#platform-specific-considerations)
- [Getting Help](#getting-help)

## Code of Conduct

This project is committed to providing a welcoming and inclusive environment for all contributors. By participating, you are expected to:

- ✅ Be respectful and considerate in your communication
- ✅ Accept constructive criticism gracefully
- ✅ Focus on what is best for the community and project
- ✅ Show empathy towards other community members

Unacceptable behavior includes harassment, trolling, insulting comments, or personal attacks. Project maintainers reserve the right to remove comments, commits, or contributions that violate these standards.

## How Can I Contribute?

### Reporting Bugs

Before creating a bug report, please:

1. **Search existing issues** to avoid duplicates
2. **Verify the bug** on the latest version
3. **Test on a clean environment** if possible

**When submitting a bug report, include:**

- **System Information:**
  - OS type and version (e.g., "Ubuntu 24.04", "macOS 14.2 (Apple Silicon)", "Windows 11 WSL2")
  - Architecture (AMD64 or ARM64)
  - Docker version: `docker --version`
  - Docker Compose version: `docker compose version`

- **Steps to Reproduce:**
  ```bash
  # Clear, numbered steps
  1. Run ./setup.sh
  2. Execute docker compose up -d
  3. Access https://traefik.docker.localhost
  ```

- **Expected vs. Actual Behavior:**
  - What you expected to happen
  - What actually happened
  - Error messages (full output, not screenshots)

- **Relevant Configuration:**
  - Your `.env` file contents (redact passwords)
  - Relevant sections of `docker-compose.yml` if modified
  - Output of `docker compose logs traefik` (last 50 lines)

**Example Issue Title:**
- ✅ Good: `setup.sh fails on Fedora 39 ARM64 - mkcert download error`
- ❌ Bad: `It doesn't work`

### Suggesting Enhancements

Enhancement suggestions are welcome! When proposing a new feature:

1. **Check existing issues** to see if it's already proposed
2. **Explain the use case** - why is this needed?
3. **Describe the solution** you'd like to see
4. **Consider alternatives** - are there other ways to solve this?
5. **Note breaking changes** - will this affect existing users?

**Enhancement Proposal Template:**

```markdown
## Problem Statement
Describe the problem or limitation you've encountered.

## Proposed Solution
Explain your proposed solution and how it addresses the problem.

## Alternatives Considered
List other solutions you've considered and why they were rejected.

## Implementation Notes
Any technical details or challenges to consider.

## Breaking Changes
Will this require changes to existing configurations? (Yes/No)
```

### Submitting Pull Requests

1. **Fork the repository** and create your branch from `master`
2. **Make your changes** following the [Development Guidelines](#development-guidelines)
3. **Add tests** for new functionality
4. **Update documentation** if you changed behavior or added features
5. **Ensure tests pass** on your local machine
6. **Submit the pull request** with a clear description

## Development Setup

### Prerequisites

Before you begin development, ensure you have:

- **Git** for version control
- **Docker Engine** (20.10.0 or later)
- **Docker Compose** (v2.0.0 or later)
- **bats-core** for running tests
- **Text editor** or IDE of your choice

### Setting Up Your Environment

1. **Fork and clone the repository:**

   ```bash
   git clone https://github.com/YOUR-USERNAME/docker-proxy.git
   cd docker-proxy
   ```

2. **Install test dependencies:**

   **macOS (Homebrew):**
   ```bash
   brew install bats-core
   ```

   **Ubuntu/Debian:**
   ```bash
   sudo apt install bats
   ```

   **Fedora/RHEL:**
   ```bash
   sudo dnf install bats
   ```

   **Arch Linux:**
   ```bash
   sudo pacman -S bats
   ```

3. **Verify your setup:**

   ```bash
   # Check Docker
   docker --version
   docker compose version

   # Check bats
   bats --version
   ```

   **Expected output:**
   - Docker version 20.10.0 or higher
   - Docker Compose version v2.0.0 or higher
   - bats 1.8.0 or higher

### Running the Proxy Locally

1. **Run the setup script:**

   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

2. **Verify the installation:**

   ```bash
   # Check Traefik is running
   docker ps | grep traefik

   # Check network exists
   docker network ls | grep traefik-proxy

   # Access dashboard
   curl -k https://traefik.docker.localhost
   ```

3. **View logs during development:**

   ```bash
   # Follow all logs
   docker compose logs --follow

   # Follow only Traefik logs
   docker logs traefik --follow
   ```

## Development Guidelines

### Shell Script Style Guide

All shell scripts in this project follow these conventions:

#### General Rules

- ✅ **Use bash** as the interpreter: `#!/bin/bash`
- ✅ **Exit on error:** `set -e` at the top of scripts
- ✅ **Use functions** for reusable logic
- ✅ **Add comments** for complex logic
- ✅ **Quote variables** to prevent word splitting: `"$VARIABLE"`
- ✅ **Use lowercase** for local variables: `local_var="value"`
- ✅ **Use UPPERCASE** for environment variables: `GLOBAL_VAR="value"`

#### Error Handling

```bash
# Good - Check command success
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    exit 1
fi

# Good - Use logging functions
log_info "Starting installation..."
log_success "Installation complete"
log_warn "Configuration file not found, using defaults"
log_error "Failed to connect to Docker daemon"
```

#### Code Formatting

```bash
# Good - Clear function structure
detect_os() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            log_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
}

# Good - Readable conditionals
if [[ "$OS_TYPE" == "linux" ]]; then
    log_info "Detected Linux system"
elif [[ "$OS_TYPE" == "macos" ]]; then
    log_info "Detected macOS system"
fi
```

#### Platform Compatibility

```bash
# Good - Handle multiple platforms
case "$OS_TYPE" in
    linux)
        install_with_apt
        ;;
    macos)
        install_with_brew
        ;;
    wsl2)
        install_for_wsl2
        ;;
    *)
        log_error "Unsupported OS: $OS_TYPE"
        exit 1
        ;;
esac
```

### YAML Configuration Style

#### Docker Compose Files

```yaml
# Good - Clear service structure
services:
  traefik:
    image: traefik:v3.3
    container_name: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    networks:
      - traefik-proxy
    ports:
      - "80:80"
      - "443:443"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(`traefik.docker.localhost`)"

# Good - Use YAML anchors for repeated configs
x-logging: &default-logging
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"

services:
  app:
    logging: *default-logging
```

#### Indentation and Structure

- ✅ **Use 2 spaces** for indentation (not tabs)
- ✅ **Align values** for readability
- ✅ **Group related** configurations together
- ✅ **Add comments** for complex configurations
- ✅ **Order keys** logically: image, container_name, restart, networks, ports, volumes, labels

### Markdown Documentation Style

#### Headings

```markdown
# Top-level heading (H1) - Only one per document

## Section heading (H2)

### Subsection heading (H3)

#### Detail heading (H4)
```

#### Code Blocks

```markdown
# Good - Always specify language
```bash
docker compose up -d
```

```yaml
services:
  web:
    image: nginx:alpine
```

# Good - Add descriptions before code blocks
Run the following command to start the proxy:

```bash
./setup.sh
```
```

#### Lists and Structure

```markdown
# Good - Use numbered lists for sequential steps
1. Install dependencies
2. Run setup script
3. Verify installation

# Good - Use bullet points for non-sequential items
- Linux (Debian/Ubuntu)
- macOS (Intel and Apple Silicon)
- Windows WSL2

# Good - Use emoji indicators consistently
- ✅ Supported feature
- ❌ Not supported
- 📖 See documentation
- 🔄 In progress
- ⚠️ Warning
```

#### Links and References

```markdown
# Good - Use descriptive link text
See the [Integration Guide](docs/INTEGRATION_GUIDE.md) for examples.

# Good - Use relative paths for internal links
[README.md](README.md)

# Bad - Non-descriptive links
Click [here](docs/INTEGRATION_GUIDE.md) for more info.
```

## Testing

### Running Tests

**Run all tests:**
```bash
bats tests/
```

**Run specific test file:**
```bash
bats tests/setup.bats
bats tests/os-detection.bats
```

**Run with verbose output:**
```bash
bats --verbose-run tests/
```

**Run tests in parallel:**
```bash
bats --jobs 4 tests/
```

### Writing New Tests

Tests are written using **bats-core** (Bash Automated Testing System). Follow these patterns:

#### Basic Test Structure

```bash
#!/usr/bin/env bats
# Description of what this test file covers

# Load test helpers
load helpers/test-helpers
load helpers/mocks

setup() {
    # Runs before each test
    save_environment_state
}

teardown() {
    # Runs after each test
    restore_environment_state
}

@test "Description of what is being tested" {
    run bash -c '
        # Setup test environment
        export TEST_VAR="value"

        # Execute function being tested
        eval "$(sed -n "/^function_name()/,/^}/p" ./setup.sh)"
        function_name

        # Validate results
        [[ "$RESULT" == "expected" ]] || exit 1
    '

    # Assert test passed
    [ "$status" -eq 0 ]
}
```

#### Testing OS Detection

```bash
@test "Detects Linux AMD64 correctly" {
    run bash -c '
        eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
        detect_os

        [[ "$OS_TYPE" == "linux" ]] || exit 1
        [[ "$ARCH" == "amd64" ]] || exit 1
    '
    [ "$status" -eq 0 ]
}
```

#### Testing Error Conditions

```bash
@test "Fails gracefully on unsupported architecture" {
    run bash -c '
        # Mock uname to return unsupported arch
        uname() { echo "unsupported-arch"; }
        export -f uname

        eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
        detect_os
    '

    # Expect non-zero exit code
    [ "$status" -ne 0 ]

    # Check error message
    [[ "$output" =~ "Unsupported architecture" ]]
}
```

#### Platform-Specific Tests

```bash
@test "macOS detection works on Darwin systems" {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        run bash -c '
            eval "$(sed -n "/^detect_os()/,/^}/p" ./setup.sh)"
            detect_os
            [[ "$OS_TYPE" == "macos" ]] || exit 1
        '
        [ "$status" -eq 0 ]
    else
        skip "Not running on macOS"
    fi
}
```

### Test Coverage Requirements

When adding new functionality:

- ✅ **Unit tests** for individual functions
- ✅ **Integration tests** for multi-step workflows
- ✅ **Platform tests** for Linux, macOS, and WSL2 (when applicable)
- ✅ **Error handling tests** for failure scenarios
- ✅ **Edge case tests** for unusual inputs

**Minimum Coverage:**
- New shell functions: 100% of code paths tested
- New features: At least one integration test
- Bug fixes: At least one regression test

## Commit Message Guidelines

Follow these conventions for clear, consistent commit history:

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Adding or updating tests
- `refactor`: Code refactoring (no behavior change)
- `perf`: Performance improvements
- `style`: Code formatting (no logic change)
- `chore`: Maintenance tasks (dependencies, build config)

### Examples

```bash
# Good - Feature addition
feat(setup): add support for Alpine Linux package manager

Added detection for apk package manager used in Alpine Linux.
Updated install_nss_tools() to handle Alpine-specific package names.

Closes #42

# Good - Bug fix
fix(mkcert): correct ARM architecture detection on Raspberry Pi

The previous logic incorrectly mapped armv7l to arm64 instead of arm.
Updated architecture mapping to use correct mkcert download URL.

Fixes #38

# Good - Documentation
docs(readme): add troubleshooting section for certificate errors

Added section explaining how to resolve browser certificate warnings
on first installation. Includes platform-specific instructions.

# Good - Test addition
test(os-detection): add tests for WSL2 environment detection

Added integration tests for WSL2 detection using /proc/version.
Covers both Ubuntu and Debian WSL2 distributions.
```

### Commit Message Rules

- ✅ **Use imperative mood** in subject: "add feature" not "added feature"
- ✅ **Keep subject under 72 characters**
- ✅ **Capitalize the subject line**
- ✅ **Don't end subject with a period**
- ✅ **Separate subject from body** with a blank line
- ✅ **Wrap body at 72 characters**
- ✅ **Reference issues** in footer: `Fixes #123` or `Closes #456`

## Pull Request Process

### Before Submitting

1. **Update your branch** with latest master:
   ```bash
   git checkout master
   git pull upstream master
   git checkout your-branch
   git rebase master
   ```

2. **Run tests locally:**
   ```bash
   bats tests/
   ```

3. **Check for common issues:**
   ```bash
   # Verify shell scripts are executable
   ls -l setup.sh

   # Check YAML syntax
   docker compose config

   # Test the setup script
   ./setup.sh
   ```

### Submitting Your PR

1. **Push your branch** to your fork:
   ```bash
   git push origin your-branch
   ```

2. **Create the pull request** with this information:

   **Title:** Clear, descriptive summary (e.g., "Add support for PostgreSQL 16")

   **Description Template:**
   ```markdown
   ## Description
   Brief description of what this PR does and why.

   ## Changes Made
   - Added X functionality
   - Updated Y configuration
   - Fixed Z bug

   ## Testing Performed
   - [ ] Ran full test suite (`bats tests/`)
   - [ ] Tested on Linux (specify distro and version)
   - [ ] Tested on macOS (if applicable)
   - [ ] Tested on WSL2 (if applicable)
   - [ ] Manual testing performed: (describe steps)

   ## Documentation Updated
   - [ ] README.md (if user-facing changes)
   - [ ] docs/ (if integration or guides affected)
   - [ ] CHANGELOG.md (if applicable)
   - [ ] Code comments (for complex logic)

   ## Breaking Changes
   - [ ] No breaking changes
   - [ ] Breaking changes documented below:

   ## Related Issues
   Fixes #123
   Closes #456
   ```

3. **Respond to review feedback** promptly and professionally

### CI/CD Checks

Your PR must pass these automated checks:

- ✅ **Test Suite** runs on Ubuntu and macOS
- ✅ **Shell Script Linting** (shellcheck)
- ✅ **YAML Validation** (docker-compose config)
- ✅ **No merge conflicts** with master branch

If checks fail:
1. Review the error logs in GitHub Actions
2. Fix issues locally
3. Push updates to your branch (CI will re-run)

## Documentation Updates

When making changes that affect users:

### README.md

Update if you:
- Add a new feature or service
- Change installation steps
- Modify configuration options
- Add/remove prerequisites

### Integration Guide (docs/INTEGRATION_GUIDE.md)

Update if you:
- Change how projects integrate with the proxy
- Add new Traefik label patterns
- Modify networking requirements
- Add framework-specific examples

### Specialized Documentation (docs/)

Update relevant files if you change:
- MySQL configuration → `docs/MYSQL.md`
- PostgreSQL configuration → `docs/POSTGRESQL.md`
- Logging behavior → `docs/LOGGING.md`

### Documentation Style

- ✅ **Add examples** for new features
- ✅ **Include expected output** for verification steps
- ✅ **Update table of contents** when adding sections
- ✅ **Test all code examples** before submitting
- ✅ **Use consistent formatting** with existing docs

## Platform-Specific Considerations

### Testing on Multiple Platforms

If your change affects platform detection or installation:

1. **Test on your primary platform** (where you develop)
2. **Request testing** in PR description for other platforms
3. **Use CI results** to verify Ubuntu and macOS
4. **Consider WSL2** if changing OS detection logic

### Platform-Specific Code

When adding platform-specific code:

```bash
# Good - Clear platform handling
case "$OS_TYPE" in
    linux)
        # Linux-specific logic
        apt-get install package
        ;;
    macos)
        # macOS-specific logic
        brew install package
        ;;
    wsl2)
        # WSL2-specific logic
        apt-get install package
        # Additional WSL2 considerations
        ;;
esac
```

### Architecture Support

Ensure your changes work on both:
- ✅ **AMD64 (x86_64)** - Intel/AMD processors
- ✅ **ARM64 (aarch64)** - Apple Silicon, Raspberry Pi, AWS Graviton

## Getting Help

### Resources

- 📖 **Documentation:** Start with [README.md](README.md)
- 📖 **Integration Guide:** See [docs/INTEGRATION_GUIDE.md](docs/INTEGRATION_GUIDE.md)
- 🐛 **Existing Issues:** Search [GitHub Issues](../../issues)
- 💬 **Discussions:** Use [GitHub Discussions](../../discussions) for questions

### Asking Questions

When asking for help:

1. **Search first** - your question may already be answered
2. **Provide context** - what are you trying to accomplish?
3. **Include details** - OS, versions, error messages
4. **Share code** - relevant configuration files (redact sensitive data)

### Maintainer Response Time

- **Bug reports:** Typically reviewed within 2-3 business days
- **Pull requests:** Initial review within 1 week
- **Questions:** Response within 3-5 business days

---

## License

By contributing to this project, you agree that your contributions will be licensed under the [MIT License](LICENSE).

**Thank you for contributing to Local Docker Proxy! 🎉**

Your efforts help make this tool better for the entire development community.
