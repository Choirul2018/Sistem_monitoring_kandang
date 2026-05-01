import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:package_info_plus/package_info_plus.dart'; // Aktifkan setelah install plugin
// import 'package:ota_update/ota_update.dart';             // Aktifkan setelah install plugin
import '../network/api_client.dart';

/*
  =============================================================================
  IN-APP UPDATE SERVICE TEMPLATE
  =============================================================================
  Layanan ini digunakan untuk melakukan update aplikasi secara mandiri dari 
  server Proxmox (Self-Hosted).
  
  CARA MENGAKTIFKAN:
  1. Jalankan: flutter pub add ota_update package_info_plus
  2. Buka komentar (uncomment) pada baris import di atas.
  3. Buka komentar pada seluruh kode di bawah ini.
  4. Tambahkan izin berikut di AndroidManifest.xml:
     <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
  =============================================================================
*/

final updateServiceProvider = Provider((ref) => UpdateService(ref.read(apiClientProvider)));

class UpdateService {
  final ApiClient _client;
  UpdateService(this._client);

  // Fungsi untuk mengecek apakah ada versi baru di server
  Future<UpdateInfo?> checkUpdate() async {
    try {
      // Pastikan endpoint '/app-version' sudah dibuat di Laravel
      final response = await _client.get('/app-version');
      
      if (response.statusCode == 200) {
        final data = response.data;
        final String latestVersion = data['latest_version'];
        final String downloadUrl = data['download_url'];
        final String notes = data['release_notes'] ?? '';

        // -- LOGIKA PENGECEKAN VERSI --
        // final packageInfo = await PackageInfo.fromPlatform();
        // final String currentVersion = packageInfo.version;

        // Contoh sederhana: Jika versi server tidak sama dengan versi HP
        // if (latestVersion != currentVersion) {
        //   return UpdateInfo(version: latestVersion, url: downloadUrl, notes: notes);
        // }
      }
    } catch (e) {
      // Silently fail or log error
    }
    return null;
  }

  // Fungsi untuk mendownload dan memicu instalasi APK
  void runUpdate(String url, Function(double progress) onProgress) {
    try {
      /*
      OtaUpdate().execute(
        url,
        destinationFilename: 'update.apk', // Nama file sementara
      ).listen((OtaEvent event) {
        if (event.status == OtaStatus.DOWNLOADING) {
          final progress = double.tryParse(event.value ?? '0') ?? 0;
          onProgress(progress);
        } else if (event.status == OtaStatus.INSTALLING) {
          // Sistem Android akan mengambil alih untuk proses instalasi
        }
      });
      */
    } catch (e) {
      // Handle error download/install
    }
  }
}

class UpdateInfo {
  final String version;
  final String url;
  final String notes;

  UpdateInfo({
    required this.version,
    required this.url,
    required this.notes,
  });
}
