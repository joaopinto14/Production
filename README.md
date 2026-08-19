# Production

Imagem Docker PHP leve e genérica para produção, com uma variante Laravel construída a partir do mesmo código-base.

## Estado

Versão de desenvolvimento: **2.0.0-dev.5**.

A `dev.5` mantém o runtime slim da `dev.4` e introduz uma variante Laravel para PHP 8.3, 8.4 e 8.5.

## Variantes

### Genérica

```text
production:2.0.0-dev.5-php8.3
production:2.0.0-dev.5-php8.4
production:2.0.0-dev.5-php8.5
```

Document root predefinido:

```text
/var/www/html
```

### Laravel

```text
production:2.0.0-dev.5-laravel-php8.3
production:2.0.0-dev.5-laravel-php8.4
production:2.0.0-dev.5-laravel-php8.5
```

Document root predefinido:

```text
/var/www/html/public
```

A variante Laravel não contém o framework, Composer ou Node. É apenas um runtime de produção preparado para receber uma aplicação já construída.

## Base comum

- Alpine Linux 3.24
- Nginx
- PHP-FPM
- runtime shell mínimo sem Supervisor/Python
- runtime non-root (`www`)
- porta interna 8080
- OPcache
- healthcheck `/healthz`
- logs em stdout/stderr
- shutdown gracioso

## PHP suportado

- PHP 8.3
- PHP 8.4
- PHP 8.5

O mesmo Dockerfile constrói todas as variantes.

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

Além das extensões da imagem genérica:

- bcmath
- DOM
- intl
- pcntl
- PDO MySQL
- PDO PostgreSQL
- PDO SQLite
- PhpRedis
- zip

A inclusão de PDO SQLite permite executar também a configuração SQLite que Laravel usa por defeito em novas aplicações.

## Nginx na variante Laravel

A configuração Laravel:

- serve `/var/www/html/public` por defeito;
- encaminha pedidos para `public/index.php`;
- não permite executar outros ficheiros `.php` diretamente;
- bloqueia ficheiros ocultos, exceto `.well-known`;
- mantém `/healthz` como healthcheck da infraestrutura.

## Build das seis variantes

```bash
docker buildx bake
```

Targets:

```text
php83
php84
php85
laravel-php83
laravel-php84
laravel-php85
```

## Build individual Laravel

```bash
docker build \
  --build-arg VERSION=2.0.0-dev.5 \
  --build-arg PHP_VERSION=8.5 \
  --build-arg VARIANT=laravel \
  -t production:2.0.0-dev.5-laravel-php8.5 .
```

## Testes

Testar a variante genérica PHP 8.5:

```bash
./tests/smoke.sh
```

Testar Laravel PHP 8.5:

```bash
VARIANT=laravel ./tests/smoke.sh
```

Testar as seis imagens:

```bash
./tests/smoke-all.sh
```

O teste Laravel valida também as extensões esperadas, o document root `public/` e que um ficheiro PHP arbitrário em `public/` não é executado diretamente.

## Comparar tamanhos

Depois de teres `dev.4` e `dev.5` construídas:

```bash
./tests/compare-size.sh
```

Mostra o tamanho da `dev.4`, da genérica `dev.5`, da Laravel `dev.5` e o custo adicional da variante Laravel.

## Variáveis de ambiente

| Variável | Predefinição | Descrição |
|---|---:|---|
| `TIMEZONE` | `UTC` | Timezone PHP/runtime |
| `DOCUMENT_ROOT` | depende da variante | Root do Nginx |
| `PHP_MEMORY_LIMIT` | `128M` | Limite de memória PHP |
| `UPLOAD_MAX_SIZE` | `8M` | Limite de upload e POST |

A variável `DOCUMENT_ROOT` pode sempre substituir o default da variante.

## Laravel: permissões

A imagem não faz `chown -R` à aplicação durante o arranque. Em produção, `storage/` e `bootstrap/cache/` devem estar graváveis pelo utilizador que corre o contentor.

## Queue workers e scheduler

A mesma imagem Laravel pode ser usada com um comando diferente, sem arrancar Nginx/PHP-FPM:

```bash
docker run --rm production:2.0.0-dev.5-laravel-php8.5 \
  php artisan queue:work
```

ou:

```bash
docker run --rm production:2.0.0-dev.5-laravel-php8.5 \
  php artisan schedule:work
```
