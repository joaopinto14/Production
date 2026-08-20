#!/bin/sh
set -eu

. ./tests/lib.sh

section "Real Laravel 13 application tests"

LARAVEL_CONSTRAINT="${LARAVEL_CONSTRAINT:-^13.0}"
COMPOSER_IMAGE="${COMPOSER_IMAGE:-composer:2}"
ROOT="$(mktemp -d)"
APP_DIR="${ROOT}/app"
CONTAINERS=""

cleanup() {
    status=$?

    # Never let cleanup permissions mask the actual test result. Laravel runs
    # as the non-root www user inside the runtime image and may create nested
    # cache directories owned by that UID on the bind-mounted host path.
    trap - EXIT INT TERM
    set +e

    for c in ${CONTAINERS}; do
        remove_container "${c}"
    done

    cleanup_image="$(image_for laravel 8.3)"
    if [ -d "${ROOT}" ] && docker image inspect "${cleanup_image}" >/dev/null 2>&1; then
        docker run --rm \
            --user 0:0 \
            --entrypoint sh \
            -v "${ROOT}:/cleanup" \
            "${cleanup_image}" \
            -ec 'rm -rf /cleanup/app' >/dev/null 2>&1 || true
    fi

    rm -rf "${ROOT}" >/dev/null 2>&1 || true
    exit "${status}"
}
trap cleanup EXIT INT TERM

log "Creating a real Laravel application (${LARAVEL_CONSTRAINT}) with Composer outside the runtime image"
docker run --rm \
    --user "$(id -u):$(id -g)" \
    -e HOME=/tmp \
    -e COMPOSER_HOME=/tmp/composer \
    -v "${ROOT}:/workspace" \
    -w /workspace \
    "${COMPOSER_IMAGE}" \
    sh -ec "composer create-project --no-install --no-scripts --prefer-dist 'laravel/laravel:${LARAVEL_CONSTRAINT}' app >/dev/null"

log "Resolving production dependencies for the lowest supported PHP version (8.3)"
docker run --rm \
    --user "$(id -u):$(id -g)" \
    -e HOME=/tmp \
    -e COMPOSER_HOME=/tmp/composer \
    -v "${APP_DIR}:/app" \
    -w /app \
    "${COMPOSER_IMAGE}" \
    sh -ec "composer config platform.php 8.3.0 && composer install --no-dev --no-scripts --prefer-dist --no-interaction --no-progress --optimize-autoloader --ignore-platform-req='ext-*'"

cat > "${APP_DIR}/app/Http/Controllers/ProductionRuntimeController.php" <<'PHP'
<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class ProductionRuntimeController extends Controller
{
    public function runtime(): JsonResponse
    {
        return response()->json([
            'ok' => true,
            'laravel' => app()->version(),
            'php' => PHP_VERSION,
            'sapi' => PHP_SAPI,
        ]);
    }

    public function database(): JsonResponse
    {
        DB::statement('CREATE TABLE IF NOT EXISTS production_runtime (id INTEGER PRIMARY KEY AUTOINCREMENT, value TEXT NOT NULL)');
        DB::table('production_runtime')->insert(['value' => 'sqlite-ok']);

        return response()->json([
            'driver' => DB::connection()->getDriverName(),
            'value' => DB::table('production_runtime')->latest('id')->value('value'),
        ]);
    }

    public function cache(): JsonResponse
    {
        Cache::put('production-runtime', 'cache-ok', 60);
        return response()->json(['value' => Cache::get('production-runtime')]);
    }

    public function storage(): JsonResponse
    {
        Storage::disk('local')->put('production-runtime.txt', 'storage-ok');
        return response()->json(['value' => Storage::disk('local')->get('production-runtime.txt')]);
    }

    public function session(): JsonResponse
    {
        session(['production-runtime' => 'session-ok']);
        return response()->json(['value' => session('production-runtime')]);
    }

    public function failure()
    {
        throw new \RuntimeException('production-rc-hidden-error');
    }
}
PHP

cat > "${APP_DIR}/routes/web.php" <<'PHP'
<?php

use App\Http\Controllers\ProductionRuntimeController;
use Illuminate\Support\Facades\Route;

Route::get('/', [ProductionRuntimeController::class, 'runtime']);
Route::get('/runtime-db', [ProductionRuntimeController::class, 'database']);
Route::get('/runtime-cache', [ProductionRuntimeController::class, 'cache']);
Route::get('/runtime-storage', [ProductionRuntimeController::class, 'storage']);
Route::get('/runtime-session', [ProductionRuntimeController::class, 'session']);
Route::get('/runtime-failure', [ProductionRuntimeController::class, 'failure']);
PHP

printf '<?php echo "must-not-run";\n' > "${APP_DIR}/public/direct.php"
rm -f "${APP_DIR}/database/database.sqlite"
touch "${APP_DIR}/database/database.sqlite"
chmod -R a+rX "${APP_DIR}"
chmod -R a+rwX "${APP_DIR}/storage" "${APP_DIR}/bootstrap/cache" "${APP_DIR}/database"
chmod 0644 "${APP_DIR}/public/direct.php"

ensure_image "$(image_for laravel 8.3)"
APP_KEY="$(docker run --rm --entrypoint php "$(image_for laravel 8.3)" -r 'echo "base64:" . base64_encode(random_bytes(32));')"

common_env_args() {
    printf '%s\n' \
        '-e' 'APP_ENV=production' \
        '-e' 'APP_DEBUG=false' \
        '-e' "APP_KEY=${APP_KEY}" \
        '-e' 'LOG_CHANNEL=stderr' \
        '-e' 'DB_CONNECTION=sqlite' \
        '-e' 'DB_DATABASE=/var/www/html/database/database.sqlite' \
        '-e' 'CACHE_STORE=file' \
        '-e' 'SESSION_DRIVER=file' \
        '-e' 'QUEUE_CONNECTION=database'
}

run_artisan() {
    image="$1"
    shift
    # shellcheck disable=SC2046
    docker run --rm \
        $(common_env_args) \
        -v "${APP_DIR}:/var/www/html" \
        "${image}" php artisan "$@"
}

for php_version in 8.3 8.4 8.5; do
    image="$(image_for laravel "${php_version}")"
    ensure_image "${image}"
    log "Booting Laravel with PHP ${php_version}"

    rm -f "${APP_DIR}/database/database.sqlite"
    touch "${APP_DIR}/database/database.sqlite"
    chmod a+rw "${APP_DIR}/database/database.sqlite"
    rm -f "${APP_DIR}/bootstrap/cache/"*.php 2>/dev/null || true

    run_artisan "${image}" package:discover >/dev/null
    run_artisan "${image}" --version | grep -F 'Laravel Framework 13.' >/dev/null || fail "Laravel 13 did not boot on PHP ${php_version}."
    run_artisan "${image}" migrate --force >/dev/null
    run_artisan "${image}" migrate:status >/dev/null
    run_artisan "${image}" about --only=environment >/dev/null
    run_artisan "${image}" route:list >/dev/null
    run_artisan "${image}" schedule:list >/dev/null
    run_artisan "${image}" queue:work --stop-when-empty --max-time=5 --sleep=1 >/dev/null
    run_artisan "${image}" optimize >/dev/null

    container="production-real-laravel-${php_version}-$$"
    CONTAINERS="${CONTAINERS} ${container}"

    # shellcheck disable=SC2046
    docker run -d \
        --name "${container}" \
        --security-opt no-new-privileges:true \
        $(common_env_args) \
        -v "${APP_DIR}:/var/www/html" \
        "${image}" >/dev/null

    wait_healthy "${container}" 45

    assert_eq '200' "$(http_status "${container}" /up)" "Laravel /up health route (${php_version})"

    runtime="$(http_body "${container}" /)"
    assert_contains "${runtime}" '"ok":true' "Laravel root boot (${php_version})"
    assert_contains "${runtime}" '"laravel":"13.' "Laravel version (${php_version})"
    assert_contains "${runtime}" "\"php\":\"${php_version}." "Laravel PHP version (${php_version})"
    assert_contains "${runtime}" '"sapi":"fpm-fcgi"' "Laravel FPM SAPI (${php_version})"

    db="$(http_body "${container}" /runtime-db)"
    assert_contains "${db}" '"driver":"sqlite"' "Laravel SQLite driver (${php_version})"
    assert_contains "${db}" '"value":"sqlite-ok"' "Laravel SQLite query (${php_version})"

    assert_contains "$(http_body "${container}" /runtime-cache)" '"value":"cache-ok"' "Laravel file cache (${php_version})"
    assert_contains "$(http_body "${container}" /runtime-storage)" '"value":"storage-ok"' "Laravel storage (${php_version})"
    assert_contains "$(http_body "${container}" /runtime-session)" '"value":"session-ok"' "Laravel session (${php_version})"
    assert_eq '404' "$(http_status "${container}" /direct.php)" "Laravel direct PHP blocking (${php_version})"
    assert_eq '500' "$(http_status "${container}" /runtime-failure)" "Laravel production exception status (${php_version})"
    failure_body="$(docker exec "${container}" wget -q -O - http://127.0.0.1:8080/runtime-failure 2>/dev/null || true)"
    assert_not_contains "${failure_body}" 'production-rc-hidden-error' "APP_DEBUG=false leaked exception message (${php_version})"
    failure_logs="$(docker logs "${container}" 2>&1)"
    assert_contains "${failure_logs}" 'production-rc-hidden-error' "Laravel exception missing from logs (${php_version})"

    drivers="$(docker exec "${container}" php -r 'echo implode(",", PDO::getAvailableDrivers());')"
    assert_contains "${drivers}" 'mysql' "PDO MySQL driver (${php_version})"
    assert_contains "${drivers}" 'pgsql' "PDO PostgreSQL driver (${php_version})"
    assert_contains "${drivers}" 'sqlite' "PDO SQLite driver (${php_version})"
    docker exec "${container}" php -r 'exit(extension_loaded("redis") ? 0 : 1);' || fail "PhpRedis missing on PHP ${php_version}."

    docker stop -t 10 "${container}" >/dev/null
    assert_eq '0' "$(docker inspect --format '{{.State.ExitCode}}' "${container}")" "Laravel graceful shutdown (${php_version})"
    remove_container "${container}"

    # Command-mode contract: Artisan must execute without spawning the web runtime.
    cli_container="production-real-laravel-cli-${php_version}-$$"
    CONTAINERS="${CONTAINERS} ${cli_container}"
    # shellcheck disable=SC2046
    docker run -d \
        --name "${cli_container}" \
        $(common_env_args) \
        -v "${APP_DIR}:/var/www/html" \
        "${image}" php -r 'sleep(3);' >/dev/null
    sleep 1
    process_list="$(docker top "${cli_container}" -eo args 2>/dev/null || docker top "${cli_container}" 2>/dev/null || true)"
    assert_not_contains "${process_list}" 'nginx' "CLI mode unexpectedly started Nginx (${php_version})"
    assert_not_contains "${process_list}" 'php-fpm' "CLI mode unexpectedly started PHP-FPM (${php_version})"
    docker stop -t 5 "${cli_container}" >/dev/null 2>&1 || true
    remove_container "${cli_container}"
done

printf '%s\n' 'Real Laravel 13 tests passed on PHP 8.3, 8.4 and 8.5.'
