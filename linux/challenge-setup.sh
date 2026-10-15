#!/bin/bash
set -e

# ======================================================================
# Challenge Setup and Permissions Initialization Script
# ======================================================================

echo "[*] Initializing challenge environment..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAGS_DIR="$(cd "$SCRIPT_DIR/../flags" && pwd)"

# 1. Setup Linux Student User
bash "$SCRIPT_DIR/users.sh"

# 2. Setup SUID Privilege Escalation Challenge
echo "[*] Compiling and configuring SUID binary /usr/local/bin/syshealth..."
gcc -Wall -O2 "$SCRIPT_DIR/privesc/syshealth.c" -o /usr/local/bin/syshealth
chown root:root /usr/local/bin/syshealth
chmod 4755 /usr/local/bin/syshealth

# 3. Setup default healthcheck binary
echo "[*] Installing default /usr/local/bin/healthcheck..."
cp "$SCRIPT_DIR/privesc/healthcheck.sh" /usr/local/bin/healthcheck
chown root:root /usr/local/bin/healthcheck
chmod 755 /usr/local/bin/healthcheck

# 4. Deploy User Flag (Stage 3)
echo "[*] Deploying Stage 3 User Flag..."
if [ -f "$FLAGS_DIR/user.flag" ]; then
    cp "$FLAGS_DIR/user.flag" /home/student/user.flag
else
    echo "FLAG{USER_SHELL_ACQUIRED}" > /home/student/user.flag
fi
chown student:student /home/student/user.flag
chmod 644 /home/student/user.flag

# 5. Deploy Student Hint / Notes
cat << 'EOF' > /home/student/notes.txt
======================================================================
 CYBERLAB LINUX SYSTEM - INTERNAL NOTE FOR STUDENT
======================================================================

Selamat! Anda berhasil mendapatkan akses shell Linux melalui kredensial
yang diperoleh dari enumerasi database.

Tugas Anda saat ini:
1. Periksa file flag user di direktori ini:
   cat user.flag

2. Lakukan enumerasi sistem Linux untuk mencari jalur Privilege Escalation:
   - Periksa binary SUID yang mencurigakan di sistem:
     find / -perm -4000 -type f 2>/dev/null
   - Periksa utilitas kustom administrator yang terpasang di /usr/local/bin
   - Periksa bagaimana binary tersebut berinteraksi dengan environment PATH

3. Dapatkan hak akses root di dalam container ini.

4. Baca root flag di lokasi aman:
   /root/root.flag
======================================================================
EOF
chown student:student /home/student/notes.txt
chmod 644 /home/student/notes.txt

# 6. Deploy Root Flag (Stage 4)
echo "[*] Deploying Stage 4 Root Flag..."
if [ -f "$FLAGS_DIR/root.flag" ]; then
    cp "$FLAGS_DIR/root.flag" /root/root.flag
else
    echo "FLAG{ROOT_COMPROMISED}" > /root/root.flag
fi
chown root:root /root/root.flag
chmod 600 /root/root.flag
chmod 700 /root

# Ensure /tmp is world-writable with sticky bit for CTF exploit creation
chmod 1777 /tmp

echo "[+] Challenge environment successfully configured."
