#!/bin/sh

# Shared helpers for the Production test suite.
# This file is sourced by the individual test scripts.

TEST_VERSION="${VERSION:-2.0.0}"
TEST_IMAGE_NAME="${IMAGE_NAME:-production}"

log() {
    printf '[test] %s\n' "$*"
}

section() {
    printf '\n%s\n' "============================================================"
    printf '%s\n' "$*"
    printf '%s\n' "============================================================"
}

fail() {
    printf '[test] ERROR: %s\n' "$*" >&2
    exit 1
}

assert_eq() {
    expected="$1"
    actual="$2"
    message="${3:-values differ}"
    [ "${actual}" = "${expected}" ] || fail "${message}: expected '${expected}', got '${actual}'"
}

assert_ne() {
    unexpected="$1"
    actual="$2"
    message="${3:-unexpected value}"
    [ "${actual}" != "${unexpected}" ] || fail "${message}: got '${actual}'"
}

assert_contains() {
    haystack="$1"
    needle="$2"
    message="${3:-text does not contain expected value}"
    printf '%s' "${haystack}" | grep -F -- "${needle}" >/dev/null 2>&1 || fail "${message}: missing '${needle}'"
}

assert_not_contains() {
    haystack="$1"
    needle="$2"
    message="${3:-text contains forbidden value}"
    if printf '%s' "${haystack}" | grep -F -- "${needle}" >/dev/null 2>&1; then
        fail "${message}: found '${needle}'"
    fi
}

image_for() {
    variant="$1"
    php_version="$2"
    case "${variant}" in
        generic) printf '%s:%s-php%s' "${TEST_IMAGE_NAME}" "${TEST_VERSION}" "${php_version}" ;;
        laravel) printf '%s:%s-laravel-php%s' "${TEST_IMAGE_NAME}" "${TEST_VERSION}" "${php_version}" ;;
        *) fail "Unsupported variant '${variant}'" ;;
    esac
}

ensure_image() {
    image="$1"
    docker image inspect "${image}" >/dev/null 2>&1 || fail "Required image not found: ${image}. Run ./tests/build-images.sh first."
}

wait_healthy() {
    container="$1"
    max_attempts="${2:-30}"
    attempt=0

    while [ "${attempt}" -lt "${max_attempts}" ]; do
        state="$(docker inspect --format '{{.State.Status}}' "${container}" 2>/dev/null || true)"
        health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "${container}" 2>/dev/null || true)"

        [ "${health}" = "healthy" ] && return 0
        [ "${state}" = "exited" ] && break

        attempt=$((attempt + 1))
        sleep 1
    done

    docker logs "${container}" >&2 2>/dev/null || true
    fail "Container ${container} did not become healthy (state=${state:-unknown}, health=${health:-unknown})."
}

wait_exited() {
    container="$1"
    max_attempts="${2:-20}"
    attempt=0

    while [ "${attempt}" -lt "${max_attempts}" ]; do
        state="$(docker inspect --format '{{.State.Status}}' "${container}" 2>/dev/null || true)"
        [ "${state}" = "exited" ] && return 0
        attempt=$((attempt + 1))
        sleep 1
    done

    docker logs "${container}" >&2 2>/dev/null || true
    fail "Container ${container} did not exit within ${max_attempts}s."
}

http_body() {
    container="$1"
    path="$2"
    docker exec "${container}" wget -q -O - "http://127.0.0.1:8080${path}"
}

http_headers() {
    container="$1"
    path="$2"
    docker exec "${container}" wget -S -O /dev/null "http://127.0.0.1:8080${path}" 2>&1 || true
}

http_status() {
    container="$1"
    path="$2"
    http_headers "${container}" "${path}" | awk '/HTTP\// {print $2; exit}'
}

remove_container() {
    container="$1"
    docker rm -f "${container}" >/dev/null 2>&1 || true
}
