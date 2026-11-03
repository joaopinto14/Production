# Support and maintenance policy

Policy reviewed on 2026-10-21. This describes the maintained runtime matrix and
the process for preparing updates; it is not a guarantee that an upstream fix is
available or that a particular published digest has no vulnerabilities.

## Maintained matrix

Production 2.x currently maintains **Generic** and **Laravel** for **PHP 8.3,
8.4 and 8.5**, on **linux/amd64** and **linux/arm64**, using **Alpine 3.24**.
PHP extensions remain part of the documented variant contract. They are updated
as Alpine packages, not installed at container startup.

| PHP branch | Upstream active support ends | Upstream security support ends |
|---|---|---|
| 8.3 | 2025-12-31 | 2027-12-31 |
| 8.4 | 2026-12-31 | 2028-12-31 |
| 8.5 | 2027-12-31 | 2029-12-31 |

These are the [PHP project's dates](https://www.php.net/supported-versions.php),
not promises that Alpine will ship every PHP branch until those dates.
[Alpine 3.24 main support is listed until 2028-06-01](https://alpinelinux.org/releases/).
Alpine **community** support normally lasts only until the next stable Alpine
release. PHP and several extensions come from community, so main's date alone
does not establish support for the complete Production image.

Review the matrix at least monthly and before every release, with particular
attention to the next Alpine stable release. Support requires all of the
following: upstream support, maintained Alpine packages for the complete variant,
availability on both architectures, and passing runtime/security validation.
An upstream-supported PHP version is not sufficient by itself.

## Base pin and reviewed updates

`Dockerfile` uses a literal `alpine:3.24@sha256:...` reference to the official
multi-architecture image index. The index pin selects the appropriate child
manifest for each architecture and prevents the base changing silently.
The old floating `ALPINE_VERSION` build argument is no longer used; a different
base requires an explicit Dockerfile change and review.

Base digest/patch references and GitHub Actions commit pins are updated through
reviewed pull requests. A new Alpine branch requires a review of packages,
extension parity, architecture support and this policy. Pull requests run CI;
release candidates additionally receive native amd64/arm64 validation before
publication. The monthly workflow refreshes APK packages using the pinned base;
it does not change the base digest or GitHub Actions references automatically.

The base pin does **not** freeze `apk upgrade` or `apk add`. Repositories remain
mutable. Each candidate therefore retains the actual package inventory and image
ID, together with the base index, resolved base manifest and scanner identity.
Independent rebuilds are not claimed to be byte-for-byte reproducible.

## Monthly package refresh and candidate validation

`.github/workflows/monthly.yml` is the only scheduled package-refresh workflow.
It runs on day **1 at 00:00 Europe/Lisbon**, or manually from `main`. It prepares
one patch-version pull request, runs CI and requests a protected merge. Main CI
then requests Release, where publication requires all of the following:

1. Build all six variants with `--pull --no-cache`, using the pinned Alpine base
   and the available APK package updates. Keep the supported Alpine/PHP branches
   and variant contracts; branch migrations require a separate reviewed change.
2. Save the staging digests, package inventories, SBOMs and provenance.
3. Pull those exact candidates on native amd64 and arm64 runners, scan them and
   run the full runtime, real PHP/Laravel application and restart suites without
   rebuilding the images under test.
4. Require complete successful evidence for both architectures, verify signatures
   and promote the same validated indexes to new version tags and eligible aliases.
5. Preserve release evidence for 90 days in Actions and attach it to the GitHub
   Release. CI scan evidence is retained for 30 days.

There is no separate daily maintenance workflow. Failed builds, tests or scans
stop publication of the candidates; existing versioned images remain available.
Packages are updated when building new images, not inside running containers.
Tests cover the documented image contract, but cannot guarantee compatibility
with every downstream application. Test that application against the new version
before rollout and retain its previous version or digest for rollback.

The scanner runs outside the runtime image and receives saved image archives,
not the Docker socket. Inventory/scanner failures remain failures, not empty
successful scans. See the [release runbook](docs/RELEASING.md#monthly-package-refresh)
for setup, publication and recovery.

The candidate vulnerability gate rejects **HIGH/CRITICAL findings with an
available fixed version**, mismatched/incomplete scan reports, incomplete APK package/version sets, stale scan/database evidence and an OS reported as end-of-support. Other findings, including those
without a fix, remain in the complete reports for review; passing is not a claim
of zero vulnerabilities. There are currently no automatic allowlists or ignore
files in this validation. Review scanner/DB failures and every failed scheduled run.
Review the pinned Trivy version/digest during the monthly maintenance review too.

To reproduce on a native supported host without touching existing local release
images:

```bash
export IMAGE_NAME=production-candidate
export VERSION="$(cat VERSION)"
export VCS_REF="$(git rev-parse HEAD)"
docker buildx bake --pull --no-cache --load
SKIP_BUILD=1 ./tests/test-all.sh
python3 scripts/check-candidates.py --platform linux/amd64
# Use --platform linux/arm64 on an ARM64 host.
```

Evidence is written to `candidate-reports/`, excluded from Git and build context.
Network access to Docker Hub and the Trivy vulnerability database is required.

## Publishing a maintenance correction

Follow [docs/RELEASING.md](docs/RELEASING.md) for preparation, registry verification,
failure recovery and application rollback. Security reports can be sent privately
as described in [SECURITY.md](SECURITY.md).

1. Review the base update and package/security reports; investigate outstanding
   findings and package availability rather than inferring CVE fixes from versions.
2. Select a **new** stable patch version, update `VERSION`, Dockerfile/Bake defaults,
   test defaults, changelog and release notes consistently. Use a minor/major
   release and migration notes for changes to the supported contract as needed.
3. Run the complete stable release validation, review both architectures' candidate
   results, and publish a matching `vX.Y.Z` tag through the release workflow.
4. The workflow builds deterministic staging tags (`candidate-<version>-<revision>-<variant>`) with SBOM/provenance, recording immutable index digests. On retry it reuses existing candidates instead of rebuilding them. If staging tags are missing after a partial public promotion, restore the saved candidate metadata/tags rather than rebuilding over a version tag.
5. Native amd64/arm64 jobs pull these digests and run full runtime and real-application suites. Scans must match the complete APK inventory and the expected configuration digest; report age is limited to 24 hours and database update/download age to 48 hours. Old output files are discarded before scanning. Registry, scanner and database errors fail closed.
6. Package comparisons are generated before publication. The publishing job signs all six tested indexes through GitHub OIDC/Cosign, verifies those signatures, and saves inventories/scans/metadata to a draft GitHub Release before touching public version tags or aliases.
7. Promotion copies the original indexes intact. It preflights all version tags: absent tags and identical digests are accepted, conflicting digests are refused before any write. All version tags are completed before aliases move. A promotion journal is saved as an Actions artifact even when a registry operation fails. The GitHub Release becomes public only after promotion succeeds.

Registry updates across multiple tags cannot be atomic. If a registry/network failure interrupts promotion, inspect the saved metadata, reports and promotion journal, then rerun failed workflow jobs or dispatch the same tag. Matching version tags are skipped and the remaining operations continue. Fresh full validation is required for a new workflow run; stale evidence never authorizes promotion. Never delete or overwrite a conflicting version tag to bypass the guard: investigate or use a new version. This protection covers this workflow, not independent registry publishers.

For notes-only repair, dispatch **Release** with the existing tag and `repair_notes=true`. This reads its saved package report and rewrites notes without building, signing or promoting images; it does not publish an unfinished draft. Missing evidence fails the repair instead of inventing a report. Artifacts are retained for 90 days in Actions and attached to the draft/public GitHub Release before promotion. Keep that release evidence for long-term recovery.

`release` is the restricted GitHub deployment environment for registry credentials. Allow only `v*` tags and the `main` dispatch branch. Keep Docker Hub credentials scoped to this repository; signing needs OIDC. GitHub write permissions are limited to release requests, monthly PR preparation and publishing jobs. Configure main to require pull requests, **Runtime tests** and **Multi-architecture build**, including strict/up-to-date status checks. `scripts/configure-repository.py` applies and verifies these protections and monthly PR permissions while preserving existing branch-review rules. Existing workflows in older Git tags are not changed retroactively.

Monthly package refreshes are scheduled for day 1 at 00:00 Europe/Lisbon, following
Portugal's summer/winter time automatically. They prepare a new
patch release through a tested PR, request main CI and use the same native release
validation gates before publishing. Published version tags are never rebuilt in
place; only eligible stable aliases move. Human review/environment requirements
can hold a monthly release, and failed tests retain the previous public images.
See [monthly refresh setup and recovery](docs/RELEASING.md#monthly-package-refresh).

After publication, verify version/alias digests, both architecture manifests, signatures and attached package/scan reports. Do not claim an upstream CVE is fixed from a version comparison alone.

## End of support and base migrations

Before PHP, Alpine or a required package loses support, prepare a reviewed
migration: confirm upstream/package dates, preserve extension parity, run both
architectures and real applications, scan candidates, and document the upgrade.
Introduce the replacement in release notes before removing a maintained variant
when practical. Do not silently redirect a PHP-specific alias to another PHP
branch or drop required extensions to keep a build green.

If a complete variant can no longer be maintained, document its last supported
release and replacement in this file, README and release notes. Stop promoting
that variant as maintained. Previously published version tags remain historical
artefacts and should not be described as receiving patches. A release must not
claim support merely because an old tag still pulls successfully.
