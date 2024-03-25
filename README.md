# Production

This repository contains the source code for the "Production" Docker image. This Docker image, designed to be compact and efficient, has the sole purpose of running your web project in a production environment.

Equipped with all the essential tools for an efficient, safe, and lightweight launch, it includes only the PHP and NGINX packages, which are the essential resources to ensure the project's operation.

For tasks such as environment configuration, dependency installation, code compilation, or test execution, it is advisable to use a dedicated development image, like the [Development](https://github.com/joaopinto14/Development) image, which was specifically designed to facilitate and optimize these tasks.

## Index

- [Image Components](#image-components)
    - [Default Installed PHP Extensions](#default-installed-php-extensions)
- [Image Build](#image-build)
- [Usage](#usage)
- [Usage Examples](#usage-examples)
    - [Using the command line](#using-the-command-line)
    - [Using Docker Compose](#using-docker-compose)
- [Environment Variables](#environment-variables)
- [Issues](#issues)
- [License](#license)
- [Author](#author)
## Image Components:

- **Alpine**: 3.19
- **PHP**: 8.3
- **NGINX**: 1.24.0-r15

### Default Installed PHP Extensions:

- **Core**
- **date**
- **filter**
- **hash**
- **json**
- **libxml**
- **pcre**
- **random**
- **readline**
- **Reflection**
- **SPL**
- **standard**
- **zlib**

## Image Build

Follow the steps below to build the Docker image:

1. Clone the repository with the command:
```
git clone https://github.com/joaopinto14/Production.git
```
2. Navigate to the project directory with the command: 
```
cd Production
```
3. Build the Docker image with the command:
```
docker build -t production .
```

## Usage

This Docker image is easy to use, requiring only the mounting of the volume of your PHP project. If the index.php file is located in a subdirectory, you will need to specify its location using the **PROJECT_PATH** environment variable.

If your project requires additional PHP extensions, you can set the **PHP_EXTENSIONS** environment variable with the names of the extensions you want to install.

Additionally, the **MEMORY_LIMIT** and **UPLOAD_MAX** environment variables can be set to adjust, respectively, the memory limit that PHP can use and the maximum size of files that can be uploaded to the server.

When using this Docker image, you don't need to worry about checking the container's functionality or the necessary permissions for your project. Everything is configured and checked automatically for you.

## Usage Examples

### Using the command line
- Simple example:
```
docker run -d -p 80:80 -v /path/to/your/project:/var/www/html production
```
- Example with environment variables:
```
docker run -d -p 80:80 -v /path/to/your/project:/var/www/html -e PHP_EXTENSIONS="pdo_mysql mysqli" -e MEMORY_LIMIT=256M -e UPLOAD_MAX=16M production
```
- Example with a Laravel project:
```
docker run -d -p 80:80 -v /path/to/your/project:/var/www/html -e PROJECT_PATH=/var/www/html/public production
```
### Using Docker Compose
- Simple example:
```
version: '3'
services:
  web:
    image: production
    ports:
      - "80:80"
    volumes:
      - ./path/to/your/project:/var/www/html
```
- Example with environment variables:
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
```
- Example with a Laravel project:
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
      - PROJECT_PATH=/var/www/html/public
```

## Environment Variables

- **PHP_EXTENSIONS**: The PHP extensions to be installed. Default: null
- **PROJECT_PATH**: The path to the project directory. Default: /var/www/html
- **MEMORY_LIMIT**: The memory limit that PHP can use. Default: 128M
- **UPLOAD_MAX**: The maximum size of files that can be uploaded. Default: 8M

## Issues

If you encounter any issues with the image or have any improvement suggestions, feel free to open an [issue](https://github.com/joaopinto14/Production/issues/new/choose) on GitHub. Please provide as many details as possible to help resolve the issue.

## License

This project is licensed under the MIT license - see the [LICENSE.md](LICENSE.md) file for more details.

## Author

This image was created by [João Pinto](https://github.com/joaopinto14).

For more information or support, please send an email to suport@joaopinto.pt.