# Production 2.0.4 — Security and release integrity

Maintenance correction for Generic/Laravel, PHP 8.3/8.4/8.5, amd64/arm64.

## Runtime corrections

- Include Phar in Generic and Laravel for all three PHP branches; validate archive reading/execution while retaining the default phar.readonly setting.

- Add Alpine-packaged Tini as PID 1 for both web and CLI commands, including queues and schedulers. Reap adopted orphan processes without forwarding shutdown signals to the entire web process group. Regression tests create 200 orphan PHP processes while each container remains alive; previous pre-init CLI images accumulate them.

- Block mixed-case PHP filenames, PHP backup suffixes and alternate PHP source extensions instead of serving their contents. Normal Generic PHP execution, Laravel's front controller, hidden-path denial and ACME access remain covered by regression tests.
- Drain active Nginx requests before stopping PHP-FPM. `SHUTDOWN_TIMEOUT` bounds the complete operation (default 30 seconds, range 1–300); forced shutdown exits with error. Give Docker/Compose a longer stop grace period, for example 40 seconds with the default.
- Add `/readyz`, backed by PHP-FPM's built-in ping, and use it for Docker health checks. `/healthz` remains Nginx liveness. Neither checks application databases or caches. CLI workers still need `--no-healthcheck` and their own checks.
- Exclude credentials and development files from Docker's build context using an explicit runtime-file allowlist. Reject malformed PHP build versions.
- Correct read-only mount ownership, modes and upload capacity guidance, including a 17 MiB multipart regression. Laravel writable storage remains application-managed.
- Make image size measurements fail on save/compressor failures; keep the current extension contracts and size budgets.

## Release corrections

Runtime validation retains suite logs, exit codes and the exact tested image IDs.
Promotion requires complete fresh results on both architectures and verifies log
hashes against the saved evidence. Registry checks read actual image configuration,
populated SPDX SBOMs and SLSA provenance for every platform before signing and
after promotion. Final tags must match the tested indexes before the GitHub
Release is made public. See the [release runbook](docs/RELEASING.md).

Staging artifacts are built once with SBOM/provenance. Native amd64 and arm64 jobs pull, scan and test their exact digests, including real PHP/Laravel applications. Scan results must match every APK package/version, identify the expected image and use a current vulnerability database. Fixable HIGH/CRITICAL findings block promotion.

Package comparison with the previous stable release is prepared before public tags change. The publishing job signs and verifies the tested indexes using keyless Cosign and saves evidence to a draft GitHub Release. It copies those same indexes to version tags, then stable aliases. Existing version tags can only be reused when their digest matches; conflicts fail before promotion. A failed partial promotion can be rerun, and notes can be repaired independently without building or moving images. See [SUPPORT.md](SUPPORT.md#publishing-a-maintenance-correction).

All workflow actions are pinned by complete commit SHA. Validation jobs have read-only repository permissions, checkout credentials are not persisted, and only publishing/signing jobs receive the required write/OIDC permissions. Monthly package refreshes use CI and native amd64/arm64 release validation before publication; weekly dependency update proposals keep base and action changes visible. The separate daily maintenance workflow has been removed.

## Package evidence and publication

The audit of public 2.0.3 identified package vulnerabilities; 2.0.4 uses fresh Alpine packages. The original local observations are recorded in [the remediation report](reports/remediation-2.0.4/REMEDIATION.md); the subsequent PID 1/orphan correction has [separate evidence](reports/zombies-2026-10-30/REPORT.md). These observations do not establish the state of future registry builds. The release workflow attaches the authoritative per-platform inventories and scan evidence for the exact promoted digests.

Release tag: `v2.0.4`, matching `VERSION`. Repository: `joaopinto14/production`. Versioned tags are `2.0.4-php8.x`, `2.0.4-laravel-php8.x` and `2.0.4` (Generic PHP 8.5). Eligible releases also promote the existing stable aliases; historical releases cannot roll them back.

After publication, recreate application containers using the selected 2.0.4 image. Old images and running containers do not update automatically. Port 8080, Alpine 3.24, UID/GID 10001:10001, CLI mode and documented extensions are retained.
