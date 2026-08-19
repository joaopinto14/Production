# Changelog

Todas as alterações relevantes do projeto Production são documentadas neste ficheiro.

## 2.0.0-dev.7 - 2026-08-19

### Adicionado

- Suite de testes reorganizada em camadas, com build único das seis imagens e reutilização entre testes.
- `tests/lib.sh` com helpers partilhados para reduzir duplicação e tornar os testes mais consistentes.
- Validação estática de scripts, versões, Docker Bake e Dockerfile checks quando suportados.
- Testes negativos de build para versões PHP e variantes inválidas.
- Testes de contrato das seis imagens: labels OCI, utilizador, porta, entrypoint/CMD, healthcheck, symlinks e extensões.
- Testes de configuração runtime para timezone, memória, uploads e document root personalizados.
- Testes HTTP aprofundados para headers de segurança, ficheiros estáticos, dotfiles, `.well-known`, front controllers e limites de POST.
- Testes de concorrência com 50 pedidos PHP simultâneos nas variantes genérica e Laravel.
- Testes de logging para confirmar logs PHP e access logs JSON em stdout/stderr.
- Testes de sinais `TERM`, `INT` e `QUIT`, além de crashes de Nginx e PHP-FPM.
- Hardening testado com `--read-only`, `--cap-drop ALL`, `no-new-privileges`, `pids-limit` e `tmpfs`.
- Orçamentos de tamanho por imagem para detetar regressões relevantes.
- `tests/test-fast.sh` para iterações locais rápidas em PHP 8.5.
- `tests/test-release.sh` para executar a suite completa seguida dos builds multi-arquitetura.

### Melhorado

- `tests/test-all.sh` mede o tempo de cada fase e evita reconstruir cada imagem em cada smoke test.
- Os smoke tests validam agora também a configuração de Nginx e PHP-FPM antes do shutdown.
- A suite completa testa todas as versões PHP onde a diferença de pacote importa e usa PHP 8.5 para testes profundos de comportamento comum, reduzindo trabalho repetido.

### Mantido

- Runtime e composição das imagens inalterados face à `2.0.0-dev.6`; esta versão é focada em qualidade e cobertura de testes.

## 2.0.0-dev.6 - 2026-08-19

### Adicionado

- Builds multi-arquitetura para `linux/amd64` e `linux/arm64` através de `docker buildx bake multiarch`.
- Variável `IMAGE_NAME` no Bake para permitir usar o mesmo ficheiro com qualquer registry/repositório.
- Variável `VCS_REF` para identificar a revisão da origem nas labels OCI.
- Labels OCI adicionais: vendor, URL, documentação, revisão e imagem base.
- Teste de falha do runtime que mata Nginx e PHP-FPM individualmente e confirma que o contentor falha rapidamente.
- Teste de segurança com root filesystem read-only, `no-new-privileges` e `tmpfs` para os diretórios temporários.
- `tests/test-all.sh` como entrada única para os testes de runtime.
- `tests/multiarch-build.sh` para validação manual dos builds multi-arquitetura.
- GitHub Actions CI com testes de runtime e build `amd64` + `arm64`.

### Melhorado

- O entrypoint recria os diretórios efémeros em `/run/production` no arranque, permitindo montar esse caminho como `tmpfs`.
- `umask 027` para ficheiros de configuração gerados em runtime.
- Smoke tests validam também metadata OCI e arrancam com `no-new-privileges`.
- `docker-bake.hcl` passa a ter grupos `generic`, `laravel` e `multiarch`.

### Mantido

- Runtime slim sem Supervisor/Python.
- Alpine 3.24.
- PHP 8.3, 8.4 e 8.5.
- Variantes genérica e Laravel.
- Runtime non-root.
- Nginx na porta 8080.
- Healthcheck `/healthz`.
- Logs em stdout/stderr.
- Shutdown gracioso.

## 2.0.0-dev.5 - 2026-08-19

### Adicionado

- Variante Laravel para PHP 8.3, 8.4 e 8.5.
- `VARIANT=generic|laravel` no mesmo Dockerfile.
- Extensões Laravel: bcmath, DOM, intl, pcntl, PDO MySQL, PDO PostgreSQL, PDO SQLite, PhpRedis e zip.
- Configuração Nginx dedicada a Laravel.
- Document root Laravel predefinido em `/var/www/html/public`.
- Proteção contra execução direta de outros ficheiros `.php` em `public/`.
- Smoke tests para as seis variantes.

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
