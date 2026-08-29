#!/bin/sh
set -eu

. ./tests/lib.sh

section "Stable release contract"

stable_version="$(tr -d '[:space:]' < VERSION)"
assert_eq "${TEST_VERSION}" "${stable_version}" "stable VERSION file"

for variant in generic laravel; do
    for php_version in 8.3 8.4 8.5; do
        image="$(image_for "${variant}" "${php_version}")"
        ensure_image "${image}"
        version="$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.version"}}' "${image}")"
        assert_eq "${TEST_VERSION}" "${version}" "OCI version (${variant}/${php_version})"

        docker run --rm --entrypoint sh "${image}" -ec '
            for path in /Dockerfile /README.md /CHANGELOG.md /tests /.git; do
                [ ! -e "$path" ] || { echo "development artefact present: $path" >&2; exit 1; }
            done
            for command in composer node npm python3 supervisord git gcc make; do
                ! command -v "$command" >/dev/null 2>&1 || { echo "forbidden runtime tool present: $command" >&2; exit 1; }
            done
        ' || fail "Release-runtime cleanliness failed (${variant}/${php_version})."
    done
done

log "Checking stable Docker Hub release tags and platforms"
release_plan="$(IMAGE_NAME=joaopinto14/production VERSION="${TEST_VERSION}" docker buildx bake release --print)"
for tag in \
    "joaopinto14/production:${TEST_VERSION}-php8.3" \
    joaopinto14/production:php8.3 \
    "joaopinto14/production:${TEST_VERSION}-php8.4" \
    joaopinto14/production:php8.4 \
    "joaopinto14/production:${TEST_VERSION}-php8.5" \
    joaopinto14/production:php8.5 \
    "joaopinto14/production:${TEST_VERSION}" \
    joaopinto14/production:latest \
    "joaopinto14/production:${TEST_VERSION}-laravel-php8.3" \
    joaopinto14/production:laravel-php8.3 \
    "joaopinto14/production:${TEST_VERSION}-laravel-php8.4" \
    joaopinto14/production:laravel-php8.4 \
    "joaopinto14/production:${TEST_VERSION}-laravel-php8.5" \
    joaopinto14/production:laravel-php8.5 \
    joaopinto14/production:laravel
do
    assert_contains "${release_plan}" "${tag}" "stable release tag plan"
done
assert_contains "${release_plan}" 'linux/amd64' "release amd64 platform"
assert_contains "${release_plan}" 'linux/arm64' "release arm64 platform"

log "Checking supply-chain attestations for every release target"
for target in \
    php83-release \
    php84-release \
    php85-release \
    laravel-php83-release \
    laravel-php84-release \
    laravel-php85-release
do
    target_plan="$(IMAGE_NAME=joaopinto14/production VERSION="${TEST_VERSION}" docker buildx bake "${target}" --print)"
    target_plan_compact="$(printf '%s' "${target_plan}" | tr -d '[:space:]')"

    # Buildx --print renders attestations as structured JSON objects, for example:
    # {"mode":"max","type":"provenance"} and {"type":"sbom"}.
    assert_contains "${target_plan_compact}" '"type":"provenance"' "release SLSA provenance attestation (${target})"
    assert_contains "${target_plan_compact}" '"mode":"max"' "release SLSA provenance mode (${target})"
    assert_contains "${target_plan_compact}" '"type":"sbom"' "release SBOM attestation (${target})"
    assert_contains "${target_plan_compact}" '"linux/amd64"' "release amd64 platform (${target})"
    assert_contains "${target_plan_compact}" '"linux/arm64"' "release arm64 platform (${target})"
done

log "Checking GitHub release workflow contract"
workflow="$(cat .github/workflows/release.yml)"
assert_contains "${workflow}" "- 'v*.*.*'" "stable tag trigger"
assert_contains "${workflow}" 'contents: write' "GitHub Release write permission"
assert_contains "${workflow}" 'Verify tag matches VERSION' "tag/VERSION validation"
assert_contains "${workflow}" 'git rev-parse HEAD' "release revision resolution"
assert_contains "${workflow}" 'VCS_REF: ${{ steps.revision.outputs.sha }}' "release image revision label"
assert_contains "${workflow}" 'docker buildx bake release --push' "Docker Hub release publication"
assert_contains "${workflow}" 'gh release create' "GitHub Release creation"
assert_contains "${workflow}" '--verify-tag' "GitHub Release tag verification"
assert_contains "${workflow}" '--notes-file RELEASE.md' "GitHub Release notes source"
assert_contains "${workflow}" 'GitHub Release ${RELEASE_TAG} already exists' "idempotent GitHub Release handling"

printf '%s\n' 'Stable release contract passed.'
