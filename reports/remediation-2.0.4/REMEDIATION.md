# Correções da auditoria — preparação de Production 2.0.4

> Histórico de 21/10: estes testes/imagens antecedem a correção adicional de Tini para órfãos CLI, reproduzida em 30/10. Não demonstram essa cobertura. Consultar a [validação posterior](../zombies-2026-10-30/REPORT.md) antes de publicar a árvore atual.

Data: 21/10/2026. Âmbito: código e automação do projeto, imagens locais Generic/Laravel
para PHP 8.3/8.4/8.5 em amd64 e ARM64 emulado e proteções do repositório GitHub.
A referência é a [auditoria original](../audit-2026-10-21/AUDIT.md), que permanece
inalterada como evidência anterior às correções.

**As correções estão implementadas para 2.0.4. Não foi publicada uma nova release,
feito push de imagens para Docker Hub ou alterada uma tag pública existente.**
A primeira execução dos novos workflows, a assinatura OIDC e a validação dos
digests públicos são gates da publicação futura, após integração do código.

## Resolução dos 11 achados

| Achado | Correção | Evidência |
|---|---|---|
| A01 — pacotes públicos desatualizados | Nova versão 2.0.4 com APK atualizados; preservação da release histórica 2.0.3. | 12 inventários/scans locais, comparação completa e digests registados. A correção pública depende da publicação de 2.0.4. |
| A02 — fontes PHP servidas estaticamente | Bloquear nomes com maiúsculas/minúsculas, backups e extensões alternativas nas duas variantes; preservar PHP Generic, front controller Laravel e ACME. | Regressões HTTP para .PHP, .pHp, .php.bak, .php~, .phtml, .phar e .phps; respostas 404. |
| A03 — pedidos interrompidos na paragem | Drenar Nginx antes de parar FPM; prazo global SHUTDOWN_TIMEOUT 1–300 s, KILL e saída 1 quando forçado. Rejeitar zero, valores fora do intervalo e overflow. | Pedido PHP de cinco segundos conclui com HTTP 200; master suspenso é terminado dentro do prazo; TERM/INT/QUIT e crashes continuam cobertos. |
| A04 — rebuild depois dos testes | Construir staging uma vez; guardar digests e puxar/testar/analisar os mesmos artefactos em jobs nativos amd64/arm64. Promover o índice original sem rebuild. | Workflow dividido por funções, testes de evidências e prova real de cópia por digest num registry localhost isolado. |
| A05 — publicação parcial sem recuperação | Preparar comparação de pacotes e draft com evidência antes das tags públicas; preflight global de conflitos; terminar tags versionadas antes dos aliases; guardar journal e aceitar repetição apenas com o mesmo digest. Reparar notas independentemente. | Testes de falha parcial, conflito, indisponibilidade do registry e idempotência; segunda promoção local preserva o digest. |
| A06 — CI/permissões/Actions | Fixar todas as Actions por SHA completo, Dependabot semanal, checkout sem credenciais persistidas e permissões por job. Exigir CI atualizado em main e restringir o ambiente release. | Actionlint e consulta remota das proteções aplicadas; revisão/admins preservados. |
| A07 — credenciais no contexto | Allowlist dos ficheiros exatos de runtime; exclusão por defeito de todos os restantes caminhos. | Build sintético confirma exclusão de .aws/.codex/.agents/.env, relatórios e segredos fictícios dentro dos diretórios de runtime. Não são lidas credenciais reais. |
| A08 — tmpfs sem proprietário/capacidade | Corrigir UID/GID/modos no README, usar 128 MiB como exemplo inicial e explicar concorrência, overhead multipart, buffers, memória e volumes persistentes. | Upload multipart de 17 MiB, limite 32M, nas duas variantes com root só de leitura, cap-drop e no-new-privileges. |
| A09 — medições que ocultavam erros | Exportar e comprimir em etapas com verificação explícita; só medir depois do sucesso. | Injeção de falha de docker save e de gzip reprova ambas as ferramentas de tamanho. |
| A10 — saúde sem PHP | Manter /healthz como liveness, acrescentar /readyz com ping FPM e timeout curto e usá-lo no HEALTHCHECK Docker. | Socket removido: /healthz=200 e /readyz=502; socket restaurado: ready. Sem dependência de ficheiros da aplicação nem status do pool exposto. |
| A11 — scans parciais/antigos | Comparar todos os nomes/versões com APK, exigir identidade/configuração/scanner esperados, relatório com até 24 h e DB atualizada/descarregada até 48 h. Eliminar saída antiga antes de cada execução. | Regressões de inventário parcial/duplicado/alterado, DB e relatório antigos/futuros e evidência ausente numa das arquiteturas. |

## Pacotes e scans finais

Os 12 scans finais Trivy não sinalizaram vulnerabilidades. Isto descreve os
relatórios e a base registada, não constitui uma garantia de ausência de falhas.
O gate de publicação bloqueia HIGH/CRITICAL com correção disponível, bem como
qualquer falha/incompletude de scanner, inventário ou atualidade da base.

| Componente | Público 2.0.3 | Candidatas finais 2.0.4, ambas as arquiteturas |
|---|---|---|
| PHP 8.3 | 8.3.33-r0 | 8.3.36-r0 |
| PHP 8.4 | 8.4.25-r0 | 8.4.27-r0 |
| PHP 8.5 | 8.5.10-r0 | 8.5.12-r0 |
| pcre2 | 10.48-r0 | 10.49-r0 |
| nghttp2-libs | 1.69.0-r0 | 1.70.0-r0 |
| zlib | 1.3.2-r0 | 1.3.2-r1 |

Durante esta preparação houve novas atualizações upstream. A evidência final
corresponde às versões acima; os pacotes continuam mutáveis no build. Por isso a
release promove os artefactos testados, em vez de os voltar a construir.

- [Resumo dos 12 scans](scan-summary.json), incluindo IDs/digests de configuração e datas da DB.
- [Inventário amd64](scans-amd64/inventory.json) e [inventário ARM64](scans-arm64/inventory.json), com os relatórios Trivy completos nos mesmos diretórios.
- [Comparação completa de pacotes](package-changes.md) e [JSON](package-changes.json), contra os digests públicos 2.0.3 registados na auditoria.
- [Hashes dos oito ficheiros de runtime nas 12 imagens](runtime-source-hashes.json), todos iguais ao código final.
- [Prova de promoção local](registry-promotion-proof.json): índice com as duas arquiteturas e attestations, mesmo digest nas tags de destino e na repetição. O registry temporário foi removido.
- [Proteções GitHub verificadas](repository-protections.json) e [preflight das sete tags 2.0.4](public-tag-preflight.txt), apenas de leitura no registry público.

## Validação e limites

Resultados finais: **amd64 aprovado em 701 s** e **ARM64 emulado aprovado em 325 s**.
A repetição ARM64 concluiu também os cinco reinícios por variante, a deteção do
zombie intencional e o contrato completo de release. Os 12 limites de tamanho
foram respeitados. [Resumo JSON](summary.json), [suite amd64](runtime-amd64.log),
[suite ARM64](runtime-arm64.log), [aplicações amd64](real-apps-amd64.log),
[aplicações ARM64](real-apps-arm64.log), [build multi-arquitetura](multiarch-build.log)
e [actionlint](actionlint.log).

As suites cobrem contratos das seis imagens, smoke, configuração, HTTP, uploads,
concorrência, logs, sinais, falhas, shutdown em curso, read-only, capabilities e
tamanho. Os 35 testes Python também cobrem política de release, inventários,
scanner e recuperação da promoção. Aplicações PHP reais foram exercitadas nos
três PHPs; Laravel 13.38.0 foi exercitado com SQLite, cache, sessão, storage,
Artisan e exceções de produção. Composer foi fixado por digest e continua fora do
runtime. A fixture Laravel e o lockfile ainda podem ser consolidados como P2;
não se apresenta essa integração como reproduzível bit a bit.

A validação ARM64 local usa QEMU, não um host ARM nativo. Os workflows preparados
exigem os testes/scans em runners nativos antes da publicação. SBOM/provenance
foram preservados na prova local; a assinatura e verificação Cosign com identidade
GitHub OIDC estão configuradas como gate, mas só podem ser confirmadas na execução
real da release no GitHub. Não foi enviada uma assinatura/release pública nesta tarefa.

O builder preexistente não conseguiu aceder ao registry pela bridge. Um builder
isolado com rede do anfitrião concluiu o build limpo das seis variantes em ambas
as arquiteturas; o builder original foi preservado e o temporário removido.
Composer também precisou desse override de rede para a repetição ARM64. Os
preflights agora mostram o erro real, sem o classificar sempre como falta de QEMU.
Uma execução ARM64 simultânea com builds/scans atingiu o prazo inicial de health;
a repetição final sem essa concorrência passou integralmente. O helper espera pelo menos um
segundo intervalo de health e regista diagnóstico perante falha.

Foi ainda corrigido um falso positivo no teste de zombies: um processo podia
terminar entre a listagem e a leitura de /proc, fazendo cut falhar. O novo detetor
lê o registo uma vez, distingue starttime/PID e exige persistência durante um
segundo; um filho propositadamente não recolhido testa a deteção negativa.

Nenhuma dependência foi acrescentada ao runtime. Os limites de tamanho existentes
são mantidos e verificados. As otimizações P2 de tamanho/RSS, integrações com
MySQL/PostgreSQL/Redis e outros ensaios adicionais permanecem identificados em
[TODO.md](../../TODO.md), separados das correções desta auditoria.

## Publicação futura

Integrar as alterações em main, confirmar CI/Dependabot/jobs nativos, garantir as
credenciais Docker Hub no ambiente apropriado e criar v2.0.4 com o workflow novo.
Rever os digests, assinaturas e anexos efetivamente publicados e recriar os
contentores das aplicações. A release pública 2.0.3 permanece histórica e não
recebe estas correções retroativamente. Seguir [SUPPORT.md](../../SUPPORT.md).
