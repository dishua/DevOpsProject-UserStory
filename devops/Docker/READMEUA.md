# Docker — DevOpsProject-UserStory

Ця директорія містить усі Docker-конфігурації та скрипти для контейнеризації та запуску застосунку **DevOpsProject-UserStory**.

## Стек технологій

| Сервіс     | Технологія              | Порт |
|------------|-------------------------|------|
| Backend    | Java 17 · Spring Boot   | 8080 |
| Frontend   | React · Node 20 · Nginx | 3000 |
| База даних | MariaDB 11              | 3306 |

---

## Структура директорії

```
docker/
├── deploy.sh            # Скрипт деплою — Linux/macOS
├── deploy.ps1           # Скрипт деплою — Windows (PowerShell)
├── cleanup.sh           # Скрипт очищення — Linux/macOS
├── cleanup.ps1          # Скрипт очищення — Windows (PowerShell)
└── config/
    ├── docker-compose.yml
    ├── backend.Dockerfile
    ├── frontend.Dockerfile
    ├── nginx.conf
    ├── .env.example     # Шаблон — скопіюй та заповни
    ├── .env             # Секрети — НЕ комітити!
    └── db/
        └── init.sql     # Схема БД (виконується автоматично при першому запуску)
```

---

## Поведінка скрипту деплою

При **першому запуску** (існуючого деплою не виявлено):
1. Пропонує створити `.env` з налаштуваннями бази даних
2. Копіює `Dockerfile`-и, `nginx.conf` та папку `db/` у корінь проекту
3. Запускає `docker compose up --build -d`

При **повторному запуску** (існуючий деплой виявлено):

```
What would you like to do?
  1) Start normally          (docker compose up -d)
  2) Restart without rebuild (docker compose restart)
  3) Rebuild and restart     (docker compose up --build -d)
  4) Exit without changes
```

> Скрипт визначає наявність існуючого деплою за Docker volume `userstory_mariadb_data`.

---

## Змінні середовища

Всі змінні зберігаються у `config/.env` (створюється при першому запуску).

| Змінна                      | Опис                                    |
|-----------------------------|-----------------------------------------|
| `DB_ROOT_PASSWORD`          | Пароль root для MariaDB                 |
| `DB_USERSTORYPROJ_USER`     | Користувач бази даних застосунку        |
| `DB_USERSTORYPROJ_PASSWORD` | Пароль користувача бази даних           |
| `PROJECT_DIR`               | Абсолютний шлях до кореня проекту       |

> `PROJECT_DIR` встановлюється та оновлюється автоматично скриптом деплою при кожному запуску. Вручну задавати не потрібно.

Щоб створити `.env` вручну з шаблону:

```bash
cp config/.env.example config/.env
# відредагуй config/.env та заповни значення
```

---

## Ініціалізація бази даних

При першому запуску MariaDB автоматично виконує `config/db/init.sql`, який створює:

```sql
CREATE DATABASE IF NOT EXISTS userstory;

CREATE TABLE IF NOT EXISTS projects (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    description VARCHAR(255),
    name        VARCHAR(255),
    PRIMARY KEY (id)
);
```

> Скрипт виконується **лише один раз** — коли volume `userstory_mariadb_data` порожній. Щоб скинути базу даних, використай скрипт очищення з рівнем **Повне** або **Ядерне**.

---

## Скрипт очищення

Зупиняє контейнери та видаляє файли, створені скриптом деплою.

```powershell
.\cleanup.ps1   # Windows
./cleanup.sh    # Linux/macOS
```

### Рівні очищення

| Рівень      | Зупиняє контейнери | Видаляє volume (дані БД) | Видаляє Docker образи | Видаляє скопійовані файли |
|-------------|:------------------:|:------------------------:|:---------------------:|:-------------------------:|
| **М'яке**   | ✅                 | ❌                        | ❌                    | ✅                        |
| **Повне**   | ✅                 | ✅                        | ❌                    | ✅                        |
| **Ядерне**  | ✅                 | ✅                        | ✅                    | ✅                        |

> ⚠️ Рівні **Повне** та **Ядерне** є незворотними — усі дані бази даних будуть втрачені.

**Скопійовані файли, які видаляє cleanup:**
```
backend/Dockerfile
frontend/Dockerfile
frontend/nginx.conf
db/
```

---

## Корисні команди Docker

```bash
# Переглянути запущені контейнери
docker compose -f config/docker-compose.yml ps

# Переглянути логи
docker compose -f config/docker-compose.yml logs -f

# Переглянути логи конкретного сервісу
docker compose -f config/docker-compose.yml logs -f backend

# Зупинити без видалення
docker compose -f config/docker-compose.yml stop

# Відкрити shell у контейнері бази даних
docker exec -it userstory-db-1 mariadb -u userstorydb -p userstory
```

---

## Назви контейнерів та volumes

Завдяки `name: userstory` у `docker-compose.yml` всі назви фіксовані незалежно від того, з якої директорії запускається compose:

| Ресурс              | Назва                      |
|---------------------|----------------------------|
| Backend контейнер   | `userstory-backend-1`      |
| Frontend контейнер  | `userstory-frontend-1`     |
| DB контейнер        | `userstory-db-1`           |
| DB volume           | `userstory_mariadb_data`   |

---

## .gitignore

Переконайся що у `.gitignore` є наступний рядок:

```gitignore
devops/docker/config/.env
```
