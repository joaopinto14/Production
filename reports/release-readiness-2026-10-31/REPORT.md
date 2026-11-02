# Preparação da release 2.0.4 — 31/10/2026

Esta passagem reforçou o processo de publicação sobre as alterações locais já
existentes de runtime, segurança, Tini e Phar. **Não foi criada uma release,
tag Git, commit, push público ou assinatura pública.**

## Alterações desta passagem

- `scripts/validate-candidate.py` executa as cinco suites de release sem rebuild,
  guarda logs, códigos de saída, tempos e IDs das seis imagens, e rejeita uma
  troca de imagens durante os testes. Resultados interrompidos/falhados não são
  marcados como aprovados.
- A promoção exige resultados frescos e completos para as duas arquiteturas,
  com os mesmos IDs dos inventários analisados e hashes dos logs correspondentes.
- `scripts/verify-release.py` lê os índices/configurações do registry, exige as
  duas plataformas, identidade de versão/revisão/variante/PHP, utilizador não-root
  previsto, SPDX com pacotes e provenance SLSA por plataforma. Depois da promoção
  verifica as sete tags versionadas e, quando aplicável, os oito aliases.
- O workflow verifica estes artefactos antes de assinar, guarda-os com a evidência
  e só torna a release GitHub pública depois da leitura/verificação das tags finais.
- Acrescentados testes de regressão para falhas, evidência ausente/antiga,
  imagens/logs alterados, plataformas/atestados incompletos e aliases divergentes.
- Documentados preparação, verificação de assinatura/digest, recuperação e
  rollback em `docs/RELEASING.md`; reporte privado em `SECURITY.md`. O README
  identifica a 2.0.4 como preparação, evitando apresentar tags ausentes como publicadas.

## Validação local

Foram reconstruídas sem cache as seis imagens **amd64**, com pacotes atuais, no
namespace separado `production-release-check`. O build precisou de acesso à rede
do anfitrião, já que este ambiente exige autorização explícita de `network.host`.

As cinco suites passaram: suite principal completa, contrato de release,
aplicação PHP real, Laravel 13.39.0 nos três PHPs e estabilidade de reinícios.
A suite principal inclui **44 testes Python**, contratos de Phar, segurança,
HTTP/readiness, sinais/crashes, drenagem, órfãos CLI/web, upload de 17 MiB e os
seis limites de tamanho. O controlo negativo do detetor de zombies falha de
propósito dentro de um teste aprovado; essa mensagem não é uma falha da suite.

Os seis scans com Trivy e base atualizada passaram a política; os relatórios
não sinalizaram vulnerabilidades nesse snapshot. O controlo de promoção também
aceitou diretamente a combinação real dos resultados/logs e inventários amd64.
O actionlint aprovou os workflows e `git diff --check` não encontrou problemas.

Um registry temporário, limitado a loopback, recebeu seis fixtures Alpine
sintéticas com índices amd64/arm64, SPDX e SLSA reais. A promoção e verificação
das **15 tags** passaram; trocar `latest` para outro digest foi detetado e
rejeitado. O registry foi removido. Este ensaio valida o formato/transporte dos
artefactos; não demonstra execução PHP em ARM64 nem assinatura OIDC pública.

A consulta pública em leitura confirmou que as sete tags 2.0.4 estavam ausentes
no momento do preflight. Esta observação não reserva as tags.

Resultados, IDs, hashes e resumos dos scans: [summary.json](summary.json).
Hashes dos ficheiros de implementação: [source-manifest.json](source-manifest.json).
Os logs completos, inventários e JSON Trivy/SPDX/SLSA permanecem localmente em
`candidate-reports/release-readiness-2026-10-31/`, excluído do Git.

## Gates ainda necessários para publicação

1. Rever e fazer commit da árvore final, integrá-la em `main` e confirmar CI.
2. Executar o workflow de release nos digests de staging, com suites/scans em
   **amd64 e ARM64 nativos**. O ensaio local não substitui estes jobs.
3. Confirmar a assinatura/verificação Cosign com GitHub OIDC, permissões e
   credenciais do ambiente `release`, promoção e evidências finais anexadas.

As imagens locais foram construídas a partir de uma árvore com alterações não
commitadas. O SHA nos labels identifica o HEAD de referência, não um commit que
contenha estas alterações. A publicação tem de construir a revisão final revista.
Nenhum serviço preexistente foi reiniciado ou reconfigurado.
