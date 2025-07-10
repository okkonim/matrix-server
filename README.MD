# Matrix Synapse Infrastructure

## Описание

Этот репозиторий содержит инфраструктуру для быстрого и безопасного развёртывания Matrix Synapse (сервер), Element (клиент), Synapse Admin (админка) и PostgreSQL с помощью Docker и nginx.  
Включены скрипты для автоматизации деплоя, первичной настройки сервера, а также CI/CD через GitHub Actions (опционально, для автоматического обновления сервера при изменениях в репозитории).

---

## Состав репозитория

- **docker-compose.prod.yml** — основной файл для запуска сервисов через Docker Compose.
- **nginx/default.conf** — конфиг nginx для HTTPS, федерации, проксирования клиентов и админки.
- **element-data/element-config.json** — шаблон конфига для Element.
- **synapse-data/homeserver.yml** — шаблон конфига для Synapse.
- **scripts/deploy.sh** — скрипт для обновления и перезапуска контейнеров.
- **scripts/setup_server.sh** — скрипт для первичной настройки сервера (установка Docker, nginx, генерация .env, клонирование репозитория, настройка SSL, автоматическая подстановка переменных в шаблоны).
- **.github/deploy.yml** — CI/CD: автоматический деплой на сервер при пуше в main.
- **element-data/** — директория c конфигом для Element.
- **nginx/** — директория с конфигами nginx.
- **scripts/** — bash-скрипты для автоматизации.
- **synapse-data/** — директория с шаблонами и данными Synapse.

---

## Архитектура и сервисы

### 1. Synapse (Matrix сервер)
- Контейнер: `matrix-synapse`
- Порт: 8008 (HTTP API)
- Хранит данные в volume `./synapse/data`
- Использует PostgreSQL как БД
- Конфигурируется через `synapse-data/homeserver.yml` (все переменные подставляются автоматически)

### 2. PostgreSQL
- Контейнер: `matrix-postgres`
- Порт: 5432 (только внутри docker-сети)
- Данные хранятся в volume `postgres_data`

### 3. Element (Matrix клиент)
- Контейнер: `element`
- Порт: 8123 (HTTP)
- Использует конфиг из `element-data/element-config.json`

### 4. Synapse Admin
- Контейнер: `synapse-admin`
- Порт: 8080 (HTTP)
- Веб-интерфейс для администрирования Synapse

### 5. nginx
- Проксирует HTTPS-запросы к Synapse, Element, Synapse Admin
- Открывает порты 80 (HTTP), 443 (HTTPS), 8448 (федерация Matrix)
- Обеспечивает безопасность (SSL, заголовки, редиректы)

---

## Создание и настройка .env

Перед запуском контейнеров создайте файл `.env` в корне проекта.  
Все переменные из `.env` автоматически подставляются в шаблоны конфигов Synapse, Element, nginx и docker-compose.

### Пример содержимого:

```ini
DOMAIN=your.domain.com
EMAIL=your@email.com
POSTGRES_PASSWORD=your_secure_password
HOMESERVER_URL=https://${DOMAIN}
CLIENT_URL=https://${DOMAIN}
IDENTITY_SERVER_URL=https://vector.im
SCALAR_UI_URL=https://scalar.vector.im/
SCALAR_API_URL=https://scalar.vector.im/api
SCALAR_WIDGETS_URL_1=https://scalar.vector.im/_matrix/integrations/v1
SCALAR_WIDGETS_URL_2=https://scalar.vector.im/api
BUG_REPORT_URL=https://element.io/bugreports/submit
PRIVACY_POLICY_URL=https://element.io/privacy
COOKIE_POLICY_URL=https://element.io/cookie-policy

REGISTRATION_SHARED_SECRET=your_registration_secret
TURN_SHARED_SECRET=your_turn_secret
ADMIN_USER=adminuser
```

**Рекомендации:**
- Для секретов используйте случайные строки, например:
  ```sh
  openssl rand -hex 32
  ```
- Если не используете TURN или регистрацию через API, всё равно задайте эти переменные (или оставьте пустыми, если не требуется).

---

## Пошаговая инструкция по развёртыванию

1. Клонируйте репозиторий:
   ```sh
   git clone https://github.com/okkonim/matrix-server.git
   cd matrix-server
   ```

2. Создайте и заполните `.env`:
   ```sh
   cp .env.example .env
   # отредактируйте .env
   ```

3. Установите Docker и Docker Compose (если не установлены):
   ```sh
   sudo apt update
   sudo apt install -y docker.io docker-compose
   ```

4. Запустите скрипт первичной настройки (на сервере):
   ```sh
   bash scripts/setup_server.sh
   ```
   - Скрипт автоматически подставит все переменные из .env в шаблоны конфигов.
   - Настроит nginx, SSL, и запустит контейнеры.

5. Проверьте работу по адресу https://your.domain.com

---

## Описание переменных .env

| Переменная                  | Описание                                                      | Пример                        |
|-----------------------------|---------------------------------------------------------------|-------------------------------|
| DOMAIN                      | Ваш основной домен                                            | matrix.example.com            |
| EMAIL                       | Email для Let's Encrypt                                       | admin@example.com             |
| POSTGRES_PASSWORD           | Пароль для PostgreSQL                                         | (любой сложный пароль)        |
| HOMESERVER_URL              | URL Matrix Synapse                                            | https://matrix.example.com    |
| CLIENT_URL                  | URL Element                                                   | https://matrix.example.com    |
| IDENTITY_SERVER_URL         | URL identity-сервера для Element                             | https://vector.im             |
| SCALAR_UI_URL               | URL Scalar UI для интеграций                                 | https://scalar.vector.im/     |
| SCALAR_API_URL              | URL Scalar API                                               | https://scalar.vector.im/api  |
| SCALAR_WIDGETS_URL_1        | URL для виджетов Scalar                                      | https://scalar.vector.im/_matrix/integrations/v1 |
| SCALAR_WIDGETS_URL_2        | URL для виджетов Scalar                                      | https://scalar.vector.im/api  |
| BUG_REPORT_URL              | URL для отправки багрепортов                                 | https://element.io/bugreports/submit |
| PRIVACY_POLICY_URL          | URL политики конфиденциальности                              | https://element.io/privacy    |
| COOKIE_POLICY_URL           | URL политики cookies                                         | https://element.io/cookie-policy |
| REGISTRATION_SHARED_SECRET  | Секрет для регистрации пользователей через API               | (случайная строка)            |
| TURN_SHARED_SECRET          | Секрет для TURN-сервера (если используется)                  | (случайная строка)            |
| ADMIN_USER                  | Имя пользователя-администратора                              | adminuser                     |

---

## Как работает подстановка переменных

- Все шаблоны конфигов (Synapse, Element, nginx, docker-compose) используют переменные вида `__VAR__`.
- Скрипт `setup_server.sh` автоматически заменяет все такие переменные на значения из `.env`.
- Это позволяет легко кастомизировать инфраструктуру под свои нужды.

---

## Подробное описание файлов и шаблонов

### docker-compose.prod.yml
- Описывает все сервисы, их переменные окружения, порты, volume'ы и сеть.
- Использует шаблонные переменные (`__DOMAIN__`, `__POSTGRES_PASSWORD__` и др.), которые подставляются скриптом.

### nginx/default.conf
- Редиректит HTTP на HTTPS
- Проксирует Matrix API, Element, Synapse Admin
- Открывает порт 8448 для федерации
- Настраивает well-known endpoints для Matrix клиентов и федерации
- Использует SSL-сертификаты из `/etc/letsencrypt/live/$DOMAIN/`

### element-data/element-config.json
- Конфиг для Element (Matrix клиент)
- Все URL и параметры подставляются из .env

### synapse-data/homeserver.yml
- Конфиг для Synapse (Matrix сервер)
- Все параметры (домены, секреты, админ и т.д.) подставляются из .env

### scripts/setup_server.sh
- Устанавливает все зависимости
- Клонирует репозиторий (если нужно)
- Генерирует .env (если нужно)
- Подставляет переменные в шаблоны
- Настраивает nginx и SSL
- Запускает контейнеры

### scripts/deploy.sh
- Обновляет репозиторий (git pull)
- Перезапускает контейнеры

### .github/deploy.yml
- CI/CD: при пуше в main архивирует проект, заливает на сервер по SSH и запускает деплой

---

## CI/CD и автоматизация

- **GitHub Actions**: автоматический деплой при пуше в main (опционально)
- Архивирует проект, заливает на сервер, запускает скрипт деплоя
- Проверяет доступность Element и Synapse API после деплоя

> **Примечание:** Автоматический деплой через CI/CD не обязателен. Если вы разворачиваете проект локально или вручную на сервере, вы можете не использовать `.github/deploy.yml` и не настраивать секреты для GitHub Actions. Просто следуйте инструкции по ручному запуску и настройке.

---

## Бэкап и восстановление

### Бэкап
- **PostgreSQL**: данные в volume `postgres_data`
- **Synapse**: данные в `./synapse/data`
- Для бэкапа достаточно сохранить эти volume'ы:

```sh
docker run --rm -v synapse_postgres_data:/data -v $(pwd):/backup busybox tar czf /backup/postgres_data.tar.gz /data
docker run --rm -v $(pwd)/synapse/data:/data -v $(pwd):/backup busybox tar czf /backup/synapse_data.tar.gz /data
```

### Восстановление
- Разархивируйте volume'ы обратно перед запуском контейнеров

---

## Безопасность

- Используйте сложные пароли для PostgreSQL и админки
- Не открывайте порт 8080 (Synapse Admin) наружу, ограничьте доступ через nginx (уже настроено, при необходимости измените)
- Следите за обновлениями образов (docker pull)
- Используйте HTTPS (Let's Encrypt)
- Открывайте порт 8448 только для федерации
- Храните .env и секреты вне публичного доступа

---

## Расширение и кастомизация

- Можно добавить интеграции, боты, bridge'ы, дополнительные сервисы в docker-compose
- Для кастомизации Element — изменяйте `element-data/element-config.json`
- Для кастомизации Synapse — изменяйте `synapse-data/homeserver.yml`

---

## Структура сервисов и портов

| Сервис         | Контейнер         | Порт (внешний) | Назначение                |
|----------------|-------------------|---------------|---------------------------|
| Synapse        | matrix-synapse    | 8008          | Matrix API (внутр. nginx) |
| PostgreSQL     | matrix-postgres   | -             | Только внутри docker      |
| Element        | element           | 8123          | Matrix клиент             |
| Synapse Admin  | synapse-admin     | 8080          | Веб-админка (локально)    |
| nginx          | -                 | 80, 443, 8448 | Проксирование, федерация  |

---

## FAQ

**Q:** Как сменить домен?  
**A:** Измените переменную DOMAIN, пересоберите шаблоны, перезапустите nginx и контейнеры.

**Q:** Как обновить образы?  
**A:**  
```sh
docker-compose pull
docker-compose up -d
```

**Q:** Как добавить бота или bridge?  
**A:** Добавьте сервис в docker-compose.prod.yml, настройте проксирование в nginx при необходимости.

---

## Лицензия

MIT License

Copyright (c) 2025 Your Name

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

## Контакты

OKKONIM

---

## Примечания

- Все шаблоны используют переменные вида `__VAR__` — они подставляются автоматически скриптом setup_server.sh.
- Для корректной работы Element и Synapse должны быть доступны по HTTPS.
- Для федерации Matrix требуется открытый порт 8448.
- Если нужна более подробная документация — дайте знать!

---
