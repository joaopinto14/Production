# Production

This repository contains the source code for the Docker image "Production". This Docker image, designed to be compact and effective, has the exclusive purpose of running your web project in a production environment.

Equipped with all the essential tools for an efficient, safe, and lightweight launch, it includes only the PHP and NGINX packages, which are the essential resources to ensure the project's operation.

For tasks such as setting up the environment, installing dependencies, compiling code, or running tests, it is advised to use a dedicated development image, such as the [Development](https://github.com/joaopinto14/Development) image, which was specifically designed to facilitate and optimize these tasks.

### Image component versions

- **Alpine**: 3.19
- **PHP**: 8.3
- **NGINX**: 1.24.0-r15

## Installation

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

This image is easy to use, it is only necessary to mount the project volume. If the project is located in a subdirectory, it may be necessary to define the PROJECT_PATH environment variable.

In addition, it is possible to define the MEMORY_LIMIT and UPLOAD_MAX environment variables to adjust the memory limit for PHP and the maximum size of files that can be uploaded to the server, respectively.

## Examples

- Simple example:
```
docker run -d -p 80:80 -v /path/to/your/project:/var/www/html production
```
- Example with environment variables:
```
docker run -d -p 80:80 -v /path/to/your/project:/var/www/html -e PROJECT_PATH=/var/www/html -e MEMORY_LIMIT=128M -e UPLOAD_MAX=100M production
```
- Example with a Laravel project:
```
docker run -d -p 80:80 -v /path/to/your/project:/var/www/html -e PROJECT_PATH=/var/www/html/public production
```

## Environment Variables

- **PROJECT_PATH**: The path to the project directory. Default: /var/www/html
- **MEMORY_LIMIT**: The memory limit that PHP can use. Default: 128M
- **UPLOAD_MAX**: The maximum size of files that can be uploaded. Default: 100M

## Author

This image was created by [João Pinto](https://github.com/joaopinto14).

For more information or support, please send an email to suport@joaopinto.pt.