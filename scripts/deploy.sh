#!/bin/bash
set -e

# Скрипт для деплоя на удаленный сервер
echo "Starting deployment..."

# Функция для безопасного выполнения sudo команд
safe_sudo() {
    if command -v sudo &> /dev/null; then
        sudo "$@"
    else
        # Если sudo нет, пытаемся выполнить без него (если у пользователя достаточно прав)
        "$@"
    fi
}

# Проверка и установка Docker при необходимости
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    echo "Docker installed successfully"
fi

# Проверка и установка Docker Compose при необходимости
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose not found. Installing Docker Compose..."
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    
    # Создаем директорию для бинарных файлов пользователя, если её нет
    mkdir -p ~/.local/bin
    
    # Пытаемся установить глобально или в пользовательскую директорию
    if [ -w /usr/local/bin ]; then
        curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    else
        echo "No write permission to /usr/local/bin, installing to ~/.local/bin"
        curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o ~/.local/bin/docker-compose
        chmod +x ~/.local/bin/docker-compose
        export PATH="$HOME/.local/bin:$PATH"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
    
    echo "Docker Compose installed successfully"
    
    # Проверяем, что Docker Compose теперь доступен
    if ! command -v docker-compose &> /dev/null; then
        echo "ERROR: Docker Compose not available in PATH after installation. Please install manually."
        exit 1
    fi
fi

# Создаем директории для сертификатов
mkdir -p certbot/conf
mkdir -p certbot/www

# Остановка и удаление существующих контейнеров (если есть)
echo "Stopping and removing existing containers..."
docker-compose down -v || true
docker rm -f $(docker ps -aq -f name="${COMPOSE_PROJECT_NAME:-nginx-proxy}") 2>/dev/null || true

# Проверяем, включен ли SSL
if [ "${ENABLE_SSL}" = "true" ]; then
    echo "SSL is enabled, setting up Certbot..."
    
    # Парсим домены для получения сертификатов
    DOMAINS_ARR=()
    
    # Попытка парсить как JSON
    if [[ "${DOMAINS}" == {* ]]; then
        # Извлекаем ключи из JSON
        DOMAINS_KEYS=$(echo "${DOMAINS}" | python3 -c "import sys, json; print(','.join(json.load(sys.stdin).keys()))")
        IFS=',' read -ra DOMAINS_ARR <<< "${DOMAINS_KEYS}"
    else
        # Парсим как список пар домен:порт
        IFS=',' read -ra DOMAIN_PAIRS <<< "${DOMAINS}"
        for pair in "${DOMAIN_PAIRS[@]}"; do
            domain=$(echo "${pair}" | cut -d':' -f1)
            DOMAINS_ARR+=("${domain}")
        done
    fi
    
    # Формируем параметры для Certbot
    CERTBOT_DOMAINS=""
    for domain in "${DOMAINS_ARR[@]}"; do
        CERTBOT_DOMAINS="${CERTBOT_DOMAINS} -d ${domain}"
    done
    
    # Запускаем сервисы (nginx с профилем ssl только при включенном SSL)
    echo "Starting Nginx for SSL certificate acquisition..."
    docker-compose up -d nginx
    
    # Создаем сертификаты для каждого домена
    for domain in "${DOMAINS_ARR[@]}"; do
        echo "Requesting SSL certificate for ${domain}..."
        
        # Проверяем, существует ли уже сертификат
        if [ -d "certbot/conf/live/${domain}" ]; then
            echo "Certificate for ${domain} already exists, skipping"
            continue
        fi
        
        # Запрашиваем сертификат
        docker-compose run --rm certbot certonly --webroot \
            --webroot-path=/var/www/certbot \
            --email "${EMAIL_FOR_SSL}" \
            --agree-tos --no-eff-email \
            -d "${domain}"
            
        echo "Certificate for ${domain} obtained successfully"
    done
    
    # Перезапускаем Nginx для применения сертификатов
    echo "Restarting Nginx to apply SSL certificates..."
    docker-compose restart nginx
    
    # Запускаем сервис Certbot для автоматического обновления сертификатов
    echo "Starting Certbot for automatic certificate renewal..."
    docker-compose --profile ssl up -d certbot
    
else
    echo "SSL is disabled, using HTTP only"
    echo "Starting Nginx..."
    docker-compose up -d nginx
fi

echo "Deployment completed successfully" 