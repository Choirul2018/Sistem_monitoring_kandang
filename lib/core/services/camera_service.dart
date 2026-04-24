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

  // ─── Capture Photo ───
  Future<File> capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw Exception('Kamera belum diinisialisasi.');
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

    // Resize if too large
    if (image.width > 1920) {
      image = img.copyResize(image, width: 1920);
    }

    // Add watermark strip at bottom
    final watermarkHeight = 120;
    final result = img.Image(
      width: image.width,
      height: image.height + watermarkHeight,
    );

    // Copy original image
    img.compositeImage(result, image);

    // Draw watermark background (semi-transparent dark)
    img.fillRect(
      result,
      x1: 0,
      y1: image.height,
      x2: image.width,
      y2: image.height + watermarkHeight,
      color: img.ColorRgba8(0, 0, 0, 200),
    );

    // Draw watermark text
    final font = img.arial14;
    final dateStr = '${timestamp.day}/${timestamp.month}/${timestamp.year} '
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
    final gpsStr = latitude != null && longitude != null
        ? '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}'
        : 'GPS tidak tersedia';

    int y = image.height + 8;
    final lines = [
      'Auditor: $auditorName',
      'Lokasi: $locationName | Bagian: $partName',
      'Tanggal: $dateStr',
      'GPS: $gpsStr',
      'ID: $qrCodeId',
    ];

    for (final line in lines) {
      img.drawString(result, line, font: font, x: 10, y: y,
          color: img.ColorRgba8(255, 255, 255, 255));
      y += 20;
    }

    // Save to app directory
    final dir = await getApplicationDocumentsDirectory();
    final photoDir = Directory('${dir.path}/audit_photos');
    if (!await photoDir.exists()) {
      await photoDir.create(recursive: true);
    }

    final fileName = 'audit_$qrCodeId.jpg';
    final outputFile = File('${photoDir.path}/$fileName');
    await outputFile.writeAsBytes(img.encodeJpg(result, quality: 85));

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
      print('Error disposing camera: $e');
    }
  }

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
}
