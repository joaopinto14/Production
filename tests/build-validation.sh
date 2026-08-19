#!/bin/sh
set -eu

. ./tests/lib.sh

section "Negative build validation"

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT INT TERM

expect_build_failure() {
    name="$1"
    expected="$2"
    shift 2
    log_file="${TMP_DIR}/${name}.log"

    if docker build --progress=plain "$@" . >"${log_file}" 2>&1; then
        cat "${log_file}" >&2 || true
        fail "Build '${name}' unexpectedly succeeded."
    fi

    output="$(cat "${log_file}")"
    assert_contains "${output}" "${expected}" "Build '${name}' did not fail for the expected reason"
}

log "Rejecting unsupported PHP versions"
expect_build_failure unsupported-php "Unsupported PHP version: 8.2" \
    --build-arg VERSION="${TEST_VERSION}" \
    --build-arg PHP_VERSION=8.2 \
    --build-arg VARIANT=generic

log "Rejecting unsupported variants"
expect_build_failure unsupported-variant "Unsupported variant: wordpress" \
    --build-arg VERSION="${TEST_VERSION}" \
    --build-arg PHP_VERSION=8.5 \
    --build-arg VARIANT=wordpress

printf '%s\n' 'Negative build validation passed.'
