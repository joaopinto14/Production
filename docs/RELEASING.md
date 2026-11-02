# Releasing Production

This procedure applies to the new release workflow prepared for **2.0.4**.
Older Git tags retain their original workflows. A local test run is preparation;
the native GitHub jobs and the evidence for the staged registry digests authorize
promotion. Do not describe 2.0.4 as published until the workflow has completed.

## Prepare the source

1. Review the changes and their migration impact. Keep `VERSION`, Dockerfile/Bake
   defaults, test defaults, changelog and `RELEASE.md` consistent. Keep the
   changelog entry marked Unreleased until the publication date is known.
2. Run the static checks and review runtime, release-policy and registry tests.
   CI must pass on the reviewed commit. Merge into `main` before tagging.
3. Confirm that the `release` GitHub environment permits `v*` tags and dispatch
   from `main`, contains the scoped `DOCKERHUB_TOKEN`, and has the intended
   reviewers. Main must require Runtime tests and Multi-architecture build.
4. Confirm access to native amd64 and arm64 runners, Docker Hub, the vulnerability
   database, GitHub OIDC and Sigstore. `scripts/configure-repository.py` is an
   administrative tool: review its requested protections before applying it.

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
- If staging tags are missing after a partial promotion, recover the saved
  candidate digests/tags. Do not rebuild with mutable APK repositories under an
  already partly published version.
- A fresh workflow run must revalidate candidates. Evidence older than the
  configured freshness limits cannot be reused to bypass validation.
- For notes-only repair, dispatch Release with the existing tag and
  `repair_notes=true`. This does not promote images or publish an unfinished draft.
- Registry conflicts require investigation or a new patch version. Do not delete
  or overwrite an immutable version tag to force a green run.

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
