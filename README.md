# 🚀 NGINX Proxy Manager

<div align="center">

<img src="https://img.shields.io/badge/NGINX-PROXY-009639?style=for-the-badge&logo=nginx&logoColor=white" alt="Nginx Proxy Banner"/>
<img src="https://img.shields.io/badge/DOCKER-POWERED-2496ed?style=for-the-badge&logo=docker&logoColor=white" alt="Docker Powered"/>
<img src="https://img.shields.io/badge/SSL-LET'S_ENCRYPT-003A70?style=for-the-badge&logo=letsencrypt&logoColor=white" alt="SSL Let's Encrypt"/>
<img src="https://img.shields.io/badge/CI/CD-GITHUB_ACTIONS-2088FF?style=for-the-badge&logo=github-actions&logoColor=white" alt="GitHub Actions"/>

**Автоматизированный reverse proxy для управления множеством сервисов на одном сервере.**

</div>

## 📋 Содержание

- [📝 Обзор](#-обзор)
- [✨ Возможности](#-возможности)
- [🛠️ Установка](#️-установка)
- [⚙️ Настройка секретов GitHub](#️-настройка-секретов-github)
- [🚀 Деплой](#-деплой)
- [🔐 SSL-сертификаты](#-ssl-сертификаты)
- [🔌 Добавление новых сервисов](#-добавление-новых-сервисов)
- [📊 Мониторинг и отладка](#-мониторинг-и-отладка)
- [🔄 Обновление](#-обновление)
- [❓ Устранение неполадок](#-устранение-неполадок)

## 📝 Обзор

**NGINX Proxy Manager** — это инструмент для автоматизации управления обратным прокси-сервером на базе NGINX. Он позволяет настроить несколько веб-сервисов на одном сервере, доступных через разные доменные имена, с автоматическим управлением SSL-сертификатами.

## ✨ Возможности

- 🌐 **Множество доменов на одном сервере** — маршрутизация запросов к нужным сервисам по доменному имени
- 🔐 **Автоматические SSL-сертификаты** — бесплатные SSL от Let's Encrypt с автообновлением
- 🔄 **Динамическая конфигурация** — NGINX-конфиги генерируются автоматически при запуске
- 🐳 **Docker-центричный подход** — полная интеграция с Docker и Docker Compose
- 🚢 **CI/CD интеграция** — автоматический деплой через GitHub Actions
- 🔧 **Простая настройка** — минимальная конфигурация через переменные окружения
- 📊 **Мониторинг** — логирование, статус сервисов и диагностика

## 🛠️ Установка

### Предварительные требования

- Linux-сервер с публичным IP-адресом
- Доменные имена, настроенные на IP вашего сервера
- Git, Docker и Docker Compose (или будут установлены автоматически)
- SSH-доступ к серверу (для CI/CD)

### Способ 1: Клонирование репозитория на сервер

```bash
# Клонирование репозитория
git clone https://github.com/yourusername/nginx-proxy.git
cd nginx-proxy

# Создание конфигурации
cp .env.example .env
nano .env  # Отредактируйте параметры

# Запуск
./scripts/deploy.sh
```

### Способ 2: Настройка через GitHub Actions (рекомендуется)

1. Форкните этот репозиторий в свой GitHub-аккаунт
2. Настройте [секреты в GitHub](#️-настройка-секретов-github)
3. Запустите workflow "Deploy" через вкладку Actions или выполните push в ветку `main`

## ⚙️ Настройка секретов GitHub

Для работы GitHub Actions требуется настроить следующие секреты в вашем репозитории:

1. Перейдите в **Settings → Secrets and variables → Actions**
2. Добавьте следующие секреты:

| Секрет | Описание | Пример |
|--------|----------|--------|
| `DOMAINS` | Список доменов и портов | `example.com:80,api.example.com:3000,admin.example.com:8080` |
| `SERVER_IP` | IP-адрес вашего сервера | `123.45.67.89` |
| `SERVER_USER` | Пользователь SSH | `root` или `ubuntu` |
| `SSH_PRIVATE_KEY` | Приватный SSH-ключ | Содержимое файла `id_rsa` |
| `ENABLE_SSL` | Включить SSL (true/false) | `true` |
| `EMAIL_FOR_SSL` | Email для Let's Encrypt | `your-email@example.com` |
| `NOTIFY_EMAIL` | Email для уведомлений | `your-email@example.com` |

### Формат переменной DOMAINS

Переменная `DOMAINS` содержит список доменов и портов в формате `домен:порт` через запятую:

```
example.com:80,api.example.com:3000,admin.example.com:8080
```

Где:
- `example.com` — домен для проксирования
- `80` — внутренний порт сервиса (куда будут перенаправляться запросы)

### Подготовка SSH-ключа для деплоя

1. Создайте SSH-ключ (если отсутствует):
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/nginx_proxy_deploy
   ```

2. Добавьте публичный ключ на сервер:
   ```bash
   ssh-copy-id -i ~/.ssh/nginx_proxy_deploy.pub user@123.45.67.89
   ```

3. Скопируйте приватный ключ и вставьте его в секрет `SSH_PRIVATE_KEY`:
   ```bash
   cat ~/.ssh/nginx_proxy_deploy
   ```

## 🚀 Деплой

### Автоматический деплой через GitHub Actions

1. Перейдите на вкладку **Actions** в своем GitHub-репозитории
2. Выберите workflow **Deploy Nginx Proxy**
3. Нажмите кнопку **Run workflow**
4. Выберите ветку `main`
5. Нажмите **Run workflow** еще раз для запуска

Процесс деплоя выполнит следующие шаги:
1. Подключение к серверу по SSH
2. Установка Docker и Docker Compose (если требуется)
3. Настройка и запуск NGINX Proxy
4. Получение SSL-сертификатов (если включено)

### Ручной деплой на сервере

```bash
cd ~/nginx-proxy

# Локальные изменения
nano .env  # Редактирование переменных

# Запуск деплоя
./scripts/deploy.sh
```

## 🔐 SSL-сертификаты

NGINX Proxy Manager автоматически получает и настраивает бесплатные SSL-сертификаты от Let's Encrypt для всех ваших доменов.

### Включение SSL

1. В GitHub секретах установите:
   - `ENABLE_SSL` = `true`
   - `EMAIL_FOR_SSL` = `your-email@example.com`

2. Убедитесь, что:
   - DNS-записи доменов указывают на ваш сервер
   - Порт 443 открыт на сервере
   - Email действителен (для уведомлений об истечении срока сертификатов)

### Как это работает

- При деплое автоматически запускается скрипт `get-certificates.sh`
- Проверяется каждый домен из списка `DOMAINS`
- Сертификаты сохраняются в Docker-томе и обновляются автоматически
- NGINX автоматически настраивается на использование HTTPS с полученными сертификатами

### Проверка SSL-сертификатов

```bash
# Проверка статуса сертификатов
docker exec nginx-proxy_nginx find /etc/letsencrypt/live -type d -name "*.*"

# Просмотр информации о сертификате
docker exec nginx-proxy_nginx openssl x509 -in /etc/letsencrypt/live/example.com/cert.pem -noout -text
```

## 🔌 Добавление новых сервисов

### Способ 1: Обновление списка доменов

1. Добавьте новый домен в GitHub-секрет `DOMAINS`:
   ```
   example.com:80,api.example.com:3000,new-service.example.com:5000
   ```

2. Запустите GitHub Actions workflow для применения изменений

### Способ 2: Интеграция существующего Docker-проекта

1. Добавьте сеть в `docker-compose.yml` вашего проекта:

```yaml
services:
  app:
    # ... существующая конфигурация
    networks:
      - default
      - nginx-proxy_network  # Добавьте эту строку

networks:
  nginx-proxy_network:
    external: true
```

2. Добавьте ваш домен в `DOMAINS` и перезапустите NGINX Proxy

### Пример: Настройка веб-приложения Node.js

`docker-compose.yml` для вашего Node.js приложения:
```yaml
version: '3'

services:
  nodejs:
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

Добавьте `nodejs.example.com:3000` в секрет `DOMAINS` и запустите деплой.

### Пример: WordPress с базой данных

```yaml
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

volumes:
  db_data:

networks:
  nginx-proxy_network:
    external: true
```

Добавьте `blog.example.com:80` в секрет `DOMAINS`.

## 📊 Мониторинг и отладка

### Проверка статуса

```bash
# Статус контейнеров
docker ps
docker-compose ps

# Проверка конфигурации Nginx
docker exec nginx-proxy_nginx nginx -t

# Просмотр лог-файлов
docker-compose logs -f nginx
```

### Диагностика проблем

```bash
# Проверка маршрутизации
docker exec nginx-proxy_nginx cat /etc/nginx/conf.d/example.com.conf

# Тестовый запрос внутри контейнера
docker exec nginx-proxy_nginx curl -I http://localhost/

# Проверка сетей Docker
docker network ls
docker network inspect nginx-proxy_network
```

## 🔄 Обновление

### Обновление через GitHub Actions

1. Обновите форк репозитория с исходным:
   ```bash
   git remote add upstream https://github.com/original-owner/nginx-proxy.git
   git fetch upstream
   git merge upstream/main
   git push origin main
   ```

2. GitHub Actions автоматически выполнит деплой обновлений

### Ручное обновление

```bash
cd ~/nginx-proxy
git pull
./scripts/deploy.sh
```

## ❓ Устранение неполадок

### Общие проблемы и решения

| Проблема | Возможные причины | Решение |
|----------|-------------------|---------|
| 502 Bad Gateway | Целевой сервис недоступен | Проверьте запущен ли сервис и порт в `DOMAINS` |
| Сертификаты не получены | Неправильно настроен DNS | Убедитесь, что домен указывает на IP сервера |
| Доступ только по HTTP | SSL не включен | Установите `ENABLE_SSL=true` и запустите деплой |
| Ошибка подключения | Порты не открыты | Проверьте файрвол сервера (порты 80, 443) |

### Проверка DNS-записей

```bash
# Проверка DNS записи домена
dig +short example.com
nslookup example.com

# Должно возвращать IP вашего сервера
```

### Сброс и чистая установка

В случае серьезных проблем можно выполнить полный сброс:

```bash
cd ~/nginx-proxy
docker-compose down -v
docker volume prune -f
./scripts/deploy.sh
```

---

<div align="center">
  <p>Сделано с ❤️ для самого удобного управления доменами и сервисами</p>
  <p>© 2024 GitHub User. <a href="https://github.com/yourusername/nginx-proxy">GitHub Репозиторий</a></p>
</div>