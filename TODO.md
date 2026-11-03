# TODO — Production

Lista de trabalho para todo o projeto. Atualizada em **30/10/2026**.

**P0:** necessário antes de utilizar o cenário ou funcionalidade em causa em produção.
**P1:** necessário para fiabilidade, segurança e operação. **P2:** melhoria ou consolidação da imagem.

- **[x] Já feito:** implementação existente ou verificação concluída no âmbito indicado.
- **[ ] Falta fazer:** desenvolvimento, validação real ou melhoria ainda pendente.

A [auditoria de 21/10/2026](reports/audit-2026-10-21/AUDIT.md) registou 11 achados.
As correções estão preparadas para **2.0.4**, com evidência em
[reports/remediation-2.0.4/REMEDIATION.md](reports/remediation-2.0.4/REMEDIATION.md).
A release pública 2.0.3 continua histórica: não foi substituída nem publicada
uma nova versão nesta tarefa. A correção adicional de órfãos em 30/10 tem evidência separada e substitui a validação da árvore anterior sem init. O merge, a execução dos novos workflows e a
publicação/validação dos digests finais continuam a ser passos de release.

## Estado atual

Runtime Alpine 3.24/Nginx/PHP-FPM, Generic e Laravel para PHP 8.3/8.4/8.5,
UID/GID 10001:10001 e porta 8080. Sem instalação de pacotes no arranque.
A versão de trabalho é **2.0.4**, com Tini para recolha de órfãos em web/CLI, proteção de fontes PHP e shutdown por fases,
readiness FPM, contexto de build restrito e medições/scans que falham perante
resultados incompletos. O workflow prepara e valida digests antes de assinar e
promover os mesmos manifests, com recuperação de falhas parciais.

No GitHub, main já exige **Runtime tests** e **Multi-architecture build** com
checks atualizados, preservando as regras de revisão e administradores existentes.
O ambiente release está limitado à branch main e tags v*. A ativação dos workflows
novos/fixados depende do merge na branch predefinida.
Nenhum resultado local substitui os gates da publicação nem os scans dos digests
finais. As propostas P2 de redução de tamanho exigem medição e preservação dos
contratos atuais.

## 1. Base, variantes e extensões — P1/P2 · implementado e validado em amd64, ativação no GitHub pendente

### Já feito

- [x] Disponibilizar Generic e Laravel para PHP 8.3, 8.4 e 8.5, através de um Dockerfile e uma matriz Docker Bake.
- [x] Instalar os pacotes no build, incluindo atualização dos pacotes Alpine, sem instalação de extensões no arranque.
- [x] Manter extensões comuns no Generic e acrescentar no Laravel drivers de bases de dados, Redis, intl, bcmath, pcntl e ZIP.
- [x] Acrescentar Phar a Generic/Laravel nos três PHPs; validar em amd64 a leitura/execução de arquivos e manter phar.readonly ligado por defeito. Evidência em reports/phar-2026-10-30/REPORT.md.
- [x] Definir metadados OCI e verificar localmente versão, identidade, extensões, entrypoint e comando nas seis imagens.
- [x] Fixar Alpine 3.24 pelo digest do índice oficial com amd64/arm64, atualizar referências por pull requests revistos e preservar o inventário dos pacotes APK.
- [x] Configurar candidatos diários, manuais e para pull requests relevantes, com builds limpos, testes, inventários e scans Trivy em jobs nativos amd64/arm64, sem publicar candidatos.
- [x] Guardar a base, manifests, identificadores Docker/digests de configuração e inventários completos; verificar os layers da base e a identidade dos scans e reprovar relatórios incompletos ou vulnerabilidades HIGH/CRITICAL corrigíveis.
- [x] Construir e validar localmente as seis novas candidatas amd64 com a suite completa, contrato de release e seis scans aprovados em 21/10/2026.
- [x] Proteger as sete tags versionadas contra rebuild/conflitos; aceitar recuperação apenas dos mesmos digests, sem tratar erros de rede/autenticação como ausência de tag.
- [x] Definir em `SUPPORT.md` a matriz PHP/Alpine, limites de suporte de community, revisão mensal, processo de atualização com nova versão e procedimento de fim de suporte.

### Falta fazer

- [ ] **Ativação/validação remota:** após integrar na branch predefinida, confirmar a primeira execução dos jobs GitHub amd64/arm64, incluindo retenção dos anexos. Não foi efetuada publicação nesta tarefa.

## 2. Arranque e gestão de processos — P1 · implementado, cenários de falha a ampliar

### Já feito

- [x] Manter Tini como PID 1 em web e CLI; executar o gestor POSIX de Nginx/PHP-FPM por baixo, sem Supervisor nem Python.
- [x] Detetar a saída inesperada de um dos serviços, pedir a paragem do outro e terminar o contentor com erro.
- [x] Tratar TERM, INT e QUIT com pedidos de paragem graciosa e confirmar esses caminhos nos testes locais.
- [x] Executar comandos CLI diretamente com `exec`, sem iniciar o runtime web.
- [x] Confirmar na auditoria A03 que TERM pode interromper um pedido PHP ativo com 502 e saída 0; confirmar também espera sem prazo perante um master suspenso.
- [x] **A03:** drenar Nginx antes de parar FPM; regressão de pedido PHP de cinco segundos com HTTP 200 e paragem limitada perante master suspenso.
- [x] Definir SHUTDOWN_TIMEOUT de 1–300 s, deadline global, escalonamento para KILL, logs e saída 1 perante paragem forçada.
- [x] Documentar o prazo do runtime e o stop timeout superior no Docker/Compose, com regressões de conclusão dentro do prazo.

- [x] Reproduzir a lacuna CLI pré-init: 30/60/90 zombies adotados por PHP PID 1; acrescentar Tini e regressão com 200 órfãos por contentor, mantendo-o vivo. Aprovar em amd64 12 cenários web/CLI, 2 400 órfãos sem acumulação, mitigação Docker --init e compatibilidade de init aninhado. Ver evidência de 30/10 em reports/zombies-2026-10-30/REPORT.md.

### Falta fazer

- [ ] **Resiliência adicional:** ampliar falhas simultâneas e condições de arranque; verificar o PPID dos zombies reportados no ambiente real para distinguir órfãos de filhos de uma aplicação ainda viva.

## 3. Configuração e PHP-FPM — P1/P2 · implementado, limites e dimensionamento pendentes

### Já feito

- [x] Validar memória, uploads, timezone e document root antes de gerar os ficheiros de configuração.
- [x] Rejeitar diretivas injetadas, quebras de linha, timezone inválido e document root web inexistente, com regressões locais aprovadas.
- [x] Preservar a execução CLI sem exigir um document root web existente.
- [x] Configurar OPcache, ocultação de erros ao cliente e encaminhamento dos erros PHP para stderr.
- [x] Limitar o pool FPM a cinco filhos e reciclar workers após 500 pedidos.

### Falta fazer

- [ ] **Validação adicional:** ampliar extremos/unidades/valores vazios de configuração PHP; versões PHP malformadas e limites inválidos/overflow de shutdown já são rejeitados por regressões.
- [ ] **Validação adicional:** ensaiar uploads exatamente na fronteira de post_max_size; a regressão de 17 MiB e a documentação de overhead multipart já estão concluídas.
- [ ] **Desempenho:** medir RSS, memória total, latência e throughput nos três PHPs, em repouso e sob carga, incluindo contentores com memória limitada.
- [ ] **Melhoria:** documentar perfis de FPM/OPcache e overrides para contentores pequenos; expor novas variáveis apenas se a medição justificar. O limite de memória PHP não é o limite total do contentor.

## 4. Nginx, HTTP e aplicações — P1 · implementado, proteção e integrações a ampliar

### Já feito

- [x] Configurar o Generic para executar ficheiros PHP existentes e o Laravel para encaminhar execução pelo front controller `index.php`.
- [x] Bloquear caminhos ocultos antes dos handlers PHP e preservar a exceção exata `.well-known`, incluindo testes de descendentes ocultos e PATH_INFO.
- [x] Servir ficheiros estáticos, aplicar limite de corpo HTTP e emitir headers de segurança sem expor as versões PHP/Nginx.
- [x] Configurar real paths e buffers FastCGI no Laravel, com regressão local aprovada para headers de resposta de 16 KiB.
- [x] Confirmar encaminhamento, headers, limites HTTP e 50 pedidos dinâmicos concorrentes por variante nos testes locais.
- [x] **A02:** bloquear .PHP, .pHp, .php.bak, .php~, .phtml, .phar e .phps nas duas variantes, mantendo execução PHP legítima e ACME.
- [x] Aplicar proteção de fontes/backup nas duas variantes, preservando o front controller e as regras de caminhos ocultos.

### Falta fazer

- [ ] **Casos adicionais:** ampliar encoding, traversal e symlinks em HTTP.
- [ ] **Integração:** testar HTTPS atrás de proxy, host, IP do cliente e falsificação de headers encaminhados; documentar proxies de confiança na aplicação sem confiar indiscriminadamente no cliente.

## 5. Utilizador, permissões e filesystem — P0/P1 · exemplo corrigido e regressão de uploads

### Já feito

- [x] Executar como utilizador não-root `www`, com UID/GID estáveis `10001:10001` e porta interna 8080.
- [x] Preparar a aplicação antes do arranque, sem `chown -R` ou `chmod -R` sobre os mounts no entrypoint.
- [x] Concentrar a configuração gerada e ficheiros temporários de runtime em `/run/production` e `/tmp`.
- [x] Validar localmente root filesystem só de leitura, capabilities removidas, no-new-privileges e tmpfs com proprietário explícito, incluindo escrita Laravel nos diretórios autorizados.
- [x] Reproduzir a falha do exemplo do README sem proprietário no tmpfs e confirmar que a definição explícita de UID/GID resolve a criação dos diretórios de runtime.
- [x] Corrigir no README o proprietário/modo de /run/production e /tmp e usar tmpfs de 128 MiB como ponto de partida documentado.
- [x] Alinhar o exemplo com tests/security.sh: resposta PHP, readiness, só de leitura, capabilities removidas e no-new-privileges nas duas variantes.
- [x] Documentar UID/GID personalizados, identidade numérica Kubernetes e escrita necessária em web, CLI e Laravel.
- [x] **A08:** documentar buffers, multipart, concorrência e orçamento de memória; aprovar upload multipart de 17 MiB com limite 32M em ambas as variantes.

### Falta fazer

- [ ] Rever a capacidade de armazenamento temporário/persistente para a carga de cada aplicação.

## 6. Health checks, logs e diagnóstico — P1 · liveness e readiness implementadas

### Já feito

- [x] Expor /healthz para liveness e /readyz para readiness FPM; configurar o health check Docker para /readyz.
- [x] Emitir access logs Nginx em JSON e enviar logs do gestor, Nginx e PHP para stdout/stderr.
- [x] Confirmar localmente a validade do JSON e a chegada dos erros da aplicação aos logs Docker.
- [x] Documentar a desativação do health check HTTP nos exemplos CLI, filas e scheduler do README.
- [x] **A10:** disponibilizar /readyz reservado com ping FPM, sem ficheiros da aplicação, timeout curto e sem detalhes do pool; usá-lo no HEALTHCHECK.
- [x] Distinguir liveness Nginx, readiness FPM e saúde da aplicação na documentação.
- [x] Preservar /healthz com resposta ok e documentar as duas verificações e o uso de --no-healthcheck em CLI.
- [x] Regressão nas duas variantes: remover temporariamente o socket FPM mantém /healthz a 200 e faz /readyz falhar com 502.

### Falta fazer

- [ ] **Operação:** medir saturação do pool e ajustar probes/limites à carga, evitando ciclos de reinício.

## 7. Tamanho, pacotes e consumo — P2 · limites locais aprovados, otimização por medir

### Já feito

- [x] Manter Composer, Node.js, Git, compiladores e ferramentas de desenvolvimento fora do runtime, com verificações nos contratos de release.
- [x] Separar Generic e Laravel para evitar extensões adicionais nas aplicações que não precisam delas.
- [x] Definir limites de tamanho por variante/PHP e aprovar os seis limites locais em 15/10/2026.
- [x] Registar a seguinte referência local, em bytes de arquivo `docker save` comprimido com gzip; não corresponde diretamente ao tamanho transferido pelo registry.

| PHP | Generic | Laravel |
| --- | ---: | ---: |
| 8.3 | 17 103 890 | 23 131 974 |
| 8.4 | 17 483 070 | 24 212 740 |
| 8.5 | 19 966 458 | 26 213 673 |

### Falta fazer

- [ ] **Medição:** produzir relatório por pacote e camada para cada variante/arquitetura, distinguindo tamanho comprimido no registry, tamanho descomprimido e arquivo local.
- [ ] **Otimização:** auditar dependências transitivas, módulos Nginx, utilitários e ficheiros dispensáveis, preservando certificados CA, bibliotecas necessárias e inventários APK coerentes.
- [ ] **Medição:** quantificar tzdata, Redis, intl/ICU, ZIP e drivers de bases de dados; avaliar um perfil mínimo adicional apenas se a poupança compensar a matriz extra de manutenção.
- [ ] **Otimização:** medir ficheiros substituídos por `apk upgrade` sobre layers da base e avaliar uma base atualizada ou outra composição apenas com ganho demonstrado, preservando correções de segurança.
- [ ] **Validação:** apresentar bytes poupados e impacto funcional em cada otimização; manter os contratos de Generic/Laravel e executar a suite relevante antes de aceitar a redução.

## 8. Arquiteturas e compatibilidade — P1 · execução emulada aprovada, CI nativo pendente

### Já feito

- [x] Definir builds `linux/amd64` e `linux/arm64` para as seis variantes.
- [x] Disponibilizar preflight ARM64 e builder dedicado na validação multi-arquitetura.
- [x] Preparar o CI com QEMU e Buildx para construir ambas as arquiteturas.
- [x] Configurar jobs de manutenção nativos amd64/arm64 com testes funcionais e scans; a execução ARM64 no GitHub ainda precisa de confirmação.
- [x] Aprovar as seis variantes ARM64 emuladas na suite completa: contratos, HTTP, configuração, sinais, segurança, uploads e tamanho, em 325 segundos na execução final (543 s na primeira validação).
- [x] Configurar runners ARM64 nativos na manutenção/release e explicitar que a validação local foi emulada; confirmar o primeiro job nativo após merge.

### Falta fazer

- [ ] **Publicação:** confirmar plataformas e digests dos manifests candidatos e finais, incluindo a associação correta das evidências por arquitetura.

## 9. Publicação, tags e recuperação — P1 · promoção por digest e recuperação implementadas

### Já feito

- [x] Validar a correspondência entre a tag estável e `VERSION` antes da publicação.
- [x] Serializar releases e comparar versões numericamente para impedir que uma release histórica promova aliases quando já existe uma tag estável mais recente.
- [x] Disponibilizar tags de versão, aliases PHP, `latest` e `laravel` no plano Bake.
- [x] Preparar a criação/atualização de GitHub Releases com notas e anexos de pacotes.
- [x] Dispor de uma suite de release com builds limpos, aplicações reais, estabilidade e builds multi-arquitetura; os componentes foram executados nesta preparação em ambas as arquiteturas, com ARM64 emulado.
- [x] Preservar tags versionadas e recusar digests incompatíveis; aceitar apenas repetição dos mesmos artefactos validados, falhando perante erros de registry.
- [x] **A04:** construir staging uma vez, guardar digests, testar/analisar artefactos exatos em jobs nativos e promover sem rebuild.
- [x] **A05:** gerar comparação de pacotes e guardar evidências no draft antes de mover tags públicas; exigir jobs de validação aprovados.
- [x] Retomar tags com o mesmo digest; recusar conflitos antes da promoção. Disponibilizar repair_notes para reparar notas sem publicar imagens.
- [x] Guardar journal da promoção, reter artefactos 90 dias e documentar recuperação, preservando a distinção entre tags versionadas e aliases.
- [x] Testar conflitos, falha durante a promoção, repetição idempotente, erros de registry e evidência incompleta para qualquer das arquiteturas.

### Falta fazer

- [ ] Integrar o workflow novo, executar os gates nativos e verificar a primeira promoção/assinatura no GitHub.

## 10. Vulnerabilidades, assinaturas e inventários — P1 · gates implementados, verificação pública pendente

### Já feito

- [x] Configurar SBOM e provenance `mode=max` nos targets de release, sem acrescentar ferramentas ao filesystem do runtime.
- [x] Gerar comparações de pacotes entre a versão anterior e os digests devolvidos pela publicação, sem executar o conteúdo das imagens para obter os inventários.
- [x] Resolver manifests por arquitetura, ignorar manifests de attestation e registar referências pedidas e resolvidas, com regressões Python aprovadas.
- [x] Preservar relatórios locais Markdown/JSON e verificar a coerência das diferenças com os inventários registados.
- [x] Distinguir alterações de versões de pacotes de correções CVE efetivamente verificadas.
- [x] Configurar scans dos candidatos de manutenção nas duas arquiteturas, com scanner fixado por digest, relatórios completos e bloqueio de HIGH/CRITICAL corrigíveis; aprovar localmente os seis scans amd64 em 21/10/2026.
- [x] Ligar os scans à promoção dos digests exatos e exigir validação nativa amd64/arm64 no workflow de release.
- [x] **A01 (preparação):** preparar 2.0.4 com APK atualizados e inventários/scans de candidatas em ambas as arquiteturas.
- [x] **A11:** exigir igualdade completa dos nomes/versões APK no scan, identidade do arquivo, scanner esperado e atualidade do relatório/base; rejeitar pacotes em falta, duplicados ou alterados.
- [x] Configurar assinatura Cosign por digest com OIDC GitHub e verificação da identidade antes da promoção; documentar verificação pelo consumidor.
- [x] Guardar inventários e scans por digest/plataforma, metadados, anexos e journal; definir retenção e rastreabilidade no workflow.

### Falta fazer

- [ ] **Ativação:** confirmar primeira execução dos novos jobs nativos após merge.
- [ ] **A01 (publicação):** publicar a nova versão e verificar CVEs/digests finais; os 13 CVEs únicos da imagem pública 2.0.3 não desaparecem retroativamente.
- [ ] **Operação:** acompanhar a política de bloqueio já definida para candidatos e definir exceções justificadas com validade se forem necessárias; atualmente não há allowlists nem aprovação perante falha do scanner.
- [ ] **Validação:** verificar SBOM, provenance e assinaturas efetivamente disponíveis no registry e associados aos digests corretos; verificar o plano Bake não basta.

## 11. CI, testes e contexto de build — P1/P2 · cobertura local aprovada, consolidação pendente

### Já feito

- [x] Disponibilizar suites rápida, completa e de release, com helpers partilhados e validação de argumentos de build inválidos.
- [x] Executar em 15/10/2026 os 13 testes Python e a suite completa com `SKIP_BUILD=1`, incluindo contratos das seis imagens, smoke, configuração, HTTP, concorrência, logs, falhas, sinais, segurança e tamanho.
- [x] Confirmar que os oito ficheiros principais de runtime da imagem local Generic PHP 8.5 correspondem ao repositório analisado.
- [x] Configurar CI para pull requests e main, com jobs de testes de runtime e build multi-arquitetura.
- [x] Excluir do contexto vários diretórios de desenvolvimento e relatórios através de `.dockerignore`.
- [x] Acrescentar 14 testes de manutenção para pin/manifests, layers da base, identidade do arquivo, scans incompletos e proteção de tags; aprovar os 27 testes Python existentes e novos.
- [x] Concluir a auditoria de 21/10/2026: suite em 243 s, aplicações PHP/Laravel nos três PHPs, reinícios, contrato de release, actionlint e scans; não detetar segredos com Gitleaks no histórico disponível e no snapshot do código.
- [x] Fixar todas as GitHub Actions por SHA completo, manter versão em comentário e atualizar referências por pull requests revistos.
- [x] Separar jobs de validação read-only e publicação/assinatura, limitar contents-write/OIDC e desativar persistência de credenciais checkout.
- [x] **A06:** aplicar e verificar no GitHub os checks obrigatórios com app_id GitHub Actions e strict=true; limitar o ambiente release a main/v*.
- [x] **A09:** verificar docker save e gzip em passos separados; ambas as suites de tamanho reprovam perante erro de qualquer comando.
- [x] **A07:** permitir apenas os ficheiros de runtime no contexto; regressão com marcadores sintéticos em .aws/.codex/.agents/.env e dentro dos diretórios permitidos.
- [x] Fixar a imagem Composer por digest, fora do runtime.
- [x] Aprovar os 35 testes Python, as suites finais amd64/ARM64 (701 s/325 s), aplicações reais, build limpo multi-arquitetura e contrato de release; ARM64 local emulado.
- [x] Disponibilizar scripts/zombie-report.py para associar zombies aos contentores e PPIDs sem ler argumentos ou variáveis de ambiente.
- [x] Confirmar por SHA256 os oito ficheiros de runtime nas 12 imagens finais e guardar evidências de testes, tamanhos, pacotes e scans.
- [x] Corrigir a corrida de leitura de /proc no teste de zombies e rejeitar um filho intencionalmente não recolhido, preservando a deteção de processos persistentes.

### Falta fazer

- [ ] **Repetibilidade adicional:** fixar a fixture Laravel e lockfile, mantendo uma execução separada com versões recentes.
- [ ] **Integração:** exercitar ligações e operações reais MySQL, PostgreSQL e Redis; atualmente SQLite é exercitado e os restantes drivers são sobretudo detetados.
- [ ] **Publicação:** executar a suite de release e conferir o CI antes de cada publicação, preservando evidência por digest; a execução local sem rebuild não substitui essa validação.

## 12. Documentação e manutenção — P1/P2 · documentação de 2.0.4 alinhada

### Já feito

- [x] Documentar variantes, extensões, configuração, permissões, Compose, CLI, filas, scheduler, migração e comandos de teste.
- [x] Registar no changelog e nas notas de release as alterações de runtime e a transparência de pacotes.
- [x] Organizar esta lista por áreas, distinguindo implementação existente, validação concluída e trabalho pendente.
- [x] Eliminar a entrada duplicada 2.0.3 do changelog e atualizar defaults de compare-size, Dockerfile/Bake e testes para 2.0.4.
- [x] Documentar gates de vulnerabilidades, falhas de scanner, retenção e recuperação de publicação incompleta; não existem exceções automáticas.
- [x] Atualizar MIGRATION.md para readiness, saúde CLI e stop grace period; alinhar exemplos de segurança com regressões.

### Falta fazer

- [ ] **Manutenção adicional:** centralizar progressivamente VERSION nas ferramentas; a coerência de Dockerfile/Bake/testes e documentação de 2.0.4 já está verificada.

## Ordem sugerida

Preparação adicional de 31/10: o workflow passa a guardar resultados/logs de todas
as suites, vinculados aos IDs analisados; a promoção exige estes resultados e os
hashes dos logs. A verificação lê plataformas, identidade, SPDX e SLSA do registry
antes da assinatura e depois da promoção, conferindo tags antes de publicar a
release GitHub. Procedimentos de recuperação/rollback e reporte privado em
`docs/RELEASING.md` e `SECURITY.md`. A execução remota e a publicação continuam pendentes.

1. Rever e integrar 2.0.4, executar os workflows novos e confirmar os gates nativos e assinaturas.
2. Publicar v2.0.4 e verificar os digests finais, evidências e aliases; recriar os contentores das aplicações.
3. Consolidar fixtures, integrações MySQL/PostgreSQL/Redis, casos de HTTP e cenários adicionais de falha.
4. Medir consumo e tamanho por pacote/camada antes de aplicar otimizações P2, preservando extensões e inventários.
