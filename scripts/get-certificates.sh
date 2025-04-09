#!/bin/bash
set -e

echo "======== СТАРТ ПРОЦЕССА ПОЛУЧЕНИЯ SSL-СЕРТИФИКАТОВ ========"

# Проверяем включен ли SSL
if [ "${ENABLE_SSL}" != "true" ]; then
    echo "SSL отключен (ENABLE_SSL != true). Пропускаем получение сертификатов."
    exit 0
fi

# Проверяем наличие email для Let's Encrypt
if [ -z "${EMAIL_FOR_SSL}" ]; then
    echo "ОШИБКА: Не указан email для Let's Encrypt (EMAIL_FOR_SSL)."
    echo "Пожалуйста, добавьте его в .env или GitHub Secrets."
    exit 1
fi

# Проверяем наличие списка доменов
if [ -z "${DOMAINS}" ]; then
    echo "ОШИБКА: Не указан список доменов (DOMAINS)."
    echo "Пожалуйста, добавьте их в .env или GitHub Secrets."
    exit 1
fi

# Устанавливаем certbot если его нет
if ! [ -x "$(command -v certbot)" ]; then
    echo "Установка Certbot..."
    apt-get update
    apt-get install -y certbot
fi

# Создаем директорию для webroot (для проверки владения доменом)
mkdir -p /var/www/certbot
chmod -R 755 /var/www/certbot

# Получаем список доменов из переменной DOMAINS в формате: domain1.ru:8080,domain2.ru:8081
echo "Анализ списка доменов из переменной DOMAINS: ${DOMAINS}"
domain_list=$(echo "${DOMAINS}" | tr ',' '\n' | cut -d':' -f1 | sort -u)

# Проверяем получился ли список доменов
if [ -z "${domain_list}" ]; then
    echo "ОШИБКА: Не удалось получить список доменов из переменной DOMAINS."
    echo "Формат должен быть: domain1.ru:8080,domain2.ru:8081"
    exit 1
fi

echo "Получены следующие домены для сертификатов:"
echo "${domain_list}" | sed 's/^/- /'

# Получаем сертификаты для каждого домена
for domain in ${domain_list}; do
    # Очищаем домен от возможных кавычек и пробелов
    domain=$(echo "${domain}" | tr -d '"' | tr -d "'" | xargs)
    
    # Проверяем что домен не пустой и похож на домен (содержит точку)
    if [ -n "${domain}" ] && [[ "${domain}" == *.* ]]; then
        echo "Обработка домена: ${domain}"
        
        # Проверяем, существует ли уже сертификат и не истек ли он
        if [ -d "/etc/letsencrypt/live/${domain}" ]; then
            echo "Сертификат для ${domain} уже существует."
            
            # Проверяем валидность сертификата, если возможно
            if [ -f "/etc/letsencrypt/live/${domain}/cert.pem" ]; then
                cert_file="/etc/letsencrypt/live/${domain}/cert.pem"
                exp_date=$(openssl x509 -in "${cert_file}" -noout -enddate 2>/dev/null | cut -d= -f2)
                
                if [ -n "${exp_date}" ]; then
                    exp_epoch=$(date -d "${exp_date}" +%s 2>/dev/null)
                    now_epoch=$(date +%s)
                    
                    if [ -n "${exp_epoch}" ] && [ -n "${now_epoch}" ]; then
                        days_left=$(( (exp_epoch - now_epoch) / 86400 ))
                        echo "Сертификат действителен ещё ${days_left} дней."
                        
                        if [ "${days_left}" -gt 30 ]; then
                            echo "Сертификат ещё действителен (осталось более 30 дней). Пропускаем."
                            continue
                        else
                            echo "Срок действия сертификата менее 30 дней. Обновляем."
                        fi
                    fi
                fi
            fi
        else
            echo "Сертификат для ${domain} не существует. Получаем новый."
        fi
        
        # Получаем сертификат через Certbot
        echo "Запуск Certbot для домена ${domain}..."
        certbot certonly --webroot \
            --webroot-path=/var/www/certbot \
            --email "${EMAIL_FOR_SSL}" \
            --agree-tos \
            --no-eff-email \
            -d "${domain}" \
            --keep-until-expiring \
            --non-interactive || {
                echo "ПРЕДУПРЕЖДЕНИЕ: Не удалось получить сертификат для ${domain}."
                echo "Пожалуйста, проверьте, что домен указывает на IP этого сервера."
            }
    else
        echo "Пропускаем некорректный домен: ${domain}"
    fi
done

# Проверяем полученные сертификаты
echo "Список полученных сертификатов:"
find /etc/letsencrypt/live -type d -name "*.*" | while read cert_dir; do
    domain=$(basename "${cert_dir}")
    if [ -f "${cert_dir}/fullchain.pem" ] && [ -f "${cert_dir}/privkey.pem" ]; then
        echo "✅ ${domain} - сертификат успешно получен"
    else
        echo "❌ ${domain} - проблема с сертификатом"
    fi
done

# Устанавливаем правильные права на сертификаты
chown -R root:root /etc/letsencrypt
chmod -R 755 /etc/letsencrypt

# Обновляем конфигурацию Nginx (если переменная ENABLE_SSL=true)
if [ -x "$(command -v python3)" ] && [ -f "/generate-configs.py" ]; then
    echo "Перегенерация конфигурации Nginx..."
    python3 /generate-configs.py
    
    # Перезапускаем Nginx, чтобы применить изменения
    echo "Перезапуск Nginx для применения сертификатов..."
    nginx -s reload || {
        echo "ПРЕДУПРЕЖДЕНИЕ: Не удалось перезапустить Nginx."
        echo "Пожалуйста, перезапустите его вручную командой: docker-compose restart nginx"
    }
else
    echo "ПРЕДУПРЕЖДЕНИЕ: Не удалось найти скрипт generate-configs.py."
    echo "Пожалуйста, перезапустите Nginx вручную командой: docker-compose restart nginx"
fi

echo "======== ПРОЦЕСС ПОЛУЧЕНИЯ SSL-СЕРТИФИКАТОВ ЗАВЕРШЕН ========" 