#!/bin/sh
set -eu

# Keep one stable entrypoint name for Docker, Compose and Swarm overrides.
if [ "$#" -eq 0 ]; then
    set -- /usr/local/bin/production-runtime
fi

exec /sbin/tini -s -- /usr/local/bin/entrypoint.sh "$@"
