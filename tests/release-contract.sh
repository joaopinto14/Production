#!/bin/sh
set -eu

. ./tests/lib.sh

section "Release-candidate contract"

assert_eq '2.0.0-rc.1' "$(cat VERSION)" "RC VERSION file"

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

printf '%s\n' 'Release-candidate contract passed.'
