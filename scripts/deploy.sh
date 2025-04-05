#!/bin/bash
set -e

# Функция для выполнения sudo команд безопасно
safe_sudo() {
    if [ -x "$(command -v sudo)" ]; then
        sudo "$@"
    else
        "$@"
    fi
}

echo "======== НАЧАЛО ПРОЦЕССА ДЕПЛОЯ ========"

echo "1. Проверка наличия Docker..."
if ! [ -x "$(command -v docker)" ]; then
    echo "Docker не установлен. Устанавливаем..."
    
    # Установка зависимостей
    apt-get update -y || { echo "Ошибка при обновлении apt"; exit 1; }
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release || { echo "Ошибка при установке зависимостей"; exit 1; }
    
    # Добавление Docker GPG ключа
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | safe_sudo apt-key add - || { echo "Ошибка при добавлении GPG ключа"; exit 1; }
    
    # Добавление репозитория Docker
    safe_sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" || { 
        echo "Ошибка при добавлении репозитория. Пробуем альтернативный метод..."
        echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | safe_sudo tee /etc/apt/sources.list.d/docker.list || { echo "Ошибка при создании файла списка источников Docker"; exit 1; }
    }
    
    # Обновление и установка Docker
    safe_sudo apt-get update -y || { echo "Ошибка при обновлении apt после добавления репозитория Docker"; exit 1; }
    safe_sudo apt-get install -y docker-ce docker-ce-cli containerd.io || { echo "Ошибка при установке Docker"; exit 1; }
    
    # Проверка установки
    if ! [ -x "$(command -v docker)" ]; then
        echo "Не удалось установить Docker. Выход."
        exit 1
    else
        echo "Docker успешно установлен."
    fi
fi

echo "2. Проверка наличия Docker Compose..."
if ! [ -x "$(command -v docker-compose)" ]; then
    echo "Docker Compose не установлен. Устанавливаем..."
    
    # Установка Docker Compose
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    COMPOSE_VERSION=${COMPOSE_VERSION:-v2.21.0} # Fallback версия, если не удается получить последнюю
    
    # Установка через curl
    safe_sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || {
        echo "Ошибка при загрузке Docker Compose. Пробуем альтернативный способ..."
        safe_sudo mkdir -p /usr/local/bin
        safe_sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || { echo "Ошибка при установке Docker Compose"; exit 1; }
    }
    
    # Установка прав
    safe_sudo chmod +x /usr/local/bin/docker-compose || { echo "Ошибка при установке прав на Docker Compose"; exit 1; }
    
    # Создание символической ссылки, если необходимо
    if ! [ -x "$(command -v docker-compose)" ]; then
        echo "Создаем символическую ссылку для Docker Compose..."
        safe_sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose || { echo "Ошибка при создании символической ссылки"; exit 1; }
    fi
    
    # Проверка установки
    if ! [ -x "$(command -v docker-compose)" ]; then
        echo "Не удалось установить Docker Compose. Выход."
        exit 1
    else
        echo "Docker Compose успешно установлен."
    fi
fi

echo "3. Полная остановка и удаление контейнеров..."
# Остановка и удаление всех контейнеров проекта
docker-compose down -v || true
docker rm -f $(docker ps -aq -f name="${COMPOSE_PROJECT_NAME:-nginx-proxy}") 2>/dev/null || true

# Удаление неиспользуемых ресурсов
echo "4. Очистка неиспользуемых Docker ресурсов..."
docker system prune -f || true

echo "5. Полная очистка директории конфигураций Nginx..."
rm -rf docker/nginx/conf.d/*.conf 2>/dev/null || true

# Проверка наличия переменных окружения
echo "6. Проверка наличия переменных окружения..."
if [ -z "$DOMAINS" ]; then
    echo "ВНИМАНИЕ: Переменная DOMAINS не установлена. Проверьте файл .env."
    if [ -f ".env" ]; then
        echo "Содержимое файла .env:"
        cat .env
    else
        echo "Файл .env не найден!"
    fi
fi

if [ -z "$SERVER_IP" ]; then
    echo "ВНИМАНИЕ: Переменная SERVER_IP не установлена. Проверьте файл .env."
fi

# Создание директорий для сертификатов, если их нет
mkdir -p certbot/conf
mkdir -p certbot/www

echo "7. Проверка SSL-настроек..."
if [ "${ENABLE_SSL:-false}" == "true" ]; then
    echo "SSL включен, запускаем процесс настройки SSL..."
    
    # Получаем список доменов
    echo "Извлечение доменов из переменной DOMAINS: $DOMAINS"
    DOMAINS_LIST=$(echo "$DOMAINS" | tr ',' '\n' | sed 's/:.*//g')
    echo "Обнаружены домены: $DOMAINS_LIST"
    
    # Проверяем наличие email для SSL
    if [ -z "$EMAIL_FOR_SSL" ]; then
        echo "ВНИМАНИЕ: EMAIL_FOR_SSL не установлен, используем значение по умолчанию."
        export EMAIL_FOR_SSL="example@example.com"
    fi
    
    # Полностью удаляем директорию certbot/conf и пересоздаем
    echo "Удаление всех существующих сертификатов и конфигураций certbot..."
    rm -rf certbot/conf
    mkdir -p certbot/conf
    chmod -R 755 certbot/conf
    
    # Создаем директорию для проверки certbot
    mkdir -p certbot/www/.well-known
    chmod -R 755 certbot/www
    
    # Устанавливаем certbot из репозитория, если его нет
    if ! [ -x "$(command -v certbot)" ]; then
        echo "Certbot не установлен. Устанавливаем..."
        safe_sudo apt-get update -y
        safe_sudo apt-get install -y software-properties-common
        safe_sudo add-apt-repository -y ppa:certbot/certbot || {
            echo "Не удалось добавить репозиторий Certbot. Пробуем альтернативный метод..."
            safe_sudo apt-get install -y python3-certbot || {
                echo "Не удалось установить Certbot. Выход."
                exit 1
            }
        }
        safe_sudo apt-get update -y
        safe_sudo apt-get install -y certbot || {
            echo "Не удалось установить Certbot. Выход."
            exit 1
        }
    fi
    
    # Запускаем Nginx для обработки запросов certbot
    echo "Запуск Nginx для обработки проверок Let's Encrypt..."
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
    
    # Получаем сертификаты для каждого домена с помощью установленного certbot
    SSL_SUCCESS=false
    
    for domain in $DOMAINS_LIST; do
        echo "Попытка получения сертификата для домена: $domain"
        
        # Используем встроенный certbot вместо контейнера
        safe_sudo certbot certonly \
            --webroot \
            --webroot-path="$(pwd)/certbot/www" \
            --email "$EMAIL_FOR_SSL" \
            --agree-tos \
            --no-eff-email \
            --domain "$domain" \
            --non-interactive \
            --force-renewal \
            --debug-challenges
        
        CERT_EXIT_CODE=$?
        if [ $CERT_EXIT_CODE -ne 0 ]; then
            echo "ПРЕДУПРЕЖДЕНИЕ: Не удалось получить сертификат для домена $domain (код: $CERT_EXIT_CODE)"
            echo "Проверьте DNS-настройки и доступность домена из интернета."
        else
            echo "Сертификат для домена $domain успешно получен!"
            
            # Копируем сертификаты из системной директории certbot в проектную
            CERT_PATH="/etc/letsencrypt/live/$domain"
            if [ -d "$CERT_PATH" ]; then
                echo "Копирование сертификатов из $CERT_PATH в certbot/conf/live/$domain"
                mkdir -p "certbot/conf/live/$domain"
                safe_sudo cp -L "$CERT_PATH/privkey.pem" "certbot/conf/live/$domain/"
                safe_sudo cp -L "$CERT_PATH/fullchain.pem" "certbot/conf/live/$domain/"
                safe_sudo cp -L "$CERT_PATH/cert.pem" "certbot/conf/live/$domain/"
                safe_sudo cp -L "$CERT_PATH/chain.pem" "certbot/conf/live/$domain/"
                
                # Устанавливаем правильные права
                chmod 644 "certbot/conf/live/$domain/"*
                
                # Копируем также файлы обновления
                mkdir -p "certbot/conf/renewal"
                if [ -f "/etc/letsencrypt/renewal/$domain.conf" ]; then
                    safe_sudo cp "/etc/letsencrypt/renewal/$domain.conf" "certbot/conf/renewal/"
                fi
                
                # Помечаем, что хотя бы один сертификат получен успешно
                SSL_SUCCESS=true
                echo "Сертификаты скопированы успешно:"
                ls -la "certbot/conf/live/$domain"
            else
                echo "ОШИБКА: Сертификат получен, но директория $CERT_PATH не найдена!"
            fi
        fi
    done
    
    # Останавливаем Nginx перед перезапуском всех сервисов
    echo "Остановка временного Nginx..."
    docker-compose down
    
    if [ "$SSL_SUCCESS" == "true" ]; then
        echo "Как минимум один сертификат успешно получен. Запускаем с поддержкой SSL..."
        docker-compose --profile ssl up -d --build
    else
        echo "ОШИБКА: Не удалось получить ни один SSL-сертификат. Запускаем без SSL."
        docker-compose up -d --build
    fi
else
    echo "SSL выключен. Запускаем без SSL."
    docker-compose up -d --build
fi

echo "8. Проверка запущенных контейнеров..."
docker-compose ps

echo "9. Просмотр логов (последние 10 строк)..."
docker-compose logs --tail=10

echo "======== ПРОЦЕСС ДЕПЛОЯ ЗАВЕРШЕН ========" 