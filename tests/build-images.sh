#!/bin/sh
set -eu

. ./tests/lib.sh

section "Building all local images once"

VCS_REF_VALUE="${VCS_REF:-unknown}"
if [ "${VCS_REF_VALUE}" = "unknown" ] && command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    VCS_REF_VALUE="$(git rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"
fi

log "VERSION=${TEST_VERSION} IMAGE_NAME=${TEST_IMAGE_NAME} VCS_REF=${VCS_REF_VALUE}"
VERSION="${TEST_VERSION}" IMAGE_NAME="${TEST_IMAGE_NAME}" VCS_REF="${VCS_REF_VALUE}" \
    docker buildx bake --load

printf '%s\n' 'All local images built.'
