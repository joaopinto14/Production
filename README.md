# Production

Production is a small general-purpose Docker runtime for PHP web applications. The 2.x line keeps the image simple while providing a solid base for framework-specific variants such as Laravel.

> **Current development version:** `2.0.0-dev.2`
>
> This is a development release. It is not intended to replace the latest stable 1.x image yet.

## Runtime

`2.0.0-dev.2` contains:

- Alpine Linux 3.24
- PHP 8.5
- PHP-FPM
- Nginx
- Supervisor
- tzdata and CA certificates
- non-root runtime (`www`)

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

Database drivers and framework-specific extensions are intentionally not included in this generic development image. They will be handled by later variants, including the planned Laravel image.

## Security model

The default runtime does not run as root. `supervisord`, Nginx and PHP-FPM all run as the `www` user.

Because an unprivileged process cannot bind to port 80, Nginx listens on `8080` inside the container.

The image also no longer needs to modify `/etc` during startup. Runtime-generated files are placed under `/run/production`.

## Build

```bash
docker build \
  --build-arg VERSION=2.0.0-dev.2 \
  -t production:2.0.0-dev.2-php8.5 .
```

## Run

Mount the application into `/var/www/html`:

```bash
docker run -d \
  --name production \
  -p 8080:8080 \
  -v /path/to/project:/var/www/html:ro \
  production:2.0.0-dev.2-php8.5
```

Open `http://localhost:8080`.

### Custom document root

For applications whose public directory is different, set `DOCUMENT_ROOT`:

```bash
docker run -d \
  -p 8080:8080 \
  -v /path/to/project:/var/www/html:ro \
  -e DOCUMENT_ROOT=/var/www/html/public \
  production:2.0.0-dev.2-php8.5
```

This is also the layout normally used by Laravel, although a dedicated Laravel variant is planned for a later 2.0.0 development release.

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `TIMEZONE` | `UTC` | Runtime and PHP timezone. |
| `DOCUMENT_ROOT` | `/var/www/html` | Directory served by Nginx. |
| `PHP_MEMORY_LIMIT` | `128M` | PHP memory limit. |
| `UPLOAD_MAX_SIZE` | `8M` | PHP and Nginx upload limit. |
| `SUPERVISOR_CONF` | empty | Optional additional Supervisor configuration file. |

### Example

```bash
docker run -d \
  -p 8080:8080 \
  -v /path/to/project:/var/www/html \
  -e TIMEZONE=Europe/Lisbon \
  -e DOCUMENT_ROOT=/var/www/html/public \
  -e PHP_MEMORY_LIMIT=256M \
  -e UPLOAD_MAX_SIZE=32M \
  production:2.0.0-dev.2-php8.5
```

## File permissions

The image intentionally does not change ownership or permissions of mounted application files.

For read-only applications, make sure the `www` user can traverse directories and read the files. For applications that need writable paths, create/mount those paths with suitable permissions on the host or in the application image.

A future Laravel variant will document and optimise the writable `storage` and `bootstrap/cache` paths specifically.

## Docker Compose

```yaml
services:
  web:
    image: production:2.0.0-dev.2-php8.5
    ports:
      - "8080:8080"
    volumes:
      - ./app:/var/www/html
    environment:
      TIMEZONE: Europe/Lisbon
      DOCUMENT_ROOT: /var/www/html/public
      PHP_MEMORY_LIMIT: 256M
      UPLOAD_MAX_SIZE: 32M
```

## Smoke test

The Docker-based smoke test builds the image and verifies:

- PHP CLI
- non-root execution
- Nginx/PHP-FPM startup
- Docker healthcheck
- PHP HTTP response
- graceful container shutdown

Run it with:

```bash
./tests/smoke.sh
```

To use a different local image tag:

```bash
IMAGE=my-production:test ./tests/smoke.sh
```

## Healthcheck

The image exposes an infrastructure health endpoint on the internal port `8080`:

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

The entrypoint does not force Nginx/Supervisor when a custom command is supplied:

```bash
docker run --rm production:2.0.0-dev.2-php8.5 php -v
```

Or, with an application mounted:

```bash
docker run --rm \
  -v /path/to/project:/var/www/html:ro \
  production:2.0.0-dev.2-php8.5 \
  php /var/www/html/script.php
```

## Breaking changes from `dev.1`

- Internal HTTP port changed from `80` to `8080`.
- The image now runs as the non-root `www` user.
- Runtime configuration files are generated below `/run/production` instead of `/etc`.
- Mounted files must be readable (and, where required, writable) by the non-root runtime user.

## Breaking changes from 1.x

- `PHP_EXTENSIONS` has been removed. Runtime package installation is no longer supported.
- `INDEX_PATH` is now `DOCUMENT_ROOT`.
- `MEMORY_LIMIT` is now `PHP_MEMORY_LIMIT`.
- The container no longer changes ownership recursively on `/var/www/html`.
- Logs are available through Docker rather than being primarily stored under `/var/log`.
- The default internal HTTP port is now `8080`.
- The runtime is non-root by default.

## Roadmap to 2.0.0

1. `2.0.0-dev.1`: clean PHP 8.5 generic runtime. ✅
2. `2.0.0-dev.2`: non-root runtime, port 8080, runtime/signal cleanup. ✅
3. Add builds/tags for multiple supported PHP versions.
4. Add a Laravel-optimised variant built from the same source.
5. Add multi-architecture builds and automated release/tag generation.
6. Release candidate and final `2.0.0`.

## License

MIT. See [LICENSE.md](LICENSE.md).
