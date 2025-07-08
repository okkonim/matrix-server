#!/bin/bash

set -e

# === Ввод данных из аргументов или переменных окружения ===
DOMAIN=${DOMAIN:?"Не указан DOMAIN"}
EMAIL=${EMAIL:?"Не указан EMAIL"}
NGINX_CONF_DIR="/etc/nginx/sites-available"
LETS_ENCRYPT_DIR="/etc/letsencrypt"

echo "=== Начинаем настройку сервера для домена $DOMAIN ==="

# === Обновление системы ===
sudo apt update && sudo apt upgrade -y

# === Установка Docker и Docker Compose ===
sudo apt install -y docker.io curl git
sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose- $(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# === Проверка установки ===
docker --version && docker-compose --version

# === Установка Certbot для Let's Encrypt ===
sudo apt install -y certbot python3-certbot-nginx

# === Генерация или выпуск SSL-сертификата ===
echo "Выберите способ получения SSL-сертификата для $DOMAIN:"
echo "  1) Сгенерировать временный self-signed сертификат"
echo "  2) Выпустить сертификат Let's Encrypt (рекомендуется для боевого домена)"
echo "  3) Пропустить (сертификаты уже существуют)"
echo -n "Введите номер варианта (1/2/3): "
read -r cert_choice

case "$cert_choice" in
  1)
    sudo mkdir -p "$LETS_ENCRYPT_DIR/live/$DOMAIN"
    if ! sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout "$LETS_ENCRYPT_DIR/live/$DOMAIN/privkey.pem" \
      -out "$LETS_ENCRYPT_DIR/live/$DOMAIN/fullchain.pem" \
      -subj "/CN=$DOMAIN"; then
      echo "[ОШИБКА] Не удалось сгенерировать self-signed сертификат для $DOMAIN" >&2
      exit 1
    else
      echo "Self-signed сертификат успешно сгенерирован для $DOMAIN."
    fi
    ;;
  2)
    if sudo certbot certonly --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL"; then
      echo "Сертификат Let's Encrypt успешно выпущен для $DOMAIN."
    else
      echo "[ОШИБКА] Не удалось выпустить сертификат Let's Encrypt для $DOMAIN" >&2
      exit 1
    fi
    ;;
  3)
    echo "Пропускаю выпуск сертификата. Убедитесь, что сертификаты уже существуют в /etc/letsencrypt/live/$DOMAIN/"
    ;;
  *)
    echo "Некорректный выбор. Прерываю установку." >&2
    exit 1
    ;;
esac

# === Клонирование репозитория ===
if ! git rev-parse --show-toplevel > /dev/null 2>&1; then
  # Если скрипт не в git-репозитории, клонируем
  export REPO_URL="https://github.com/okkonim/matrix-server.git"
  PROJECT_DIR="/home/ubuntu/matrix"
  if [ ! -d "$PROJECT_DIR" ]; then
    git clone "$REPO_URL" "$PROJECT_DIR"
    cd "$PROJECT_DIR"
  else
    echo "Репозиторий уже существует. Выполняю pull..."
    cd "$PROJECT_DIR" && git pull origin main
  fi
else
  echo "Скрипт запущен из git-репозитория, клонирование не требуется."
fi

cd "$PROJECT_DIR"

# === Замена __DOMAIN__ в шаблонах ===
find . -type f -name "*.template" -o -name "*.conf" -o -name "*.yml" | while read file; do
  sed -i "s/__DOMAIN__/$DOMAIN/g" "$file"
done

# === Создание .env файла с данными ===
cat > .env <<EOL
DOMAIN=$DOMAIN
HOMESERVER_URL=https://$DOMAIN
CLIENT_URL=https://$DOMAIN
IDENTITY_SERVER_URL=https://vector.im 
SCALAR_UI_URL=https://scalar.vector.im/ 
SCALAR_API_URL=https://scalar.vector.im/api 
SCALAR_WIDGETS_URL_1=https://scalar.vector.im/_matrix/integrations/v1 
SCALAR_WIDGETS_URL_2=https://scalar.vector.im/api 
BUG_REPORT_URL=https://element.io/bugreports/submit 
PRIVACY_POLICY_URL=https://element.io/privacy 
COOKIE_POLICY_URL=https://element.io/cookie-policy 
POSTGRES_PASSWORD=__your_secure_password_here__
EOL

# === Настройка Nginx ===
sudo cp "$PROJECT_DIR/nginx/default.conf" "/etc/nginx/sites-available/matrix"
sudo ln -sf "/etc/nginx/sites-available/matrix" "/etc/nginx/sites-enabled/matrix"
sudo nginx -t && sudo systemctl reload nginx

# === Запуск контейнеров ===
docker-compose up -d

echo "Сервер настроен!"
echo "Проверь доступ по адресу: https://$DOMAIN"