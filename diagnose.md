# Инструкция для работы на сервере

## Текущая ситуация

Проект установлен в `/root/kvn-lite` (видно из автозапуска).

## Шаг 1: Перейти в директорию проекта

```bash
cd /root/kvn-lite
```

## Шаг 2: Обновить код из репозитория

```bash
# Проверить текущую ветку
git branch

# Если нужно переключиться на ветку с исправлениями
git checkout fix-bot-server-S9rmS

# Обновить код
git pull
```

## Шаг 3: Запустить ПОЛНУЮ диагностику (РЕКОМЕНДУЕТСЯ)

```bash
# Сделать скрипт исполняемым
chmod +x scripts/diagnose_bot.sh

# Запустить полную диагностику - выведет ВСЕ логи и информацию
bash scripts/diagnose_bot.sh
```

Этот скрипт покажет:
- Статус всех контейнеров
- Все логи из контейнера PHP (php_error, auth_debug, requests_error, bot_input)
- Статус webhook
- Содержимое config.php
- Последние изменения в коде
- Итоговую сводку проблем

**Скопируйте весь вывод скрипта для анализа!**

## Шаг 4: Альтернатива - быстрая проверка

Если нужна только быстрая проверка:

```bash
chmod +x scripts/check_bot_status.sh
bash scripts/check_bot_status.sh
```

## Шаг 5: Проверить логи (важно!)

Логи находятся **внутри контейнера PHP**, а не на хосте. Есть два способа:

### Способ 1: Через docker compose logs

```bash
# Логи всех контейнеров
docker compose logs

# Логи только PHP контейнера
docker compose logs php

# Следить за логами в реальном времени
docker compose logs -f php
```

### Способ 2: Зайти в контейнер PHP

```bash
# Зайти в контейнер PHP
make php
# или
docker compose exec php /bin/sh

# Внутри контейнера проверить логи
tail -50 /logs/php_error
tail -50 /logs/auth_debug
tail -50 /logs/requests_error
tail -50 /logs/bot_input
```

## Шаг 6: Перезапустить контейнеры после обновления кода

```bash
# Перезапустить все контейнеры
make r
# или
docker compose restart

# Или только PHP контейнер
docker compose restart php
```

## Шаг 7: Проверить что бот работает

1. Отправьте боту `/start` или `/menu`
2. Проверьте логи:
   ```bash
   # Через docker compose
   docker compose logs -f php | grep auth_debug
   
   # Или зайдя в контейнер
   make php
   tail -20 /logs/auth_debug
   ```
3. Проверьте config.php:
   ```bash
   # Зайти в контейнер
   make php
   
   # Проверить config.php
   cat /app/config.php | grep admin
   ```

## Быстрая проверка статуса

```bash
cd /root/kvn-lite

# 1. Обновить код
git pull

# 2. Перезапустить
make r

# 3. Проверить логи
docker compose logs -f php
```

## Важные замечания

1. **Логи находятся в контейнере**, не на хосте
2. **config.php находится в `/app/config.php` внутри контейнера** (на хосте это `./app/config.php`)
3. **Для проверки логов используйте `docker compose logs` или заходите в контейнер через `make php`**

## Если скрипт check_bot_status.sh не найден

Скрипт должен быть в репозитории. Если его нет:

1. Проверьте что вы в правильной ветке:
   ```bash
   git branch
   git checkout fix-bot-server-S9rmS
   git pull
   ```

2. Или создайте скрипт вручную (скопируйте содержимое из репозитория)

