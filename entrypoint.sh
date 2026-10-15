#!/bin/bash
set -e

# ======================================================================
# Container Entrypoint Script for CyberLab
# Starts SSH daemon, initializes challenge environment, and launches Django
# ======================================================================

echo "=========================================================="
echo " Starting CyberLab Target Services"
echo "=========================================================="

# 1. Initialize Challenge Environment (Users, SUID Privesc, Flags)
echo "[*] Running challenge setup..."
bash /app/linux/challenge-setup.sh

# 2. Configure and Start SSH Daemon
echo "[*] Initializing OpenSSH Server..."
mkdir -p /run/sshd
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -A
fi
/usr/sbin/sshd
echo "[+] OpenSSH Server started on port 22."

# 3. Wait for PostgreSQL Database
DB_HOST="${DB_HOST:-db}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-labuser}"
DB_NAME="${DB_NAME:-cyberlab}"
DB_PASS="${DB_PASS:-labpassword123}"

echo "[*] Waiting for PostgreSQL ($DB_HOST:$DB_PORT)..."
export PGPASSWORD="$DB_PASS"
MAX_TRIES=30
TRIES=0
until pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; do
    TRIES=$((TRIES + 1))
    if [ $TRIES -ge $MAX_TRIES ]; then
        echo "[-] Timeout waiting for database connection."
        break
    fi
    sleep 1
done
echo "[+] PostgreSQL connection established."

# Ensure database tables are created if not already populated
TABLE_CHECK=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT to_regclass('products');" 2>/dev/null || echo "")
if [[ "$TABLE_CHECK" != *"products"* ]]; then
    echo "[*] Initializing database tables from init.sql..."
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f /app/database/init.sql
    echo "[+] Database tables initialized."
else
    echo "[+] Database schema already present."
fi

# 4. Start Django Web Application
echo "[*] Starting Django Web Application on port 8000..."
cd /app/web
exec python manage.py runserver 0.0.0.0:8000
