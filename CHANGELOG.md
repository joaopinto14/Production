# Changelog

## 2.0.0-dev.2

- Corrigidos os diretórios temporários `uwsgi` e `scgi` do Nginx para execução non-root.
- Nginx passa a fixar explicitamente o error log em `/dev/stderr` logo no arranque.
- Adicionado placeholder de configuração para evitar o aviso de include vazio do Supervisor.

Second development release of the Production 2.x line.

### Changed

- The container now runs as the unprivileged `www` user by default.
- Nginx now listens on port `8080` inside the container instead of privileged port `80`.
- Runtime-generated configuration moved from `/etc` to `/run/production`.
- PHP runtime overrides are loaded from `/run/production/php/conf.d` through `PHP_INI_SCAN_DIR`.
- Nginx runtime server configuration is generated under `/run/production/nginx/http.d`.
- Optional Supervisor configuration is copied to `/run/production/supervisor/conf.d`.
- Timezone selection no longer modifies `/etc/localtime` or `/etc/timezone` during startup; the runtime exports `TZ` and configures PHP directly.
- PHP-FPM and Nginx PID/socket/temp paths are now kept under `/run/production`.
- PHP-FPM pool no longer contains root-only user/group switching directives.
- Docker `STOPSIGNAL` is explicitly set to `SIGTERM`.
- Supervisor child shutdown settings were made explicit for graceful Nginx/PHP-FPM termination.
- Smoke tests now verify non-root execution and graceful shutdown in addition to HTTP/PHP health.

### Kept

- Alpine 3.24.
- PHP 8.5.
- Nginx + PHP-FPM.
- Supervisor as PID 1/process manager.
- The same intentionally small generic PHP extension set from `dev.1`.

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
- Supervisor as the process manager.
- Optional `SUPERVISOR_CONF` support for additional processes.
