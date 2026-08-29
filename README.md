# Production 2.0.1

**Production** is a small, production-focused Docker image for running **PHP applications** with **Nginx + PHP-FPM** already configured.

Production 2.0.1 is a security and supply-chain maintenance release. It refreshes Alpine 3.24 packages to current patched revisions at build time and publishes SBOM and SLSA provenance attestations with stable registry releases.

It is designed to keep deployment simple: your application is prepared during the build/deployment stage, mounted or copied into the container, and Production provides the web runtime.

Production is available in two variants:

- **Generic** — for general PHP applications;
- **Laravel** — for Laravel applications, with Laravel-oriented PHP extensions and Nginx configuration.

Production 2.0 supports:

- PHP **8.3**, **8.4**, and **8.5**;
- `linux/amd64` and `linux/arm64`;
- a **non-root** runtime user;
- Docker health checks;
- stdout/stderr logging;
- graceful shutdown;
- read-only root filesystem deployments;
- web workloads, queues, schedulers, migrations, and other CLI commands.

Official Docker Hub repository:

```text
joaopinto14/production
```

Images are published by the release workflow after the complete stable release validation succeeds.

---

## Table of contents

- [Quick start](#quick-start)
- [Which image should I use?](#which-image-should-i-use)
- [Stable tags](#stable-tags)
- [How it works](#how-it-works)
- [Using the Generic image](#using-the-generic-image)
- [Using the Laravel image](#using-the-laravel-image)
- [Queues, Scheduler, and Artisan](#queues-scheduler-and-artisan)
- [Configuration](#configuration)
- [Health check](#health-check)
- [Logs](#logs)
- [Security and permissions](#security-and-permissions)
- [PHP extensions](#php-extensions)
- [What is not included](#what-is-not-included)
- [Docker Compose](#docker-compose)
- [Multi-architecture support](#multi-architecture-support)
- [Testing](#testing)
- [Migrating from 1.1.3 to 2.0.0](#migrating-from-113-to-200)

---

# Quick start

## Generic PHP

If your application has an `index.php` file in its root directory:

```bash
docker run --rm \
  -p 8080:8080 \
  -v "$PWD:/var/www/html:ro" \
  joaopinto14/production:2.0.1-php8.5
```

Open:

```text
http://localhost:8080
```

The default document root is:

```text
/var/www/html
```

---

## Laravel

For a Laravel project with `vendor/` already installed:

```bash
docker run --rm \
  -p 8080:8080 \
  -v "$PWD:/var/www/html:ro" \
  -v "$PWD/storage:/var/www/html/storage" \
  -v "$PWD/bootstrap/cache:/var/www/html/bootstrap/cache" \
  joaopinto14/production:2.0.1-laravel-php8.5
```

Open:

```text
http://localhost:8080
```

The Laravel variant automatically uses:

```text
/var/www/html/public
```

as its document root.

---

# Which image should I use?

## Generic

Use the Generic variant for PHP applications that do not need Laravel-specific configuration or extensions.

```text
joaopinto14/production:2.0.1-php8.3
joaopinto14/production:2.0.1-php8.4
joaopinto14/production:2.0.1-php8.5
```

Recommended example for PHP 8.5:

```text
joaopinto14/production:2.0.1-php8.5
```

## Laravel

Use the Laravel variant for Laravel applications.

```text
joaopinto14/production:2.0.1-laravel-php8.3
joaopinto14/production:2.0.1-laravel-php8.4
joaopinto14/production:2.0.1-laravel-php8.5
```

Recommended example for PHP 8.5:

```text
joaopinto14/production:2.0.1-laravel-php8.5
```

The Laravel variant adds commonly required extensions for MySQL/MariaDB, PostgreSQL, SQLite, Redis, `intl`, `bcmath`, `pcntl`, and `zip`.

---


# Stable tags

Production 2.0.1 publishes immutable version tags and convenient stable aliases.

| Purpose | Tag |
|---|---|
| Generic PHP 8.3 | `joaopinto14/production:2.0.1-php8.3` |
| Generic PHP 8.4 | `joaopinto14/production:2.0.1-php8.4` |
| Generic PHP 8.5 | `joaopinto14/production:2.0.1-php8.5` |
| Laravel PHP 8.3 | `joaopinto14/production:2.0.1-laravel-php8.3` |
| Laravel PHP 8.4 | `joaopinto14/production:2.0.1-laravel-php8.4` |
| Laravel PHP 8.5 | `joaopinto14/production:2.0.1-laravel-php8.5` |

Stable aliases:

```text
joaopinto14/production:php8.3
joaopinto14/production:php8.4
joaopinto14/production:php8.5
joaopinto14/production:latest
joaopinto14/production:laravel-php8.3
joaopinto14/production:laravel-php8.4
joaopinto14/production:laravel-php8.5
joaopinto14/production:laravel
```

`latest` points to Generic PHP 8.5. `laravel` points to Laravel PHP 8.5.

---

# How it works

Production uses a simple runtime architecture:

```text
HTTP request :8080
       │
       ▼
     Nginx
       │
       ▼
    PHP-FPM
       │
       ▼
 PHP application
```

PID 1 is Production's own lightweight runtime manager:

```text
production-runtime
├── Nginx
└── PHP-FPM
```

The runtime manager:

- starts Nginx and PHP-FPM;
- forwards signals correctly;
- performs graceful shutdown;
- stops the container if Nginx or PHP-FPM exits unexpectedly.

Production 2.0 does **not** use Supervisor, systemd, or Python.

## Web mode

When the container starts with its default command:

```bash
production-runtime
```

it starts:

```text
Nginx + PHP-FPM
```

## CLI mode

If you provide another command, Production runs that command directly without starting Nginx or PHP-FPM.

Example:

```bash
docker run --rm \
  -v "$PWD:/var/www/html" \
  joaopinto14/production:2.0.1-laravel-php8.5 \
  php artisan about
```

This lets you use the same Laravel image for the web application, queue workers, scheduler, migrations, and other CLI tasks.

---

# Using the Generic image

The Generic variant uses this document root by default:

```text
DOCUMENT_ROOT=/var/www/html
```

A simple project may look like this:

```text
my-project/
├── index.php
├── assets/
└── ...
```

Run it with:

```bash
docker run --rm \
  -p 8080:8080 \
  -v "$PWD:/var/www/html:ro" \
  joaopinto14/production:2.0.1-php8.5
```

## Custom document root

If your application uses a `public/` or `web/` directory:

```bash
docker run --rm \
  -p 8080:8080 \
  -e DOCUMENT_ROOT=/var/www/html/public \
  -v "$PWD:/var/www/html:ro" \
  joaopinto14/production:2.0.1-php8.5
```

---

# Using the Laravel image

The Laravel variant is configured for the standard Laravel project layout.

Default document root:

```text
/var/www/html/public
```

Before starting the runtime image, the application should already be prepared.

A typical production dependency installation is:

```bash
composer install --no-dev --optimize-autoloader
```

Frontend assets should also be built before deployment when your application requires them.

Production intentionally **does not include Composer or Node.js in the runtime image**.

## Expected project structure

```text
app/
bootstrap/
config/
public/
resources/
routes/
storage/
vendor/
artisan
composer.json
```

The following directories must be writable by the application runtime user:

```text
storage/
bootstrap/cache/
```

## Basic Laravel example

```bash
docker run --rm \
  -p 8080:8080 \
  -e TIMEZONE=Europe/Lisbon \
  -e PHP_MEMORY_LIMIT=256M \
  -e UPLOAD_MAX_SIZE=32M \
  -v "$PWD:/var/www/html:ro" \
  -v "$PWD/storage:/var/www/html/storage" \
  -v "$PWD/bootstrap/cache:/var/www/html/bootstrap/cache" \
  joaopinto14/production:2.0.1-laravel-php8.5
```

## Direct PHP file protection

In the Laravel variant, Nginx only forwards the Laravel front controller:

```text
/public/index.php
```

to PHP-FPM.

A file such as:

```text
/public/test.php
```

is not executed directly.

This reduces the application's exposed PHP surface and keeps requests routed through Laravel's front controller.

---

# Queues, Scheduler, and Artisan

The same Laravel image can be used for different application services.

## Queue worker

```bash
docker run --rm \
  -v "$PWD:/var/www/html" \
  joaopinto14/production:2.0.1-laravel-php8.5 \
  php artisan queue:work
```

## Scheduler

```bash
docker run --rm \
  -v "$PWD:/var/www/html" \
  joaopinto14/production:2.0.1-laravel-php8.5 \
  php artisan schedule:work
```

## Migrations

```bash
docker run --rm \
  -v "$PWD:/var/www/html" \
  joaopinto14/production:2.0.1-laravel-php8.5 \
  php artisan migrate --force
```

## Other Artisan commands

```bash
docker run --rm \
  -v "$PWD:/var/www/html" \
  joaopinto14/production:2.0.1-laravel-php8.5 \
  php artisan about
```

In CLI mode, **Nginx and PHP-FPM are not started**.

---

# Configuration

Production is intentionally configured through a small set of environment variables.

| Variable | Default | Purpose |
|---|---|---|
| `TIMEZONE` | `UTC` | Runtime and PHP timezone |
| `DOCUMENT_ROOT` | Generic: `/var/www/html` / Laravel: `/var/www/html/public` | Directory served by Nginx |
| `PHP_MEMORY_LIMIT` | `128M` | PHP memory limit |
| `UPLOAD_MAX_SIZE` | `8M` | PHP upload limits and Nginx request body limit |

## Example

```bash
docker run --rm \
  -p 8080:8080 \
  -e TIMEZONE=Europe/Lisbon \
  -e PHP_MEMORY_LIMIT=512M \
  -e UPLOAD_MAX_SIZE=64M \
  -v "$PWD:/var/www/html:ro" \
  joaopinto14/production:2.0.1-php8.5
```

## Invalid timezone

If an invalid timezone is provided, the container exits instead of silently starting with an incorrect configuration.

---

# Health check

Production exposes:

```text
GET /healthz
```

on port:

```text
8080
```

Manual test:

```bash
curl http://localhost:8080/healthz
```

Expected response:

```text
ok
```

`/healthz` verifies that the web runtime is responding. Database connectivity and other application dependencies should be checked by the application itself when required.

---

# Logs

Runtime logs are written to stdout/stderr.

Use:

```bash
docker logs -f <container-name>
```

This integrates naturally with Docker, Docker Swarm, Kubernetes, and external logging platforms.

Nginx access logs are emitted in JSON format.

You do not need to mount `/var/log` to collect Production runtime logs.

---

# Security and permissions

Production runs as a **non-root** user.

The internal HTTP port is:

```text
8080
```

The image is designed to work with hardening options such as:

```text
--read-only
--cap-drop ALL
--security-opt no-new-privileges:true
```

## Hardened example

```bash
docker run --rm \
  --read-only \
  --cap-drop ALL \
  --security-opt no-new-privileges:true \
  --tmpfs /run/production:rw,nosuid,nodev,noexec,size=16m \
  --tmpfs /tmp:rw,nosuid,nodev,noexec,size=16m \
  -p 8080:8080 \
  -v "$PWD:/var/www/html:ro" \
  joaopinto14/production:2.0.1-php8.5
```

For Laravel, `storage/` and `bootstrap/cache/` still need writable storage.

## File permissions

Production 2.0.1 **does not run `chown -R` on your application at startup**.

Application permissions should be prepared during the image build or deployment process.

To discover the runtime UID and GID:

```bash
UID_RUNTIME=$(docker run --rm --entrypoint id joaopinto14/production:2.0.1-php8.5 -u)
GID_RUNTIME=$(docker run --rm --entrypoint id joaopinto14/production:2.0.1-php8.5 -g)

echo "$UID_RUNTIME:$GID_RUNTIME"
```

---

# PHP extensions

## Generic

The Generic variant includes the common PHP runtime extensions used by many applications:

```text
ctype
curl
fileinfo
mbstring
openssl
pdo
session
tokenizer
xml
opcache
```

## Laravel

The Laravel variant includes everything in Generic and adds:

```text
bcmath
dom
intl
pcntl
pdo_mysql
pdo_pgsql
pdo_sqlite
redis
zip
```

This makes the Laravel variant ready to work with:

- MySQL/MariaDB;
- PostgreSQL;
- SQLite;
- Redis through PhpRedis.

---

# What is not included

To keep the runtime small and production-focused, Production does not include:

```text
Composer
Node.js
npm
Git
Supervisor
Python
GCC
make
Laravel framework
application vendor/
```

Production is a **runtime image**, not a development or build image.

The recommended workflow is:

```text
Source code
    ↓
Build / Composer / Node.js
    ↓
Prepared application
    ↓
Production runtime
```

---

# Docker Compose

## Generic PHP

```yaml
services:
  web:
    image: joaopinto14/production:2.0.1-php8.5
    ports:
      - "8080:8080"
    environment:
      TIMEZONE: Europe/Lisbon
      PHP_MEMORY_LIMIT: 256M
      UPLOAD_MAX_SIZE: 32M
    volumes:
      - ./:/var/www/html:ro
```

## Laravel with web + queue + scheduler

```yaml
services:
  web:
    image: joaopinto14/production:2.0.1-laravel-php8.5
    ports:
      - "8080:8080"
    environment:
      TIMEZONE: Europe/Lisbon
      PHP_MEMORY_LIMIT: 256M
      UPLOAD_MAX_SIZE: 32M
    volumes:
      - ./:/var/www/html:ro
      - ./storage:/var/www/html/storage
      - ./bootstrap/cache:/var/www/html/bootstrap/cache

  queue:
    image: joaopinto14/production:2.0.1-laravel-php8.5
    command: php artisan queue:work
    restart: unless-stopped
    volumes:
      - ./:/var/www/html

  scheduler:
    image: joaopinto14/production:2.0.1-laravel-php8.5
    command: php artisan schedule:work
    restart: unless-stopped
    volumes:
      - ./:/var/www/html
```

In production, secrets and application configuration should be supplied using the mechanism appropriate for your deployment platform.

---

# Multi-architecture support

Production 2.0.1 is built and validated for:

```text
linux/amd64
linux/arm64
```

When the images are published as multi-platform Docker manifests, Docker automatically selects the correct architecture for the host.

## Supply-chain metadata

The stable release targets are configured to publish BuildKit attestations together with the Docker Hub images:

```text
SBOM        SPDX software bill of materials
Provenance  SLSA provenance (mode=max)
```

These attestations are registry metadata attached to the published image index. They do not add packages or tools to the Production runtime filesystem. Docker Scout can use this metadata alongside its own image analysis for package, vulnerability, and supply-chain visibility.

Attestations are intentionally enabled only for registry release targets. Local and test builds remain compatible with Docker engines using image stores that do not support attestations.

---

# Testing

Production 2.0 includes an extensive automated test suite.

## Fast tests

```bash
./tests/test-fast.sh
```

Useful during normal development.

## Full test suite

```bash
./tests/test-all.sh
```

The full suite validates, among other things:

- all six image variants;
- image contracts;
- health checks;
- Nginx;
- PHP-FPM;
- runtime configuration;
- concurrent PHP requests;
- logging;
- crash handling;
- signal handling;
- hardened runtime operation;
- image-size regression budgets.

## Release validation

```bash
./tests/test-release.sh
```

Release validation additionally includes:

- clean no-cache builds;
- a real Generic PHP application;
- a real Laravel application;
- PHP 8.3, 8.4, and 8.5;
- restart stability;
- zombie-process detection;
- `linux/amd64` builds;
- `linux/arm64` builds.

---

# Migrating from 1.1.3 to 2.0.0

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

# Production 2.0 philosophy

Production 2.0 follows one simple rule:

> **The build prepares the application. Production runs the application.**

Tools that are only needed to build or develop the project stay outside the final runtime image.

This keeps the image smaller, more deterministic, and better suited for production deployments.

---

# License

See [`LICENSE.md`](LICENSE.md) for license information.
