# Contributing to Local Docker Proxy

Thank you for your interest in contributing! This guide covers how to report issues, submit pull requests, and develop locally.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Enhancements](#suggesting-enhancements)
- [Development Setup](#development-setup)
- [Code Style Guidelines](#code-style-guidelines)
- [Testing](#testing)
- [Commit Message Guidelines](#commit-message-guidelines)
- [Pull Request Process](#pull-request-process)
- [License](#license)

## Code of Conduct

Be respectful, accept constructive criticism gracefully, and focus on what's best for the community. Harassment, trolling, and personal attacks are not tolerated.

## Reporting Bugs

**Before submitting:**
- Search existing issues to avoid duplicates
- Verify the bug on the latest version
- Test on a clean environment

**Include in your report:**
- OS type, version, and architecture (AMD64/ARM64)
- Docker and Docker Compose versions
- Steps to reproduce (numbered and clear)
- Expected vs. actual behavior
- Error messages (full text, not screenshots)
- Relevant `.env` and `docker-compose.yml` sections (redact passwords)

**Good title:** `setup.sh fails on Fedora 39 ARM64 - mkcert download error`

## Suggesting Enhancements

When proposing a feature:
1. Check if it's already proposed in existing issues
2. Explain the use case and why it's needed
3. Describe your proposed solution
4. Note any breaking changes

## Development Setup

**Prerequisites:**
- Git
- Docker Engine 20.10.0+
- Docker Compose v2.0.0+
- bats-core for testing

**Setup steps:**

```bash
# 1. Clone your fork
git clone https://github.com/YOUR-USERNAME/docker-proxy.git
cd docker-proxy

# 2. Install test dependencies
# macOS: brew install bats-core
# Ubuntu/Debian: sudo apt install bats
# Fedora/RHEL: sudo dnf install bats
# Arch Linux: sudo pacman -S bats

# 3. Run the proxy
./setup.sh

# 4. Verify
docker ps | grep traefik
```

## Code Style Guidelines

### Shell Scripts

- Use `#!/bin/bash` and `set -e`
- Quote variables: `"$VARIABLE"`
- Use lowercase for local vars, UPPERCASE for env vars
- Use logging functions: `log_info()`, `log_error()`, `log_warn()`, `log_success()`
- Handle multiple platforms with case statements

**Example:**
```bash
detect_os() {
    case "$(uname -m)" in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *) log_error "Unsupported architecture"; exit 1 ;;
    esac
}
```

### YAML Files

- Use 2 spaces for indentation (no tabs)
- Order keys logically: image, container_name, restart, networks, ports, volumes, labels
- Add comments for complex configurations
- Use YAML anchors for repeated configs

### Markdown Documentation

- Use clear headings (# H1, ## H2, ### H3)
- Always specify language for code blocks
- Use relative paths for internal links
- Use emoji indicators: ✅ ❌ 📖 ⚠️

## Testing

**Run tests:**
```bash
# All tests
bats tests/

# Specific file
bats tests/setup.bats

# Verbose output
bats --verbose-run tests/
```

**Writing tests:**
- Use bats-core framework
- Test all code paths for new functions
- Include error handling tests
- Add platform-specific tests when needed
- See `tests/setup.bats` for examples

**Coverage requirements:**
- New shell functions: 100% of code paths
- New features: At least one integration test
- Bug fixes: At least one regression test

**CI runs tests on:**
- ubuntu-latest
- macos-latest

## Commit Message Guidelines

**Format:**
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Adding or updating tests
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `chore`: Maintenance tasks

**Example:**
```
fix(mkcert): correct ARM architecture detection on Raspberry Pi

The previous logic incorrectly mapped armv7l to arm64.
Updated architecture mapping to use correct download URL.

Fixes #38
```

**Rules:**
- Use imperative mood: "add" not "added"
- Keep subject under 72 characters
- Capitalize subject line
- Separate subject from body with blank line
- Reference issues: `Fixes #123`

## Pull Request Process

**Before submitting:**
```bash
# Update your branch
git checkout master
git pull upstream master
git checkout your-branch
git rebase master

# Run tests
bats tests/

# Verify setup script
./setup.sh
```

**PR description should include:**
- Brief description of changes
- List of changes made
- Testing performed (platforms tested)
- Documentation updated
- Breaking changes (if any)
- Related issues

**CI checks that must pass:**
- Test suite (Ubuntu and macOS)
- Shell script linting (shellcheck)
- YAML validation
- No merge conflicts

**Documentation updates:**
- Update README.md for user-facing changes
- Update docs/INTEGRATION_GUIDE.md for integration changes
- Update relevant docs/ files (MYSQL.md, POSTGRESQL.md, LOGGING.md)
- Test all code examples

## License

By contributing, you agree your contributions will be licensed under the [MIT License](LICENSE).

---

**Resources:**
- 📖 [README.md](README.md) - Project documentation
- 📖 [Integration Guide](docs/INTEGRATION_GUIDE.md) - Integration examples
- 🐛 [GitHub Issues](https://github.com/fkrzski/docker-proxy/issues) - Bug reports and features

**Thank you for contributing! 🎉**
