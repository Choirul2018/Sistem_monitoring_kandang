# Panduan Sistem Monitoring Kandang (Full Installation & Production)

Panduan ini mencakup instalasi Backend (Laravel Filament) dan Frontend (Flutter) untuk lingkungan pengembangan maupun produksi.

---

## 1. Persyaratan Sistem
- **PHP**: ^8.2 (Pastikan ekstensi `gd`, `intl`, `zip`, `sqlite3` aktif)
- **Composer**: Untuk dependency Laravel
- **Node.js & NPM**: Untuk build asset
- **Flutter SDK**: Versi terbaru
- **Web Server**: Apache/Nginx (untuk Production)

---

## 2. Instalasi Backend (Laravel)

### Step 1: Persiapan Project
```bash
# Clone project (jika dari git)
# Masuk ke folder backend
composer install
cp .env.example .env
php artisan key:generate
```

### Step 2: Konfigurasi Database
Buka file `.env` dan sesuaikan koneksi database Anda (MySQL/PostgreSQL/SQLite).
```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=monitoring_kandang
DB_USERNAME=root
DB_PASSWORD=
```

### Step 3: Migrasi & Data Master
```bash
php artisan migrate:fresh --seed
# Ini akan membuat user admin: admin / password
```

### Step 4: Storage Link (PENTING untuk Foto)
Agar foto yang diupload dari Flutter bisa muncul di Admin Panel:
```bash
php artisan storage:link
```

---

## 3. Instalasi Frontend (Flutter)

### Step 1: Jalankan Project
```bash
flutter pub get
```

### Step 2: Konfigurasi API
Buka file `lib/core/network/api_client.dart` dan sesuaikan `baseUrl`:
- **Chrome/Localhost**: `http://localhost:8000/api`
- **Emulator Android**: `http://10.0.2.2:8000/api`
- **HP Fisik**: Isikan IP WiFi laptop Anda (contoh: `http://192.168.1.5:8000/api`)

---

## 4. Panduan Production (Deploy ke Server)

Untuk menjalankan Laravel secara publik, pastikan folder root web server Anda diarahkan ke folder `/public`, bukan root project.

### Step 1: Konfigurasi .env (Production)
```env
APP_ENV=production
APP_DEBUG=false
APP_URL=https://nama-domain-anda.com

# Aktifkan HTTPS jika sudah ada SSL
FORCE_HTTPS=true
```

### Step 2: Optimasi Laravel
Jalankan perintah ini di server agar loading lebih cepat:
```bash
php artisan config:cache
php artisan route:cache
php artisan view:cache
```

### Step 3: Pengaturan Folder Public (Shared Hosting)
Jika Anda menggunakan Shared Hosting tanpa akses SSH, pindahkan seluruh isi folder `/public` ke `public_html`, lalu sesuaikan file `index.php` untuk mengarah ke lokasi folder core Laravel yang baru.

### Step 4: Konfigurasi CORS (PENTING untuk Flutter Web)
Buka `config/cors.php` dan pastikan domain Flutter Web Anda sudah diizinkan:
```php
'allowed_origins' => ['*'], // Gunakan '*' untuk awal, lalu ganti dengan domain asli nanti
```

---

## 5. Troubleshooting (Masalah Umum)
- **Error 401 Unauthorized**: Lakukan Login ulang. Ini terjadi jika database barusan di-reset (id token lama hilang).
- **Error 404 Not Found**: Pastikan `php artisan serve` berjalan atau Apache RewriteRule sudah aktif.
- **Foto Tidak Muncul**: Pastikan sudah menjalankan `php artisan storage:link`.
- **Lokasi Tidak Muncul**: Cek `AuditSyncController.php` di Laravel, pastikan kolom `parts` sudah di-Select.

---

*Terakhir diperbarui: 24 April 2026 - Antigravity AI Assistant*