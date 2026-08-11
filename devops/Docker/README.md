# [README in Ukrainian](READMEUA.md)
---

# Docker — DevOpsProject-UserStory

This directory contains all Docker-related configuration and scripts for containerizing and running the **DevOpsProject-UserStory** application.

## Stack

| Service  | Technology             | Port |
|----------|------------------------|------|
| Backend  | Java 17 · Spring Boot  | 8080 |
| Frontend | React · Node 20 · Nginx| 3000 |
| Database | MariaDB 11             | 3306 |

---

## Directory Structure

```
docker/
├── deploy.sh            # Deploy script — Linux/macOS
├── deploy.ps1           # Deploy script — Windows (PowerShell)
├── cleanup.sh           # Cleanup script — Linux/macOS
├── cleanup.ps1          # Cleanup script — Windows (PowerShell)
└── config/
    ├── docker-compose.yml
    ├── backend.Dockerfile
    ├── frontend.Dockerfile
    ├── nginx.conf
    ├── .env.example     # Template — copy and fill in
    ├── .env             # Your secrets — DO NOT commit!
    └── db/
        └── init.sql     # Database schema (auto-runs on first start)
```

---

## Deploy Script Behavior

On **first run** (no existing deployment detected):
1. Prompts to create `.env` with database credentials
2. Copies `Dockerfile`s, `nginx.conf`, and `db/` to the project root
3. Runs `docker compose up --build -d`

On **subsequent runs** (existing deployment detected):

```
What would you like to do?
  1) Start normally          (docker compose up -d)
  2) Restart without rebuild (docker compose restart)
  3) Rebuild and restart     (docker compose up --build -d)
  4) Exit without changes
```

> The script detects an existing deployment by checking for the Docker volume `userstory_mariadb_data`.

---

## Environment Variables

All variables are stored in `config/.env` (created on first run).

| Variable                   | Description                        |
|----------------------------|------------------------------------|
| `DB_ROOT_PASSWORD`         | MariaDB root password              |
| `DB_USERSTORYPROJ_USER`    | Application database user          |
| `DB_USERSTORYPROJ_PASSWORD`| Application database user password |
| `PROJECT_DIR`              | Absolute path to project root      |

> `PROJECT_DIR` is set and updated automatically by the deploy script on every run. You do not need to set it manually.

To create `.env` manually from the template:

```bash
cp config/.env.example config/.env
# then edit config/.env with your values
```

---

## Database Initialization

On first start, MariaDB automatically runs `config/db/init.sql`, which creates:

```sql
CREATE DATABASE IF NOT EXISTS userstory;

CREATE TABLE IF NOT EXISTS projects (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    description VARCHAR(255),
    name        VARCHAR(255),
    PRIMARY KEY (id)
);
```

> This runs **only once** — when the `userstory_mariadb_data` volume is empty. To reset the database, use the cleanup script with level **Full** or **Nuclear**.

---

## Cleanup Script

Stops containers and removes files created by the deploy script.

```powershell
.\cleanup.ps1   # Windows
./cleanup.sh    # Linux/macOS
```

### Cleanup Levels

| Level      | Stops containers | Removes volume (DB data) | Removes Docker images | Removes copied files |
|------------|:----------------:|:------------------------:|:---------------------:|:--------------------:|
| **Soft**   | ✅               | ❌                        | ❌                    | ✅                   |
| **Full**   | ✅               | ✅                        | ❌                    | ✅                   |
| **Nuclear**| ✅               | ✅                        | ✅                    | ✅                   |

> ⚠️ **Full** and **Nuclear** levels are irreversible — all database data will be lost.

**Copied files removed by cleanup:**
```
backend/Dockerfile
frontend/Dockerfile
frontend/nginx.conf
db/
```

---

## Useful Docker Commands

```bash
# View running containers
docker compose -f config/docker-compose.yml ps

# View logs
docker compose -f config/docker-compose.yml logs -f

# View logs for a specific service
docker compose -f config/docker-compose.yml logs -f backend

# Stop without removing
docker compose -f config/docker-compose.yml stop

# Open a shell in the database container
docker exec -it userstory-db-1 mariadb -u userstorydb -p userstory
```

---

## Container & Volume Names

Thanks to `name: userstory` in `docker-compose.yml`, all names are fixed regardless of which directory you run from:

| Resource          | Name                       |
|-------------------|----------------------------|
| Backend container | `userstory-backend-1`      |
| Frontend container| `userstory-frontend-1`     |
| DB container      | `userstory-db-1`           |
| DB volume         | `userstory_mariadb_data`   |

---

## .gitignore

Make sure the following is in your `.gitignore`:

```gitignore
devops/docker/config/.env
```
