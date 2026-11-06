# Releasing Production

This procedure applies to the release workflow used for **2.0.5** and recovery
of the original **2.0.4** artifacts.
Older Git tags retain their original workflows. A local test run is preparation;
the native GitHub jobs and the evidence for the staged registry digests authorize
promotion. Do not describe a version as published until its workflow has completed.

## Prepare the source

1. Review the changes and their migration impact. Keep `VERSION`, Dockerfile/Bake
   defaults, test defaults, changelog and `RELEASE.md` consistent. Keep the
   changelog entry marked Unreleased until the publication date is known.
2. Run the static checks and review runtime, release-policy and registry tests.
   Pushes to `dev`, pull requests and `main` run intensive CI, including real
   PHP/Laravel applications, restart tests, scans and multi-architecture builds.
   Require the checks before merging the reviewed pull request into `main`.
3. Confirm that the `release` GitHub environment permits `v*` tags and dispatch
   from `main`, contains the scoped `DOCKERHUB_TOKEN`, and has the intended
   reviewers. Main must require pull requests, Runtime tests and
   Multi-architecture build, with strict/up-to-date checks.
4. Confirm access to native amd64 and arm64 runners, Docker Hub, the vulnerability
   database, GitHub OIDC and Sigstore. `scripts/configure-repository.py` is an
   administrative tool: review its requested protections before applying it.

## Automatic releases after main CI

Each workflow has one responsibility:

| Workflow | Responsibility |
|---|---|
| `ci.yml` | Build, test and scan changes. Repository access is read-only; CI never creates tags or publishes images. |
| `release.yml` | After successful main CI, prepare or recover the version and run the publication gates in the same workflow. Tags and manual runs remain supported. |
| `monthly.yml` | Prepare the monthly patch PR, await its tests, merge through protections and request main CI. |

Release listens for completed CI runs using `workflow_run`. Only successful
`push` or `workflow_dispatch` runs on this repository's `main` branch can prepare
a release; pull requests, forks, failed CI and superseded main revisions cannot.
The request job checks out the exact tested SHA and rechecks the current main
revision before continuing. Already published versions are skipped. Keep the
version defaults, `RELEASE.md`, README and changelog consistent in the pull request.

If an unpublished version already has a tag at an earlier commit, automation
checks that the tagged commit is an ancestor of tested main and that its VERSION
matches. It then recovers the **original tagged source**, without moving the tag
or including newer main changes in that version. The release gates still require
fresh native tests/scans for the original candidate digests. Tags outside main's
history or with mismatched VERSION fail. New source changes require a new version.

To recover the pending 2.0.4 release after these changes reach main, run **CI** on
`main` (or let the merge's main CI finish). A successful CI starts Release, which
recovers `v2.0.4` without retagging it. Alternatively dispatch **Release** from
`main` with `tag=v2.0.4` and `repair_notes=false`.

Registry reads retry transient rate limits, server errors and timeouts up to
four attempts, waiting 5, 15 and 30 seconds. Authentication/missing-artifact and
validation errors still fail immediately; persistent failures stop publication.
The existing combined content reads and verified-index reuse reduce Docker Hub
requests. These measures cannot guarantee that an exhausted Docker Hub quota
will recover within the retry window.
Release notes combine the curated `RELEASE.md`, the Git source diff/commits, and
the exact per-image/per-architecture package comparison. The comparison starts
from the preceding **published** stable GitHub Release, excluding drafts and
prereleases. Source comparison data is attached as `release-changes.md/.json`.

## Monthly package refresh

`monthly.yml` runs on day **1 at 00:00 Europe/Lisbon**, following Portugal's summer
and winter time automatically, or manually from `main`. The monthly release period
also uses Lisbon time, so summer midnight selects the new month even while UTC
is still on the previous day. Merge these workflow changes into the default
`main` branch to activate scheduling. GitHub may delay a scheduled run; this is a
calendar schedule rather than a guarantee that packages are never over a month
old. Failed validation retains the previous public version.

This is the only scheduled package-refresh workflow; there is no separate daily
maintenance workflow. Keep `ci.yml` and `release.yml`: the monthly workflow uses
them to validate and publish the refreshed images. Package updates stay within
the pinned Alpine branch and selected PHP branches; changing those branches
requires a separate reviewed update. Packages are never upgraded at container
startup.

The monthly workflow:

1. If the current main VERSION is still unpublished, requests main CI to recover
   it and exits without creating another version. Run monthly again after recovery
   to prepare the month's patch. Otherwise requires main to match the latest
   published stable release.
2. Creates one `maintenance/monthly-YYYY-MM` branch and pull request, increments
   only the patch version, synchronizes build/test/documentation defaults, and
   writes monthly release notes/changelog metadata.
3. Explicitly dispatches CI for that branch and waits for a new successful run
   of the exact commit. CI performs fresh, no-cache builds and intensive tests.
4. Requests a squash merge through normal branch protections, with the tested
   head SHA. It neither approves itself nor uses an administrator bypass.
5. Explicitly requests main CI after merging. Its successful completion starts
   Release, which builds once into staging and scans/tests exact digests on native amd64
   and ARM64, signs, and only then moves version tags and eligible stable aliases.

The workflow uses `GITHUB_TOKEN`; no additional personal access token is needed.
Enable **Settings → Actions → General → Allow GitHub Actions to create and approve
pull requests**, and allow squash merging. Existing required human reviews and
release-environment approvals still apply. For unattended monthly releases,
configure zero required human approvals while retaining required PRs and checks.
`scripts/configure-repository.py` verifies these settings; `--apply` can enable
missing settings without lowering existing review requirements.

Repeated runs in the same month reuse the existing PR or resume main CI after a
merge; they do not create another patch or overwrite version tags. Failed CI,
changed PR heads, protected merges and stale main checkouts stop the process.
An unpublished current version takes the recovery route instead of creating a
second version. The monthly job allows 140 minutes for branch CI within its
150-minute job budget, so a valid 120-minute runtime test is not cut short by the
previous 110-minute polling limit. Inspect the failed run/PR and rerun after resolving
the cause. If main moved since the monthly branch was created, update/review the
PR and rerun its checks before merging. Do not force a merge to bypass checks.

For example, a successful refresh publishes `2.0.5-php8.5` and moves `php8.5` and
`latest` to it; `2.0.4-php8.5` remains unchanged. Existing application containers
need an image pull and recreation to consume the update. Before rollout, test
the application against the new version and retain the previous version or
digest for rollback. Passing the image suites reduces regression risk but does
not guarantee compatibility with every application.

References: [GitHub workflow events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows),
[Actions repository permissions](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository).

For a local preparation run, use a separate image namespace:

```bash
export IMAGE_NAME=production-release-check
export VERSION="$(cat VERSION)"
export VCS_REF="$(git rev-parse HEAD)"
docker buildx bake --pull --no-cache --load
python3 scripts/validate-candidate.py --platform linux/amd64 \
  --revision "$VCS_REF" --output candidate-reports/local-release
python3 scripts/check-candidates.py --repository "$IMAGE_NAME" \
  --platform linux/amd64 --output candidate-reports/local-release
```

On an ARM64 host select `linux/arm64`. These commands create local images and
evidence; they do not publish. An uncommitted tree is not a release source, even
when its labels contain the current commit SHA. Commit/review the final tree and
let the release workflow build it. QEMU results do not replace native validation.

## Publish the reviewed tag

Creating and pushing `v2.0.4` starts publication, including registry writes.
Do this only when ready to publish the reviewed `main` commit:

```bash
git switch main
git pull --ff-only
test "$(cat VERSION)" = 2.0.4
test -z "$(git status --porcelain)"
git tag -a v2.0.4 -m "Production 2.0.4"
git push origin v2.0.4
```

The workflow performs these gates, in order of dependency:

1. Resolve the tag, check VERSION and require ancestry on `main`.
2. Create or reuse six staging indexes, each containing amd64/arm64, SBOM and
   provenance. Read the registry contents and verify platform/configuration
   identity, populated SPDX SBOMs and SLSA provenance for both architectures.
3. On native runners, scan exact platform digests and execute the complete suites
   without replacing the candidate images. Save every suite's log, exit code,
   duration and image IDs in `runtime-tests.json`; failed runs retain evidence.
4. Prepare the comparison with the previous stable release. Recheck both scan
   inventories, freshness, successful suites, image IDs and log hashes before
   signing. Verify the keyless signatures and attach evidence to a draft release.
5. Preflight immutable tags, promote the tested indexes, then move eligible
   aliases. Read back all version tags and eligible aliases; require matching
   digests, platforms, SBOMs and provenance before making the GitHub Release public.

After successful publication, update the default branch's README release-status
notice and changelog date to reflect the result. Do not rewrite the Git tag or
registry version tags to make a documentation correction.

The candidate/promotion artifact reports contain registry-read SPDX/provenance
contents. `release-verification.json` records the final registry check. This is a
structural/content check; authenticity comes from the separate Cosign signature
and its GitHub OIDC identity. Neither proves that application code is secure.

## Verify and consume a release

Download `release-metadata.json` from the matching GitHub Release and obtain the
full commit SHA from its reviewed Git tag. Check the version tags without moving
or rebuilding anything:

```bash
python3 scripts/verify-release.py --version 2.0.4 --revision FULL_COMMIT_SHA \
  --metadata release-metadata.json --published
```

Add `--aliases` only when checking the current release immediately after
publication: aliases can legitimately move to a newer release. Inspect
`release-evidence.tar.gz`, `release-packages.json`, `release-artifacts.json`,
`release-promotion.json`, `release-verification.json` and `release-digests.txt`.
Preserve these assets; Actions retention is 90 days.

Verify each digest's signature, with the workflow identity used for that run:

```bash
cosign verify \
  --certificate-identity 'https://github.com/joaopinto14/Production/.github/workflows/release.yml@refs/tags/v2.0.4' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  joaopinto14/production@sha256:INDEX_DIGEST
```

For a manual workflow dispatch from main, the signing workflow identity ends in
`@refs/heads/main`; the image revision must still match the selected release tag.
Use the exact identity of the reviewed run rather than a permissive regular
expression. Deploy by an approved digest when immutable selection is required.

## Recover a failed publication

Registry changes across tags are not atomic. Keep the GitHub Release as a draft
until final verification passes. Download the candidate metadata, per-platform
evidence and promotion journal from the failed run before retrying.

- Rerun failed jobs to reuse the staged indexes. Existing version tags with the
  same digest are accepted; a conflicting version tag stops promotion.
- Signature verification retries only registry discovery errors reporting
  `no signatures found`, with six attempts and bounded delays. Every attempt
  requires the same digest, certificate identity and issuer. Identity, certificate
  and claim failures still stop immediately; missing signatures also fail after
  the retry limit. Rerun artifacts replace earlier files with the same name so
  the preserved evidence describes the latest attempt.
- Manifest-only checks use raw index bytes to avoid loading child configurations
  and attestations repeatedly. Image configuration, SPDX and SLSA are read together.
  After promotion, fresh pre-signing artifact contents may be reused only for
  identical immutable digests and release identity; every final tag is still read
  from the registry and compared with its expected digest. This reduces registry
  requests without accepting different or unverified artifacts.
- If staging tags are missing after a partial promotion, recover the saved
  candidate digests/tags. Candidate creation automatically recovers missing
  digests from immutable version tags, including the bare version for PHP 8.5,
  and rejects conflicts with surviving staging tags. It never uses moving aliases.
  All six indexes must be recoverable once any version tag exists; otherwise
  restore the original saved candidates or use a new version. Recovery writes
  metadata only; it still requires registry identity/attestation verification and
  fresh native tests/scans before signing and promotion. Do not rebuild with
  mutable APK repositories under an already partly published version.
- If candidate creation fails before writing metadata, its artifact upload is
  skipped. Metadata from a partially completed build is still preserved.
- A fresh workflow run must revalidate candidates. Evidence older than the
  configured freshness limits cannot be reused to bypass validation.
- For notes-only repair, dispatch Release with the existing tag and
  `repair_notes=true`. This does not promote images or publish an unfinished draft.
- Registry conflicts require investigation or a new patch version. Do not delete
  or overwrite an immutable version tag to force a green run.

The candidate/publishing jobs load release tooling from the workflow's exact
commit SHA in a separate checkout. The image source remains the selected Git tag,
with its original revision and staging digests. This lets a reviewed workflow fix
on `main` recover an existing release through manual dispatch without rewriting
its tag or rebuilding its images. Fresh native validation is still required in
that new run; the publishing identity is then `@refs/heads/main`.

## Roll back an application

Keep the last approved image digest, application image, configuration and database
backup before deployment. Roll back the application service to that digest and
recreate it using the normal stop grace period. Keep volumes and persistent
Laravel storage. Verify health, a representative application request, worker
progress and logs after deployment.

Database migrations and application changes determine whether rollback is safe;
image rollback does not undo data/schema changes. Do not move shared `latest` or
PHP aliases backwards to roll back one application. Correct a bad public release
with a new version and clearly document the affected versions.

References: [BuildKit attestation storage](https://docs.docker.com/build/metadata/attestations/attestation-storage/),
[Buildx registry inspection](https://docs.docker.com/reference/cli/docker/buildx/imagetools/inspect/),
[support and maintenance policy](../SUPPORT.md).
