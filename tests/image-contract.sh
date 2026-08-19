#!/bin/sh
set -eu

. ./tests/lib.sh

section "Image contract validation"

PHP_VERSIONS="${PHP_VERSIONS:-8.3 8.4 8.5}"
VARIANTS="${VARIANTS:-generic laravel}"

for variant in ${VARIANTS}; do
    for php_version in ${PHP_VERSIONS}; do
        image="$(image_for "${variant}" "${php_version}")"
        ensure_image "${image}"
        log "Checking ${image}"

        assert_eq "www" "$(docker image inspect "${image}" --format '{{.Config.User}}')" "runtime user"
        assert_eq "${TEST_VERSION}" "$(docker image inspect "${image}" --format '{{index .Config.Labels "org.opencontainers.image.version"}}')" "OCI version"
        assert_eq "${php_version}" "$(docker image inspect "${image}" --format '{{index .Config.Labels "io.joaopinto.production.php-version"}}')" "PHP label"
        assert_eq "${variant}" "$(docker image inspect "${image}" --format '{{index .Config.Labels "io.joaopinto.production.variant"}}')" "variant label"
        assert_eq "8080" "$(docker image inspect "${image}" --format '{{index .Config.Labels "io.joaopinto.production.runtime-port"}}')" "runtime port label"

        entrypoint="$(docker image inspect "${image}" --format '{{json .Config.Entrypoint}}')"
        command="$(docker image inspect "${image}" --format '{{json .Config.Cmd}}')"
        ports="$(docker image inspect "${image}" --format '{{json .Config.ExposedPorts}}')"
        health="$(docker image inspect "${image}" --format '{{json .Config.Healthcheck.Test}}')"
        envs="$(docker image inspect "${image}" --format '{{range .Config.Env}}{{println .}}{{end}}')"

        assert_eq '["/usr/local/bin/entrypoint.sh"]' "${entrypoint}" "entrypoint contract"
        assert_eq '["/usr/local/bin/production-runtime"]' "${command}" "command contract"
        assert_contains "${ports}" '8080/tcp' "exposed port contract"
        assert_contains "${health}" '/healthz' "healthcheck contract"
        assert_contains "${envs}" 'TIMEZONE=UTC' "timezone default"
        assert_contains "${envs}" 'PHP_MEMORY_LIMIT=128M' "memory default"
        assert_contains "${envs}" 'UPLOAD_MAX_SIZE=8M' "upload default"

        actual_php="$(docker run --rm "${image}" php -r 'echo PHP_MAJOR_VERSION, ".", PHP_MINOR_VERSION;')"
        assert_eq "${php_version}" "${actual_php}" "PHP runtime version"

        runtime_uid="$(docker run --rm --entrypoint /usr/bin/id "${image}" -u)"
        assert_ne "0" "${runtime_uid}" "image must not run as root"

        slot="$(printf '%s' "${php_version}" | tr -d '.')"
        docker run --rm --entrypoint /bin/sh "${image}" -c "
            set -eu
            [ \"\$(readlink /usr/local/bin/php)\" = \"/usr/bin/php${slot}\" ]
            [ \"\$(readlink /usr/local/sbin/php-fpm)\" = \"/usr/sbin/php-fpm${slot}\" ]
            [ \"\$(readlink /etc/php-active)\" = \"/etc/php${slot}\" ]
            ! command -v supervisord >/dev/null 2>&1
            ! command -v python3 >/dev/null 2>&1
            ! apk info -e supervisor >/dev/null 2>&1
            test -x /usr/local/bin/production-runtime
        "

        if [ "${variant}" = "generic" ]; then
            docker run --rm "${image}" php -r '
                $required = ["ctype","curl","fileinfo","mbstring","openssl","PDO","session","tokenizer","xml","Zend OPcache"];
                $forbidden = ["bcmath","dom","intl","pcntl","pdo_mysql","pdo_pgsql","pdo_sqlite","redis","zip"];
                foreach ($required as $ext) { if (!extension_loaded($ext)) { fwrite(STDERR, "Missing extension: $ext\n"); exit(1); } }
                foreach ($forbidden as $ext) { if (extension_loaded($ext)) { fwrite(STDERR, "Unexpected generic extension: $ext\n"); exit(1); } }
            '
        else
            docker run --rm "${image}" php -r '
                $required = [
                    "ctype","curl","dom","fileinfo","filter","hash","mbstring","openssl","pcre","PDO","session","tokenizer","xml","Zend OPcache",
                    "bcmath","intl","pcntl","pdo_mysql","pdo_pgsql","pdo_sqlite","redis","zip"
                ];
                foreach ($required as $ext) { if (!extension_loaded($ext)) { fwrite(STDERR, "Missing Laravel extension: $ext\n"); exit(1); } }
            '
        fi
    done
done

printf '%s\n' 'Image contract validation passed.'
