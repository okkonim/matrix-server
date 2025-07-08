#!/bin/bash

set -e

PROJECT_DIR="/home/ubuntu/matrix"

echo "=== Обновление проекта ==="

cd "$PROJECT_DIR"

# === Получаем последние изменения ===
git pull origin main

# === Пересобираем и перезапускаем контейнеры ===
docker-compose down
docker-compose up -d

echo "Проект обновлён."