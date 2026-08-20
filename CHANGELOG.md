# Changelog

All notable changes to Production are documented in this file.

## 2.0.0 - 2026-08-20

### Stable release

- Promoted the fully validated `2.0.0-rc.1` runtime to stable without introducing new runtime behavior.
- Added stable Docker Hub release targets for `joaopinto14/production`.
- Added versioned and stable aliases for Generic and Laravel images.
- Added an automated Docker Hub release workflow gated by the full release test suite.
- Finalized the English public README and the 1.1.3 → 2.0.0 migration documentation.

### Runtime highlights

- Alpine Linux 3.24 base.
- Nginx + PHP-FPM.
- PHP 8.3, 8.4 and 8.5.
- Generic and Laravel variants.
- Lightweight POSIX runtime manager; Supervisor and Python are no longer required.
- Non-root `www` runtime user.
- Internal port 8080.
- `/healthz` health endpoint.
- stdout/stderr logging.
- Graceful signal handling and fail-fast child-process monitoring.
- Read-only-root compatible runtime layout.
- `linux/amd64` and `linux/arm64` builds.
- OCI image metadata.

### Validation

- Clean no-cache builds for all six image variants.
- Static and negative build validation.
- Image contract tests.
- Smoke matrix for PHP 8.3/8.4/8.5 and Generic/Laravel.
- Runtime configuration tests.
- Deep HTTP/Nginx tests.
- Concurrent PHP-FPM workload tests.
- Docker logging contract tests.
- Crash and signal tests.
- Hardened runtime tests with read-only root, no-new-privileges and zero effective capabilities.
- Image size regression budgets.
- Real PHP application tests.
- Real Laravel 13 tests on PHP 8.3, 8.4 and 8.5.
- Restart stability and zombie-process checks.
- Multi-architecture build validation for amd64 and arm64.

## 2.0.0-rc.1 - 2026-08-20

### Fixed

- Multi-architecture validation uses a dedicated Buildx `docker-container` builder, avoiding ARM64 `exec format error` failures caused by unsuitable host builders.
- Added ARM64 execution preflight and clear QEMU/binfmt remediation.
- Laravel test cleanup handles bind-mounted cache files without masking the original test exit code.

### Added

- Clean-build release gate.
- Real Generic PHP application tests.
- Real Laravel 13 application tests.
- Restart stability and zombie-process tests.
- Multi-architecture release validation.
