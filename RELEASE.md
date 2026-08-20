# Production 2.0.0 — Stable Release

Production 2.0.0 is the first stable release of the redesigned 2.x runtime.
It promotes the validated `2.0.0-rc.1` runtime without adding new runtime features.

## Official Docker Hub repository

```text
joaopinto14/production
```

## Stable images

### Generic

```text
joaopinto14/production:2.0.0-php8.3
joaopinto14/production:2.0.0-php8.4
joaopinto14/production:2.0.0-php8.5
```

Stable aliases:

```text
joaopinto14/production:php8.3
joaopinto14/production:php8.4
joaopinto14/production:php8.5
joaopinto14/production:2.0.0
joaopinto14/production:latest
```

`2.0.0` and `latest` point to the Generic PHP 8.5 image.

### Laravel

```text
joaopinto14/production:2.0.0-laravel-php8.3
joaopinto14/production:2.0.0-laravel-php8.4
joaopinto14/production:2.0.0-laravel-php8.5
```

Stable aliases:

```text
joaopinto14/production:laravel-php8.3
joaopinto14/production:laravel-php8.4
joaopinto14/production:laravel-php8.5
joaopinto14/production:laravel
```

`laravel` points to the Laravel PHP 8.5 image.

## Architectures

Every published release target contains:

```text
linux/amd64
linux/arm64
```

## Release validation

Before publication, the release workflow runs:

```bash
./tests/test-release.sh
```

The stable gate validates clean builds, image contracts, smoke tests, configuration,
HTTP behavior, concurrency, logs, crash/signal handling, hardened execution, size
budgets, real PHP applications, a real Laravel 13 application, restart stability,
and both supported CPU architectures.

## Publishing

The GitHub Actions release workflow publishes only from the exact Git tag:

```text
v2.0.0
```

The repository must contain this GitHub Actions secret:

```text
DOCKERHUB_TOKEN
```

The Docker Hub username is fixed in the workflow as `joaopinto14`.

The workflow publishes the six multi-architecture images and their stable aliases
only after the complete release validation succeeds.

## Upgrade from 1.1.3

Production 2.0.0 contains intentional breaking changes. Read the migration section
in `README.md` or `MIGRATION.md` before upgrading an existing deployment.
