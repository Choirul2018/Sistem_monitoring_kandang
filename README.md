# Sistem Monitoring Kandang

Aplikasi monitoring dan audit kandang berbasis Flutter dengan pendekatan *offline-first* menggunakan Hive dan Supabase.

## Alur Program (Workflow)

Berikut adalah ringkasan alur penggunaan aplikasi Sistem Monitoring Kandang:

### 1. Autentikasi & Dashboard
*   **Login**: Pengguna masuk menggunakan akun Auditor atau Admin.
*   **Dashboard**: Melihat riwayat audit sebelumnya, status sinkronisasi, dan memulai audit baru.

### 2. Memulai Audit
*   **Pilih Lokasi**: Auditor memilih lokasi kandang yang akan diaudit dari daftar lokasi yang tersedia.
*   **Manajemen Draft**: Jika ada audit yang belum selesai di lokasi tersebut, aplikasi akan menawarkan untuk melanjutkan draft yang ada atau membuat baru.

### 3. Pelaksanaan Audit (Step-by-Step)
*   **Pemeriksaan Bagian**: Auditor memeriksa setiap bagian kandang satu per satu sesuai urutan yang ditentukan.
*   **Penilaian**: Memberikan penilaian kondisi (Baik, Cukup, Buruk) atau menandai jika bagian tersebut tidak ada.
*   **Dokumentasi**: Mengambil foto bukti dan menambahkan catatan detail untuk setiap bagian.

### 4. Sampling Hewan Ternak
*   **Data Sampling**: Mengambil sampel hewan (misal: Ayam) untuk mendeteksi keberadaan penyakit atau kondisi kesehatan secara acak.
*   **Validasi**: Pengambilan minimal satu sampel hewan wajib dilakukan sebelum audit dapat dikirim.

### 5. Ringkasan & Validasi Akhir
*   **Review Ringkasan**: Melihat statistik keseluruhan audit (jumlah bagian yang baik/buruk, total foto, dll).
*   **Tanda Tangan**: Auditor memberikan tanda tangan digital sebagai bukti verifikasi lapangan.
*   **Pengiriman**: Mengirim audit untuk ditinjau (Pending Review).

### 6. Sinkronisasi & Pelaporan
*   **Offline-First**: Semua data disimpan di database lokal (Hive) terlebih dahulu, memungkinkan kerja di area tanpa sinyal.
*   **Background Sync**: Data akan otomatis disinkronkan ke server Supabase saat koneksi tersedia.
*   **Laporan PDF**: Audit yang telah disetujui dapat diunduh dalam format PDF sebagai laporan resmi.

---

## Teknologi yang Digunakan
*   **Flutter**: Framework UI.
*   **Riverpod**: State management.
*   **Hive**: Database lokal terenkripsi.
*   **Supabase**: Backend & Database cloud.
*   **GoRouter**: Navigasi aplikasi.
