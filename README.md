# ⚙️ *Production*

&nbsp;&nbsp;&nbsp;&nbsp;***Production*** is a *Docker* image that is compact and efficient, with the sole purpose of running your web project 
in a production environment.

## 📖 **Project Description**

A imagem Docker "Production", baseada na distribuição Linux Alpine 3.19, foi projetada para ser eficiente e fácil de usar. Ela vem equipada com PHP 8.3 e as extensões core, date, filter, hash, json, libxml, pcre, random, readline, reflection, spl, standard, e zlib. Para o servidor web, é usado o NGINX 1.24.0-r15, permitindo assim a execução eficiente de projetos web. Se ajustes adicionais forem necessários, eles podem ser feitos de forma simples e fácil, usando as variáveis de ambiente disponíveis.

&nbsp;&nbsp;&nbsp;&nbsp;The *Docker* image "***Production***", based on the Linux distribution *Alpine* 3.19, was designed to be efficient and easy
to use. It comes equipped with *PHP* 8.3 and the extensions *core, date, filter, hash, json, libxml, pcre, random, readline,
reflection, spl, standard, and zlib*. For the web server, *NGINX* 1.24.0-r15 is used, thus allowing the efficient execution
of web projects. If additional adjustments are necessary, they can be made simply and easily, using the available 
[environment variables](#-environment-variables).

## ⚒️ **Image Build**

Follow the steps below to build the *Docker* image:

1. Clone the repository with the command:

```
git clone https://github.com/joaopinto14/Production.git
```

1. Navigate to the project directory with the command:

```
cd Production
```

1. Build the *Docker* image with the command:

```
docker build -t production .
```

## 📑 Environment Variables

- **PHP_EXTENSIONS**: The *PHP* extensions to be installed. Default: null (e.g.: pdo_mysql mysqli)
- **PROJECT_PATH**: The path to the project directory. Default: /var/www/html
- **MEMORY_LIMIT**: The memory limit that *PHP* can use. Default: 128M
- **UPLOAD_MAX**: The maximum size of files that can be uploaded. Default: 8M

## ▶️ **Usage Examples**

### - Using the command line:
```
docker run -d -p 80:80 -v /path/to/your/project:/var/www/html -e PHP_EXTENSIONS="pdo_mysql mysqli" -e MEMORY_LIMIT=256M -e UPLOAD_MAX=16M -e PROJECT_PATH=/var/www/html/public production
```
### - Using *Docker Compose*:
```
version: '3'
services:
  web:
    image: production
    ports:
      - "80:80"
    volumes:
      - ./path/to/your/project:/var/www/html
    environment:
      - PHP_EXTENSIONS=pdo_mysql mysqli
      - MEMORY_LIMIT=256M
      - UPLOAD_MAX=16M
      - PROJECT_PATH=/var/www/html/public
```

## 📝 Issues and Suggestions

&nbsp;&nbsp;&nbsp;&nbsp;If you find any issues related to the image or have suggestions for improvements, do not hesitate to open an
[issue](https://github.com/joaopinto14/Production/issues/new/choose) on *GitHub*. Please provide as many
details as possible to assist in resolving the issue or implementing your suggestion.

## 🪧 **Extra**

&nbsp;&nbsp;&nbsp;&nbsp;If you need a *Docker* image for tasks such as environment setup, dependency installation, code 
compilation, or test execution, it is recommended to use a dedicated development image, use the image 
"[Development](https://github.com/joaopinto14/Development)". This was specifically designed to facilitate and optimize these tasks.

## 👥 Contributors

- [João Pinto](https://github.com/joaopinto14) (Developer)

## 🧾️ License

&nbsp;&nbsp;&nbsp;&nbsp;This project is licensed under the *MIT* license - see the [LICENSE.md](LICENSE.md) file for more details.