#!/bin/bash
set -e

echo "======== НАЧАЛО ПРОЦЕССА ПОЛУЧЕНИЯ SSL-СЕРТИФИКАТОВ ========"

if [ -z "$DOMAINS" ]; then
    echo "ОШИБКА: Переменная DOMAINS не установлена."
    echo "Укажите домены в формате: domain1.com,domain2.com"
    echo "Пример запуска: DOMAINS='replinet.ru,infinity.replinet.ru' EMAIL_FOR_SSL='your@email.com' ./scripts/setup-ssl.sh"
    exit 1
fi

if [ -z "$EMAIL_FOR_SSL" ]; then
    echo "ВНИМАНИЕ: EMAIL_FOR_SSL не установлен, используем значение по умолчанию."
    export EMAIL_FOR_SSL="example@example.com"
fi

# Получаем список доменов
echo "Извлечение доменов из переменной DOMAINS: $DOMAINS"
DOMAINS_LIST=$(echo "$DOMAINS" | tr ',' '\n' | sed 's/:.*//g')
echo "Обнаружены домены: $DOMAINS_LIST"

# Полная очистка директорий certbot
echo "Очистка директорий certbot..."
rm -rf certbot/conf/live certbot/conf/archive certbot/conf/renewal 2>/dev/null || true

# Создаем директории заново
mkdir -p certbot/conf
mkdir -p certbot/www/.well-known/acme-challenge
chmod -R 755 certbot/conf
chmod -R 755 certbot/www

# Останавливаем всё для чистого запуска
echo "Остановка всех контейнеров..."
docker-compose down || true

# Запускаем только Nginx для валидации
echo "Запуск Nginx для проверок Let's Encrypt..."
docker-compose up -d nginx

# Ждем запуска Nginx
echo "Ожидаем 10 секунд для полного запуска Nginx..."
sleep 10

# Проверяем, запущен ли Nginx
if ! docker ps | grep -q nginx-proxy_nginx; then
    echo "ОШИБКА: Nginx не запустился. Проверьте логи:"
    docker-compose logs nginx
    exit 1
else
    echo "Nginx успешно запущен и готов обрабатывать запросы Let's Encrypt."
fi

# Выводим команду для ручной проверки доступности
echo "Вы можете проверить доступность вебсервера по доменам:"
for domain in $DOMAINS_LIST; do
    echo "curl -v http://$domain/.well-known/acme-challenge/test"
done
echo "Если curl не возвращает ошибку, значит сервер доступен из интернета."
echo "Нажмите ENTER для продолжения или Ctrl+C для отмены"
read -r

# Получаем сертификаты для каждого домена отдельно, с дополнительными опциями отладки
SSL_SUCCESS=false

for domain in $DOMAINS_LIST; do
    echo "=========================================="
    echo "Попытка получения сертификата для домена: $domain"
    echo "=========================================="
    
    # Создаем тестовый файл для проверки доступности webroot
    mkdir -p certbot/www/.well-known/acme-challenge
    echo "Testing acme-challenge directory" > certbot/www/.well-known/acme-challenge/test
    chmod -R 755 certbot/www
    
    echo "Тестовый файл создан, выполните команду для проверки:"
    echo "curl http://$domain/.well-known/acme-challenge/test"
    echo "Если вы видите текст 'Testing acme-challenge directory', значит путь настроен верно."
    echo "Нажмите ENTER для продолжения или Ctrl+C для отмены"
    read -r
    
    # Принудительная выдача нового сертификата с явным указанием путей
    docker-compose run --rm certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$EMAIL_FOR_SSL" \
        --agree-tos \
        --no-eff-email \
        -d "$domain" \
        --force-renewal \
        --staging \
        --debug \
        --break-my-certs \
        --verbose
    
    echo "Результат запроса для тестового сертификата (staging):"
    docker-compose logs certbot
    
    echo "Если тестовый сертификат получен успешно, запрашиваем реальный сертификат."
    echo "Нажмите ENTER для продолжения или Ctrl+C для отмены"
    read -r
    
    # Запрашиваем реальный сертификат
    docker-compose run --rm certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$EMAIL_FOR_SSL" \
        --agree-tos \
        --no-eff-email \
        -d "$domain" \
        --force-renewal
    
    # Проверка результата
    CERT_EXIT_CODE=$?
    if [ $CERT_EXIT_CODE -ne 0 ]; then
        echo "ПРЕДУПРЕЖДЕНИЕ: Не удалось получить сертификат для домена $domain (код: $CERT_EXIT_CODE)"
        echo "Логи certbot:"
        docker-compose logs certbot
        
        echo "Проверьте следующее:"
        echo "1. DNS-настройки - домен должен указывать на IP-адрес сервера"
        echo "2. Доступность порта 80 - он должен быть открыт и доступен из интернета"
        echo "3. Правильность домена - он должен быть зарегистрирован и валиден"
    else
        echo "Сертификат для домена $domain успешно получен!"
        if [ -d "certbot/conf/live/$domain" ]; then
            echo "Сертификат найден в директории certbot/conf/live/$domain:"
            ls -la "certbot/conf/live/$domain"
            SSL_SUCCESS=true
        else
            echo "ОШИБКА: Сертификат не найден в ожидаемой директории."
            # Проверяем все возможные места сертификатов
            find certbot/conf -type f -name "*.pem" | sort
        fi
    fi
    
    echo "Нажмите ENTER для продолжения с следующим доменом или Ctrl+C для отмены"
    read -r
done

# Останавливаем Nginx перед перезапуском всех сервисов
echo "Остановка временного Nginx..."
docker-compose down

if [ "$SSL_SUCCESS" == "true" ]; then
    echo "Как минимум один сертификат успешно получен."
    echo "Теперь вы можете запустить сервис с SSL, выполнив:"
    echo "ENABLE_SSL=true docker-compose --profile ssl up -d"
else
    echo "ОШИБКА: Не удалось получить ни один SSL-сертификат."
    echo "Запустите сервис без SSL, выполнив:"
    echo "docker-compose up -d"
fi

echo "======== ПРОЦЕСС ПОЛУЧЕНИЯ SSL-СЕРТИФИКАТОВ ЗАВЕРШЕН ========" 