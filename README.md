# Production

Imagem Docker PHP leve e orientada a produção, com variantes genérica e Laravel, PHP 8.3/8.4/8.5 e suporte `amd64` + `arm64`.

## Estado

Release candidate atual: **2.0.0-rc.1**.

A arquitetura e o conjunto de funcionalidades estão congelados. A `rc.1` concentra-se em validação com aplicações reais, builds limpos, estabilidade de restart e multi-arquitetura.

## Variantes

### Genérica

```text
production:2.0.0-rc.1-php8.3
production:2.0.0-rc.1-php8.4
production:2.0.0-rc.1-php8.5
```

Document root predefinido:

```text
/var/www/html
```

### Laravel

```text
production:2.0.0-rc.1-laravel-php8.3
production:2.0.0-rc.1-laravel-php8.4
production:2.0.0-rc.1-laravel-php8.5
```

Document root predefinido:

```text
/var/www/html/public
```

A variante Laravel é um **runtime de produção**. Não contém Laravel, Composer, Node, npm ou ferramentas de compilação.

## Base comum

- Alpine Linux 3.24
- Nginx
- PHP-FPM
- PHP 8.3, 8.4 ou 8.5
- runtime shell mínimo, sem Supervisor/Python
- utilizador non-root `www`
- porta interna `8080`
- OPcache
- healthcheck `/healthz`
- logs em stdout/stderr
- shutdown gracioso
- suporte a root filesystem read-only
- labels OCI
- `linux/amd64` e `linux/arm64`

## Extensões — genérica

- ctype
- curl
- fileinfo
- mbstring
- openssl
- PDO
- session
- tokenizer
- XML
- OPcache

## Extensões adicionais — Laravel

- bcmath
- DOM
- intl
- pcntl
- PDO MySQL
- PDO PostgreSQL
- PDO SQLite
- PhpRedis
- zip

## Build local

Construir as seis imagens:

```bash
docker buildx bake
```

Apenas genéricas:

```bash
docker buildx bake generic
```

Apenas Laravel:

```bash
docker buildx bake laravel
```

## Utilização genérica

```bash
docker run --rm \
  -p 8080:8080 \
  -v "$PWD:/var/www/html:ro" \
  production:2.0.0-rc.1-php8.5
```

## Utilização Laravel

A aplicação deve chegar à imagem já preparada, incluindo `vendor/` e assets compilados quando aplicável.

```bash
docker run --rm \
  -p 8080:8080 \
  -v "$PWD:/var/www/html" \
  production:2.0.0-rc.1-laravel-php8.5
```

### Artisan / worker / scheduler

O `ENTRYPOINT` não inicia Nginx/PHP-FPM quando é fornecido outro comando:

```bash
docker run --rm \
  -v "$PWD:/var/www/html" \
  production:2.0.0-rc.1-laravel-php8.5 \
  php artisan migrate --force
```

```bash
docker run --rm \
  -v "$PWD:/var/www/html" \
  production:2.0.0-rc.1-laravel-php8.5 \
  php artisan queue:work
```

```bash
docker run --rm \
  -v "$PWD:/var/www/html" \
  production:2.0.0-rc.1-laravel-php8.5 \
  php artisan schedule:work
```

## Variáveis de ambiente

| Variável | Predefinição | Descrição |
|---|---:|---|
| `TIMEZONE` | `UTC` | Timezone PHP/runtime |
| `DOCUMENT_ROOT` | depende da variante | Root servido por Nginx |
| `PHP_MEMORY_LIMIT` | `128M` | Limite de memória PHP |
| `UPLOAD_MAX_SIZE` | `8M` | Limite de upload e POST |

## Root filesystem read-only

O runtime pode funcionar com filesystem root read-only. `/run/production` e `/tmp` precisam de áreas temporárias graváveis.

```bash
UID_RUNTIME=$(docker run --rm --entrypoint id production:2.0.0-rc.1-php8.5 -u)
GID_RUNTIME=$(docker run --rm --entrypoint id production:2.0.0-rc.1-php8.5 -g)

docker run --rm \
  --read-only \
  --cap-drop ALL \
  --security-opt no-new-privileges:true \
  --tmpfs "/run/production:rw,nosuid,nodev,noexec,size=16m,mode=0755,uid=${UID_RUNTIME},gid=${GID_RUNTIME}" \
  --tmpfs "/tmp:rw,nosuid,nodev,noexec,size=16m,mode=1777" \
  -v "$PWD:/var/www/html:ro" \
  production:2.0.0-rc.1-php8.5
```

Numa aplicação Laravel, `storage/` e `bootstrap/cache/` também precisam de volumes ou tmpfs graváveis.

## Testes

### Desenvolvimento rápido

```bash
./tests/test-fast.sh
```

### Suite completa

```bash
./tests/test-all.sh
```

Para reutilizar imagens já construídas:

```bash
SKIP_BUILD=1 ./tests/test-all.sh
```

### Aplicação PHP real

```bash
./tests/real-generic.sh
```

Testa as três versões PHP com front-controller, sessões, POST, escrita temporária, OPcache, logs e shutdown.

### Laravel 13 real

```bash
./tests/real-laravel.sh
```

Este teste usa `composer:2` **fora da imagem de runtime** para criar uma aplicação Laravel 13 real e resolver as dependências para a versão mínima suportada, PHP 8.3. A mesma aplicação é depois testada nas variantes PHP 8.3, 8.4 e 8.5.

Valida, entre outros:

- boot real do framework;
- `/up`;
- Artisan;
- migrations;
- SQLite;
- drivers MySQL/PostgreSQL/SQLite;
- PhpRedis;
- file cache;
- storage;
- sessions;
- `artisan optimize`;
- queue worker;
- bloqueio de PHP direto em `public/`;
- command-mode sem Nginx/PHP-FPM.

### Release candidate completa

```bash
./tests/test-release.sh
```

Executa:

1. build das seis imagens com `--no-cache`;
2. suite completa reutilizando essas imagens;
3. contrato de limpeza da release;
4. aplicação PHP real nas três versões;
5. Laravel 13 real nas três versões;
6. ciclos repetidos de restart + verificação de zombies;
7. build sem cache para `linux/amd64` + `linux/arm64`.

### Comparação de tamanho

```bash
./tests/compare-size.sh
```

Por predefinição compara `2.0.0-dev.7` com `2.0.0-rc.1`.

## Multi-arquitetura

Para validação local, usa o script dedicado:

```bash
./tests/multiarch-build.sh
```

O script cria ou reutiliza um builder Buildx `docker-container` chamado `production-multiarch`, faz bootstrap e valida primeiro que consegue executar passos `RUN` em `linux/arm64`. Isto evita depender do builder `docker:default` do host.

Para uma validação sem cache:

```bash
NO_CACHE=1 ./tests/multiarch-build.sh
```

Se o host Linux não tiver emulação ARM64 disponível, o preflight termina antes do build completo e indica o comando oficial para registar QEMU/binfmt. Também podes escolher outro builder com `MULTIARCH_BUILDER=<nome>`.

## Tags da RC

A `rc.1` usa apenas tags explícitas:

```text
2.0.0-rc.1-php8.3
2.0.0-rc.1-php8.4
2.0.0-rc.1-php8.5
2.0.0-rc.1-laravel-php8.3
2.0.0-rc.1-laravel-php8.4
2.0.0-rc.1-laravel-php8.5
```

Não são criados `latest`, `php8.x`, `laravel-php8.x` ou `laravel` até à release estável.

Consulta [RELEASE.md](RELEASE.md) para os critérios de aprovação da RC.
