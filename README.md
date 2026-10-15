# SQL Injection to Root Privilege Escalation Lab

Lab cybersecurity praktikum terisolasi berbasis Docker yang melatih alur penyerangan lengkap (Full Attack Chain): dari kerentanan aplikasi web (SQL Injection) hingga eskalasi hak istimewa (Privilege Escalation) ke akun root di lingkungan Linux.

Lab ini dirancang khusus untuk pembelajaran siswa SMK, mahasiswa, dan pemula cybersecurity dalam memahami interaksi nyata antara kelemahan backend web, database internal, kredensial sistem, dan konfigurasi Linux.

---

> [!CAUTION]
> **PERINGATAN KEAMANAN**: Lingkungan ini sengaja dibuat rentan (*vulnerable by design*). Jalankan lab ini **hanya** pada komputer lokal atau jaringan privat terisolasi. Jangan pernah mempublikasikan port lab ini ke internet publik.

---

## 1. Alur Tantangan (Attack Chain)

1. **Tahap 1 — SQL Injection Login**:
   - Eksploitasi bypass autentikasi SQL Injection pada portal login web.
   - Mengakses Dashboard dan mengklaim **Flag 1** (`FLAG{SQLI_LOGIN_BYPASS}`).
2. **Tahap 2 — Enumerasi Database via Katalog Produk**:
   - Analisis parameter kategori produk yang rentan terhadap UNION-based SQL Injection.
   - Enumerasi skema database PostgreSQL internal untuk menemukan tabel rahasia.
   - Mengambil **Flag 2** (`FLAG{DATABASE_ENUMERATION}`) dari tabel `challenge_flags`.
   - Mengambil kredensial SSH akun `student` dari tabel `system_credentials`.
3. **Tahap 3 — Akses Shell SSH dan Enumerasi Linux**:
   - Login ke OpenSSH server container menggunakan akun `student`.
   - Menemukan dan membaca **Flag 3** (`FLAG{USER_SHELL_ACQUIRED}`) di home directory.
   - Melakukan enumerasi sistem Linux untuk mencari kelemahan izin hak akses.
4. **Tahap 4 — Linux Privilege Escalation ke Root**:
   - Menemukan program binary SUID `/usr/local/bin/syshealth`.
   - Mengeksploitasi kerentanan pemanggilan perintah relatif melalui teknik **PATH Hijacking**.
   - Memperoleh root shell interaktif di dalam container.
   - Membaca **Flag 4** (`FLAG{ROOT_COMPROMISED}`) di `/root/root.flag`.

---

## 2. Persyaratan Sistem

- **Sistem Operasi**: Linux / macOS / Windows (dengan WSL2).
- **Docker Engine**: Versi 20.10+ (atau Docker Desktop).
- **Docker Compose**: Versi 2.0+ (perintah `docker compose`).
- **Port Tersedia**:
  - `8000` (Web Application HTTP)
  - `2223` (OpenSSH Service Target)

---

## 3. Instalasi dan Menjalankan Lab

### 1. Clone atau Buka Direktori Proyek
```bash
cd /home/mik/Projects/SQL_lab.1.0
```

### 2. Salin Konfigurasi Environment (Opsional jika ingin mengubah port)
```bash
cp .env.example .env
```
Default port: `WEB_PORT=8000`, `SSH_PORT=2223`.

### 3. Build dan Jalankan Kontainer
```bash
docker compose up -d --build
```

### 4. Periksa Status Layanan
```bash
docker compose ps
```
Kedua layanan (`sqli_lab_db` dan `sqli_lab_web`) harus berstatus `Up` / `Healthy`.

---

## 4. Akses Layanan

| Layanan | Protokol | Alamat / Endpoint | Port Host | Deskripsi |
|---|---|---|---|---|
| **Portal Web** | HTTP | `http://localhost:8000/` | `8000` | Antarmuka web Django siswa |
| **OpenSSH** | SSH | `ssh student@localhost -p 2223` | `2223` | Akses shell Linux target |
| **PostgreSQL** | TCP | `db:5432` | *Internal Only* | Database terisolasi dalam Docker |

---

## 5. Akses Root Administrator (Maintainer Mode)

Sebagai instruktur atau maintainer lab, Anda dapat langsung masuk ke container target dengan hak root penuh melalui Docker tanpa harus menyelesaikan tantangan:

```bash
docker compose exec -u 0 web /bin/bash
```

Perintah ini memberikan interactive root bash shell di dalam container `sqli_lab_web` untuk pemeliharaan, inspeksi, atau penilaian.

---

## 6. Prosedur Reset dan Pemulihan

Jika database telah diubah atau siswa selesai mengerjakan latihan, jalankan script reset:

### Soft Reset (Cepat & In-Place)
Mengembalikan tabel database ke seed data awal, menghapus file exploit di `/tmp/`, dan mereset permission tanpa mematikan container:
```bash
./reset.sh
```

### Full Reset (Hard Clean)
Menghapus volume Docker `pgdata`, menghapus container, dan membangun ulang dari awal:
```bash
./reset.sh --full
```

### Menghentikan Lab
```bash
docker compose down
```

---

## 7. Monitoring dan Log

Untuk melihat log aktivitas real-time aplikasi web dan service:
```bash
# Log seluruh layanan
docker compose logs -f

# Log khusus layanan web
docker compose logs -f web

# Log khusus database PostgreSQL
docker compose logs -f db
```

---

## 8. Panduan Dokumentasi Lengkap

- [Arsitektur Sistem](docs/architecture.md): Diagram alur, komponen sistem, dan isolasi jaringan.
- [Prosedur Pengujian](docs/testing.md): Langkah-langkah verifikasi manual dan kriteria penerimaan.
- [Panduan Reset](docs/reset.md): Detail teknis pemulihan lab dan pengelolaan volume persisten.

---

## 9. Troubleshooting Umum

1. **Port 8000 atau 2223 bentrok dengan service lain di host**:
   Edit file `.env`, ubah `WEB_PORT` atau `SSH_PORT` ke nomor port lain (misalnya `8080` dan `2224`), lalu jalankan:
   ```bash
   docker compose up -d
   ```
2. **Container DB lambat siap**:
   Layanan `web` menggunakan `condition: service_healthy` pada database sebelum menyala. Tunggu beberapa detik hingga postgres menyelesaikan inisialisasi awal.
3. **Koneksi SSH ditolak (Host key changed)**:
   Jika Anda melakukan rebuild, host key SSH baru akan digenerate. Bersihkan entry host key lama di komputer Anda:
   ```bash
   ssh-keygen -f "$HOME/.ssh/known_hosts" -R "[localhost]:2223"
   ```
