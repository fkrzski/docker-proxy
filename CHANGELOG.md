## [1.2.0] - 2026-02-20

### 🔒 Security
- Added Redis password authentication via `REDIS_PASSWORD` environment variable
- Redis connections now require password by default for improved security

### 📚 Documentation
- Updated README with Redis password configuration instructions

## [1.1.0] - 2026-02-14

### 🚀 Added
- Platform detection and multi-platform support (Linux, macOS, WSL2, Windows)
- Comprehensive logging configuration with Traefik access logs
- Health checks for all services (Traefik, Redis, MySQL, phpMyAdmin)
- Integration guides and code examples for Node.js, Python, Go, and PHP frameworks
- Quick start guide with 5-minute walkthrough
- Troubleshooting guide and FAQ section
- Network topology diagram
- Post-installation certificate trust instructions for Windows
- Homebrew detection and mkcert installation support
- macOS-specific logging and Docker Desktop requirement notes
- Supported Platforms section with tested architecture matrix
- Project overview and setup instructions (CLAUDE.md)

### 🔧 Improvements
- Reorganized test scripts into `tests/` directory for better structure
- Cross-distro package manager detection
- Platform-specific mkcert binary downloads
- Improved dashboard URL configuration (traefik.docker.localhost)

### 📚 Documentation
- Updated README with prerequisites, logging section, and integration guide references
- Created comprehensive logging documentation
- Updated platform support documentation
- Fixed markdown syntax in integration guide

### 🐛 Bug Fixes
- Fixed QA feedback issues on test suite
- Addressed code review feedback on logging configuration
- Fixed security and code quality issues
- Fixed Traefik access log command flags
- Removed unicode typo from setup script
- Fixed markdown formatting for Host domain syntax

### 📋 Other Changes
- Updated .gitignore to exclude log files and auto-claude entries
- Added comprehensive ARM64 test cases
- Verified mkcert URL generation and acceptance criteria