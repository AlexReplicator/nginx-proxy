#!/bin/bash
set -e

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