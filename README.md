# Production

Este repositório contém o código-fonte para uma imagem Docker robusta e segura. Ela fornece todas as ferramentas necessárias para implantar seu projeto web em um ambiente de produção de maneira estável, segura e leve.

Embora a imagem tenha sido inicialmente concebida para projetos que utilizam a framework Laravel, ela é versátil o suficiente para ser utilizada com qualquer tipo de projeto web.


## Constituição

Imagems baseada em PHP versão 8.3 alpine + NGINX
2. [PHP](https://hub.docker.com/_/php/)
3. [NGINX](https://www.nginx.com/)

## Configurações

1. Limite de memória: 512M
2. Máximo de envio: 100M

## Instalação

Siga os passos abaixo para construir a imagem Docker:

1. Clone o repositório com o comando: 
```
git clone https://github.com/joaopinto14/Production.git
```
2. Navegue até o diretório do projeto com: 
```
cd Production
```
3. Construa a imagem Docker com: 
```
docker build -t production .
```

## Author

This image was created by [João Pinto](https://github.com/joaopinto14).

For more information or support, please send an email to suport@joaopinto.pt.