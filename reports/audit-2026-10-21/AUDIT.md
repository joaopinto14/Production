# Auditoria de segurança e melhorias — Production

Data: **21/10/2026**. Versão do repositório: **2.0.3**. HEAD: `5bc91e1`.
Âmbito: árvore de trabalho, incluindo a implementação da secção 1 ainda não
commitada, seis candidatas locais amd64 e doze imagens públicas 2.0.3, em
amd64/arm64. O [manifesto SHA256](source-manifest.json) identifica o código
analisado. A auditoria acrescenta este relatório, provas e atualização do TODO;
as correções propostas continuam pendentes.

## Conclusão

A base tem boas medidas já verificadas: utilizador não-root, socket FPM privado,
configuração validada, proteção de caminhos ocultos, filesystem só de leitura com
mounts corretos e testes de falhas. A suite funcional pode passar enquanto há
problemas importantes de segurança e de disponibilidade fora dos casos cobertos.

As prioridades são **publicar uma nova versão com dependências atualizadas**,
**impedir exposição de código PHP por nomes alternativos/backups** e **corrigir a
paragem que interrompe pedidos ativos**. A publicação também precisa de ligar
testes/scans aos artefactos exatos promovidos e de recuperar falhas parciais.

Foram registados **11 achados**: 2 de prioridade alta, 8 média e 1 baixa. São
classificações de triagem desta auditoria, não pontuações CVSS. Alguns achados são
limitações operacionais ou de garantias de teste, e não vulnerabilidades remotas.
As condições de exploração estão indicadas em cada caso.

## Métodos e resultados

| Verificação | Resultado |
|---|---|
| Leitura de runtime, PHP/Nginx, Docker/Bake, scripts, workflows, testes e documentação | Concluída |
| Ligação das candidatas ao código | Oito ficheiros de runtime iguais por SHA256 nas seis imagens |
| Suite `test-all.sh`, sem reconstruir candidatas | Aprovada, **243 s**, incluindo 27 testes Python |
| Aplicação PHP real | Aprovada em PHP 8.3/8.4/8.5 |
| Laravel real | Framework **13.38.0**, aprovado em PHP 8.3/8.4/8.5 |
| Reinícios e zombies | Cinco ciclos por variante, aprovados |
| Contrato de release | Aprovado |
| Trivy nas seis candidatas amd64 | Nenhum finding de vulnerabilidade reportado nesta execução |
| Trivy nas doze imagens públicas 2.0.3 | 13 CVEs únicos: **2 HIGH, 10 MEDIUM, 1 LOW**, nenhum CRITICAL |
| Provas HTTP/permissões/capacidade/falhas | Achados reproduzidos, descritos abaixo |
| Gitleaks, histórico | Sem deteções em 20 commits disponíveis, com `--all` |
| Gitleaks, código atual | Sem deteções no snapshot de código, incluindo alterações não commitadas |
| Actionlint | Aprovado nos três workflows locais |
| ShellCheck | Seis avisos SC2016; são pesquisas intencionais de strings literais com `$` |
| Hadolint | Avisos analisados; não foram tratados automaticamente como vulnerabilidades |
| GitHub, leitura | `main` pública; CI/Release ativos; novo workflow de manutenção ainda ausente |

Os scans usaram **Trivy 0.76.1 fixado por digest**, com inventários completos e
identidade de configuração verificada. Não se executaram os conteúdos das imagens
públicas para obter os inventários/scans. As ferramentas de auditoria ficaram fora
do runtime. Os digests dos linters estão em [lint-image-digests.jsonl](lint-image-digests.jsonl).

## A01 — Alta: a release pública conserva dependências sinalizadas

**Estado:** versões/inventários e findings confirmados; explorabilidade depende
do componente, módulos instalados e utilização pela aplicação.

As seis variantes públicas 2.0.3 foram resolvidas para manifests imutáveis de
ambas as arquiteturas. Em cada imagem foram detetados os mesmos 13 CVEs únicos.
As ocorrências repetem-se por pacote de extensão PHP e por arquitetura; não são
centenas de vulnerabilidades distintas.

| Variante/PHP | HIGH por imagem | MEDIUM por imagem | LOW por imagem |
|---|---:|---:|---:|
| Generic 8.3 / 8.4 | 14 | 106 | 13 |
| Generic 8.5 | 13 | 98 | 12 |
| Laravel 8.3 / 8.4 | 24 | 186 | 23 |
| Laravel 8.5 | 23 | 178 | 22 |

Os valores da tabela aplicam-se separadamente a amd64 e arm64. Não há findings
CRITICAL nesta execução. Os HIGH únicos são:

- `CVE-2026-103111`, PCRE2: publicado `10.48-r0`; correção indicada `10.49-r0`.
  O [advisory do projeto](https://github.com/PCRE2Project/pcre2/security/advisories/GHSA-r9hj-j2rw-4q3m)
  exige que a aplicação aceite uma expressão regular controlada pelo atacante e
  use a configuração de JIT afetada. Uma URL contra uma expressão fixa do Nginx
  não demonstra, por si só, exploração desta falha.
- `CVE-2026-91765`, PHP/SOAP: correções indicadas em PHP `8.3.35`, `8.4.26` e
  `8.5.11`. O [advisory PHP](https://github.com/php/php-src/security/advisories/GHSA-rgrp-mwpx-f6rm)
  diz respeito a `ext-soap` e `SoapServer`. Os inventários destas imagens não
  incluem o pacote `phpXX-soap`; a multiplicação deste CVE pelos subpacotes PHP
  não prova que o caminho SOAP esteja presente ou exposto. É necessário avaliar
  alcance/VEX antes de o apresentar como explorável nestas imagens.

Existem ainda findings nos componentes PHP, nghttp2 e zlib, com caminhos de uso
distintos. Por exemplo, o runtime usa socket Unix para FPM, não o controlo IPv6
de clientes TCP referido num dos advisories PHP. A atualização continua a ser
recomendada; a contagem do scanner não substitui análise de alcance.

| Componente | Publicado | Candidatas locais auditadas |
|---|---|---|
| PHP 8.3 | 8.3.33-r0 | 8.3.35-r0 |
| PHP 8.4 | 8.4.25-r0 | 8.4.26-r0 |
| PHP 8.5 | 8.5.10-r0 | 8.5.11-r0 |
| PCRE2 | 10.48-r0 | 10.49-r0 |
| nghttp2 | 1.69.0-r0 | 1.70.0-r0 |
| zlib | 1.3.2-r0 | 1.3.2-r1 |

**Recomendação:** preparar uma nova release patch, validar os digests finais e
recriar os contentores consumidores. Preservar as tags 2.0.3 existentes. Não
descrever as candidatas locais atualizadas como se já estivessem publicadas.
O projeto PHP confirma que [8.3.35 é uma release de segurança](https://www.php.net/releases/8_3_35.php).

**Evidência:** [inventários públicos](published/inventory.json),
[CVEs consolidados](published-vulnerabilities.json), doze JSON Trivy em
`published/`, seis scans atuais em `scans/`. Todos identificam os artefactos.

## A02 — Alta, condicional: exposição de código por nomes alternativos

**Local:** `nginx/default.conf.template:31–40` e `nginx/laravel.conf.template:34–64`.

Os handlers usam regex sensível a maiúsculas e terminada em `.php`. Ficheiros
como `source.PHP`, `source.pHp`, `source.php.bak`, `source.php~` e `source.phtml`
passam pelo tratamento de estáticos quando existem no document root.

**Prova:** em ambas as variantes, um GET anónimo a cada um desses cinco ficheiros
devolveu **200** com `<?php /* AUDIT_SOURCE_MARKER */ ...` intacto. O Generic
executou `source.php` normalmente; o Laravel bloqueou esse nome com 404, mas
devolveu as alternativas como texto. `.env`, `%2eenv`, descendentes ocultos de
`.well-known` e PATH_INFO oculto continuaram protegidos com 403.

**Impacto:** leitura de código, configuração ou credenciais se esses ficheiros
forem publicados. Foram usados apenas marcadores fictícios; não foi demonstrada
uma fuga de segredos de uma aplicação real. A condição é a presença do ficheiro
no diretório público, não uma capacidade demonstrada de o atacante o criar.

**Recomendação:** definir uma negação de nomes PHP alternativos/backups antes
do serviço estático, preservando a execução `.php` pretendida no Generic e o
front controller no Laravel. Remover backups/fontes do artefacto público e testar
as variantes de maiúsculas, sufixos, encoding e PATH_INFO.

**Aceitação:** os cinco nomes de prova deixam de devolver código; rotas normais,
PHP permitido, `.well-known`, `public/storage` e os testes atuais continuam válidos.
Referências: [locations Nginx](https://nginx.org/en/docs/http/ngx_http_core_module.html#location)
e [teste OWASP de backups](https://wstg.owasp.org/latest/4-Web_Application_Security_Testing/02-Configuration_and_Deployment_Management/04-Review_Old_Backup_and_Unreferenced_Files_for_Sensitive_Information/).
Evidência: [probes.json](probes.json), chaves `http_generic` e `http_laravel`.

## A03 — Média: paragem interrompe pedidos e pode ficar bloqueada

**Local:** `entrypoint/runtime.sh:21–42`.

O gestor envia QUIT aos dois serviços e espera pelos filhos sem prazo próprio.
Na prova independente, um pedido PHP que já tinha escrito o marcador de início
e executava `sleep(5)` recebeu **502** após TERM ao PID 1; o contentor terminou
com **0**. QUIT direto ao FPM também interrompeu o pedido. QUIT apenas ao Nginx
permitiu concluí-lo com **200** antes de o gestor tratar a saída do serviço.

Um teste separado suspendeu o master Nginx com STOP e enviou TERM ao gestor.
O contentor continuava em execução após três segundos; uma paragem forçada com
prazo curto terminou em **137**. A ausência de um prazo é também visível no código.

**Impacto:** pedidos perdidos durante deploy/restart e paragens sem duração
previsível. Não é uma demonstração de execução remota ou elevação de privilégios.

**Recomendação:** parar a aceitação de pedidos e drenar Nginx antes de terminar
FPM, com prazo global e escalonamento de sinais. Cobrir pedidos ativos e filhos
bloqueados, não apenas saída 0 em repouso.
**Aceitação:** o pedido de cinco segundos termina em 200 dentro do prazo;
bloqueios esgotam um prazo documentado e produzem diagnóstico explícito.
Evidência: [shutdown.json](shutdown.json) e `blocked_shutdown` em [probes.json](probes.json).

## A04 — Média: testes/scans não estão ligados ao digest promovido

**Local:** `.github/workflows/release.yml:89–113` e `maintenance.yml`.

A release executa os testes e depois faz outro build com `bake release --push`.
Os scans de manutenção são de candidatos locais, num workflow independente,
sem um gate de scan do digest exato no workflow de publicação. Os repositórios APK
são mutáveis. A assinatura/verificação criptográfica da identidade também está pendente.

**Recomendação:** construir candidatos de registry uma vez, testar e analisar
esses digests por arquitetura, verificar SBOM/provenance/assinatura e promover os
mesmos manifests. Exigir a aprovação da política antes de promover aliases.
**Aceitação:** igualdade verificável entre digests testados, analisados e promovidos;
findings bloqueantes ou evidência ausente impedem a promoção. Sem rebuild na promoção.

## A05 — Média: falha parcial deixa publicação incompleta e sem retoma

**Local:** `.github/workflows/release.yml:109–155`; `scripts/check-release-tags.py`.

O push já atualiza tags/aliases antes de validar a baseline e gerar anexos.
Uma falha posterior pode deixar Docker Hub atualizado e GitHub Release incompleta.
Na repetição, o preflight recusa as tags agora existentes antes de alcançar os
passos de recuperação dos anexos. A proteção de imutabilidade é útil, mas ainda
não existe um percurso separado para retomar os mesmos artefactos.

**Recomendação:** validar baseline/anexos antes dos aliases e persistir o estado
da publicação. Separar promoção de imagens de reparação de notas/anexos, sem
permitir sobrescrever tags com novos builds. Testar falhas entre todos os passos.

## A06 — Média: endurecimento do CI ainda incompleto

**Local:** `.github/workflows/*.yml`.

As Actions usam tags mutáveis (`@v7`, `@v4`) e a release atribui `contents: write`
ao job completo, incluindo validação. O checkout da release mantém credenciais
por omissão. A manutenção é melhor isolada: permissões de leitura, checkout sem
credenciais persistidas e ausência de login/push.

**Recomendação:** fixar Actions por SHA completo e automatizar atualizações;
separar validação e publicação, restringir permissões/credenciais e proteger o
ambiente de publicação. Exigir checks efetivos antes de merge/promoção.
Na consulta remota, `main` exigia revisão de PR e aplicava a proteção aos admins,
mas `required_status_checks` era nulo e a API de regras efetivas devolveu uma
lista vazia. Assim, não foi encontrada uma exigência de CI bem-sucedido para merge.
Não foi demonstrado comprometimento de uma Action. A recomendação segue as
[orientações GitHub](https://docs.github.com/en/actions/reference/security/secure-use).
Estado remoto recolhido em [github-readonly.json](github-readonly.json) e regras
efetivas em [github-effective-rules.json](github-effective-rules.json).

## A07 — Média, preventiva: contexto de build permite ficheiros sensíveis

**Local:** `.dockerignore`.

O ignore não exclui `.aws/`, `.codex/`, `.agents/` nem `.env`. Num contexto
sintético com o mesmo `.dockerignore`, um Dockerfile `FROM scratch; COPY . /context`
exportou os quatro marcadores. Os `COPY` atuais são específicos: esta prova não
demonstra que credenciais reais estejam na imagem ou tenham sido transferidas.
O BuildKit pode transferir ficheiros de forma seletiva, conforme os inputs pedidos.

**Recomendação:** excluir os diretórios e padrões de segredos e avaliar uma
allowlist de contexto. Manter uma regressão com marcadores fictícios, sem ler
credenciais reais. Referência: [boas práticas Docker](https://docs.docker.com/build/building/best-practices/#exclude-with-dockerignore).
Evidência: `context_markers` em [probes.json](probes.json).

## A08 — Média: exemplo read-only falha e tmpfs pode limitar uploads válidos

**Local:** `README.md`, exemplo Hardened; `nginx/nginx.conf`, `client_body_temp_path`.

1. O exemplo sem UID/GID no tmpfs de `/run/production` terminou com **1** e
   `Permission denied`, antes de servir a aplicação. Os testes usam o proprietário correto.
2. Corrigindo o proprietário mas mantendo o tmpfs de **16 MiB**, com
   `UPLOAD_MAX_SIZE=32M`, um POST de **17 MiB** devolveu **500** e registou
   `No space left on device`. O POST de 1 KiB devolveu 200.

**Recomendação:** corrigir o exemplo com `mode=0755,uid=10001,gid=10001`, definir
`mode=1777` em `/tmp` e documentar dimensionamento para uploads, concorrência e
buffers. Para cargas maiores, fornecer armazenamento temporário apropriado e
limites coerentes; não assumir que 16 MiB serve qualquer `UPLOAD_MAX_SIZE`.
Documentar UID/GID personalizados e escrita Laravel em storage/bootstrap/cache.
Evidência: `readme_readonly` e `tmpfs_capacity` em [probes.json](probes.json).

## A09 — Média: orçamento de tamanho pode aprovar uma exportação falhada

**Local:** `tests/size-budget.sh:13–19` e `tests/compare-size.sh`.

Sem verificar cada etapa, `docker save | gzip | wc` pode terminar com sucesso
mesmo quando a primeira etapa falha. Um wrapper temporário fez `docker save`
terminar com **42**, mantendo o inspect bem-sucedido. O teste mediu **20 bytes**
para cada imagem e terminou com **0**, aprovando os seis orçamentos.

**Recomendação:** verificar separadamente exportação/compressão, ou adotar uma
pipeline com semântica de erro garantida no shell escolhido. Falhas simuladas de
`docker save` e `gzip` devem reprovar. Evidência: `size_false_success` em [probes.json](probes.json).

## A10 — Média operacional: health check não verifica PHP

**Local:** `nginx/*.conf.template`, `location = /healthz`; `Dockerfile`, HEALTHCHECK.

Com o socket FPM temporariamente indisponível no contentor de prova, `/healthz`
continuou a devolver **200**, enquanto `/` devolvia **502**. É uma limitação já
documentada, não um bypass de autenticação; torna-se relevante se o orquestrador
usar este endpoint como sinal de disponibilidade para pedidos PHP.

**Recomendação:** preservar `/healthz` como liveness compatível e acrescentar uma
readiness opcional via FastCGI, com timeout e sem depender da aplicação. Separar
essa verificação da saúde de bases de dados/filas e evitar loops de reinícios
durante saturação. Evidência: `health_without_fpm_socket` em [probes.json](probes.json).

## A11 — Baixa: a política aceita um inventário parcial do scanner

**Local:** `scripts/check-candidates.py:60–78`, implementação recente da secção 1.

A identidade e existência de algum pacote são verificadas, mas não a
correspondência com o inventário APK completo. Conservando a metadata legítima
de um scan com 50 pacotes e substituindo Results por um único pacote fictício,
sem findings, a função de política devolveu aprovação. Os 18 scans reais desta
auditoria não apresentaram essa truncagem; não foi demonstrado que Trivy a produza.

**Recomendação:** comparar nomes/versões com o inventário APK esperado, validar
metadata/idade da base de vulnerabilidades e impedir reutilização inadvertida
de relatórios antigos. Cobrir truncagem e relatórios de outra execução em testes.
Evidência: [scan-policy-partial.json](scan-policy-partial.json).

## Melhorias adicionais, sem falha remota demonstrada

- **Leveza:** medir contribuição por pacote/camada antes de remover dependências.
  As candidatas comprimidas ficaram entre 16 983 389 e 26 094 031 bytes no método
  local `docker save + gzip`, dentro dos seis limites. Preservar CA, APK DB,
  timezone/extensões contratadas e visibilidade dos scanners. Ferramentas de
  auditoria não precisam de entrar no runtime.
- **Memória/concorrência:** medir RSS e carga representativa antes de alterar
  cinco filhos FPM, OPcache 128 MiB e um worker Nginx. Definir recursos/pids no
  deployment e dimensionar tmpfs com concorrência real.
- **Argumentos de build:** validar a versão PHP completa; a normalização por
  `tr -d '.'` converte também `8..5` em `85`. É uma inconsistência de input
  controlado pelo construtor, não uma injeção remota demonstrada.
- **Logs e proxies:** considerar query strings sensíveis em access logs e testar
  a política de proxies de confiança na aplicação. Não acrescentar confiança
  universal em X-Forwarded-* ou headers TLS sem conhecer a topologia.
- **Kubernetes:** documentar `runAsUser`/`runAsGroup` numéricos para ambientes que
  exigem comprovar `runAsNonRoot`; a imagem usa o nome `www` e a identidade real
  não-root foi verificada. Não interpretar o aviso Hadolint como execução root.
- **Repetibilidade:** fixar fixture/lockfile e Composer nos testes Laravel e
  manter testes separados com versões recentes; esta execução resolveu v13.38.0.
- **Manutenção:** corrigir changelog 2.0.3 duplicado, defaults antigos de
  `compare-size.sh` e migração CLI. Enquadrar os avisos de lint: SC2016 nos greps
  literais e splitting da lista APK são intencionais; congelar versões APK sem
  processo de atualização pode atrasar correções, em vez de melhorar segurança.

## Limites de validação

- Não foram auditadas aplicações privadas, contas/cloud, segredos externos,
  TLS/proxy de produção, bases de dados reais ou configurações do consumidor.
- Não foram executados runtime tests em ARM64 nem refeitos builds multi-arquitetura
  nesta auditoria. Os doze scans públicos cobrem as duas arquiteturas sem as executar.
- Os novos workflows/Dependabot ainda precisam de integração/ativação no GitHub.
  A consulta remota encontrou CI e Release, não Maintenance candidates.
- Não foi executado o comando agregado `test-release.sh`, que inclui builds
  limpos/multiarch; executaram-se a suite completa e os testes adicionais indicados.
- Scanners fornecem uma fotografia da base de vulnerabilidades usada. Zero
  findings nas candidatas não é uma garantia universal de ausência de falhas.
- Não foi publicada uma nova release nem alterado o runtime para corrigir os achados.

## Ordem de correção recomendada

1. Resolver A01/A02: preparar dependências atualizadas e bloquear exposição de
   fontes; acrescentar regressões e publicar uma nova versão verificada.
2. Corrigir A03 e A08: drenar pedidos, limitar paragens e alinhar permissões/capacidade.
3. Corrigir A09/A11 para que os gates de teste/scan não aprovem evidência incompleta.
4. Resolver A04/A05: ligar validação aos digests promovidos e suportar recuperação.
5. Consolidar A06/A07/A10 e confirmar gates/workflows/execução ARM64 remotos.

O [resumo JSON](summary.json) contém a classificação e os scans por imagem.
`verify.py`, `verify-shutdown.py` e `scan-published.py` permitem repetir as provas
com Docker. Os dois primeiros usam apenas contentores próprios, mounts temporários
e marcadores fictícios. `scan-published.py` consulta o registry e não executa os
conteúdos das imagens. Consultar os logs e os inventários para os digests exatos.
