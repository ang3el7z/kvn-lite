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

# Проверка логов (внутри Docker контейнера)
echo "2. Проверка логов:"
echo "   Примечание: Логи находятся внутри контейнера PHP"
echo ""

# Проверяем доступность Docker
if command -v docker &> /dev/null; then
    # Пытаемся получить имя контейнера PHP
    PHP_CONTAINER=$(docker compose ps -q php 2>/dev/null || docker ps --filter "name=php" --format "{{.Names}}" | head -1)
    
    if [ -n "$PHP_CONTAINER" ]; then
        echo "   ✓ Контейнер PHP найден: $PHP_CONTAINER"
        echo ""
        
        # Проверяем логи внутри контейнера
        for log_file in "php_error" "auth_debug" "requests_error" "bot_input"; do
            echo "   Проверка /logs/$log_file:"
            LOG_CONTENT=$(docker exec "$PHP_CONTAINER" sh -c "if [ -f /logs/$log_file ]; then tail -n 5 /logs/$log_file 2>/dev/null; else echo 'FILE_NOT_FOUND'; fi" 2>/dev/null)
            
            if [ "$LOG_CONTENT" = "FILE_NOT_FOUND" ]; then
                echo "   ⚠ $log_file не существует в контейнере"
            elif [ -z "$LOG_CONTENT" ]; then
                echo "   ⚠ $log_file пуст"
            else
                echo "   ✓ $log_file существует, последние 5 строк:"
                echo "$LOG_CONTENT" | sed 's/^/      /'
            fi
            echo ""
        done
    else
        echo "   ⚠ Контейнер PHP не найден. Проверьте что контейнеры запущены:"
        echo "      docker compose ps"
    fi
else
    echo "   ⚠ Docker не установлен или недоступен"
    echo "   Логи находятся в /logs/ внутри контейнера PHP"
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

# Проверка контейнера PHP
echo "4. Проверка контейнера PHP:"
if command -v docker &> /dev/null; then
    PHP_CONTAINER=$(docker compose ps -q php 2>/dev/null || docker ps --filter "name=php" --format "{{.Names}}" | head -1)
    if [ -n "$PHP_CONTAINER" ]; then
        CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "$PHP_CONTAINER" 2>/dev/null)
        if [ "$CONTAINER_STATUS" = "running" ]; then
            echo "   ✓ Контейнер PHP запущен: $PHP_CONTAINER"
            # Проверяем процессы внутри контейнера
            PHP_PROCESSES=$(docker exec "$PHP_CONTAINER" sh -c "ps aux | grep -i php | grep -v grep | wc -l" 2>/dev/null || echo "0")
            if [ "$PHP_PROCESSES" -gt 0 ]; then
                echo "   ✓ PHP процессы работают внутри контейнера"
            else
                echo "   ⚠ PHP процессы не найдены внутри контейнера"
            fi
        else
            echo "   ✗ Контейнер PHP не запущен (статус: $CONTAINER_STATUS)"
        fi
    else
        echo "   ⚠ Контейнер PHP не найден"
    fi
else
    echo "   ⚠ Docker не установлен или недоступен"
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
echo "1. Проверьте логи внутри контейнера PHP:"
echo "   docker compose exec php sh -c 'tail -50 /logs/php_error'"
echo "   docker compose exec php sh -c 'tail -50 /logs/auth_debug'"
echo "   docker compose exec php sh -c 'tail -50 /logs/requests_error'"
echo "   docker compose exec php sh -c 'tail -50 /logs/bot_input'"
echo ""
echo "2. Или зайдите в контейнер:"
echo "   docker compose exec php /bin/sh"
echo "   tail -50 /logs/auth_debug"
echo ""
echo "3. Или используйте docker compose logs:"
echo "   docker compose logs -f php"
echo ""
echo "4. Убедитесь, что webhook настроен правильно: https://YOUR_IP/tlgrm?k=BOT_TOKEN"
echo "   Проверить: docker compose exec php php checkwebhook.php"

