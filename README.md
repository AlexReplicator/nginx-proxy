# Nginx Reverse Proxy

Сервис для управления обратным прокси-сервером на основе Nginx с автоматическим SSL-сертификацией через Let's Encrypt.

## Возможности

- Автоматическая настройка обратного прокси для указанных доменов
- Автоматическое получение и обновление SSL-сертификатов через Let's Encrypt
- Поддержка множества доменов и портов
- Автоматический деплой через GitHub Actions
- Мониторинг и уведомления о проблемах
- Безопасная конфигурация SSL/TLS

## Требования

- Docker и Docker Compose
- Доступ к DNS-записям доменов
- Публичный IP-адрес
- GitHub аккаунт (для автоматического деплоя)

## Быстрый старт

1. Клонируйте репозиторий:
   ```bash
   git clone https://github.com/AlexReplicator/nginx-proxy.git
   cd nginx-proxy
   ```

2. Создайте файл `.env` на основе примера:
   ```bash
   cp .env.example .env
   ```

3. Настройте переменные окружения в `.env`:
   ```env
   # Формат: domain.com:port или {"domain.com":port}
   DOMAINS=example.com:80,api.example.com:8080

   # IP-адрес сервера
   SERVER_IP=your-server-ip

   # Включить SSL (true/false)
   ENABLE_SSL=true

   # Email для Let's Encrypt
   EMAIL_FOR_SSL=your-email@example.com

   # Email для уведомлений
   NOTIFY_EMAIL=your-email@example.com

   # Имя проекта для Docker
   COMPOSE_PROJECT_NAME=nginx-proxy
   ```

4. Запустите сервис:
   ```bash
   docker-compose up -d
   ```

## Настройка автоматического деплоя

### 1. Подготовка SSH-ключей

1. Сгенерируйте пару SSH-ключей для деплоя:
   ```bash
   ssh-keygen -t ed25519 -C "deploy@nginx-proxy" -f ~/.ssh/deploy_key -N ""
   ```

2. Добавьте публичный ключ на сервер:
   ```bash
   # На сервере
   echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKlA9yPshf8ZhMWA1l7VeYemRa9AeCY+49i+TR07JH+5 deploy@nginx-proxy" >> ~/.ssh/authorized_keys
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/authorized_keys
   ```

### 2. Настройка GitHub Secrets

В настройках репозитория (Settings -> Secrets and variables -> Actions) добавьте следующие секреты:

- `SSH_PRIVATE_KEY` - содержимое приватного ключа (включая BEGIN и END)
- `SERVER_USER` - имя пользователя на сервере
- `SERVER_IP` - IP-адрес сервера
- `DOMAINS` - домены для прокси
- `ENABLE_SSL` - true/false
- `EMAIL_FOR_SSL` - email для Let's Encrypt
- `NOTIFY_EMAIL` - email для уведомлений

### 3. Настройка DNS

1. Добавьте A-записи для ваших доменов, указывающие на IP-адрес сервера
2. Убедитесь, что порты 80 и 443 открыты на сервере
3. Если используете файрвол, разрешите входящие соединения:
   ```bash
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   ```

## Структура проекта

```
nginx-proxy/
├── docker/
│   └── nginx/
│       └── templates/
│           └── https.conf.template  # Шаблон конфигурации Nginx
├── scripts/
│   └── deploy.sh                   # Скрипт деплоя
├── .env.example                    # Пример переменных окружения
├── docker-compose.yml              # Конфигурация Docker Compose
└── README.md                       # Этот файл
```

## Мониторинг и логи

- Просмотр логов Nginx:
  ```bash
  docker-compose logs -f nginx
  ```

- Просмотр логов Certbot:
  ```bash
  docker-compose logs -f certbot
  ```

- Проверка статуса сервисов:
  ```bash
  docker-compose ps
  ```

## Безопасность

- Все SSL-сертификаты хранятся в защищенном volume
- Используются современные настройки SSL/TLS
- Регулярное обновление сертификатов
- Защита от основных веб-уязвимостей через заголовки безопасности

## Устранение неполадок

1. **Проблемы с SSL**:
   - Проверьте, что порты 80 и 443 открыты
   - Убедитесь, что DNS-записи правильно настроены
   - Проверьте логи certbot: `docker-compose logs certbot`

2. **Проблемы с прокси**:
   - Проверьте конфигурацию в `.env`
   - Проверьте логи nginx: `docker-compose logs nginx`
   - Убедитесь, что целевые сервисы доступны

3. **Проблемы с деплоем**:
   - Проверьте GitHub Actions логи
   - Убедитесь, что все секреты правильно настроены
   - Проверьте права доступа на сервере

## Лицензия

MIT
