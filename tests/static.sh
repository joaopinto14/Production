#!/bin/sh
set -eu

. ./tests/lib.sh

section "Static validation"

version_file="$(cat VERSION)"
assert_eq "${TEST_VERSION}" "${version_file}" "VERSION file mismatch"

grep -F "ARG VERSION=${TEST_VERSION}" Dockerfile >/dev/null || fail "Dockerfile VERSION default is not ${TEST_VERSION}."
grep -F "default = \"${TEST_VERSION}\"" docker-bake.hcl >/dev/null || fail "docker-bake.hcl VERSION default is not ${TEST_VERSION}."
grep -F "apk upgrade --no-cache" Dockerfile >/dev/null || fail "Dockerfile must refresh Alpine security packages with apk upgrade --no-cache."

log "Checking shell syntax"
for script in entrypoint/*.sh tests/*.sh; do
    sh -n "${script}" || fail "Shell syntax error in ${script}."
done

log "Checking executable bits"
for script in entrypoint/*.sh tests/*.sh; do
    [ -x "${script}" ] || fail "Script is not executable: ${script}"
done

log "Checking Docker Bake definition"
docker buildx bake --print >/dev/null

if docker buildx build --help 2>/dev/null | grep -q -- '--check'; then
    log "Running Dockerfile build checks"
    docker buildx build --check . >/dev/null
else
    log "Docker build --check is not supported by this Buildx version; skipping lint check"
fi

log "Checking for CRLF line endings in runtime/test scripts"
for script in entrypoint/*.sh tests/*.sh; do
    if LC_ALL=C grep "$(printf '\r')" "${script}" >/dev/null 2>&1; then
        fail "CRLF line ending found in ${script}."
    fi
done

printf '%s\n' 'Static validation passed.'
