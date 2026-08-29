# Production 2.0.1 — Security & Supply-Chain Maintenance Release

Production 2.0.1 is a maintenance release for the Production 2.x runtime. It keeps the application/runtime contract of 2.0.0 while refreshing Alpine packages for available security fixes and strengthening published image metadata.

## What changed

### Security maintenance

Production now runs this during the image build before installing PHP, Nginx, and the remaining runtime packages:

```sh
apk upgrade --no-cache
```

This refreshes packages already present in the Alpine 3.24 base image to the latest revisions available in the configured stable repositories at build time. It allows fixed OpenSSL libraries and other security-sensitive base packages to replace older vulnerable revisions when Alpine has published a fix.

No OpenSSL version is pinned manually; Production follows patched package revisions from the Alpine 3.24 stable branch.

### Supply-chain metadata

Stable registry releases now publish:

```text
SBOM        BuildKit software bill of materials
Provenance  SLSA provenance (mode=max)
```

These attestations are attached to the registry image index. They do not install additional tools or packages in the Production runtime filesystem and can improve Docker Scout supply-chain visibility.

### Release automation

The stable release workflow now supports semantic stable tags (`vX.Y.Z`), verifies that the tag matches `VERSION`, publishes Docker Hub images, and then creates the corresponding GitHub Release from this `RELEASE.md`.

## Compatibility

There are no intentional application-facing breaking changes from Production 2.0.0.

The following remain unchanged:

- Alpine Linux 3.24 base branch;
- PHP 8.3, 8.4 and 8.5 variants;
- Generic and Laravel variants;
- Nginx + PHP-FPM runtime;
- non-root `www` user;
- internal port 8080;
- `/healthz`;
- environment-variable configuration;
- CLI mode;
- `linux/amd64` and `linux/arm64`.

## Official Docker Hub repository

```text
joaopinto14/production
```

## Stable images

### Generic

```text
joaopinto14/production:2.0.1-php8.3
joaopinto14/production:2.0.1-php8.4
joaopinto14/production:2.0.1-php8.5
```

Stable aliases:

```text
joaopinto14/production:php8.3
joaopinto14/production:php8.4
joaopinto14/production:php8.5
joaopinto14/production:2.0.1
joaopinto14/production:latest
```

`2.0.1` and `latest` point to the Generic PHP 8.5 image.

### Laravel

```text
joaopinto14/production:2.0.1-laravel-php8.3
joaopinto14/production:2.0.1-laravel-php8.4
joaopinto14/production:2.0.1-laravel-php8.5
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

The stable gate validates clean builds, image contracts, smoke tests, configuration, HTTP behavior, concurrency, logs, crash/signal handling, hardened execution, size budgets, real PHP applications, a real Laravel application, restart stability, supported CPU architectures, release tags, and supply-chain attestations.

## Publishing

The stable release tag for this version is:

```text
v2.0.1
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

Users already running Production 2.0.0 can move to the equivalent 2.0.1 tag without application configuration changes. Rebuild/pull the image to receive the refreshed Alpine packages.

Users migrating from Production 1.1.3 should still read `MIGRATION.md`, which documents the major 1.1.3 → 2.0.0 runtime changes that also apply to 2.0.1.
