#!/bin/sh
set -eu

. ./tests/lib.sh

section "Stable release contract"

assert_eq '2.0.0' "$(cat VERSION)" "stable VERSION file"

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
release_plan="$(IMAGE_NAME=joaopinto14/production VERSION=2.0.0 docker buildx bake release --print)"
for tag in \
    joaopinto14/production:2.0.0-php8.3 \
    joaopinto14/production:php8.3 \
    joaopinto14/production:2.0.0-php8.4 \
    joaopinto14/production:php8.4 \
    joaopinto14/production:2.0.0-php8.5 \
    joaopinto14/production:php8.5 \
    joaopinto14/production:2.0.0 \
    joaopinto14/production:latest \
    joaopinto14/production:2.0.0-laravel-php8.3 \
    joaopinto14/production:laravel-php8.3 \
    joaopinto14/production:2.0.0-laravel-php8.4 \
    joaopinto14/production:laravel-php8.4 \
    joaopinto14/production:2.0.0-laravel-php8.5 \
    joaopinto14/production:laravel-php8.5 \
    joaopinto14/production:laravel
do
    assert_contains "${release_plan}" "${tag}" "stable release tag plan"
done
assert_contains "${release_plan}" 'linux/amd64' "release amd64 platform"
assert_contains "${release_plan}" 'linux/arm64' "release arm64 platform"
printf '%s\n' 'Stable release contract passed.'
