import 'dart:io';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  static const _uuid = Uuid();

  // ─── Initialize Cameras ───
  Future<List<CameraDescription>> getAvailableCameras() async {
    _cameras ??= await availableCameras();
    return _cameras!;
  }

  // ─── Initialize Controller ───
  Future<CameraController> initializeCamera({
    CameraDescription? camera,
    ResolutionPreset resolution = ResolutionPreset.high,
  }) async {
    if (_controller != null && _controller!.value.isInitialized) {
      return _controller!;
    }

    final cameras = await getAvailableCameras();
    if (cameras.isEmpty) throw Exception('Tidak ada kamera tersedia.');

    final selectedCamera = camera ?? cameras.first;

    _controller = CameraController(
      selectedCamera,
      resolution,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();
    return _controller!;
  }

  // ─── Persistent Session Management ───
  bool _isSessionActive = false;
  bool get isSessionActive => _isSessionActive;

  Future<void> startSession() async {
    if (_isSessionActive) return;
    try {
      await initializeCamera();
      _isSessionActive = true;
    } catch (e) {
      // Error ignored to reduce log noise
    }
  }

  Future<void> stopSession() async {
    _isSessionActive = false;
    await dispose();
  }

  // ─── Capture Photo ───
  Future<File> capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      // Jika sesi tidak aktif tapi dipanggil, coba inisialisasi cepat
      await initializeCamera();
    }

    final xFile = await _controller!.takePicture();
    return File(xFile.path);
  }

  // ─── Save Photo With Watermark ───
  Future<File> savePhotoWithWatermark({
    required File originalPhoto,
    required String auditorName,
    required String locationName,
    required String partName,
    required DateTime timestamp,
    required double? latitude,
    required double? longitude,
    required String qrCodeId,
  }) async {
    final bytes = await originalPhoto.readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) throw Exception('Gagal memproses foto.');

    // Resize if too large for performance
    if (image.width > 1280) {
      image = img.copyResize(image, width: 1280);
    }

    final width = image.width;
    final height = image.height;

    // ─── Draw Watermark Overlay (Bottom Section) ───
    final overlayHeight = (height * 0.15).toInt().clamp(100, 180);
    final overlayY = height - overlayHeight;

    // Semi-transparent black background at the bottom
    img.fillRect(
      image,
      x1: 0,
      y1: overlayY,
      x2: width,
      y2: height,
      color: img.ColorRgba8(0, 0, 0, 160),
    );

    // ─── Draw Info Text ───
    final fontTitle = img.arial24;
    final fontContent = img.arial14;
    
    final dateStr = '${timestamp.day}/${timestamp.month}/${timestamp.year} '
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}';
    
    final gpsStr = latitude != null && longitude != null
        ? '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}'
        : 'GPS Not Available';

    // Grouping: Row by Row for better alignment
    int row1Y = overlayY + 15;
    int row2Y = row1Y + 35;
    int row3Y = row2Y + 22;
    int row4Y = row3Y + 22;

    // Row 1: Location Name (MAIN TITLE)
    img.drawString(image, locationName.toUpperCase(), 
        font: fontTitle, x: 20, y: row1Y, 
        color: img.ColorRgba8(255, 204, 0, 255)); // Gold

    // Row 2: Part Name (Left) & GPS (Right)
    img.drawString(image, 'BAGIAN: $partName', 
        font: fontContent, x: 20, y: row2Y, 
        color: img.ColorRgba8(255, 255, 255, 255));
    
    img.drawString(image, '📍 $gpsStr', 
        font: fontContent, x: (width - 300).clamp(20, width - 300), y: row2Y, 
        color: img.ColorRgba8(255, 255, 255, 255));

    // Row 3: Auditor (Left) & Time (Right)
    img.drawString(image, 'AUDITOR: $auditorName', 
        font: fontContent, x: 20, y: row3Y, 
        color: img.ColorRgba8(255, 255, 255, 255));

    img.drawString(image, '🕒 $dateStr', 
        font: fontContent, x: (width - 300).clamp(20, width - 300), y: row3Y, 
        color: img.ColorRgba8(255, 255, 255, 255));

    // Row 4: Photo ID
    img.drawString(image, 'ID: $qrCodeId', 
        font: fontContent, x: 20, y: row4Y, 
        color: img.ColorRgba8(180, 180, 180, 200));

    // Save to app directory
    final dir = await getApplicationDocumentsDirectory();
    final photoDir = Directory('${dir.path}/audit_photos');
    if (!await photoDir.exists()) {
      await photoDir.create(recursive: true);
    }

    final fileName = 'audit_$qrCodeId.jpg';
    final outputFile = File('${photoDir.path}/$fileName');
    await outputFile.writeAsBytes(img.encodeJpg(image, quality: 90));

    return outputFile;
  }

  // ─── Generate Unique Photo ID ───
  String generatePhotoId() => _uuid.v4();

  // ─── Dispose Camera ───
  Future<void> dispose() async {
    if (_controller == null) return;
    
    final tempController = _controller;
    _controller = null; // Clear reference first
    
    try {
      if (tempController!.value.isInitialized) {
        await tempController.dispose();
      }
    } catch (e) {
      // Error ignored to reduce log noise
    }
  }

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
}
