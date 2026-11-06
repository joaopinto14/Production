# Production Migration Guide

## Moving to 2.0.5: simpler Laravel services

The image now exposes `production` as its entrypoint. It retains Tini as PID 1
and accepts Laravel shortcuts:

```yaml
command: ["scheduler"]
# Or: command: ["queue", "--tries=3"]
```

Full PHP/Artisan commands remain supported. New services can omit `entrypoint`.
For an existing Swarm/Portainer service whose saved entrypoint is `php artisan`,
replace it explicitly with `entrypoint: ["production"]` before redeploying.
Otherwise that service override still bypasses the image initialization.

The image health check now selects PHP-FPM readiness for web containers and
foreground process liveness for CLI. Existing disabled/custom health checks
remain valid. Remove a saved `healthcheck: {test: ["NONE"]}` override if you want
to use the new CLI liveness check. Liveness does not measure task progress.

Recreate/redeploy the service with the new image and configuration. Existing
2.0.4 version tags and running containers are not modified by this upgrade.

This document contains the breaking changes and practical upgrade steps for moving from Production 1.1.3 to Production 2.0.0.

# Migrating Production 1.1.3 to 2.0.0

Production 2.0.0 is a major evolution from **1.1.3** and contains breaking changes that should be reviewed before upgrading.

## Quick migration summary

| Area | 1.1.3 | 2.0.0 |
|---|---|---|
| PHP | PHP 8.3 | PHP 8.3, 8.4, and 8.5 |
| Variants | One image | Generic + Laravel |
| Internal port | `80` | `8080` |
| Process manager | Supervisor | Production's lightweight runtime manager |
| Runtime user | Privileged startup | `www` non-root |
| Document root variable | `INDEX_PATH` | `DOCUMENT_ROOT` |
| PHP memory variable | `MEMORY_LIMIT` | `PHP_MEMORY_LIMIT` |
| Runtime extension installation | `PHP_EXTENSIONS` | Removed; extensions are installed at image build time |
| Extra processes | `SUPERVISOR_CONF` | Separate containers / explicit CLI commands |
| Permissions | `chown -R` at startup | Permissions prepared during build/deployment |
| Logs | Files under `/var/log` | stdout/stderr |
| Health check | `/` on port 80 | `/healthz` on port 8080 |
| Architectures | No validated release matrix | `linux/amd64` + `linux/arm64` |

---

## 1. Internal port changed from 80 to 8080

### 1.1.3

```bash
docker run -p 80:80 joaopinto14/production:1.1.3
```

### 2.0.0

```bash
docker run -p 8080:8080 joaopinto14/production:2.0.0-php8.5
```

If you use a reverse proxy, update the backend/service port to:

```text
8080
```

---

## 2. `INDEX_PATH` was replaced by `DOCUMENT_ROOT`

### Before

```yaml
environment:
  INDEX_PATH: /var/www/html/public
```

### Now

```yaml
environment:
  DOCUMENT_ROOT: /var/www/html/public
```

For the Laravel variant, you usually do not need to set this variable because the default is already:

```text
/var/www/html/public
```

---

## 3. `MEMORY_LIMIT` was replaced by `PHP_MEMORY_LIMIT`

### Before

```yaml
environment:
  MEMORY_LIMIT: 256M
```

### Now

```yaml
environment:
  PHP_MEMORY_LIMIT: 256M
```

`UPLOAD_MAX_SIZE` and `TIMEZONE` remain available.

---

## 4. `PHP_EXTENSIONS` was removed

In 1.1.3, additional PHP extensions could be installed at container startup:

```yaml
environment:
  PHP_EXTENSIONS: pdo_mysql
```

This behavior has been removed in 2.0.0.

PHP extensions are now installed when the image is built, making startup:

- faster;
- deterministic;
- reproducible;
- compatible with non-root and read-only runtime operation.

The Laravel variant already includes MySQL, PostgreSQL, SQLite, and Redis support.

---

## 5. Supervisor was removed

Production 1.1.3 used Supervisor to manage processes.

Production 2.0.0 replaces Supervisor with a very small POSIX runtime manager that only manages:

```text
Nginx
PHP-FPM
```

As a result, this configuration was removed:

```text
SUPERVISOR_CONF
```

Queue workers and schedulers should run as separate containers or services.

### Before

A single container could use Supervisor to manage additional application processes.

### Now

```yaml
services:
  web:
    image: joaopinto14/production:2.0.0-laravel-php8.5

  queue:
    image: joaopinto14/production:2.0.0-laravel-php8.5
    command: php artisan queue:work

  scheduler:
    image: joaopinto14/production:2.0.0-laravel-php8.5
    command: php artisan schedule:work
```

---

## 6. The container now runs as non-root

Production 2.0.0 runs as:

```text
www
```

Applications should no longer depend on root privileges during startup.

This improves runtime security but means mounted volume permissions must be correct before the container starts.

---

## 7. Automatic `chown -R` was removed

Production 1.1.3 could recursively change ownership under `/var/www/html` during startup.

Production 2.0.0 no longer does this.

Application permissions must be prepared before startup.

For Laravel, make sure these directories are writable:

```text
storage/
bootstrap/cache/
```

---

## 8. Logs now use stdout/stderr

Instead of relying on log files inside the container, use:

```bash
docker logs -f <container-name>
```

This is now the standard way to consume Production runtime logs.

---

## 9. The health check endpoint changed

### 1.1.3

```text
http://container/
```

on port 80.

### 2.0.0

```text
http://container:8080/healthz
```

Expected response:

```text
ok
```

---

## 10. Generic and Laravel are now separate variants

Production 1.1.3 used a single image approach.

Production 2.0.0 lets you choose the runtime that matches your application.

### General PHP application

```text
joaopinto14/production:2.0.0-php8.5
```

### Laravel application

```text
joaopinto14/production:2.0.0-laravel-php8.5
```

This keeps the Generic image smaller and avoids installing Laravel-specific extensions in applications that do not need them.

---

## 11. PHP 8.3, 8.4, and 8.5 are available

### Generic

```text
joaopinto14/production:2.0.0-php8.3
joaopinto14/production:2.0.0-php8.4
joaopinto14/production:2.0.0-php8.5
```

### Laravel

```text
joaopinto14/production:2.0.0-laravel-php8.3
joaopinto14/production:2.0.0-laravel-php8.4
joaopinto14/production:2.0.0-laravel-php8.5
```

---

# Complete migration example

## Production 1.1.3

```yaml
services:
  web:
    image: joaopinto14/production:1.1.3
    ports:
      - "80:80"
    volumes:
      - ./:/var/www/html
    environment:
      INDEX_PATH: /var/www/html/public
      MEMORY_LIMIT: 256M
      UPLOAD_MAX_SIZE: 32M
      PHP_EXTENSIONS: pdo_mysql
      TIMEZONE: Europe/Lisbon
```

## Production 2.0.0 — Laravel

```yaml
services:
  web:
    image: joaopinto14/production:2.0.0-laravel-php8.5
    ports:
      - "8080:8080"
    volumes:
      - ./:/var/www/html:ro
      - ./storage:/var/www/html/storage
      - ./bootstrap/cache:/var/www/html/bootstrap/cache
    environment:
      PHP_MEMORY_LIMIT: 256M
      UPLOAD_MAX_SIZE: 32M
      TIMEZONE: Europe/Lisbon
```

The following 1.1.3 settings are no longer used:

```text
INDEX_PATH
MEMORY_LIMIT
PHP_EXTENSIONS
SUPERVISOR_CONF
```

They are replaced, when applicable, by:

```text
DOCUMENT_ROOT
PHP_MEMORY_LIMIT
```

---

## Changes in 2.0.4

Docker health checks now use `/readyz` (Nginx plus PHP-FPM); `/healthz` remains Nginx liveness. Disable the inherited HTTP check with `--no-healthcheck` for CLI workers/schedulers and supply an application-specific probe. The runtime reserves both endpoint paths.

Set Docker `--stop-timeout 40` or Compose `stop_grace_period: 40s` for the default 30-second `SHUTDOWN_TIMEOUT`. Nginx drains before FPM stops; a forced deadline exits with error. See the README for read-only mount ownership and upload capacity sizing.

Starting with the final 2.0.4 preparation, `/sbin/tini -s --` wraps the entrypoint in web and CLI modes. PHP CLI is no longer PID 1. Keep the entrypoint when overriding commands; if you override it, retain an init explicitly. Existing older containers can use Docker `--init` or Compose `init: true` after recreation. This reaps adopted orphans; children belonging to a living parent still require that parent's wait/proc_close handling.
