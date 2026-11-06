# Production 2.0.5 — Simpler Laravel services

Run Generic and Laravel on PHP 8.3, 8.4 and 8.5, on amd64 and ARM64.

## Laravel commands

Laravel images now accept `scheduler`, `queue` and `artisan` directly. For
example, `command: ["scheduler"]` runs `php artisan schedule:work`, and
`command: ["queue", "--tries=3"]` runs `php artisan queue:work --tries=3`.
Full commands such as `php artisan schedule:work` remain supported.

The image entrypoint is now the stable executable `production`, which starts
Tini with subreaper support before configuring and executing the requested
command. Existing Swarm/Portainer services with a saved `php artisan` entrypoint
override must replace it with `entrypoint: ["production"]`; otherwise Docker
continues to bypass the image entrypoint. New services can omit this override.

## Automatic health checks

Web containers retain the PHP-FPM-backed `/readyz` readiness probe. CLI containers
check that their foreground process remains alive; they no longer require the
HTTP health check to be disabled. This is process liveness, not confirmation of
scheduler progress, queue throughput, or database availability. Application-level
health checks can still replace or disable it.

## Validation and release integrity

Service tests exercise all three PHP versions, argument preservation, explicit
Swarm-style entrypoints, application exit codes, signal forwarding, read-only
filesystems and adopted orphan collection while the service stays alive. The
existing web, security and release gates remain required.

Version 2.0.4 tags and digests remain immutable. Publication of 2.0.5 requires the
normal native amd64/ARM64 scans and runtime tests, package/source comparisons,
SBOM/provenance verification and signing of the exact promoted indexes. This
file describes the target release; it is not evidence of publication.
