#!/bin/bash
# ---------------------------------------------------------
#  deploy.sh
#  Copies Dockerfiles to project folders and starts
#  docker-compose for DevOpsProject-UserStory
# ---------------------------------------------------------

set -e

# -- Colors ------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# -- Paths -------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
VOLUME_NAME="userstory_mariadb_data"
export COMPOSE_PROJECT_NAME="userstory"
START_DIR="$(pwd)"

# -- Restore directory on exit ----------------------------
cleanup_dir() { cd "$START_DIR"; }
trap cleanup_dir EXIT

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════╗"
echo "║        DevOpsProject-UserStory           ║"
echo "║              Docker Deploy               ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# -- Check Docker ------------------------------------------
if ! command -v docker &>/dev/null; then
    echo -e "${RED}[ERROR] Docker not found. Install Docker and try again.${NC}"
    exit 1
fi
if ! docker compose version &>/dev/null; then
    echo -e "${RED}[ERROR] Docker Compose not found.${NC}"
    exit 1
fi

# -- Function: setup .env ----------------------------------
setup_env() {
    echo ""
    echo -e "${CYAN}Setting up environment variables (.env)${NC}"
    echo ""

    # DB_ROOT_PASSWORD - required, hidden
    while [[ -z "$INPUT_ROOT_PASS" ]]; do
        read -rsp "  DB_ROOT_PASSWORD (MariaDB root password): " INPUT_ROOT_PASS
        echo ""
        [[ -z "$INPUT_ROOT_PASS" ]] && echo -e "  ${RED}[X] Password cannot be empty${NC}"
    done
    DB_ROOT_PASSWORD="$INPUT_ROOT_PASS"

    # DB_USERSTORYPROJ_USER - optional
    read -rp "  DB_USERSTORYPROJ_USER (database user) [userstorydb]: " INPUT_DB_USER
    DB_USERSTORYPROJ_USER="${INPUT_DB_USER:-userstorydb}"

    # DB_USERSTORYPROJ_PASSWORD - required, hidden
    while [[ -z "$INPUT_PASS" ]]; do
        read -rsp "  DB_USERSTORYPROJ_PASSWORD (database user password): " INPUT_PASS
        echo ""
        [[ -z "$INPUT_PASS" ]] && echo -e "  ${RED}[X] Password cannot be empty${NC}"
    done
    DB_USERSTORYPROJ_PASSWORD="$INPUT_PASS"

    cat > "$CONFIG_DIR/.env" <<EOL
COMPOSE_PROJECT_NAME=userstory
DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
DB_USERSTORYPROJ_USER=${DB_USERSTORYPROJ_USER}
DB_USERSTORYPROJ_PASSWORD=${DB_USERSTORYPROJ_PASSWORD}
PROJECT_DIR=${PROJECT_DIR}
EOL

    echo ""
    echo -e "  ${GREEN}[OK]${NC} .env created successfully"
    echo ""
}

# -- Check .env --------------------------------------------
if [[ ! -f "$CONFIG_DIR/.env" ]]; then
    echo -e "${YELLOW}[WARN] .env file not found.${NC}"

    if [[ ! -f "$CONFIG_DIR/.env.example" ]]; then
        echo -e "${RED}[ERROR] .env.example not found. Check project structure.${NC}"
        exit 1
    fi

    echo -e "Choose an option:"
    echo -e "  ${GREEN}1)${NC} Enter values now (interactive)"
    echo -e "  ${GREEN}2)${NC} Copy .env.example and fill in manually later"
    echo ""
    read -rp "Your choice [1/2]: " ENV_CHOICE

    case "$ENV_CHOICE" in
        1) setup_env ;;
        2)
            cp "$CONFIG_DIR/.env.example" "$CONFIG_DIR/.env"
            echo -e "${YELLOW}[WARN] Edit $CONFIG_DIR/.env and run the script again.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}[ERROR] Invalid choice. Exiting.${NC}"
            exit 1
            ;;
    esac
fi

# -- Set working dir and update PROJECT_DIR in .env --------
cd "$CONFIG_DIR"
grep -v "^PROJECT_DIR=" "$CONFIG_DIR/.env" > "$CONFIG_DIR/.env.tmp"
echo "PROJECT_DIR=${PROJECT_DIR}" >> "$CONFIG_DIR/.env.tmp"
mv "$CONFIG_DIR/.env.tmp" "$CONFIG_DIR/.env"

# -- Check if first deploy or re-deploy --------------------
if docker volume inspect "$VOLUME_NAME" &>/dev/null; then

    # ── RE-DEPLOY ─────────────────────────────────────────
    echo -e "${YELLOW}[INFO] Existing deployment detected (volume: $VOLUME_NAME)${NC}"
    echo ""

    RUNNING=$(docker compose ps --services --filter "status=running" 2>/dev/null \
              | grep -v '^$' | wc -l | tr -d ' ')

    if [[ "$RUNNING" -gt 0 ]]; then
        echo -e "${GREEN}[INFO] Containers are running:${NC}"
        docker compose ps --format "table {{.Name}}\t{{.Status}}"
    else
        echo -e "${YELLOW}[INFO] Containers are stopped.${NC}"
    fi

    echo ""
    echo -e "What would you like to do?"
    echo -e "  ${GREEN}1)${NC} Start normally          (docker compose up -d)"
    echo -e "  ${GREEN}2)${NC} Restart without rebuild (docker compose restart)"
    echo -e "  ${GREEN}3)${NC} Rebuild and restart     (docker compose up --build -d)"
    echo -e "  ${GREEN}4)${NC} Exit without changes"
    echo ""
    read -rp "Your choice [1/2/3/4]: " CHOICE

    case "$CHOICE" in
        1)
            echo -e "${CYAN}Starting containers...${NC}"
            docker compose up -d
            ;;
        2)
            echo -e "${CYAN}Restarting containers...${NC}"
            docker compose restart
            ;;
        3)
            echo -e "${CYAN}Rebuilding and restarting...${NC}"
            docker compose up --build -d
            ;;
        4)
            echo -e "${YELLOW}Exit without changes.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}[ERROR] Invalid choice. Exiting.${NC}"
            exit 1
            ;;
    esac

else

    # ── FIRST DEPLOY ──────────────────────────────────────
    echo -e "${CYAN}[1/3] First deploy — copying files...${NC}"

    cp "$CONFIG_DIR/backend.Dockerfile"  "$PROJECT_DIR/backend/Dockerfile"
    echo -e "  ${GREEN}[OK]${NC} backend/Dockerfile"

    cp "$CONFIG_DIR/frontend.Dockerfile" "$PROJECT_DIR/frontend/Dockerfile"
    echo -e "  ${GREEN}[OK]${NC} frontend/Dockerfile"

    cp "$CONFIG_DIR/nginx.conf.example" "$PROJECT_DIR/frontend/nginx.conf"
    echo -e "  ${GREEN}[OK]${NC} frontend/nginx.conf"

    mkdir -p "$PROJECT_DIR/db-init"
    cp -r "$CONFIG_DIR/db-init/"* "$PROJECT_DIR/db/"
    echo -e "  ${GREEN}[OK]${NC} db/ (init.sql)"

    echo ""
    echo -e "${CYAN}[2/3] Starting containers...${NC}"
    docker compose up --build -d

fi

# -- Result ------------------------------------------------
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Started successfully!  [OK]     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "Container status:"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
echo ""