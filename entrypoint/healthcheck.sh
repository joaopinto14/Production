#!/bin/sh
set -eu

mode="$(cat /run/production/mode 2>/dev/null)" || {
    printf '%s\n' 'Runtime not initialized; retain the production entrypoint.' >&2
    exit 1
}

case "${mode}" in
    web)
        exec wget -q -T 2 -O /dev/null http://127.0.0.1:8080/readyz
        ;;
    cli)
        # Liveness only: application progress needs an application-specific check.
        pid="$(cat /run/production/command.pid)"
        case "${pid}" in
            ''|*[!0-9]*|0) exit 1 ;;
        esac
        kill -0 "${pid}" 2>/dev/null || exit 1
        state="$(awk '/^State:/ {print $2}' "/proc/${pid}/status" 2>/dev/null)" || exit 1
        case "${state}" in
            ''|Z|X|x) exit 1 ;;
        esac
        ;;
    *) exit 1 ;;
esac
