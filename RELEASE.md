# Production 2.0.3 — Runtime Hardening and Package Transparency

Production 2.0.3 is a maintenance release for the Generic and Laravel PHP runtime.

## Runtime fixes

- Hidden-file and hidden-directory protection now takes precedence over PHP execution in both Nginx templates. The ACME exception matches the exact `.well-known` path segment, and hidden descendants remain blocked.
- Runtime configuration rejects invalid memory/upload syntax, unsafe web document roots, timezone traversal and line breaks before writing PHP or Nginx configuration.
- Memory limits accept bytes, K/M/G (case-insensitive), or `-1`. Upload limits accept bytes or K/M/G. Web document roots must be absolute and contain only letters, digits, slash, dot, underscore or hyphen.
- CLI commands still do not require an existing web document root.
- CLI/queue/scheduler examples disable the inherited HTTP health check, which requires Nginx. Applications may supply their own worker-specific checks.

## Release reliability

Stable publication is serialized. Immediately before publishing, the workflow fetches tags and compares numeric stable versions. A historical release can publish its version-specific tags but cannot promote the shared stable aliases when a newer stable tag exists. Prerelease tags do not control this decision.

This safeguard applies to workflows containing this change; it does not retroactively modify workflows stored in older Git tags. Only the latest stable release should promote aliases through a manual publishing process.

Image signing and promotion of the exact tested build artifacts remain separate follow-up work. This release does not claim that mutable package repositories make independent rebuilds byte-for-byte reproducible.

## Package updates

Every successful release now appends a package-by-package comparison with the previous stable release to its GitHub Release notes and attaches Markdown and JSON inventories. The report covers Generic/Laravel, PHP 8.3/8.4/8.5 and amd64/arm64. Current-image references come from the digests returned by the actual publication.

The local amd64 preparation for 2.0.3 confirmed these changes against the existing local 2.0.2 images:

| Packages | Previous | New | Affected variants |
|---|---|---|---|
| apk-tools, libapk | 3.0.7-r0 | 3.0.8-r0 | All six |
| libcurl | 8.21.0-r0 | 8.22.0-r0 | All six |
| pcre2 | 10.47-r1 | 10.48-r0 | All six |
| tzdata | 2026c-r0 | 2026d-r0 | All six |
| xz-libs | 5.8.3-r0 | 5.8.4-r0 | All six |
| PHP 8.4 core and bundled extensions | 8.4.24-r0 | 8.4.25-r0 | Generic and Laravel PHP 8.4 |
| PHP 8.5 core and bundled extensions | 8.5.9-r0 | 8.5.10-r0 | Generic and Laravel PHP 8.5 |

See [the detailed local package comparison](reports/2.0.3-local-packages.md) and [machine-readable evidence](reports/2.0.3-local-packages.json). These are local build observations, not a claim about the eventual published images; the automatically attached registry report is authoritative for publication.

No specific CVE correction is claimed from a version comparison alone. The reported Docker Scout high-severity finding must be checked against its CVE and a scan of the published digest. Docker Scout was not available during local preparation.

## Compatibility

Alpine 3.24, PHP 8.3/8.4/8.5, Generic/Laravel variants, port 8080, UID/GID 10001:10001, CLI mode, non-root execution and the existing `/healthz` response are retained.

The `/healthz` endpoint checks Nginx only; it does not execute PHP or verify application dependencies. Configuration values outside the documented syntax now fail early.

## Validation

The release gate remains `./tests/test-release.sh`: clean builds, six-image contracts, smoke tests, configuration, HTTP behavior, concurrency, logging, crash/signal handling, hardened execution, size budgets, real PHP/Laravel applications, restart stability and amd64/arm64 builds.

New regression coverage includes hidden PHP files and directories, hidden PATH_INFO, exact ACME exceptions, invalid configuration, a real 16 KiB FastCGI response header, stable alias selection and package inventory comparisons.

## Publishing

The release tag is `v2.0.3` and must match `VERSION`. The official repository is `joaopinto14/production`.

Version tags follow `2.0.3-php8.x` and `2.0.3-laravel-php8.x`. When eligible for alias promotion, Generic PHP 8.5 also receives `latest` and Laravel PHP 8.5 receives `laravel`; the PHP-specific stable aliases are updated as well.

The GitHub Actions workflow requires `DOCKERHUB_TOKEN`, builds with SBOM and provenance attestations, publishes images, generates the package report and creates or updates the GitHub Release with the report attached. A missing baseline or incomplete inventory fails the release-note step instead of silently claiming a complete package comparison.

## Upgrade

Use the matching 2.0.3 image and recreate the application containers. Existing images and running containers do not update themselves. Preserve writable Laravel `storage/` and `bootstrap/cache/` mounts for UID/GID 10001:10001.
