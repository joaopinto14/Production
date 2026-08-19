# Changelog

Todas as alterações relevantes do projeto Production são documentadas neste ficheiro.

## 2.0.0-dev.4 - 2026-08-19

### Removido

- Supervisor.
- Python 3 e dependências transitivas trazidas pelo Supervisor.
- `SUPERVISOR_CONF`.
- Diretórios e configuração específicos do Supervisor.

### Adicionado

- `/usr/local/bin/production-runtime`, um gestor mínimo em POSIX shell para Nginx e PHP-FPM.
- Deteção da saída inesperada de Nginx ou PHP-FPM.
- Encerramento do processo restante quando um serviço falha.
- Encaminhamento de shutdown gracioso para Nginx e PHP-FPM.
- Teste explícito de ausência de Supervisor/Python.
- Medição do tamanho da imagem no smoke test.
- `tests/compare-size.sh` para comparar dev.3 e dev.4.

### Mantido

- Alpine 3.24.
- PHP 8.3, 8.4 e 8.5 a partir do mesmo Dockerfile.
- O mesmo conjunto de extensões PHP da dev.3.
- Runtime non-root com utilizador `www`.
- Nginx na porta 8080.
- Healthcheck `/healthz`.
- Logs em stdout/stderr.
- Configuração runtime em `/run/production`.

## 2.0.0-dev.3 - 2026-08-19

### Adicionado

- Suporte multi-PHP num único Dockerfile:
  - PHP 8.3
  - PHP 8.4
  - PHP 8.5
- `docker-bake.hcl`.
- `tests/smoke-all.sh`.
- Caminhos PHP estáveis em `/usr/local/bin/php`, `/usr/local/sbin/php-fpm` e `/etc/php-active`.

### Mantido

- Supervisor como PID 1.
- Runtime non-root.
- Nginx na porta 8080.

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
