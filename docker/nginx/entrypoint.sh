#!/bin/bash
set -e

# Создание необходимых директорий
echo "Creating required directories..."
mkdir -p /var/www/certbot
chown -R nginx:nginx /var/www/certbot
chmod -R 755 /var/www/certbot

# Функция для генерации конфигурации Nginx
generate_nginx_configs() {
    echo "Generating Nginx configurations..."
    python3 /generate-configs.py
    echo "Nginx configurations generated successfully."
}

# Перезагрузка Nginx
reload_nginx() {
    echo "Reloading Nginx configuration..."
    nginx -s reload
    echo "Nginx configuration reloaded successfully."
}

# Генерируем конфигурацию при старте
generate_nginx_configs

# Запускаем Nginx на переднем плане
echo "Starting Nginx..."
exec "$@" 