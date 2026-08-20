#!/bin/sh
set -eu

. ./tests/lib.sh

section "Clean release build (six variants, no cache)"

VCS_REF="${VCS_REF:-rc.1-clean-build}"
log "Building all six ${TEST_VERSION} images from scratch"
VERSION="${TEST_VERSION}" IMAGE_NAME="${TEST_IMAGE_NAME}" VCS_REF="${VCS_REF}" \
    docker buildx bake --no-cache --load

printf '%s\n' 'Clean release build passed.'
