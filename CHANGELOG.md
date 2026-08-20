# Changelog

Todas as alterações relevantes do projeto Production são documentadas neste ficheiro.

## 2.0.0-rc.1 - 2026-08-20

### Fixed

- Multi-architecture validation now uses a dedicated Buildx `docker-container` builder instead of relying on the host `docker:default` builder, preventing ARM64 `exec format error` failures when the default builder lacks emulation.
- Added an ARM64 execution preflight with a clear QEMU/binfmt remediation command when emulation is unavailable.
- Laravel test cleanup now removes bind-mounted cache files safely without host UID permission failures, while preserving the original test exit code.

### Estado

- Funcionalidades da linha 2.0 congeladas para estabilização.
- Mantidas as seis variantes genérica/Laravel em PHP 8.3, 8.4 e 8.5.
- Runtime inalterado face à `2.0.0-dev.7`, salvo correções que venham a ser exigidas pelos testes da RC.

### Adicionado

- `tests/clean-build.sh` para construir as seis imagens sem cache.
- `tests/release-contract.sh` para verificar metadata e ausência de ferramentas/artefactos de desenvolvimento no runtime.
- `tests/real-generic.sh` com uma aplicação PHP real nas três versões suportadas.
- `tests/real-laravel.sh` que cria e executa uma aplicação Laravel 13 real nas variantes PHP 8.3, 8.4 e 8.5.
- Validação real de Artisan, migrations, SQLite, PDO MySQL/PostgreSQL/SQLite, PhpRedis, cache, storage, sessions, optimize e queue worker.
- Validação explícita de command-mode sem Nginx/PHP-FPM.
- `tests/restart-stability.sh` com cinco ciclos de restart e deteção de processos zombie.
- Build multi-arquitetura opcionalmente sem cache através de `NO_CACHE=1`.
- `RELEASE.md` com critérios de aprovação e política da release candidate.
- Workflow dedicado à validação de tags RC.

### Melhorado

- `tests/test-release.sh` passa a ser uma verdadeira gate de release: clean build, suite completa, aplicações reais, restart stability e multi-arch.
- `tests/compare-size.sh` compara por predefinição a `dev.7` com a `rc.1`.
- Documentação reorganizada para utilização real, command-mode, hardening e processo de release.

### Política

- Durante a RC apenas são aceites correções de bugs, melhorias de testes e documentação necessárias à estabilização.
- Novas funcionalidades ficam adiadas para uma versão posterior à 2.0.0.

