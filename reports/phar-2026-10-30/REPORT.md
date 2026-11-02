# Extensão Phar — 30/10/2026

Adicionada à lista comum do Dockerfile através de `php${PHP_SLOT}-phar`, para Generic e Laravel em PHP 8.3/8.4/8.5. A versão preparada mantém-se 2.0.4, ainda sem publicação.

Foram construídas seis imagens locais amd64 no namespace production-phar. Os testes validam a extensão e classe, leitura via phar:// e execução de um arquivo real com assinatura SHA-256. A criação do fixture usa phar.readonly=0 apenas num subprocesso de teste; o processo normal e a imagem mantêm o valor por defeito ligado. Este hash deteta corrupção; não autentica a origem do arquivo.

Passaram os contratos das seis imagens, smoke PHP-FPM, regressões HTTP (incluindo bloqueio de acesso direto a .phar) e os seis limites de tamanho. Os scans e versões dos pacotes estão resumidos em [summary.json](summary.json); a saída de testes está em [tests.log](tests.log). Os relatórios locais completos de scan/inventário estão em `candidate-reports/phar-2026-10-30/` (excluídos do Git).

Esta validação é amd64. A execução nativa ARM64 e os gates de release continuam obrigatórios antes da publicação. Os relatórios anteriores à adição Phar correspondem às suas próprias imagens/snapshots e não validam esta extensão.
