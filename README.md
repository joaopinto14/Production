# Production

Imagem Docker PHP leve e genérica, preparada para utilização em produção e pensada para servir de base a aplicações PHP e, futuramente, a uma variante otimizada para Laravel.

## Estado

Versão de desenvolvimento: **2.0.0-dev.3**.

Esta versão introduz um único código-base para PHP **8.3**, **8.4** e **8.5**.

## Base

- Alpine Linux 3.24
- Nginx
- PHP-FPM
- Supervisor
- Runtime non-root (`www`)
- Porta interna 8080
- Healthcheck `/healthz`

## Variantes PHP

A mesma `2.0.0-dev.3` pode gerar:

```text
production:2.0.0-dev.3-php8.3
production:2.0.0-dev.3-php8.4
production:2.0.0-dev.3-php8.5
```

A variante predefinida é PHP 8.5.

## Build individual

PHP 8.5:

```bash
docker build \
  --build-arg VERSION=2.0.0-dev.3 \
  --build-arg PHP_VERSION=8.5 \
  -t production:2.0.0-dev.3-php8.5 .
```

PHP 8.4:

```bash
docker build \
  --build-arg VERSION=2.0.0-dev.3 \
  --build-arg PHP_VERSION=8.4 \
  -t production:2.0.0-dev.3-php8.4 .
```

PHP 8.3:

```bash
docker build \
  --build-arg VERSION=2.0.0-dev.3 \
  --build-arg PHP_VERSION=8.3 \
  -t production:2.0.0-dev.3-php8.3 .
```

Valores diferentes de `8.3`, `8.4` ou `8.5` fazem o build falhar explicitamente.

## Build das três variantes

Com Docker Buildx Bake:

```bash
docker buildx bake
```

Ou uma variante específica:

```bash
docker buildx bake php85
```

Targets disponíveis:

```text
php83
php84
php85
```

## Smoke tests

Testar a variante predefinida (PHP 8.5):

```bash
./tests/smoke.sh
```

Testar uma versão específica:

```bash
PHP_VERSION=8.4 ./tests/smoke.sh
```

Testar as três versões:

```bash
./tests/smoke-all.sh
```

Cada smoke test valida:

1. build da imagem;
2. versão PHP correta;
3. runtime non-root;
4. OPcache carregado;
5. arranque Nginx + PHP-FPM;
6. healthcheck;
7. execução PHP através de HTTP;
8. shutdown gracioso.

## Extensões PHP base

Todas as variantes incluem o mesmo conjunto funcional:

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

A futura variante Laravel acrescentará extensões próprias sem tornar a imagem genérica desnecessariamente pesada.

## Variáveis de ambiente

| Variável | Predefinição | Descrição |
|---|---:|---|
| `TIMEZONE` | `UTC` | Timezone PHP/runtime |
| `DOCUMENT_ROOT` | `/var/www/html` | Document root do Nginx |
| `PHP_MEMORY_LIMIT` | `128M` | Limite de memória PHP |
| `UPLOAD_MAX_SIZE` | `8M` | Limite de upload e POST |
| `SUPERVISOR_CONF` | vazio | Configuração adicional opcional do Supervisor |

Exemplo:

```bash
docker run --rm \
  -e TIMEZONE=Europe/Lisbon \
  -e DOCUMENT_ROOT=/var/www/html/public \
  -e PHP_MEMORY_LIMIT=256M \
  -e UPLOAD_MAX_SIZE=32M \
  production:2.0.0-dev.3-php8.5
```

## Execução de comandos PHP

O comando `php` é estável em todas as variantes:

```bash
docker run --rm production:2.0.0-dev.3-php8.3 php -v
docker run --rm production:2.0.0-dev.3-php8.4 php -v
docker run --rm production:2.0.0-dev.3-php8.5 php -v
```

Internamente, a imagem liga esse comando ao binário correspondente da Alpine.

## Estrutura PHP independente da versão

A configuração da imagem deixa de depender de caminhos como `/etc/php85`:

```text
/etc/php-active                 -> configuração da versão selecionada
/etc/production/php             -> configuração da imagem Production
/run/production/php             -> configuração/estado gerado em runtime
/usr/local/bin/php              -> PHP selecionado
/usr/local/sbin/php-fpm         -> PHP-FPM selecionado
```

Isto permite manter Nginx, Supervisor e entrypoint iguais entre todas as variantes.

## Laravel

A `2.0.0-dev.3` continua a ser uma imagem genérica. A variante Laravel será criada numa iteração posterior sobre esta mesma base multi-PHP.
