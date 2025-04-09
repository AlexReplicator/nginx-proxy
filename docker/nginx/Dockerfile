FROM nginx:1.25.3-alpine

# Установка необходимых зависимостей, включая certbot для SSL
RUN apk add --no-cache python3 bash curl openssl certbot

# Создание директорий для конфигураций
RUN mkdir -p /etc/nginx/conf.d/templates
RUN mkdir -p /var/www/certbot

# Копирование стандартной конфигурации Nginx
COPY nginx.conf /etc/nginx/nginx.conf
COPY templates/ /etc/nginx/conf.d/templates/

# Копирование скриптов
COPY entrypoint.sh /entrypoint.sh
COPY generate-configs.py /generate-configs.py

RUN chmod +x /entrypoint.sh \
    && chmod +x /generate-configs.py

# Рабочая директория
WORKDIR /etc/nginx

# Открываем порты
EXPOSE 80 443

# Запуск Nginx с нашим entrypoint скриптом
ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"] 