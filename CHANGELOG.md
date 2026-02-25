## [1.2.0] - 2026-02-25

### ✨ Added
- New `strict-headers` and `relaxed-headers` middleware for enhanced security configuration flexibility
- PostgreSQL service with integrated pgAdmin interface for database management
- Mailpit service for email testing and development workflows with HTTPS support
- Automated dependency management via Dependabot for docker-compose and GitHub Actions
- CONTRIBUTING.md guidelines with complete contribution procedures and validation
- Comprehensive PostgreSQL and MySQL documentation guides (docs/POSTGRESQL.md, docs/MYSQL.md)

### ⚡ Changed
- Upgraded Docker image versions to pinned, stable releases for Traefik, MySQL, PostgreSQL, phpMyAdmin, and pgAdmin
- Removed deprecated MySQL authentication plugin (mysql_native_password) for improved security
- Applied security headers middleware across all services with enhanced Content Security Policy directives
- Parallelize CI test execution using BATS --jobs capability for faster testing
- Refactored certificate permission handling in setup.sh with explicit chmod rules for different file types
- Updated INTEGRATION_GUIDE.md with consistent formatting and comprehensive framework configuration examples

### 🐛 Fixed
- Enhanced Content Security Policy with object-src and base-uri directives
- Removed unsafe-inline from security headers for stricter enforcement across all services
- Corrected pgAdmin default credentials to use valid email format
- Fixed pgAdmin healthcheck mechanism to use wget instead of curl
- Corrected MySQL backup documentation to properly reference `mysqldump` command
- Updated GitHub Issues link in CONTRIBUTING.md to use absolute URL
- Enforce certificate file permissions on every setup.sh execution
- Restored and corrected Mailpit integration guide with HTTPS configuration and agent examples

### 📚 Documentation
- Updated README with PostgreSQL section including environment variable documentation
- Clarified PostgreSQL superuser configuration and default credentials
- Improved pgAdmin healthcheck and volume configuration documentation
- Enhanced MySQL documentation with security best practices and `MYSQL_PWD` usage
- Added Mailpit configuration examples for popular frameworks in integration guide

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