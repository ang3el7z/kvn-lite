#!/bin/bash

# Скрипт для проверки статуса бота и диагностики проблем

echo "=== Проверка статуса VPN бота ==="
echo ""

# Проверка существования config.php
echo "1. Проверка config.php:"
if [ -f "./app/config.php" ]; then
    echo "   ✓ config.php существует"
    if [ -r "./app/config.php" ]; then
        echo "   ✓ config.php читается"
        # Пытаемся получить ключ бота (безопасно)
        KEY=$(grep -oP "'key'\s*=>\s*'\K[^']+" ./app/config.php | head -1)
        if [ -n "$KEY" ]; then
            echo "   ✓ Ключ бота найден (первые 10 символов: ${KEY:0:10}...)"
        else
            echo "   ⚠ Ключ бота не найден в config.php"
        fi
    else
        echo "   ✗ config.php не читается (проблемы с правами)"
    fi
else
    echo "   ✗ config.php НЕ СУЩЕСТВУЕТ!"
    echo "   Это критическая проблема. Нужно создать файл."
fi
echo ""

# Проверка логов
echo "2. Проверка логов:"
LOG_DIR="/logs"
if [ -d "$LOG_DIR" ]; then
    echo "   ✓ Директория логов существует: $LOG_DIR"
    
    # Проверяем основные логи
    for log_file in "php_error" "auth_debug" "requests_error" "bot_input"; do
        if [ -f "$LOG_DIR/$log_file" ]; then
            SIZE=$(stat -f%z "$LOG_DIR/$log_file" 2>/dev/null || stat -c%s "$LOG_DIR/$log_file" 2>/dev/null || echo "0")
            if [ "$SIZE" -gt 0 ]; then
                echo "   ✓ $log_file существует ($SIZE байт)"
                echo "   Последние 5 строк:"
                tail -n 5 "$LOG_DIR/$log_file" | sed 's/^/      /'
            else
                echo "   ⚠ $log_file пуст"
            fi
        else
            echo "   ⚠ $log_file не существует"
        fi
        echo ""
    done
else
    echo "   ✗ Директория логов не существует: $LOG_DIR"
    echo "   Возможно, нужно создать её или проверить путь"
fi
echo ""

# Проверка webhook
echo "3. Проверка webhook (если доступен API ключ):"
if [ -n "$KEY" ] && [ ${#KEY} -gt 10 ]; then
    WEBHOOK_INFO=$(curl -s "https://api.telegram.org/bot$KEY/getWebhookInfo")
    if [ $? -eq 0 ]; then
        echo "$WEBHOOK_INFO" | python3 -m json.tool 2>/dev/null || echo "$WEBHOOK_INFO"
    else
        echo "   ⚠ Не удалось получить информацию о webhook"
    fi
else
    echo "   ⚠ Не удалось получить ключ бота для проверки webhook"
fi
echo ""

# Проверка процессов PHP
echo "4. Проверка процессов PHP:"
PHP_PROCESSES=$(ps aux | grep -i php | grep -v grep | wc -l)
if [ "$PHP_PROCESSES" -gt 0 ]; then
    echo "   ✓ Найдено PHP процессов: $PHP_PROCESSES"
    ps aux | grep -i php | grep -v grep | head -3 | sed 's/^/      /'
else
    echo "   ⚠ PHP процессы не найдены"
fi
echo ""

# Проверка Docker контейнеров (если используется)
echo "5. Проверка Docker контейнеров:"
if command -v docker &> /dev/null; then
    CONTAINERS=$(docker ps --format "{{.Names}}" 2>/dev/null)
    if [ -n "$CONTAINERS" ]; then
        echo "   ✓ Запущенные контейнеры:"
        echo "$CONTAINERS" | sed 's/^/      /'
    else
        echo "   ⚠ Нет запущенных контейнеров"
    fi
else
    echo "   ⚠ Docker не установлен или недоступен"
fi
echo ""

echo "=== Конец проверки ==="
echo ""
echo "Рекомендации:"
echo "1. Проверьте логи в /logs/php_error для ошибок PHP"
echo "2. Проверьте /logs/auth_debug для проблем с авторизацией"
echo "3. Проверьте /logs/requests_error для ошибок API Telegram"
echo "4. Проверьте /logs/bot_input для входящих запросов"
echo "5. Убедитесь, что webhook настроен правильно: https://YOUR_IP/tlgrm?k=BOT_TOKEN"

