#!/usr/bin/env python3
"""
Скрипт для автоматической генерации конфигурации Nginx
на основе переменных окружения.
"""

import os
import json
import sys
import re

def parse_domains():
    """
    Парсит переменную окружения DOMAINS и возвращает словарь
    с доменами и соответствующими портами.
    
    Формат DOMAINS: json строка или список пар "домен:порт"
    Пример: {"replinet.ru":80, "project.replinet.ru":8082} или
            replinet.ru:80,project.replinet.ru:8082
    
    Returns:
        dict: Словарь вида {домен: порт}
    """
    domains_env = os.environ.get('DOMAINS')
    if not domains_env:
        print("ERROR: DOMAINS environment variable is not set")
        sys.exit(1)
    
    server_ip = os.environ.get('SERVER_IP', '127.0.0.1')
    
    domains = {}
    
    # Пробуем парсить как JSON
    try:
        domains = json.loads(domains_env)
        print(f"Parsed domains as JSON: {domains}")
        return domains, server_ip
    except json.JSONDecodeError:
        # Если не JSON, то пробуем парсить как список
        try:
            for domain_port in domains_env.split(','):
                if ':' in domain_port:
                    domain, port = domain_port.strip().split(':')
                    # Очищаем имя домена от недопустимых символов
                    domain = clean_domain_name(domain)
                    domains[domain] = int(port)
                else:
                    # Если порт не указан, используем 80 по умолчанию
                    domain = clean_domain_name(domain_port.strip())
                    domains[domain] = 80
            
            print(f"Parsed domains as list: {domains}")
            return domains, server_ip
        except Exception as e:
            print(f"ERROR: Failed to parse DOMAINS: {e}")
            sys.exit(1)

def clean_domain_name(domain):
    """
    Очищает имя домена от недопустимых символов для имени файла.
    
    Args:
        domain (str): Имя домена для очистки
        
    Returns:
        str: Очищенное имя домена
    """
    # Убираем слеши и другие недопустимые символы
    return re.sub(r'[^a-zA-Z0-9.-]', '', domain)

def generate_configs(domains, server_ip):
    """
    Генерирует конфигурационные файлы Nginx для каждого домена.
    
    Args:
        domains (dict): Словарь вида {домен: порт}
        server_ip (str): IP-адрес сервера
    """
    templates_dir = "/etc/nginx/conf.d/templates"
    output_dir = "/etc/nginx/conf.d"
    
    # Очищаем старые конфигурации (кроме шаблонов)
    for file in os.listdir(output_dir):
        if file.endswith(".conf") and not file.startswith("."):
            os.remove(os.path.join(output_dir, file))
    
    # Проверяем, включен ли SSL
    enable_ssl = os.environ.get('ENABLE_SSL', 'false').lower() == 'true'
    template_file = "https.conf.template" if enable_ssl else "http.conf.template"
    
    # Генерируем конфигурацию для каждого домена
    for domain, port in domains.items():
        print(f"Generating config for domain: {domain} -> port: {port}")
        
        # Очищаем имя домена для использования в имени файла
        clean_domain = clean_domain_name(domain)
        
        # Проверяем, существует ли сертификат, если SSL включен
        ssl_cert_path = f"/etc/letsencrypt/live/{domain}/fullchain.pem"
        if enable_ssl and not os.path.exists(ssl_cert_path):
            print(f"WARNING: SSL certificate for {domain} not found, using HTTP config")
            template_file = "http.conf.template"
        
        template_path = os.path.join(templates_dir, template_file)
        
        # Проверяем наличие шаблона
        if not os.path.exists(template_path):
            print(f"ERROR: Template file {template_path} not found")
            continue
        
        # Читаем шаблон
        with open(template_path, 'r') as f:
            template = f.read()
        
        # Заменяем переменные в шаблоне
        config = template.replace('{{DOMAIN}}', domain)
        config = config.replace('{{PORT}}', str(port))
        config = config.replace('{{SERVER_IP}}', server_ip)
        
        # Записываем конфигурацию
        output_path = os.path.join(output_dir, f"{clean_domain}.conf")
        with open(output_path, 'w') as f:
            f.write(config)
        
        print(f"Configuration for {domain} generated at {output_path}")

def main():
    """
    Основная функция.
    """
    print("Starting Nginx configuration generation...")
    
    # Парсим домены
    domains, server_ip = parse_domains()
    
    # Генерируем конфиги
    generate_configs(domains, server_ip)
    
    print("Nginx configuration generation completed.")

if __name__ == "__main__":
    main() 