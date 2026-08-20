#!/bin/sh
set -eu

. ./tests/lib.sh

section "Multi-architecture build validation"

BUILDER_NAME="${MULTIARCH_BUILDER:-production-multiarch}"

extra_args=""
if [ "${NO_CACHE:-0}" = "1" ]; then
    extra_args="--no-cache"
    log "Multi-architecture build cache disabled"
fi

ensure_builder() {
    if docker buildx inspect "${BUILDER_NAME}" >/dev/null 2>&1; then
        log "Using existing Buildx builder: ${BUILDER_NAME}"
    else
        log "Creating dedicated docker-container Buildx builder: ${BUILDER_NAME}"
        docker buildx create \
            --name "${BUILDER_NAME}" \
            --driver docker-container \
            >/dev/null
    fi

    log "Bootstrapping Buildx builder"
    docker buildx inspect "${BUILDER_NAME}" --bootstrap >/dev/null
}

preflight_arm64() {
    log "Checking that the builder can execute ARM64 RUN steps"

    if printf '%s\n' \
        '# syntax=docker/dockerfile:1' \
        'FROM alpine:3.24' \
        'RUN uname -m >/dev/null' \
        | docker buildx build \
            --builder "${BUILDER_NAME}" \
            --platform linux/arm64 \
            --progress quiet \
            -f - \
            . >/dev/null 2>&1; then
        return 0
    fi

    cat >&2 <<EOF2
[test] ERROR: builder '${BUILDER_NAME}' cannot execute linux/arm64 RUN steps.

This host needs ARM64 emulation (QEMU/binfmt) or a native ARM64 builder node.
Docker's documented Linux fallback is:

  docker run --privileged --rm tonistiigi/binfmt --install arm64

Then rerun:

  ./tests/multiarch-build.sh

You can inspect detected builder platforms with:

  docker buildx inspect ${BUILDER_NAME} --bootstrap
EOF2
    exit 1
}

ensure_builder
preflight_arm64

# Intentionally no --load: a multi-platform result cannot be loaded into the
# classic local Docker image store as a single image. A dedicated
# docker-container builder is used so the test does not depend on the host's
# default `docker` builder implementation.
# shellcheck disable=SC2086
VERSION="${TEST_VERSION}" IMAGE_NAME="${TEST_IMAGE_NAME}" BUILDX_BUILDER="${BUILDER_NAME}" \
    docker buildx bake multiarch ${extra_args}

printf '%s\n' "Multi-architecture build validation passed (linux/amd64 + linux/arm64) with builder ${BUILDER_NAME}."
