# Production

Imagem Docker PHP leve para produção, com variantes genérica e Laravel, várias versões PHP e suporte multi-arquitetura.

## Estado

Versão de desenvolvimento: **2.0.0-dev.7**.

A `dev.7` mantém o runtime da `dev.6` e concentra-se numa suite de testes muito mais completa, com maior cobertura e menos rebuilds redundantes.

## Variantes

### Genérica

```text
production:2.0.0-dev.7-php8.3
production:2.0.0-dev.7-php8.4
production:2.0.0-dev.7-php8.5
```

Document root predefinido:

```text
/var/www/html
```

### Laravel

```text
production:2.0.0-dev.7-laravel-php8.3
production:2.0.0-dev.7-laravel-php8.4
production:2.0.0-dev.7-laravel-php8.5
```

Document root predefinido:

```text
/var/www/html/public
```

A variante Laravel não contém Laravel, Composer ou Node. É um runtime de produção para uma aplicação já construída.

## Base comum

- Alpine Linux 3.24
- Nginx
- PHP-FPM
- PHP 8.3, 8.4 ou 8.5
- runtime shell mínimo, sem Supervisor/Python
- runtime non-root (`www`)
- porta interna 8080
- OPcache
- healthcheck `/healthz`
- logs em stdout/stderr
- shutdown gracioso
- labels OCI
- `linux/amd64` e `linux/arm64`

## Extensões da imagem genérica

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

## Extensões adicionais da variante Laravel

- bcmath
- DOM
- intl
- pcntl
- PDO MySQL
- PDO PostgreSQL
- PDO SQLite
- PhpRedis
- zip

## Build local das seis variantes

```bash
docker buildx bake
```

Também existem grupos específicos:

```bash
docker buildx bake generic
docker buildx bake laravel
```

## Multi-arquitetura

O grupo `multiarch` constrói todas as variantes para:

```text
linux/amd64
linux/arm64
```

```bash
docker buildx bake multiarch
```

Para publicar num registry, define o nome completo da imagem e usa `--push`:

```bash
IMAGE_NAME=registry.example.com/user/production \
VERSION=2.0.0-dev.7 \
docker buildx bake multiarch --push
```

Em hosts que não executem ambas as arquiteturas nativamente, é necessário um builder com suporte de emulação/QEMU ou builders nativos para cada plataforma.

## Testes

### Suite completa local

```bash
./tests/test-all.sh
```

A suite completa faz um único build local das seis imagens e reutiliza-as nas fases seguintes. Atualmente cobre:

1. validação estática de shell, versões, Bake e Dockerfile;
2. builds inválidos (PHP/variant não suportados);
3. build paralelo das seis imagens;
4. contrato das seis imagens e respetivas extensões;
5. arranque, healthcheck e shutdown das seis combinações;
6. overrides de timezone, memória, upload e document root;
7. contrato HTTP/Nginx aprofundado;
8. 50 pedidos PHP concorrentes por variante principal;
9. logs PHP e access logs JSON em stdout/stderr;
10. crashes de Nginx/PHP-FPM e sinais TERM/INT/QUIT;
11. hardening (`read-only`, `cap-drop ALL`, `no-new-privileges`, `pids-limit`, `tmpfs`) e budgets de tamanho.

Para repetir a suite sem reconstruir imagens já existentes:

```bash
SKIP_BUILD=1 ./tests/test-all.sh
```

### Suite rápida de desenvolvimento

```bash
./tests/test-fast.sh
```

Usa apenas PHP 8.5 genérico + Laravel e executa as verificações de maior valor para iterações rápidas.

### Smoke matrix

```bash
./tests/smoke-all.sh
```

Testa as seis combinações PHP/variante sem reconstruir as imagens.

### Testes específicos

```bash
./tests/image-contract.sh
./tests/configuration.sh
./tests/http-contract.sh
./tests/concurrency.sh
./tests/logging.sh
./tests/runtime-failure.sh
./tests/security.sh
./tests/size-budget.sh
```

### Build multi-arquitetura

```bash
./tests/multiarch-build.sh
```

### Validação de nível release

```bash
./tests/test-release.sh
```

Executa primeiro toda a suite local e depois valida as seis imagens para `linux/amd64` e `linux/arm64`.

## Executar com root filesystem read-only

A imagem pode ser usada com root filesystem read-only. Como Nginx/PHP precisam de estado temporário, fornece `tmpfs` para `/run/production` e `/tmp`.

Os UID/GID podem ser obtidos diretamente da imagem:

```bash
UID_RUNTIME=$(docker run --rm --entrypoint id production:2.0.0-dev.7-php8.5 -u)
GID_RUNTIME=$(docker run --rm --entrypoint id production:2.0.0-dev.7-php8.5 -g)
```

Exemplo:

```bash
docker run --rm \
  --read-only \
  --security-opt no-new-privileges:true \
  --tmpfs "/run/production:rw,nosuid,nodev,noexec,size=16m,mode=0755,uid=${UID_RUNTIME},gid=${GID_RUNTIME}" \
  --tmpfs "/tmp:rw,nosuid,nodev,noexec,size=16m,mode=1777" \
  -v /caminho/app:/var/www/html:ro \
  production:2.0.0-dev.7-php8.5
```

Uma aplicação Laravel real continua a precisar de escrita em `storage/` e `bootstrap/cache/`; esses caminhos devem ser volumes/directórios graváveis quando se usa `--read-only`.

## Variáveis de ambiente

| Variável | Predefinição | Descrição |
|---|---:|---|
| `TIMEZONE` | `UTC` | Timezone PHP/runtime |
| `DOCUMENT_ROOT` | depende da variante | Root do Nginx |
| `PHP_MEMORY_LIMIT` | `128M` | Limite de memória PHP |
| `UPLOAD_MAX_SIZE` | `8M` | Limite de upload e POST |

## Queue workers e scheduler Laravel

A mesma imagem Laravel pode executar comandos sem arrancar Nginx/PHP-FPM:

```bash
docker run --rm production:2.0.0-dev.7-laravel-php8.5 \
  php artisan queue:work
```

```bash
docker run --rm production:2.0.0-dev.7-laravel-php8.5 \
  php artisan schedule:work
```

## Estratégia de tags para a release estável

Durante desenvolvimento, apenas tags versionadas `dev` devem ser publicadas. `latest` não deve apontar para uma versão de desenvolvimento.

Para uma futura `2.0.0`, a estratégia prevista é:

```text
# Genérica PHP específica
2.0.0-php8.3
2.0.0-php8.4
2.0.0-php8.5
php8.3
php8.4
php8.5

# Laravel
2.0.0-laravel-php8.3
2.0.0-laravel-php8.4
2.0.0-laravel-php8.5
laravel-php8.3
laravel-php8.4
laravel-php8.5

# Defaults, quando a release estiver estável
2.0.0 -> genérica PHP 8.5
latest -> genérica PHP 8.5
laravel -> Laravel PHP 8.5
```

Os aliases só devem ser criados quando a linha `2.0.0` estiver pronta para release.

## CI

`.github/workflows/ci.yml` executa:

- a suite completa de runtime em `amd64`;
- um build das seis imagens em `linux/amd64` e `linux/arm64` através de Buildx/QEMU.

O workflow não publica imagens. A publicação fica separada para a fase de release, quando o registry e a política de tags forem definitivamente escolhidos.
