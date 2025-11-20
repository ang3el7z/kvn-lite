#!/bin/bash

# Скрипт полной диагностики бота - собирает все логи и информацию

echo "=========================================="
echo "  ПОЛНАЯ ДИАГНОСТИКА VPN БОТА"
echo "=========================================="
echo ""
echo "Дата и время: $(date)"
echo ""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для вывода заголовка
print_header() {
    echo ""
    echo "=========================================="
    echo "  $1"
    echo "=========================================="
    echo ""
}

# Функция для проверки команды
check_command() {
    if command -v $1 &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 установлен"
        return 0
    else
        echo -e "${RED}✗${NC} $1 не установлен"
        return 1
    fi
}

# 1. Проверка окружения
print_header "1. ПРОВЕРКА ОКРУЖЕНИЯ"

echo "Текущая директория: $(pwd)"
echo "Пользователь: $(whoami)"
echo ""

check_command docker
check_command docker-compose
check_command git
echo ""

# 2. Проверка Git статуса
print_header "2. СТАТУС GIT"

if [ -d ".git" ]; then
    echo "Ветка: $(git branch --show-current 2>/dev/null || echo 'неизвестно')"
    echo "Последний коммит: $(git log -1 --oneline 2>/dev/null || echo 'нет коммитов')"
    echo "Статус:"
    git status --short 2>/dev/null || echo "Не удалось получить статус"
else
    echo -e "${YELLOW}⚠${NC} Это не git репозиторий"
fi
echo ""

# 3. Проверка config.php
print_header "3. ПРОВЕРКА CONFIG.PHP"

if [ -f "./app/config.php" ]; then
    echo -e "${GREEN}✓${NC} config.php существует"
    echo ""
    echo "Содержимое config.php (без токена):"
    sed "s/'key' => '[^']*'/'key' => '***HIDDEN***'/g" ./app/config.php | head -20
    echo ""
    
    # Проверяем наличие админов
    if grep -q "admin" ./app/config.php; then
        echo -e "${GREEN}✓${NC} Админы найдены в config.php"
        echo "Админы:"
        grep "admin" ./app/config.php | sed 's/^/  /'
    else
        echo -e "${YELLOW}⚠${NC} Админы не найдены в config.php"
    fi
else
    echo -e "${RED}✗${NC} config.php НЕ СУЩЕСТВУЕТ!"
    echo "Это критическая проблема!"
fi
echo ""

# 4. Проверка Docker контейнеров
print_header "4. СТАТУС DOCKER КОНТЕЙНЕРОВ"

if command -v docker &> /dev/null; then
    echo "Запущенные контейнеры:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Не удалось получить список контейнеров"
    echo ""
    
    # Ищем контейнер PHP
    PHP_CONTAINER=$(docker compose ps -q php 2>/dev/null || docker ps --filter "name=php" --format "{{.Names}}" | head -1)
    
    if [ -n "$PHP_CONTAINER" ]; then
        echo -e "${GREEN}✓${NC} Контейнер PHP найден: $PHP_CONTAINER"
        CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "$PHP_CONTAINER" 2>/dev/null)
        echo "Статус контейнера: $CONTAINER_STATUS"
    else
        echo -e "${RED}✗${NC} Контейнер PHP не найден!"
        echo "Попробуйте запустить: make r или docker compose up -d"
    fi
else
    echo -e "${RED}✗${NC} Docker не установлен"
fi
echo ""

# 5. ЛОГИ ИЗ КОНТЕЙНЕРА PHP
print_header "5. ЛОГИ ИЗ КОНТЕЙНЕРА PHP"

if [ -n "$PHP_CONTAINER" ] && [ "$CONTAINER_STATUS" = "running" ]; then
    echo "Контейнер: $PHP_CONTAINER"
    echo ""
    
    # Проверяем каждый лог файл
    for log_file in "php_error" "auth_debug" "requests_error" "bot_input"; do
        echo "--- /logs/$log_file ---"
        LOG_CONTENT=$(docker exec "$PHP_CONTAINER" sh -c "if [ -f /logs/$log_file ]; then tail -50 /logs/$log_file 2>/dev/null; else echo 'ФАЙЛ НЕ СУЩЕСТВУЕТ'; fi" 2>/dev/null)
        
        if [ "$LOG_CONTENT" = "ФАЙЛ НЕ СУЩЕСТВУЕТ" ] || [ -z "$LOG_CONTENT" ]; then
            echo -e "${YELLOW}⚠${NC} Лог файл /logs/$log_file пуст или не существует"
        else
            echo "$LOG_CONTENT"
        fi
        echo ""
    done
    
    # Также показываем логи через docker compose logs
    echo "--- Последние 30 строк из docker compose logs php ---"
    docker compose logs --tail=30 php 2>/dev/null || echo "Не удалось получить логи"
    echo ""
else
    echo -e "${RED}✗${NC} Контейнер PHP не запущен, логи недоступны"
    echo "Попробуйте запустить: make r"
fi
echo ""

# 6. Проверка webhook
print_header "6. ПРОВЕРКА WEBHOOK"

if [ -f "./app/config.php" ]; then
    # Пытаемся получить токен бота
    KEY=$(grep -oP "'key'\s*=>\s*'\K[^']+" ./app/config.php | head -1)
    
    if [ -n "$KEY" ] && [ ${#KEY} -gt 10 ]; then
        echo "Проверка webhook через API Telegram..."
        WEBHOOK_INFO=$(curl -s "https://api.telegram.org/bot$KEY/getWebhookInfo" 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            echo "$WEBHOOK_INFO" | python3 -m json.tool 2>/dev/null || echo "$WEBHOOK_INFO"
            
            # Проверяем URL webhook
            if echo "$WEBHOOK_INFO" | grep -q '"url"'; then
                WEBHOOK_URL=$(echo "$WEBHOOK_INFO" | grep -oP '"url"\s*:\s*"\K[^"]+' | head -1)
                echo ""
                echo "Webhook URL: $WEBHOOK_URL"
                
                # Проверяем что URL правильный
                if echo "$WEBHOOK_URL" | grep -q "/tlgrm?k="; then
                    echo -e "${GREEN}✓${NC} URL webhook содержит правильный путь /tlgrm?k="
                else
                    echo -e "${YELLOW}⚠${NC} URL webhook может быть неправильным"
                fi
            fi
        else
            echo -e "${RED}✗${NC} Не удалось получить информацию о webhook"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Не удалось получить токен бота из config.php"
    fi
else
    echo -e "${RED}✗${NC} config.php не существует, невозможно проверить webhook"
fi
echo ""

# 7. Проверка последних изменений в коде
print_header "7. ПОСЛЕДНИЕ ИЗМЕНЕНИЯ В КОДЕ"

if [ -d ".git" ]; then
    echo "Последние 5 коммитов:"
    git log --oneline -5 2>/dev/null || echo "Не удалось получить историю"
    echo ""
    echo "Измененные файлы в последнем коммите:"
    git diff --name-only HEAD~1 HEAD 2>/dev/null || echo "Не удалось получить изменения"
else
    echo "Не git репозиторий"
fi
echo ""

# 8. Проверка прав доступа
print_header "8. ПРОВЕРКА ПРАВ ДОСТУПА"

if [ -f "./app/config.php" ]; then
    PERMS=$(stat -c "%a" ./app/config.php 2>/dev/null || stat -f "%OLp" ./app/config.php 2>/dev/null || echo "неизвестно")
    echo "Права на config.php: $PERMS"
    
    if [ -w "./app/config.php" ]; then
        echo -e "${GREEN}✓${NC} config.php доступен для записи"
    else
        echo -e "${RED}✗${NC} config.php НЕ доступен для записи!"
        echo "Попробуйте: chmod 666 ./app/config.php"
    fi
fi

if [ -d "./logs" ]; then
    PERMS=$(stat -c "%a" ./logs 2>/dev/null || stat -f "%OLp" ./logs 2>/dev/null || echo "неизвестно")
    echo "Права на директорию logs: $PERMS"
else
    echo -e "${YELLOW}⚠${NC} Директория logs не существует на хосте (логи в контейнере)"
fi
echo ""

# 9. Проверка переменных окружения
print_header "9. ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ"

if [ -f "./.env" ]; then
    echo -e "${GREEN}✓${NC} .env файл существует"
    echo "Первые 5 строк (без секретов):"
    head -5 .env | sed 's/=.*/=***/' || echo "Не удалось прочитать"
else
    echo -e "${YELLOW}⚠${NC} .env файл не найден"
fi
echo ""

# 10. Рекомендации
print_header "10. РЕКОМЕНДАЦИИ"

echo "Если бот не отвечает, проверьте:"
echo ""
echo "1. Контейнер PHP запущен:"
echo "   docker compose ps"
echo ""
echo "2. Логи в реальном времени:"
echo "   docker compose logs -f php"
echo ""
echo "3. Зайти в контейнер и проверить логи:"
echo "   docker compose exec php /bin/sh"
echo "   tail -50 /logs/auth_debug"
echo "   tail -50 /logs/php_error"
echo ""
echo "4. Перезапустить контейнеры:"
echo "   make r"
echo ""
echo "5. Проверить webhook:"
echo "   docker compose exec php php checkwebhook.php"
echo ""
echo "6. Отправить боту /start и сразу проверить логи:"
echo "   docker compose exec php sh -c 'tail -20 /logs/auth_debug'"
echo ""

# 11. Итоговая сводка
print_header "ИТОГОВАЯ СВОДКА"

ISSUES=0

if [ ! -f "./app/config.php" ]; then
    echo -e "${RED}✗${NC} КРИТИЧНО: config.php не существует"
    ISSUES=$((ISSUES + 1))
fi

if [ -z "$PHP_CONTAINER" ] || [ "$CONTAINER_STATUS" != "running" ]; then
    echo -e "${RED}✗${NC} КРИТИЧНО: Контейнер PHP не запущен"
    ISSUES=$((ISSUES + 1))
fi

if [ -f "./app/config.php" ] && ! grep -q "admin" ./app/config.php 2>/dev/null; then
    echo -e "${YELLOW}⚠${NC} ВНИМАНИЕ: Админы не найдены в config.php"
    ISSUES=$((ISSUES + 1))
fi

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Критических проблем не обнаружено"
    echo "Проверьте логи выше для детальной диагностики"
else
    echo -e "${RED}✗${NC} Обнаружено проблем: $ISSUES"
    echo "Исправьте критические проблемы перед тестированием бота"
fi

echo ""
echo "=========================================="
echo "  ДИАГНОСТИКА ЗАВЕРШЕНА"
echo "=========================================="
echo ""
echo "Все логи сохранены выше. Скопируйте вывод этого скрипта для анализа."
echo ""

