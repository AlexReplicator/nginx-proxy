# 🚀 NGINX Proxy Manager

Автоматизированный reverse proxy для управления множеством сервисов на одном сервере.

![Nginx Proxy Banner](https://img.shields.io/badge/NGINX-PROXY-blue?style=for-the-badge&logo=nginx&logoColor=white)
![Docker Powered](https://img.shields.io/badge/DOCKER-POWERED-2496ed?style=for-the-badge&logo=docker&logoColor=white)

## 📋 Содержание

- [Обзор](#-обзор)
- [Установка](#-установка)
- [Конфигурация](#-конфигурация)
- [Деплой прокси-сервера](#-деплой-прокси-сервера)
- [Добавление новых проектов](#-добавление-новых-проектов)
- [Примеры конфигураций](#-примеры-конфигураций)
- [Вопросы и устранение неполадок](#-вопросы-и-устранение-неполадок)

## 🔍 Обзор

Этот проект предоставляет легко настраиваемый NGINX reverse proxy для маршрутизации трафика между различными веб-сервисами, запущенными в Docker-контейнерах на одном сервере. Ключевые возможности:

- 🌐 Автоматическое перенаправление HTTP-запросов на соответствующие сервисы по доменному имени
- 🔄 Динамическая генерация конфигураций NGINX при запуске
- 🐳 Полная интеграция с Docker и Docker Compose
- 🔧 Простая настройка через переменные окружения
- 📊 Простой мониторинг журналов событий
- 🚢 Автоматический CI/CD через GitHub Actions

## 💾 Установка

### Предварительные требования

- Linux-сервер с доступом к интернету
- Docker и Docker Compose
- Зарегистрированные доменные имена, указывающие на ваш сервер

### Способ 1: Клонирование репозитория на сервер

```bash
git clone https://github.com/AlexReplicator/nginx-proxy.git
cd nginx-proxy
```

### Способ 2: Настройка через GitHub Actions

1. Форкните репозиторий на GitHub
2. Настройте следующие секреты в настройках репозитория (Settings → Secrets and variables → Actions):
   - `DOMAINS` - список доменов и портов (например: `replinet.ru:80,project.replinet.ru:8082`)
   - `SERVER_IP` - IP-адрес вашего сервера
   - `SERVER_USER` - пользователь SSH на сервере (например, `root`)
   - `SSH_PRIVATE_KEY` - приватный SSH-ключ для доступа к серверу
   - `NOTIFY_EMAIL` - email для уведомлений (опционально)

3. Запустите workflow "Deploy" вручную или сделайте push в ветку `main`

## ⚙️ Конфигурация

### Локальная конфигурация

Создайте файл `.env` в корневой директории проекта:

```bash
cp .env.example .env
nano .env
```

Необходимые параметры:

```bash
# Список доменов и портов для проксирования в формате домен:порт
# Например: site1.com:3000,site2.com:8080
DOMAINS=example.com:3000,app.example.com:8080

# IP-адрес сервера (используется для шаблонов и логирования)
SERVER_IP=123.45.67.89

# Email для уведомлений
NOTIFY_EMAIL=your-email@example.com

# Имя проекта для Docker Compose (префикс для контейнеров и сетей)
COMPOSE_PROJECT_NAME=nginx-proxy
```

### Конфигурация через GitHub Actions

Формат секретов:

- **DOMAINS**: строка с перечислением пар "домен:порт" через запятую или JSON строка
  ```
  replinet.ru:80,project.replinet.ru:8082
  ```
  или
  ```json
  {"replinet.ru":80,"project.replinet.ru":8082}
  ```

- **SERVER_IP**: IP-адрес вашего сервера (например, `45.130.215.114`)
- **SERVER_USER**: пользователь SSH на сервере (например, `root`)
- **SSH_PRIVATE_KEY**: содержимое приватного SSH-ключа 
- **NOTIFY_EMAIL**: email для уведомлений (опционально)

## 🚀 Деплой прокси-сервера

### Автоматический деплой

Запустите скрипт деплоя, который автоматически настроит всё необходимое:

```bash
./scripts/deploy.sh
```

Этот скрипт:
1. Проверит наличие Docker и Docker Compose (установит их при необходимости)
2. Остановит и удалит существующие контейнеры
3. Сгенерирует конфигурации NGINX на основе переменных окружения
4. Запустит новые контейнеры

### Ручной деплой

Если вы предпочитаете ручное управление:

```bash
# Остановка существующих контейнеров
docker-compose down

# Запуск новых контейнеров
docker-compose up -d
```

### Деплой через GitHub Actions

После настройки секретов в GitHub:

1. Перейдите на вкладку "Actions" вашего репозитория
2. Выберите workflow "Deploy"
3. Нажмите "Run workflow"

## 🔌 Добавление новых проектов

### Способ 1: Через переменную DOMAINS

Самый простой способ добавить новый проект - обновить переменную `DOMAINS` в файле `.env` или в GitHub Secrets:

1. Добавьте новый домен и порт в формате `домен:порт`
2. Перезапустите прокси-сервер командой `./scripts/deploy.sh` или запустите GitHub Action

Пример:
```
DOMAINS=example.com:3000,app.example.com:8080,new-service.example.com:5000
```

### Способ 2: Интеграция с существующими Docker Compose проектами

Чтобы интегрировать ваш проект с NGINX Proxy:

1. Убедитесь, что ваш проект находится в одной сети с NGINX Proxy

```yaml
# docker-compose.yml вашего проекта
version: '3'
services:
  your-service:
    image: your-service-image
    ports:
      - "3000:3000"  # Экспортируйте порт только в сеть, не наружу
    networks:
      - default
      - nginx-proxy_network  # Подключитесь к сети NGINX Proxy

networks:
  nginx-proxy_network:
    external: true
```

2. Запустите ваш проект:

```bash
docker-compose up -d
```

3. Добавьте домен в `.env` файл NGINX Proxy или в GitHub Secrets:

```
DOMAINS=example.com:3000,app.example.com:8080,your-service.example.com:3000
```

4. Перезапустите NGINX Proxy:

```bash
cd /path/to/nginx-proxy
./scripts/deploy.sh
```

### Способ 3: Создание нового Docker-проекта

Вот шаблон для создания нового проекта, который будет работать с NGINX Proxy:

1. Создайте новую директорию для вашего проекта:

```bash
mkdir ~/projects/my-new-service
cd ~/projects/my-new-service
```

2. Создайте `docker-compose.yml`:

```yaml
version: '3'

services:
  app:
    image: node:16-alpine  # Замените на нужный образ
    working_dir: /app
    volumes:
      - ./app:/app
    command: npm start
    environment:
      - NODE_ENV=production
    networks:
      - default
      - nginx-proxy_network

networks:
  nginx-proxy_network:
    external: true
```

3. Создайте `.env` файл:

```
SERVICE_PORT=3000
```

4. Добавьте ваш сервис в NGINX Proxy:

```bash
# Добавить новый домен в DOMAINS в .env файле NGINX Proxy
cd ~/projects/nginx-proxy
echo "Текущие домены: $(grep DOMAINS .env)"
nano .env  # Обновите переменную DOMAINS
./scripts/deploy.sh
```

## 📝 Примеры конфигураций

### Пример 1: Простой Node.js сервис

```yaml
# docker-compose.yml
version: '3'

services:
  node-app:
    image: node:16-alpine
    working_dir: /app
    volumes:
      - ./app:/app
    command: npm start
    environment:
      - PORT=3000
    networks:
      - default
      - nginx-proxy_network

networks:
  nginx-proxy_network:
    external: true
```

В NGINX Proxy `.env`:
```
DOMAINS=node-app.example.com:3000
```

### Пример 2: WordPress с базой данных

```yaml
# docker-compose.yml
version: '3'

services:
  wordpress:
    image: wordpress:latest
    volumes:
      - ./wp-content:/var/www/html/wp-content
    environment:
      - WORDPRESS_DB_HOST=db
      - WORDPRESS_DB_NAME=wordpress
      - WORDPRESS_DB_USER=wp_user
      - WORDPRESS_DB_PASSWORD=secure_password
    networks:
      - default
      - nginx-proxy_network
    depends_on:
      - db

  db:
    image: mysql:5.7
    volumes:
      - db_data:/var/lib/mysql
    environment:
      - MYSQL_DATABASE=wordpress
      - MYSQL_USER=wp_user
      - MYSQL_PASSWORD=secure_password
      - MYSQL_ROOT_PASSWORD=very_secure_root_password
    networks:
      - default

volumes:
  db_data:

networks:
  nginx-proxy_network:
    external: true
```

В NGINX Proxy `.env`:
```
DOMAINS=blog.example.com:80
```

### Пример 3: API на Python Flask

```yaml
# docker-compose.yml
version: '3'

services:
  flask-api:
    build: .
    volumes:
      - ./app:/app
    environment:
      - FLASK_ENV=production
      - FLASK_APP=app.py
    networks:
      - default
      - nginx-proxy_network

networks:
  nginx-proxy_network:
    external: true
```

Пример `Dockerfile`:
```dockerfile
FROM python:3.9-alpine
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY app/ .
CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]
```

В NGINX Proxy `.env`:
```
DOMAINS=api.example.com:5000
```

## ❓ Вопросы и устранение неполадок

### Как проверить, что NGINX Proxy работает?

```bash
# Проверка статуса контейнеров
docker-compose ps

# Просмотр логов
docker-compose logs -f nginx
```

### Проблема с соединением к сервису

1. Убедитесь, что домен правильно указывает на IP вашего сервера:
   ```bash
   ping your-domain.com
   ```

2. Проверьте, что порт вашего сервиса указан правильно в переменной DOMAINS.

3. Убедитесь, что ваш сервис и NGINX Proxy находятся в одной сети:
   ```bash
   docker network inspect nginx-proxy_network
   ```

4. Проверьте, что ваш сервис запущен и слушает нужный порт:
   ```bash
   docker ps
   docker logs имя_контейнера
   ```

### 502 Bad Gateway

Если вы видите ошибку 502 Bad Gateway, это означает, что NGINX не может соединиться с вашим сервисом. Проверьте:

1. Запущен ли ваш сервис: `docker ps`
2. Доступен ли сервис из контейнера NGINX:
   ```bash
   docker exec -it nginx-proxy_nginx ping имя_сервиса
   docker exec -it nginx-proxy_nginx curl http://имя_сервиса:порт
   ```
3. Правильно ли указан порт в переменной DOMAINS

### DNS не работает

Если у вас возникают проблемы с разрешением DNS имен внутри контейнеров:

```bash
# Добавьте в docker-compose.yml для вашего сервиса
dns:
  - 8.8.8.8
  - 8.8.4.4
```

## 🔄 Обновление

Чтобы обновить NGINX Proxy:

```bash
cd ~/projects/nginx-proxy
git pull
./scripts/deploy.sh
```

Если вы используете GitHub Actions:

1. Pull последние изменения из основного репозитория
2. Push в свой форк
3. GitHub Action автоматически обновит сервер

---
