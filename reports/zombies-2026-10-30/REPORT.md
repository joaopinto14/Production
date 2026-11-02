# Zombies PHP — correção adicional de 30/10/2026

**A preparação anterior da 2.0.4 não resolvia toda esta classe de problemas.**
Os testes de reinício/deteção anteriores não cobriam a acumulação de órfãos num
PHP CLI mantido como PID 1. Esta lacuna foi reproduzida e corrigida na árvore
local. Não foi efetuada publicação nem reiniciado qualquer serviço existente.

## Reprodução

Na imagem local anterior `production-candidate:2.0.4-laravel-php8.5`, ainda sem
init, um PHP CLI mantido vivo criou descendentes que ficaram órfãos. Três lotes
produziram **30 → 60 → 90 zombies**, todos adotados por PHP PID 1. A prova está
em [before.json](before.json).

O teste definitivo usa apenas PHP core e uma shell intermédia, incluindo assim
as variantes Generic sem acrescentar pcntl ao seu contrato. O processo principal
permanece vivo durante a medição: terminar o contentor não pode esconder os
zombies. O controlo negativo acumulou **200 zombies persistentes**, em cinco
lotes de 40: [negative-control.json](negative-control.json).

A captura fornecida mostra processos em estado Z, mas não o PPID, o serviço ou
a árvore de processos. Não permite concluir que a origem real é esta mesma
lacuna. A reprodução estabelece um defeito concreto na imagem, não um diagnóstico
remoto do servidor.

## Correção

- Instalar `tini` dos repositórios Alpine, mantendo UID/GID 10001:10001.
- Usar `ENTRYPOINT ["/sbin/tini", "-s", "--", "/usr/local/bin/entrypoint.sh"]`.
- Tini passa a ser o init e recolhe os órfãos adotados, tanto em web como em CLI,
  filas e scheduler. O modo subreaper cobre também a presença de Docker --init.
- O gestor POSIX continua responsável por Nginx/FPM. Não se usa encaminhamento
  de sinais para todo o grupo: isso interromperia o shutdown por fases.
- Preservar os argumentos/comando, códigos de saída CLI e encaminhamento TERM;
  a paragem web mantém drenagem Nginx antes de terminar FPM.

O pacote instalado é **tini 0.19.0-r3**. O binário mede **23 576 bytes** na imagem
amd64. É a única dependência runtime acrescentada. As extensões Generic/Laravel
e os limites de tamanho mantêm-se.

## Validação

A [matriz de órfãos](orphan-reaping-amd64.json) identifica os IDs imutáveis das
seis imagens locais corrigidas, Generic/Laravel × PHP 8.3/8.4/8.5. Cada imagem é
exercitada em CLI e web: **12 cenários × 200 processos = 2 400 órfãos**, sem
zombies persistentes. Os contentores mantêm-se vivos durante a medição e usam
root só de leitura, capabilities removidas e no-new-privileges. Os testes
confirmam também saída CLI 7, propagação de TERM para saída 143 e saída web 0.

A prova de mitigação com a imagem pré-init e Docker --init recolhe 200 órfãos em
cada modo sem acumulação: [older-image-docker-init.json](older-image-docker-init.json).
A combinação entre Docker --init e a nova imagem é validada separadamente em
[nested-docker-init.json](nested-docker-init.json).

Os contratos das seis imagens, smoke, configuração, HTTP, concorrência, logs,
crash/sinais, pedido PHP ativo durante shutdown e deadline forçado passaram com
o novo entrypoint. O primeiro percurso de test-all foi interrompido por uma
corrida no novo fixture ao ler um /proc que desaparecia durante a recolha; o
fixture passou a tratar a leitura vazia. Os testes de órfãos e todos os passos
restantes foram reexecutados e aprovados após essa correção. Não se apresenta
esse primeiro percurso como uma execução integral de test-all bem-sucedida.

As verificações seguintes confirmam hardening, upload de 17 MiB, os seis limites
de tamanho, reinícios e contrato de release. O detetor continua a reprovar o
filho intencionalmente não recolhido de um pai ainda vivo. As evidências e o
resumo final ficam neste diretório. Os seis scans amd64 atuais não sinalizaram
vulnerabilidades; inventários e relatórios completos em [scans-amd64](scans-amd64/inventory.json).

A validação desta alteração foi realizada em **amd64**. Os resultados ARM64 da
preparação de 21/10 antecedem Tini e não validam este novo entrypoint. A primeira
execução dos jobs nativos amd64/arm64 e os restantes gates de release continuam
obrigatórios antes da promoção pública.

## Mitigação da imagem antiga

Adicionar `init: true` ao serviço Compose afetado, ou `--init` a docker run, e
**recriar** o contentor preservando volumes/configuração e a sua política normal
de paragem. Um restart não altera a configuração init de um contentor existente.
Exemplo para o serviço já configurado:

```yaml
services:
  worker:
    # manter image, command, volumes, environment e restantes opções existentes
    init: true
```

```sh
docker compose up -d --force-recreate worker
```

Não foram executados estes comandos contra a aplicação do utilizador.

## Limite importante e diagnóstico

O init recolhe órfãos adotados. **Não pode recolher filhos que ainda pertencem a
um processo PHP vivo**: esse pai tem de executar waitpid/proc_close ou a operação
equivalente da biblioteca de processos. O mesmo limite se aplica a Docker --init.
Enviar SIGKILL ao zombie não o remove, porque o processo já terminou. Recriar o
contentor limpa a sua namespace, mas é necessário corrigir a origem para evitar
recorrência.

Para identificar o serviço e o pai sem recolher ambientes ou argumentos:

```sh
python3 scripts/zombie-report.py
```

Executar no host Docker afetado e repetir para distinguir transições breves de
acumulação persistente. O script só lê Docker ps/top e o PID principal; não mata,
reinicia nem altera contentores. A saída deste computador de desenvolvimento
não corresponde ao servidor da captura.

Referências: [Tini](https://github.com/krallin/tini),
[Docker Compose init](https://docs.docker.com/reference/compose-file/services/#init)
e [wait/waitpid Linux](https://man7.org/linux/man-pages/man2/wait.2.html).
