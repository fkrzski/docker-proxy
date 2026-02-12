# Running Tests

## Prerequisites

This test suite uses [bats-core](https://github.com/bats-core/bats-core) for testing.

### Installing bats-core

**On Debian/Ubuntu:**
```bash
sudo apt update
sudo apt install bats
```

**On macOS:**
```bash
brew install bats-core
```

**On Fedora/RHEL:**
```bash
sudo dnf install bats
```

**Manual installation:**
```bash
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

## Running Tests

Run all tests:
```bash
bats tests/*.bats
```

Run specific test file:
```bash
bats tests/os-detection.bats
bats tests/mkcert.bats
bats tests/package-manager.bats
```

Run with verbose output:
```bash
bats -t tests/*.bats
```

## Test Structure

- `tests/os-detection.bats` - OS and architecture detection tests
- `tests/mkcert.bats` - mkcert URL generation tests  
- `tests/package-manager.bats` - Package manager detection tests
- `tests/helpers/test-helpers.bash` - Helper functions for tests
- `tests/helpers/mocks.bash` - Mock functions for external commands

## Test Coverage

The tests use mocking to avoid making actual system changes and to test behavior across different platforms.
