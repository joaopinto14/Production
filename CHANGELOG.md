# Changelog

All notable changes to Production are documented in this file.

## Unreleased

No changes yet.

## 2.0.2 - 2026-08-30

### Fixed

- Added explicit Laravel FastCGI response buffers (`32k`, `8 x 32k`, busy buffer `64k`) to avoid `upstream sent too big header while reading response header from upstream` failures caused by Nginx defaults.
- Laravel FastCGI now passes resolved real paths to PHP-FPM through `$realpath_root` for `SCRIPT_FILENAME` and `DOCUMENT_ROOT`.

### Permissions

- Assigned the non-root `www` runtime user a stable UID/GID of `10001:10001` in official images.
- Added OCI labels for the runtime UID and GID.
- Kept the secure non-root startup model: Production does not perform recursive `chown`/`chmod` on mounted applications.
- Documented the host-side Laravel permission contract for `storage/` and `bootstrap/cache/`.

### Validation

- Added static regression checks for Laravel FastCGI buffers and real-path forwarding.
- Added image-contract checks for the stable `www` UID/GID and runtime identity labels.

## 2.0.1 - 2026-08-29

### Security

- Refreshes installed Alpine 3.24 packages with `apk upgrade --no-cache` before runtime dependencies are installed, ensuring available security fixes are applied at build time.
- Rebuilds all Generic and Laravel variants from the current Alpine 3.24 repositories, allowing patched OpenSSL libraries and other base packages to replace vulnerable revisions when fixes are available.
- Keeps the runtime API and application compatibility unchanged from 2.0.0.

### Supply chain

- Added release-only BuildKit SBOM attestations for published Docker Hub images.
- Added release-only SLSA provenance attestations in `mode=max` for published Docker Hub images.
- Extended the release contract to verify both supply-chain attestations are present in the Bake release plan.

### Release tooling

- Generalized the stable release workflow from a hardcoded `v2.0.0` trigger to stable `vX.Y.Z` tags.
- Added validation that the Git tag matches the repository `VERSION` file.
- Added automatic GitHub Release creation after successful Docker Hub publication.
- GitHub Releases use `RELEASE.md` as their release notes and are idempotent on re-runs.
- Generalized release contract tests so future stable versions are not hardcoded to 2.0.0.
- Fixed release attestation contract validation to match Buildx structured JSON output and verify SBOM/provenance on all six release targets.

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
