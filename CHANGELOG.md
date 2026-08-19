# Changelog

## 2.0.0-dev.1

First development release of the Production 2.x line.

### Changed

- Base image pinned to Alpine 3.24.
- PHP upgraded from 8.3 to 8.5.
- PHP extensions are installed at image build time instead of container startup.
- `INDEX_PATH` was replaced by `DOCUMENT_ROOT`.
- `MEMORY_LIMIT` was replaced by `PHP_MEMORY_LIMIT` for clearer naming.
- Nginx and PHP-FPM logs are sent to stdout/stderr.
- Runtime configuration is generated from immutable defaults on every startup.
- PHP-FPM now uses a dedicated, explicit pool configuration.
- The image now uses a proper Docker `ENTRYPOINT` + `CMD` split, allowing commands such as `docker run IMAGE php -v`.
- Healthcheck now uses the dedicated `/healthz` endpoint.

### Removed

- Runtime package installation through `PHP_EXTENSIONS`.
- Recursive `chown -R` of `/var/www/html` during container startup.
- Renaming packaged PHP binaries.
- Requirement for an `index.php` file to exist before the container starts.
- File-based Nginx logs under `/var/log/nginx`.

### Kept for this development release

- Nginx + PHP-FPM architecture.
- Supervisor as the process manager. Its removal or replacement will be evaluated in a later 2.0.0 development release.
- Optional `SUPERVISOR_CONF` support for additional processes.
