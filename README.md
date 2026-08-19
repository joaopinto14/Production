# Production

Imagem Docker PHP leve e genérica, preparada para produção e pensada para servir de base a aplicações PHP e, futuramente, a uma variante otimizada para Laravel.

## Estado

Versão de desenvolvimento: **2.0.0-dev.4**.

Esta iteração é a variante **slim runtime**: mantém o suporte PHP 8.3/8.4/8.5 da dev.3, mas remove Supervisor e toda a cadeia Python que este adicionava à imagem.

## Base

- Alpine Linux 3.24
- Nginx
- PHP-FPM
- BusyBox `sh` como gestor mínimo dos dois processos
- Runtime non-root (`www`)
- Porta interna 8080
- Healthcheck `/healthz`
- Shutdown gracioso com `SIGTERM` -> `SIGQUIT` para Nginx e PHP-FPM

## O que mudou na dev.4

A dev.3 utilizava Supervisor para gerir Nginx e PHP-FPM. O pacote Supervisor puxava também Python 3 e várias dependências Python.

Na dev.4, o processo PID 1 é `/usr/local/bin/production-runtime`, um pequeno script POSIX shell que:

- arranca PHP-FPM;
- arranca Nginx;
- acompanha os dois processos;
- termina o contentor se um deles morrer inesperadamente;
- encaminha o shutdown para ambos;
- espera pelos processos filhos para evitar zombies.

Não são instalados `supervisor`, `python3`, `setuptools` ou dependências associadas.

## Variantes PHP

```text
production:2.0.0-dev.4-php8.3
production:2.0.0-dev.4-php8.4
production:2.0.0-dev.4-php8.5
```

A variante predefinida é PHP 8.5.

## Build individual

```bash
docker build \
  --build-arg VERSION=2.0.0-dev.4 \
  --build-arg PHP_VERSION=8.5 \
  -t production:2.0.0-dev.4-php8.5 .
```

Substitui `8.5` por `8.4` ou `8.3` conforme necessário.

## Build das três variantes

```bash
docker buildx bake
```

Targets disponíveis:

```text
php83
php84
php85
```

## Smoke tests

PHP 8.5:

```bash
./tests/smoke.sh
```

Uma versão específica:

```bash
PHP_VERSION=8.4 ./tests/smoke.sh
```

As três versões:

```bash
./tests/smoke-all.sh
```

O teste valida:

1. build da imagem;
2. versão PHP correta;
3. runtime non-root;
4. ausência de Supervisor e Python;
5. OPcache;
6. Nginx + PHP-FPM;
7. healthcheck e resposta PHP via HTTP;
8. shutdown gracioso;
9. tamanho final da imagem.

## Comparar dev.3 e dev.4

Se tiveres as imagens das duas versões construídas:

```bash
./tests/compare-size.sh
```

O script compara, em bytes, as variantes PHP 8.3, 8.4 e 8.5.

## Extensões PHP base

Todas as variantes incluem o mesmo conjunto funcional da dev.3:

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

Nesta dev.4 não foram removidas extensões para que a comparação de tamanho com a dev.3 seja justa.

## Variáveis de ambiente

| Variável | Predefinição | Descrição |
|---|---:|---|
| `TIMEZONE` | `UTC` | Timezone PHP/runtime |
| `DOCUMENT_ROOT` | `/var/www/html` | Document root do Nginx |
| `PHP_MEMORY_LIMIT` | `128M` | Limite de memória PHP |
| `UPLOAD_MAX_SIZE` | `8M` | Limite de upload e POST |

Exemplo:

```bash
docker run --rm \
  -e TIMEZONE=Europe/Lisbon \
  -e DOCUMENT_ROOT=/var/www/html/public \
  -e PHP_MEMORY_LIMIT=256M \
  -e UPLOAD_MAX_SIZE=32M \
  production:2.0.0-dev.4-php8.5
```

## Execução de comandos PHP

O entrypoint continua a permitir substituir o runtime por um comando normal:

```bash
docker run --rm production:2.0.0-dev.4-php8.5 php -v
```

Isto será útil mais tarde para workers e comandos Laravel em contentores separados.

## Estrutura PHP independente da versão

```text
/etc/php-active                 -> configuração da versão selecionada
/etc/production/php             -> configuração da imagem Production
/run/production/php             -> configuração/estado gerado em runtime
/usr/local/bin/php              -> PHP selecionado
/usr/local/sbin/php-fpm         -> PHP-FPM selecionado
```

## Laravel

A `2.0.0-dev.4` continua genérica. A variante Laravel fica para a próxima iteração, caso a abordagem slim prove valer a pena nos testes de tamanho e estabilidade.
