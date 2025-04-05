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
    echo "SSL включен, проверка наличия сертификатов..."
    
    # Получаем список доменов
    echo "Извлечение доменов из переменной DOMAINS: $DOMAINS"
    DOMAINS_LIST=$(echo "$DOMAINS" | tr ',' '\n' | sed 's/:.*//g')
    echo "Обнаружены домены: $DOMAINS_LIST"
    
    # Проверяем наличие сертификатов
    SSL_SUCCESS=false
    for domain in $DOMAINS_LIST; do
        if [ -d "certbot/conf/live/$domain" ]; then
            echo "Найден сертификат для домена $domain"
            SSL_SUCCESS=true
        else
            echo "ПРЕДУПРЕЖДЕНИЕ: Сертификат для домена $domain не найден."
        fi
    done
    
    if [ "$SSL_SUCCESS" == "true" ]; then
        echo "Обнаружены действительные сертификаты. Запускаем с поддержкой SSL..."
        docker-compose --profile ssl up -d --build
    else
        echo "ПРЕДУПРЕЖДЕНИЕ: Не найдены действительные SSL-сертификаты."
        echo "Запускаем без SSL. Для получения сертификатов выполните отдельно:"
        echo "DOMAINS='$DOMAINS' EMAIL_FOR_SSL='$EMAIL_FOR_SSL' ./scripts/setup-ssl.sh"
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