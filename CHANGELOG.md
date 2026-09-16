# Changelog

All notable changes to Production are documented in this file.

## Unreleased

### Fixed

- Resolve each registry image index to its architecture-specific manifest digest before collecting package inventories. This avoids `cannot overwrite digest` when a classic Docker image store pulls amd64 and arm64 through the same index digest.
- Record both the requested image reference and the resolved platform reference in package reports; add regression tests for platform selection, attestations, registry ports and missing/ambiguous manifests.

## 2.0.3 - 2026-09-16

### Security and reliability

- Evaluate hidden-path denial before PHP handlers in both Nginx templates, including hidden PHP files, directories and PATH_INFO. Restrict the ACME exception to the exact `.well-known` path segment.
- Validate memory/upload sizes, web document roots and timezones before writing runtime configuration; reject line breaks and unsafe directives.
- Preserve CLI commands without a web document root and document disabling the inherited HTTP health check for workers and schedulers.
- Serialize releases and prevent historical versions from promoting stable aliases when a newer stable tag exists.

### Package transparency

- Generate package comparisons from the previous stable registry images and the digests of newly published images, covering all six variants on amd64 and arm64.
- Include package names, old/new versions, additions/removals and image identities in Markdown/JSON release attachments and GitHub Release notes.
- Record local amd64 updates in `reports/2.0.3-local-packages.md`: apk-tools/libapk 3.0.7-r0 → 3.0.8-r0, libcurl 8.21.0-r0 → 8.22.0-r0, pcre2 10.47-r1 → 10.48-r0, tzdata 2026c-r0 → 2026d-r0, xz-libs 5.8.3-r0 → 5.8.4-r0, PHP 8.4.24-r0 → 8.4.25-r0 and PHP 8.5.9-r0 → 8.5.10-r0 with bundled extensions. Published inventories are generated separately; no CVE remediation is inferred from package changes alone.

### Validation

- Add HTTP regression coverage for hidden paths and a real 16 KiB FastCGI response header.
- Add negative configuration tests, numeric release-policy tests and package inventory comparison tests.

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
