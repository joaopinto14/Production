#!/bin/sh
set -eu

zombies() {
    for stat in /proc/[0-9]*/stat; do
        # Processes may exit between glob/read. Read once without spawning cut;
        # the command name in parentheses may itself contain spaces or ')'.
        IFS= read -r record 2>/dev/null < "${stat}" || continue
        fields="${record##*) }"
        [ "${fields%% *}" = Z ] || continue
        # Remaining fields start at state (field 3); starttime is field 22.
        # shellcheck disable=SC2086
        set -- ${fields}
        printf '%s:%s\n' "${stat}" "${20}"
    done
}

first="$(zombies)"
if [ -n "${first}" ]; then
    sleep 1
    second="$(zombies)"
    for before in ${first}; do
        for after in ${second}; do
            if [ "${before}" = "${after}" ]; then
                printf 'persistent zombie found: %s\n' "${before}" >&2
                exit 1
            fi
        done
    done
fi
