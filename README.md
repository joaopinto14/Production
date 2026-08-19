# Production

Production is a small general-purpose Docker runtime for PHP web applications. The 2.x line keeps the image simple while providing a solid base for framework-specific variants such as Laravel.

> **Current development version:** `2.0.0-dev.1`
>
> This is a development release. It is not intended to replace the latest stable 1.x image yet.

## Runtime

`2.0.0-dev.1` contains:

- Alpine Linux 3.24
- PHP 8.5
- PHP-FPM
- Nginx
- Supervisor
- tzdata and CA certificates

PHP 8.5 includes OPcache as part of PHP core. The image configures OPcache with conservative production defaults.

### Included PHP extensions

The generic image intentionally keeps the extension set small:

- ctype
- curl
- fileinfo
- mbstring
- openssl
- PDO
- session
- tokenizer
- XML

Database drivers and framework-specific extensions are intentionally not included in this first generic development image. They will be handled by later variants, including the planned Laravel image.

## Build

```bash
docker build \
  --build-arg VERSION=2.0.0-dev.1 \
  -t production:2.0.0-dev.1-php8.5 .
```

## Run

Mount the application into `/var/www/html`:

```bash
docker run -d \
  --name production \
  -p 8080:80 \
  -v /path/to/project:/var/www/html \
  production:2.0.0-dev.1-php8.5
```

Open `http://localhost:8080`.

### Custom document root

For applications whose public directory is different, set `DOCUMENT_ROOT`:

```bash
docker run -d \
  -p 8080:80 \
  -v /path/to/project:/var/www/html \
  -e DOCUMENT_ROOT=/var/www/html/public \
  production:2.0.0-dev.1-php8.5
```

This is also the layout normally used by Laravel, although a dedicated Laravel variant is planned for a later 2.0.0 development release.

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `TIMEZONE` | `UTC` | System and PHP timezone. |
| `DOCUMENT_ROOT` | `/var/www/html` | Directory served by Nginx. |
| `PHP_MEMORY_LIMIT` | `128M` | PHP memory limit. |
| `UPLOAD_MAX_SIZE` | `8M` | PHP and Nginx upload limit. |
| `SUPERVISOR_CONF` | empty | Optional additional Supervisor configuration file. |

### Example

```bash
docker run -d \
  -p 8080:80 \
  -v /path/to/project:/var/www/html \
  -e TIMEZONE=Europe/Lisbon \
  -e DOCUMENT_ROOT=/var/www/html/public \
  -e PHP_MEMORY_LIMIT=256M \
  -e UPLOAD_MAX_SIZE=32M \
  production:2.0.0-dev.1-php8.5
```

## Docker Compose

```yaml
services:
  web:
    image: production:2.0.0-dev.1-php8.5
    ports:
      - "8080:80"
    volumes:
      - ./app:/var/www/html
    environment:
      TIMEZONE: Europe/Lisbon
      DOCUMENT_ROOT: /var/www/html/public
      PHP_MEMORY_LIMIT: 256M
      UPLOAD_MAX_SIZE: 32M
```

## Smoke test

A Docker-based smoke test is included. It builds the image, checks the PHP CLI, starts Nginx/PHP-FPM, waits for the healthcheck, and executes a PHP request:

```bash
./tests/smoke.sh
```

To use a different local image tag:

```bash
IMAGE=my-production:test ./tests/smoke.sh
```

## Healthcheck

The image exposes an infrastructure health endpoint:

```text
/healthz
```

It returns HTTP `200` without executing the application or querying external services.

## Logs

Nginx and PHP-FPM write directly to Docker stdout/stderr:

```bash
docker logs production
```

## CLI commands

The entrypoint does not force Nginx/Supervisor when a custom command is supplied. For example:

```bash
docker run --rm production:2.0.0-dev.1-php8.5 php -v
```

Or, with an application mounted:

```bash
docker run --rm \
  -v /path/to/project:/var/www/html \
  production:2.0.0-dev.1-php8.5 \
  php /var/www/html/script.php
```

## Breaking changes from 1.x

- `PHP_EXTENSIONS` has been removed. Runtime package installation is no longer supported.
- `INDEX_PATH` is now `DOCUMENT_ROOT`.
- `MEMORY_LIMIT` is now `PHP_MEMORY_LIMIT`.
- The container no longer changes ownership recursively on `/var/www/html`.
- Logs are available through Docker rather than being primarily stored under `/var/log`.

## Roadmap to 2.0.0

The initial development plan is:

1. `2.0.0-dev.1`: clean PHP 8.5 generic runtime.
2. Evaluate the process model and whether Supervisor should remain.
3. Add builds/tags for multiple supported PHP versions.
4. Add a Laravel-optimised variant built from the same source.
5. Add multi-architecture builds and automated release/tag generation.
6. Release candidate and final `2.0.0`.

## License

MIT. See [LICENSE.md](LICENSE.md).
