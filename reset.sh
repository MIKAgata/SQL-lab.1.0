#!/bin/bash
set -e

# ======================================================================
# CyberLab Reset Script
# Restores database, flags, user accounts, and challenge permissions
# ======================================================================

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}==========================================================${NC}"
echo -e "${CYAN}             CYBERLAB RESET & RECOVERY UTILITY            ${NC}"
echo -e "${CYAN}==========================================================${NC}"

MODE="soft"
if [ "$1" == "--full" ] || [ "$1" == "-f" ]; then
    MODE="full"
fi

if [ "$MODE" == "full" ]; then
    echo -e "${YELLOW}[!] WARNING: Full reset selected!${NC}"
    echo -e "${YELLOW}[!] This will stop all containers and WIPE all persistent volumes (pgdata).${NC}"
    read -p "Are you sure you want to proceed with full reset? (y/N): " -r CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${RED}[*] Reset canceled.${NC}"
        exit 0
    fi

    echo -e "${CYAN}[*] Tearing down containers and removing volumes...${NC}"
    docker compose down -v

    echo -e "${CYAN}[*] Rebuilding and launching clean containers...${NC}"
    docker compose up -d --build

    echo -e "${GREEN}[+] Full reset completed successfully.${NC}"
    exit 0
fi

# Default: Soft / In-place reset
echo -e "${CYAN}[*] Performing in-place challenge and database reset...${NC}"

# Check if containers are running
if ! docker compose ps --services --filter "status=running" | grep -q "web"; then
    echo -e "${YELLOW}[!] Containers are not currently running. Starting them up...${NC}"
    docker compose up -d
fi

# 1. Reset Database State
echo -e "${CYAN}[*] Resetting PostgreSQL database tables to initial seed data...${NC}"
docker compose exec -T -u 0 web bash -c "
    export PGPASSWORD=\"\$DB_PASS\"
    psql -h \"\$DB_HOST\" -p \"\$DB_PORT\" -U \"\$DB_USER\" -d \"\$DB_NAME\" -f /app/database/init.sql >/dev/null 2>&1
"
echo -e "${GREEN}[+] Database restored.${NC}"

# 2. Clean Up Exploits in /tmp
echo -e "${CYAN}[*] Cleaning up temporary exploit payloads in /tmp...${NC}"
docker compose exec -T -u 0 web bash -c "
    rm -rf /tmp/healthcheck /tmp/*.sh /tmp/*.py /tmp/*.txt /tmp/root_* 2>/dev/null || true
"

# 3. Restore Linux Challenge State (Users, Flags, SUID permissions)
echo -e "${CYAN}[*] Restoring Linux challenge files, SUID permissions, and flags...${NC}"
docker compose exec -T -u 0 web bash /app/linux/challenge-setup.sh

echo -e "${GREEN}[+] Challenge environment restored to original state.${NC}"
echo -e "${GREEN}[+] Student password reset to: student_ctf_p4ssw0rd!${NC}"
echo -e "${CYAN}==========================================================${NC}"
