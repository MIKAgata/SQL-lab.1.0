# Panduan Prosedur Reset dan Pemulihan Lab

Dokumen ini mendokumentasikan mekanisme pemulihan kondisi awal (reset) pada lab **SQL Injection to Root Privilege Escalation**.

---

## 1. Konsep dan Filosofi Reset

Selama siswa mengeksploitasi lab:
1. File exploit, binary palsu, atau skrip dapat tertinggal di `/tmp/`.
2. Password user `student` dapat saja diubah secara sengaja atau tidak sengaja.
3. Baris atau tabel di database dapat terhapus atau termodifikasi akibat SQL Injection bertingkat.
4. Permission SUID atau flag dapat terganggu.

Untuk memfasilitasi penggunaan berulang (misal untuk kelas berikutnya atau pengujian berulang), disediakan dua level reset:
- **Soft Reset (In-Place)**: Mengembalikan state database, file, dan hak akses tanpa mematikan atau membuat ulang container.
- **Full Reset (Hard)**: Memusnahkan container dan menghapus persistent volume database, lalu membangun ulang secara bersih.

---

## 2. Prosedur Soft Reset (Direkomendasikan)

Gunakan metode ini untuk membersihkan sisa pengerjaan siswa tanpa downtime panjang:

```bash
./reset.sh
```

### Apa yang Dilakukan Soft Reset?
1. **Memulihkan Database**:
   Mengeksekusi ulang file `database/init.sql` ke dalam container PostgreSQL. Semua tabel `products`, `categories`, `challenge_flags`, `system_credentials`, dan `app_users` di-drop dan di-seed ulang.
2. **Membersihkan File Sementara**:
   Menghapus payload di `/tmp/` seperti `/tmp/healthcheck`, skrip exploit, atau file dump root.
3. **Memulihkan Hak Akses & Akun**:
   Menjalankan ulang `/app/linux/challenge-setup.sh`:
   - Password `student` dipulihkan ke `student_ctf_p4ssw0rd!`.
   - Menghapus `student` dari grup administratif.
   - Mengompilasi ulang binary SUID `/usr/local/bin/syshealth` dengan permission `4755`.
   - Mengembalikan permission `0600` pada `/root/root.flag`.
   - Mengembalikan flag user di `/home/student/user.flag`.

Waktu eksekusi: **~2 detik**.

---

## 3. Prosedur Full Reset (Pemusnahan Volume)

Gunakan metode ini jika terjadi kerusakan struktur container, kesalahan konfigurasi library, atau saat ingin membersihkan seluruh cache Docker.

> [!WARNING]
> Full reset akan menghapus volume persisten `pgdata` dan menghentikan seluruh layanan sementara waktu.

Perintah:
```bash
./reset.sh --full
```
Atau manual melalui Docker Compose:
```bash
docker compose down -v
docker compose up -d --build
```

---

## 4. Penjelasan Persistent Volume

Lab ini mendefinisikan satu Docker Volume bernama `pgdata`:
- Volume ini terpasang pada `/var/lib/postgresql/data` di layanan `db`.
- Tujuan: Menjaga persistensi data selama restart kontainer standar (`docker compose restart` atau `docker compose down` tanpa `-v`).
- Ketika menjalankan `docker compose down`, volume **tidak dihapus secara default**.
- Volume hanya akan dihapus jika administrator secara eksplisit memberikan flag `-v` atau `--volumes`.

---

## 5. Pemeriksaan Setelah Reset

Setelah menjalankan reset, lakukan verifikasi cepat:
```bash
# 1. Periksa container berjalan
docker compose ps

# 2. Periksa HTTP login merespons
curl -I http://localhost:8000/login/

# 3. Periksa port SSH terbuka
nc -zv localhost 2223
```
