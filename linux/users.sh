#!/bin/bash
set -e

# ======================================================================
# Linux User Setup Script
# Creates student user with credentials matching system_credentials table
# ======================================================================

STUDENT_USER="student"
STUDENT_PASS="student_ctf_p4ssw0rd!"

echo "[*] Setting up Linux student user..."

if id "$STUDENT_USER" &>/dev/null; then
    echo "[*] User $STUDENT_USER already exists. Updating password..."
    echo "$STUDENT_USER:$STUDENT_PASS" | chpasswd
else
    echo "[*] Creating user $STUDENT_USER..."
    useradd -m -s /bin/bash "$STUDENT_USER"
    echo "$STUDENT_USER:$STUDENT_PASS" | chpasswd
fi

# Ensure student is not in sudo or wheel groups
gpasswd -d "$STUDENT_USER" sudo 2>/dev/null || true
gpasswd -d "$STUDENT_USER" wheel 2>/dev/null || true

# Lock down student home directory permissions
chmod 750 "/home/$STUDENT_USER"
chown "$STUDENT_USER:$STUDENT_USER" "/home/$STUDENT_USER"

echo "[+] Student user configured successfully."
