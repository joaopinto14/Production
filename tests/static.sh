#!/bin/sh
set -eu

. ./tests/lib.sh

section "Static validation"

version_file="$(cat VERSION)"
assert_eq "${TEST_VERSION}" "${version_file}" "VERSION file mismatch"

grep -F "ARG VERSION=${TEST_VERSION}" Dockerfile >/dev/null || fail "Dockerfile VERSION default is not ${TEST_VERSION}."
grep -F "default = \"${TEST_VERSION}\"" docker-bake.hcl >/dev/null || fail "docker-bake.hcl VERSION default is not ${TEST_VERSION}."
grep -F "# Production ${TEST_VERSION}" RELEASE.md >/dev/null || fail "RELEASE.md does not describe ${TEST_VERSION}."
grep -F "# Production ${TEST_VERSION}" README.md >/dev/null || fail "README.md version is not ${TEST_VERSION}."
grep -F "## ${TEST_VERSION} - " CHANGELOG.md >/dev/null || fail "CHANGELOG.md has no entry for ${TEST_VERSION}."
grep -F "apk upgrade --no-cache" Dockerfile >/dev/null || fail "Dockerfile must refresh Alpine security packages with apk upgrade --no-cache."
grep -F 'ARG WWW_UID=10001' Dockerfile >/dev/null || fail "Dockerfile WWW_UID default must remain 10001."
grep -F 'ARG WWW_GID=10001' Dockerfile >/dev/null || fail "Dockerfile WWW_GID default must remain 10001."
grep -F 'addgroup -S -g "${WWW_GID}" www' Dockerfile >/dev/null || fail "Dockerfile must create www with the configured stable GID."
grep -F 'adduser -S -D -H -u "${WWW_UID}" -G www www' Dockerfile >/dev/null || fail "Dockerfile must create www with the configured stable UID."

grep -F 'fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;' nginx/laravel.conf.template >/dev/null || fail "Laravel FastCGI SCRIPT_FILENAME must use realpath_root."
grep -F 'fastcgi_param DOCUMENT_ROOT $realpath_root;' nginx/laravel.conf.template >/dev/null || fail "Laravel FastCGI DOCUMENT_ROOT must use realpath_root."
grep -F 'fastcgi_buffer_size 32k;' nginx/laravel.conf.template >/dev/null || fail "Laravel fastcgi_buffer_size regression."
grep -F 'fastcgi_buffers 8 32k;' nginx/laravel.conf.template >/dev/null || fail "Laravel fastcgi_buffers regression."
grep -F 'fastcgi_busy_buffers_size 64k;' nginx/laravel.conf.template >/dev/null || fail "Laravel fastcgi_busy_buffers_size regression."
grep -F 'fastcgi_read_timeout 300s;' nginx/laravel.conf.template >/dev/null || fail "Laravel fastcgi_read_timeout regression."
grep -F 'location ~* \.(?:php|phtml|phar|phps)(?:[^a-z0-9]|$) {' nginx/laravel.conf.template >/dev/null || fail "Laravel must block direct execution/exposure of non-front-controller PHP files."

log "Checking shell syntax"
python3 tests/release-policy.py
python3 tests/package-report.py
python3 tests/maintenance.py
python3 tests/release-promotion.py
python3 tests/release-verification.py
python3 tests/candidate-validation.py
python3 tests/signature-verification.py
python3 tests/release-automation.py
python3 -c 'import runpy; from pathlib import Path; runpy.run_path("scripts/check-candidates.py")["base_reference"](Path("Dockerfile").read_text())'
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
