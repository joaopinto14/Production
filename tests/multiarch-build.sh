#!/bin/sh
set -eu

. ./tests/lib.sh

section "Multi-architecture build validation"

log "Bootstrapping Buildx builder"
builder_info="$(docker buildx inspect --bootstrap)"
assert_contains "${builder_info}" 'linux/amd64' "Buildx builder does not advertise amd64"
assert_contains "${builder_info}" 'linux/arm64' "Buildx builder does not advertise arm64; configure QEMU/binfmt first"

log "Building all six variants for linux/amd64 + linux/arm64"
VERSION="${TEST_VERSION}" IMAGE_NAME="${TEST_IMAGE_NAME}" docker buildx bake multiarch

printf '%s\n' 'Multi-architecture build validation passed.'
