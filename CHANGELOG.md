# Changelog

Todas as alterações relevantes do projeto Production são documentadas neste ficheiro.

## 2.0.0-dev.5 - 2026-08-19

### Adicionado

- Variante Laravel para PHP 8.3, 8.4 e 8.5.
- `VARIANT=generic|laravel` no mesmo Dockerfile.
- Tags Laravel:
  - `production:2.0.0-dev.5-laravel-php8.3`
  - `production:2.0.0-dev.5-laravel-php8.4`
  - `production:2.0.0-dev.5-laravel-php8.5`
- Extensões adicionais Laravel: bcmath, DOM, intl, pcntl, PDO MySQL, PDO PostgreSQL, PDO SQLite, PhpRedis e zip.
- Configuração Nginx dedicada a Laravel.
- Document root Laravel predefinido em `/var/www/html/public`.
- Proteção contra execução direta de outros ficheiros `.php` em `public/`.
- Smoke tests para as seis variantes.
- Testes das extensões Laravel e do contrato Nginx Laravel.
- Comparação de tamanho entre dev.4, dev.5 genérica e dev.5 Laravel.

### Mantido

- Runtime slim sem Supervisor/Python.
- Alpine 3.24.
- PHP 8.3, 8.4 e 8.5.
- Runtime non-root.
- Nginx na porta 8080.
- Healthcheck `/healthz`.
- Logs em stdout/stderr.
- Shutdown gracioso.
- Imagem genérica com o mesmo conjunto funcional da dev.4.

## 2.0.0-dev.4 - 2026-08-19

### Removido

- Supervisor.
- Python 3 e dependências transitivas trazidas pelo Supervisor.

### Adicionado

- `/usr/local/bin/production-runtime`, gestor mínimo em POSIX shell para Nginx e PHP-FPM.
- Deteção da saída inesperada dos serviços.
- Shutdown gracioso.
- Medição e comparação de tamanho.

## 2.0.0-dev.3 - 2026-08-19

- Suporte multi-PHP 8.3, 8.4 e 8.5 num único Dockerfile.
- `docker-bake.hcl`.
- Caminhos PHP independentes da versão.

## 2.0.0-dev.2 - 2026-08-19

- Runtime non-root.
- Nginx na porta 8080.
- Configuração runtime em `/run/production`.

## 2.0.0-dev.1 - 2026-08-19

- Nova base Alpine 3.24 + PHP 8.5.
- Extensões instaladas no build.
- Remoção da instalação dinâmica de extensões no arranque.
- `DOCUMENT_ROOT` e `/healthz`.
