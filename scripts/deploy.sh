#!/bin/bash
set -e

# Скрипт для деплоя на удаленный сервер
echo "Starting deployment..."

# Создаем директории для сертификатов
mkdir -p certbot/conf
mkdir -p certbot/www

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
    docker-compose restart nginx
    
    # Запускаем сервис Certbot для автоматического обновления сертификатов
    docker-compose --profile ssl up -d certbot
    
else
    echo "SSL is disabled, using HTTP only"
    docker-compose up -d nginx
fi

echo "Deployment completed successfully" 