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
    """
    domains_env = os.environ.get('DOMAINS')
    if not domains_env:
        print("WARNING: DOMAINS environment variable is not set. No standard domains will be configured.")
        domains_env = "{}" # Используем пустой JSON по умолчанию

    server_ip = os.environ.get('SERVER_IP', '127.0.0.1')
    domains = {}

    # Пробуем парсить как JSON
    try:
        raw_domains = json.loads(domains_env)
        for domain, port in raw_domains.items():
            clean_domain = clean_domain_name(domain)
            domains[clean_domain] = int(port)
        print(f"Parsed domains as JSON: {domains}")
        return domains, server_ip
    except json.JSONDecodeError:
        # Если не JSON, то пробуем парсить как список
        print("DOMAINS is not valid JSON, attempting to parse as comma-separated list...")
        try:
            for domain_port in domains_env.split(','):
                domain_port = domain_port.strip()
                if not domain_port: # Пропускаем пустые элементы после split
                    continue
                if ':' in domain_port:
                    domain, port_str = domain_port.split(':', 1)
                    domain = clean_domain_name(domain.strip())
                    port = int(port_str.strip())
                else:
                    # Если порт не указан, используем 80 по умолчанию
                    domain = clean_domain_name(domain_port)
                    port = 80

                if domain: # Проверяем, что домен не пустой после очистки
                    domains[domain] = port
            print(f"Parsed domains as list: {domains}")
            return domains, server_ip
        except Exception as e:
            print(f"ERROR: Failed to parse DOMAINS as list: {e}")
            # Возвращаем пустой словарь в случае ошибки парсинга списка
            return {}, server_ip

def parse_wildcard_ports():
    """
    Парсит переменную окружения WILDCARD_LOCALHOST_PORTS.
    Формат: subdomain:port,subdomain:port,*:default_port
    Возвращает словарь {subdomain: port} и порт по умолчанию.
    """
    ports_env = os.environ.get('WILDCARD_LOCALHOST_PORTS', '*:80') # По умолчанию порт 80 для всех
    ports_map = {}
    default_port = 80 # Значение по умолчанию, если '*' не задан явно

    print(f"Parsing WILDCARD_LOCALHOST_PORTS: '{ports_env}'")
    try:
        for item in ports_env.split(','):
            item = item.strip()
            if not item:
                continue
            if ':' in item:
                subdomain, port_str = item.split(':', 1)
                subdomain = subdomain.strip()
                port_str = port_str.strip()
                try:
                    port = int(port_str)
                    if subdomain == '*':
                        default_port = port
                        print(f"  Found default wildcard port: {port}")
                    else:
                        clean_subdomain = clean_domain_name(subdomain) # Очищаем имя поддомена
                        if clean_subdomain:
                            ports_map[clean_subdomain] = port
                            print(f"  Mapped subdomain '{clean_subdomain}' to port {port}")
                except ValueError:
                    print(f"  WARNING: Invalid port number '{port_str}' for subdomain '{subdomain}'. Skipping.")
            else:
                 print(f"  WARNING: Invalid format '{item}'. Expected 'subdomain:port'. Skipping.")
    except Exception as e:
        print(f"ERROR: Failed to parse WILDCARD_LOCALHOST_PORTS: {e}. Using default port 80.")
        return {}, 80 # Возвращаем пустой словарь и порт по умолчанию при ошибке

    print(f"Parsed wildcard ports map: {ports_map}, Default port: {default_port}")
    return ports_map, default_port


def clean_domain_name(domain):
    """
    Очищает имя домена/поддомена от недопустимых символов.
    """
    domain = domain.replace('/', '')
    # Удаляем все, кроме букв, цифр, точек и дефисов
    return re.sub(r'[^a-zA-Z0-9.-]', '', domain)

def generate_configs(domains, server_ip):
    """
    Генерирует конфигурационные файлы Nginx.
    """
    templates_dir = "/etc/nginx/conf.d/templates"
    output_dir = "/etc/nginx/conf.d"
    map_file_path = os.path.join(output_dir, "00-wildcard_map.conf") # Путь к файлу с map
    wildcard_conf_path = os.path.join(output_dir, "wildcard.localhost.conf")

    # Очищаем старые конфигурации
    print("Clearing old configuration files...")
    for file in os.listdir(output_dir):
        # Удаляем только .conf файлы, не являющиеся шаблонами и не служебными файлами
        if file.endswith(".conf") and not file.startswith(".") and file not in ["wildcard.localhost.conf", "00-wildcard_map.conf"]:
            file_path = os.path.join(output_dir, file)
            try:
                print(f"Removing {file_path}")
                os.remove(file_path)
            except OSError as e:
                print(f"Error removing file {file_path}: {e}")

    # --- Wildcard localhost ---
    wildcard_target_enabled = os.environ.get('WILDCARD_LOCALHOST_TARGET', 'false').lower() == 'true'

    if wildcard_target_enabled:
        print("WILDCARD_LOCALHOST_TARGET is enabled.")
        wildcard_ports_map, default_wildcard_port = parse_wildcard_ports()

        # Генерируем map блок для Nginx
        map_block_lines = [f"map $subdomain $target_port {{"]
        map_block_lines.append(f"    default {default_wildcard_port};") # Порт по умолчанию
        for sub, port in wildcard_ports_map.items():
            map_block_lines.append(f"    {sub} {port};")
        map_block_lines.append(f"}}")
        nginx_map_block = "\n".join(map_block_lines)
        print("Generated Nginx map block:")
        print(nginx_map_block)

        # Записываем map блок в отдельный файл
        try:
            with open(map_file_path, 'w') as f:
                f.write(nginx_map_block + "\n") # Добавляем перенос строки в конце
            print(f"Wildcard map block saved to {map_file_path}")
        except IOError as e:
            print(f"Error writing map file {map_file_path}: {e}")

        # Генерируем основной wildcard конфиг
        wildcard_template_path = os.path.join(templates_dir, "wildcard.localhost.conf.template")
        if os.path.exists(wildcard_template_path):
            print("Generating config for *.localhost...")
            try:
                with open(wildcard_template_path, 'r') as f:
                    wildcard_template = f.read()

                # Шаблон больше не содержит плейсхолдера для map
                wildcard_config = wildcard_template

                with open(wildcard_conf_path, 'w') as f:
                    f.write(wildcard_config)
                print(f"Configuration for *.localhost generated at {wildcard_conf_path}")
            except IOError as e:
                print(f"Error processing wildcard template {wildcard_template_path}: {e}")
        else:
            print(f"WARNING: Wildcard template {wildcard_template_path} not found. Skipping *.localhost config.")
    else:
        # Если wildcard не включен, удаляем старые конфиги wildcard и map, если они есть
        for conf_file in [wildcard_conf_path, map_file_path]:
             if os.path.exists(conf_file):
                try:
                    print(f"WILDCARD_LOCALHOST_TARGET is not set. Removing {conf_file}")
                    os.remove(conf_file)
                except OSError as e:
                    print(f"Error removing file {conf_file}: {e}")

    # --- Standard domains ---
    if domains:
        print("Generating standard domain configurations...")
        enable_ssl = os.environ.get('ENABLE_SSL', 'false').lower() == 'true'

        for domain, port in domains.items():
            print(f"Generating config for domain: {domain} -> port: {port}")

            current_template_file = "http.conf.template"
            if enable_ssl:
                ssl_cert_path = f"/etc/letsencrypt/live/{domain}/fullchain.pem"
                if os.path.exists(ssl_cert_path):
                    current_template_file = "https.conf.template"
                    print(f"SSL certificate found for {domain}. Using HTTPS template.")
                else:
                    print(f"WARNING: SSL certificate for {domain} not found at {ssl_cert_path}. Using HTTP config instead.")

            template_path = os.path.join(templates_dir, current_template_file)

            if not os.path.exists(template_path):
                print(f"ERROR: Template file {template_path} not found for domain {domain}. Skipping.")
                continue

            try:
                with open(template_path, 'r') as f:
                    template = f.read()

                config = template.replace('{{DOMAIN}}', domain)
                config = config.replace('{{PORT}}', str(port))
                config = config.replace('{{SERVER_IP}}', server_ip)

                clean_domain_name_for_file = clean_domain_name(domain) # Используем очищенное имя для файла
                output_path = os.path.join(output_dir, f"{clean_domain_name_for_file}.conf")
                with open(output_path, 'w') as f:
                    f.write(config)

                print(f"Configuration for {domain} generated at {output_path}")
            except IOError as e:
                 print(f"Error processing template {template_path} for domain {domain}: {e}")
    else:
        print("No domains found in DOMAINS variable. Skipping standard domain configuration.")


def main():
    """
    Основная функция.
    """
    print("Starting Nginx configuration generation...")
    domains, server_ip = parse_domains()
    generate_configs(domains, server_ip)
    print("Nginx configuration generation completed.")

if __name__ == "__main__":
    main()