# Changelog

Todas as alterações relevantes do projeto Production são documentadas neste ficheiro.

## 2.0.0-dev.3 - 2026-08-19

### Adicionado

- Suporte a múltiplas versões de PHP a partir do mesmo Dockerfile:
  - PHP 8.3
  - PHP 8.4
  - PHP 8.5
- Argumento de build `PHP_VERSION`.
- Metadado OCI `io.joaopinto.production.php-version`.
- `docker-bake.hcl` para construir as três variantes com um único comando.
- `tests/smoke-all.sh` para validar todas as variantes.
- O smoke test valida agora a versão PHP esperada e a presença do OPcache.

### Alterado

- Os caminhos internos deixaram de estar presos a PHP 8.5.
- `php` é exposto de forma estável em `/usr/local/bin/php`.
- `php-fpm` é exposto de forma estável em `/usr/local/sbin/php-fpm`.
- A configuração PHP ativa é exposta através de `/etc/php-active`.
- A configuração própria da imagem foi movida para `/etc/production/php`.
- Supervisor usa o caminho genérico de PHP-FPM, independentemente da versão PHP escolhida.
- PHP 8.3 e 8.4 instalam explicitamente o pacote OPcache; em PHP 8.5 o OPcache faz parte do runtime.

### Mantido

- Alpine 3.24.
- Runtime non-root com utilizador `www`.
- Nginx na porta 8080.
- Supervisor como PID 1.
- Healthcheck `/healthz`.
- Logs em stdout/stderr.
- Configuração runtime em `/run/production`.

## 2.0.0-dev.2 - 2026-08-19

- Runtime non-root.
- Nginx na porta 8080.
- Configuração runtime em `/run/production`.
- Shutdown gracioso com `SIGTERM`.

## 2.0.0-dev.1 - 2026-08-19

- Nova base Alpine 3.24 + PHP 8.5.
- Extensões instaladas no build.
- Remoção de instalação dinâmica de extensões no arranque.
- `DOCUMENT_ROOT` e `/healthz`.
