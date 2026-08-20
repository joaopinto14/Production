# Production 2.0.0-rc.1 — Release Candidate

A `2.0.0-rc.1` congela a arquitetura da linha 2.0 e serve para validação final antes da release estável.

## Funcionalidades congeladas

A RC mantém seis variantes:

```text
2.0.0-rc.1-php8.3
2.0.0-rc.1-php8.4
2.0.0-rc.1-php8.5
2.0.0-rc.1-laravel-php8.3
2.0.0-rc.1-laravel-php8.4
2.0.0-rc.1-laravel-php8.5
```

Não são criados aliases `latest`, `php8.x` ou `laravel` durante a fase RC.

## Critérios de aprovação

A RC só deve avançar para `2.0.0` se:

- `./tests/test-release.sh` passar integralmente;
- as seis imagens forem construídas sem cache;
- a suite completa da `dev.7` continuar a passar;
- a aplicação PHP real funcionar em PHP 8.3, 8.4 e 8.5;
- uma aplicação Laravel 13 real funcionar em PHP 8.3, 8.4 e 8.5;
- Artisan, migrations, SQLite, cache, storage, session e queue worker forem validados;
- Nginx/PHP-FPM continuarem ausentes em command-mode;
- cinco ciclos de restart não deixarem processos zombie;
- os builds `linux/amd64` e `linux/arm64` passarem;
- os budgets de tamanho não forem ultrapassados;
- não forem encontrados bugs bloqueantes em utilização real.

## Teste de release

```bash
./tests/test-release.sh
```

Este teste é deliberadamente mais lento que a suite normal. Faz build sem cache, testes aprofundados, aplicações reais e multi-arquitetura. O teste multi-arquitetura usa um builder Buildx `docker-container` dedicado e faz um preflight ARM64 antes dos seis builds. Em Linux sem emulação ARM64, o script termina com instruções para registar QEMU/binfmt.

## Publicação experimental

A RC está preparada para um registry, mas o repositório oficial deve ser escolhido antes de ativar `--push` no CI.

Exemplo manual:

```bash
IMAGE_NAME=registry.example.com/utilizador/production \
VERSION=2.0.0-rc.1 \
docker buildx bake multiarch --push
```

Isto publica apenas tags explícitas da RC.

## Política da RC

Durante a fase RC:

- corrigir bugs;
- melhorar testes/documentação quando necessário;
- não adicionar novas funcionalidades;
- não alterar extensões ou arquitetura sem um problema concreto que o justifique.

Se não forem encontrados problemas bloqueantes, a próxima versão pode ser `2.0.0`. Caso contrário, as correções seguem para `2.0.0-rc.2`.
