#!/bin/bash
# ---------------------------------------------------------
#  cleanup.sh
#  Stops and removes containers, images, volumes
#  for DevOpsProject-UserStory
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

echo -e "${RED}"
echo "╔══════════════════════════════════════════╗"
echo "║        DevOpsProject-UserStory           ║"
echo "║              Docker Cleanup              ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# -- Check Docker ------------------------------------------
if ! command -v docker &> /dev/null; then
    echo -e "${RED}[ERROR] Docker not found.${NC}"
    exit 1
fi

# -- Check if anything was ever deployed -------------------
cd "$CONFIG_DIR"

VOLUME_EXISTS=false
docker volume inspect "$VOLUME_NAME" &>/dev/null && VOLUME_EXISTS=true

COPIED_FILES=(
    "$PROJECT_DIR/backend/Dockerfile"
    "$PROJECT_DIR/frontend/Dockerfile"
    "$PROJECT_DIR/frontend/nginx.conf"
    "$PROJECT_DIR/db"
)

FILES_EXIST=false
for F in "${COPIED_FILES[@]}"; do
    if [ -e "$F" ]; then
        FILES_EXIST=true
        break
    fi
done

if ! $VOLUME_EXISTS && ! $FILES_EXIST; then
    echo -e "${YELLOW}[INFO] No existing deployment found.${NC}"
    echo -e "${YELLOW}       Volume $VOLUME_NAME not detected and no copied files found.${NC}"
    exit 0
fi

echo ""
if $VOLUME_EXISTS; then
    echo -e "  ${GREEN}[found]${NC} Volume: $VOLUME_NAME"
else
    echo -e "  ${YELLOW}[none] ${NC} Volume: $VOLUME_NAME not found"
fi

for F in "${COPIED_FILES[@]}"; do
    if [ -e "$F" ]; then
        RELATIVE="${F#$PROJECT_DIR/}"
        echo -e "  ${GREEN}[found]${NC} File:   $RELATIVE"
    fi
done
echo ""

# -- Select cleanup level ----------------------------------
echo -e "Select cleanup level:\n"
echo -e "  ${GREEN}1)${NC} Soft    - stop containers, remove copied files"
echo -e "  ${GREEN}2)${NC} Full    - + remove volume  ${RED}(database data will be lost!)${NC}"
echo -e "  ${GREEN}3)${NC} Nuclear - + remove Docker images"
echo -e "  ${GREEN}4)${NC} Exit without changes"
echo ""
read -rp "Your choice [1/2/3/4]: " LEVEL

case "$LEVEL" in
    1|2|3) ;;
    4)
        echo -e "${YELLOW}Exit without changes.${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}[ERROR] Invalid choice. Exiting.${NC}"
        exit 1
        ;;
esac

# -- Confirm -----------------------------------------------
echo ""
if [[ "$LEVEL" == "2" || "$LEVEL" == "3" ]]; then
    echo -e "${RED}!! WARNING: This action is irreversible! Database data will be deleted! !!${NC}"
fi
read -rp "Continue? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cancelled.${NC}"
    exit 0
fi

echo ""

# -- Step 1: Stop and remove containers -------------------
echo -e "${CYAN}[1/3] Stopping containers...${NC}"

HAS_CONTAINERS=false
if docker compose ps -q 2>/dev/null | grep -q .; then
    HAS_CONTAINERS=true
fi

if [[ "$LEVEL" == "2" || "$LEVEL" == "3" ]]; then
    docker compose down -v 2>/dev/null || true
    if $HAS_CONTAINERS; then
        echo -e "  ${GREEN}[OK]${NC} Containers stopped, volume removed"
    else
        echo -e "  ${YELLOW}[--]${NC} No containers were running, volume removed"
    fi
else
    docker compose down 2>/dev/null || true
    if $HAS_CONTAINERS; then
        echo -e "  ${GREEN}[OK]${NC} Containers stopped"
    else
        echo -e "  ${YELLOW}[--]${NC} No containers were running"
    fi
fi

# -- Step 2: Remove Docker images -------------------------
echo ""
if [[ "$LEVEL" == "3" ]]; then
    echo -e "${CYAN}[2/3] Removing Docker images...${NC}"

    for IMAGE in "userstory-backend" "userstory-frontend"; do
        if docker image inspect "$IMAGE" &>/dev/null; then
            docker rmi "$IMAGE"
            echo -e "  ${GREEN}[OK]${NC} Removed image: $IMAGE"
        else
            echo -e "  ${YELLOW}[--]${NC} Image not found: $IMAGE"
        fi
    done
else
    echo -e "${YELLOW}[2/3] Image removal - skipped${NC}"
fi

# -- Step 3: Remove copied files --------------------------
echo ""
echo -e "${CYAN}[3/3] Removing copied files...${NC}"

FILES_TO_REMOVE=(
    "$PROJECT_DIR/backend/Dockerfile"
    "$PROJECT_DIR/frontend/Dockerfile"
    "$PROJECT_DIR/frontend/nginx.conf"
)

for FILE in "${FILES_TO_REMOVE[@]}"; do
    if [ -f "$FILE" ]; then
        rm "$FILE"
        RELATIVE="${FILE#$PROJECT_DIR/}"
        echo -e "  ${GREEN}[OK]${NC} Removed: $RELATIVE"
    else
        RELATIVE="${FILE#$PROJECT_DIR/}"
        echo -e "  ${YELLOW}[--]${NC} Not found: $RELATIVE"
    fi
done

if [ -d "$PROJECT_DIR/db" ]; then
    rm -rf "$PROJECT_DIR/db"
    echo -e "  ${GREEN}[OK]${NC} Removed: db/"
else
    echo -e "  ${YELLOW}[--]${NC} Not found: db/"
fi

cd "$SCRIPT_DIR"

# -- Result -----------------------------------------------
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Cleanup complete!  [OK]        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""

case "$LEVEL" in
    1) echo -e "  Done: containers stopped, copied files removed" ;;
    2) echo -e "  Done: containers + volume removed, files removed" ;;
    3) echo -e "  Done: containers + volume + images removed, files removed" ;;
esac

echo ""
echo -e "  To deploy again: ${CYAN}./deploy.sh${NC}"
echo ""