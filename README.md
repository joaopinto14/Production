# ⚙️ *Production*

&nbsp;&nbsp;&nbsp;&nbsp;***Production*** is a *Docker* image that is compact and efficient, with the sole purpose of running your web project 
in a production environment.

## 📖 Project Description

&nbsp;&nbsp;&nbsp;&nbsp;***Production*** is a *Docker* image created using the Linux distribution ***Alpine*** version 3.19.
The ***PHP*** interpreter version 8.3 was installed, including the extensions *core, date, filter, hash, json, libxml, pcre,
random, readline, reflection, spl, standard, and zlib*. In addition, the web server ***NGINX*** version 1.24.0-r15 was installed
to allow the efficient execution of your web projects.

&nbsp;&nbsp;&nbsp;&nbsp;To facilitate the management of processes, the ***Supervisor*** version 4.2.5-r4 was installed, which allows
the control of the execution of multiple processes, such as the web server and the PHP interpreter. The ***Supervisor*** is also responsible
for monitoring and restarting processes in case of failures, ensuring greater availability of your project.

&nbsp;&nbsp;&nbsp;&nbsp;If additional adjustments are necessary, they can be made simply and easily, using the available
[environment variables](#-environment-variables).

## ⚒️ Image Build

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

## 🚀 How to Run Your Project in the Image

To run your project in the Docker image ***Production***, follow the steps below:

1. **Project Directory**: The main directory of your project should be mapped to the `/var/www/html` directory of the container. This is where the web server and the PHP interpreter will run your project safely and efficiently.

2. **Execution File**: If the execution file of your project `index.php` is not in the `/var/www/html` directory, you can define the directory of your project through the `INDEX_PATH` environment variable.

3. ***PHP* Extensions**: If your project requires additional *PHP* extensions or adjustments in the *PHP* settings, you can define the `PHP_EXTENSIONS`, `MEMORY_LIMIT`, and `UPLOAD_MAX` environment variables as needed.

4. ***Additional Processes***: If you need to run more processes in addition to those existing in the image (for example, queues, workers, etc.), you can use the `SUPERVISOR_CONF` environment variable to indicate the path of the *Supervisor* configuration file.

5. **Viewing Logs**: If you need to view the logs, they are located in the `/var/log` directory within the container.

By following these steps, you will be able to run your project in the *Docker* image ***Production*** efficiently and safely.

## 📑 Environment Variables

- **PHP_EXTENSIONS**: The *PHP* extensions to be installed. Default: null (e.g.: pdo_mysql mysqli)
- **INDEX_PATH**: The directory where the execution file of your project is located. Default: /var/www/html
- **MEMORY_LIMIT**: The memory limit that *PHP* can use. Default: 128M
- **UPLOAD_MAX**: The maximum size of files that can be uploaded. Default: 8M
- **SUPERVISOR_CONF**: The path of the *Supervisor* configuration file. Default: null (e.g.: /var/www/html/supervisor.conf)

## ▶️ Usage Examples

### - Using the command line:
```
docker run -d -p 80:80 -v /path/to/your/project:/var/www/html -v /path/to/your/supervisor/conf:/etc/supervisor/conf -e PHP_EXTENSIONS="pdo_mysql mysqli" -e MEMORY_LIMIT=256M -e UPLOAD_MAX=16M -e INDEX_PATH=/var/www/html/public production
```
### - Using *Docker Compose*:
```
services:
  web:
    image: production
    ports:
      - "80:80"
    volumes:
      - ./path/to/your/project:/var/www/html
      - ./path/to/your/supervisor/conf:/etc/supervisor/conf
    environment:
      - PHP_EXTENSIONS=pdo_mysql mysqli
      - MEMORY_LIMIT=256M
      - UPLOAD_MAX=16M
      - INDEX_PATH=/var/www/html/public
```

## 📝 Issues and Suggestions

&nbsp;&nbsp;&nbsp;&nbsp;If you find any issues related to the image or have suggestions for improvements, do not hesitate to open an
[issue](https://github.com/joaopinto14/Production/issues/new/choose) on *GitHub*. Please provide as many
details as possible to assist in resolving the issue or implementing your suggestion.

## 🪧 Extra

&nbsp;&nbsp;&nbsp;&nbsp;If you need a *Docker* image for tasks such as environment setup, dependency installation, code 
compilation, or test execution, it is recommended to use a dedicated development image, use the image 
"[Development](https://github.com/joaopinto14/Development)". This was specifically designed to facilitate and optimize these tasks.

## 👥 Contributors

- [João Pinto](https://github.com/joaopinto14) (Developer)

## 🧾️ License

&nbsp;&nbsp;&nbsp;&nbsp;This project is licensed under the *MIT* license - see the [LICENSE.md](LICENSE.md) file for more details.