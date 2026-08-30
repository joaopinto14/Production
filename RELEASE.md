# Production 2.0.2 — Laravel Runtime Reliability Release

Production 2.0.2 is a maintenance release focused on Laravel FastCGI reliability and predictable non-root permissions while preserving the Production 2.x runtime architecture.

## What changed

### Laravel FastCGI buffering

The Laravel Nginx template now defines explicit response buffers instead of relying on Nginx defaults:

```nginx
fastcgi_buffer_size 32k;
fastcgi_buffers 8 32k;
fastcgi_busy_buffers_size 64k;
fastcgi_read_timeout 300s;
```

This prevents common Laravel failures such as:

```text
upstream sent too big header while reading response header from upstream
```

The Laravel front-controller FastCGI parameters also use `$realpath_root`, making resolved paths explicit when deployments use symlinks.

### Predictable non-root permissions

Official Production images now use a stable runtime identity:

```text
www UID = 10001
www GID = 10001
```

Production still starts directly as `www`. It does not start as root and does not recursively change ownership or permissions on mounted applications.

For Laravel bind mounts, the host should grant the runtime identity write access to only the directories Laravel needs to modify:

```bash
sudo chown -R 10001:10001 storage bootstrap/cache
```

Application code can remain read-only to the runtime user.

## Security and supply chain

Production 2.0.2 retains the 2.0.1 security and supply-chain behavior:

- Alpine 3.24 package refresh with `apk upgrade --no-cache` during builds;
- non-root runtime;
- support for read-only root filesystems;
- SBOM attestations on stable registry releases;
- SLSA provenance attestations in `mode=max`;
- stable release contract validation before Docker Hub publication.

## Compatibility

The following remain unchanged:

- Alpine Linux 3.24 base branch;
- PHP 8.3, 8.4 and 8.5 variants;
- Generic and Laravel variants;
- Nginx + PHP-FPM runtime;
- internal port 8080;
- `/healthz` health endpoint;
- environment-variable configuration;
- CLI mode;
- `linux/amd64` and `linux/arm64`.

The stable UID/GID is an intentional permission-contract improvement. Hosts using bind mounts should prepare Laravel writable directories for `10001:10001` before starting the container.

## Official Docker Hub repository

```text
joaopinto14/production
```

## Stable images

### Generic

```text
joaopinto14/production:2.0.2-php8.3
joaopinto14/production:2.0.2-php8.4
joaopinto14/production:2.0.2-php8.5
```

Stable aliases:

```text
joaopinto14/production:php8.3
joaopinto14/production:php8.4
joaopinto14/production:php8.5
joaopinto14/production:2.0.2
joaopinto14/production:latest
```

`2.0.2` and `latest` point to the Generic PHP 8.5 image.

### Laravel

```text
joaopinto14/production:2.0.2-laravel-php8.3
joaopinto14/production:2.0.2-laravel-php8.4
joaopinto14/production:2.0.2-laravel-php8.5
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

Before publication, the workflow runs:

```bash
./tests/test-release.sh
```

The stable gate validates clean builds, image contracts, smoke tests, configuration, HTTP behavior, concurrency, logs, crash/signal handling, hardened execution, size budgets, real PHP applications, a real Laravel application, restart stability, supported CPU architectures, stable runtime UID/GID, Laravel FastCGI configuration, release tags, and supply-chain attestations.

## Publishing

The stable release tag for this version is:

```text
v2.0.2
```

The tag must match the repository `VERSION` file. The release workflow then:

1. resolves and validates the stable Git tag;
2. verifies that the tag version matches `VERSION`;
3. runs the complete stable release validation;
4. publishes all six multi-architecture images, stable aliases, SBOM and provenance to Docker Hub;
5. creates the corresponding GitHub Release using `RELEASE.md`.

The repository requires the GitHub Actions secret:

```text
DOCKERHUB_TOKEN
```

## Upgrade notes

Users already running Production 2.0.1 can move to the equivalent 2.0.2 tag. Laravel deployments that bind-mount the project from the host should ensure `storage/` and `bootstrap/cache/` are writable by UID/GID `10001:10001`.

Users migrating from Production 1.1.3 should still read `MIGRATION.md`, which documents the major 1.1.3 → 2.0.0 runtime changes that also apply to 2.0.2.
