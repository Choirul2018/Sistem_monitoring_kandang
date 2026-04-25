import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'providers/audit_provider.dart';
import '../data/photo_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../../app/theme/app_colors.dart';

class CameraCaptureScreen extends ConsumerStatefulWidget {
  final String auditId;
  final int partIndex;

  const CameraCaptureScreen({
    super.key,
    required this.auditId,
    required this.partIndex,
  });

  @override
  ConsumerState<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends ConsumerState<CameraCaptureScreen> {
  CameraController? _cameraController;
  bool _isInitializing = true;
  bool _isCapturing = false;
  bool _isProcessing = false;
  File? _capturedPhoto;
  String? _gpsStatus;
  double? _currentLat;
  double? _currentLng;
  bool _isInsideGeofence = false;
  String? _validationMessage;
  bool? _validationPassed;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initGps();
  }

  Future<void> _initCamera() async {
    try {
      final cameraService = ref.read(cameraServiceProvider);
      _cameraController = await cameraService.initializeCamera();
      setState(() => _isInitializing = false);
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _validationMessage = 'Gagal inisialisasi kamera: $e';
      });
    }
  }

  Future<void> _initGps() async {
    try {
      final locationService = ref.read(locationServiceProvider);
      final position = await locationService.getCurrentPosition();

      setState(() {
        _currentLat = position.latitude;
        _currentLng = position.longitude;
        _gpsStatus = 'GPS aktif';
      });

      // Check geofence
      final audit = await ref.read(auditDetailProvider(widget.auditId).future);
      if (audit != null) {
        final locationRepo = ref.read(locationRepositoryProvider);
        final location = await locationRepo.getLocation(audit.locationId);
        if (location != null) {
          final inside = locationService.isInsideGeofence(
            userLat: position.latitude,
            userLng: position.longitude,
            targetLat: location.latitude,
            targetLng: location.longitude,
            radiusMeters: location.geofenceRadiusM.toDouble(),
          );

          final distance = locationService.calculateDistance(
            position.latitude,
            position.longitude,
            location.latitude,
            location.longitude,
          );

          setState(() {
            _isInsideGeofence = inside;
            _gpsStatus = inside
                ? 'Dalam area (${locationService.formatDistance(distance)})'
                : 'Di luar area! (${locationService.formatDistance(distance)})';
          });
        }
      }
    } catch (e) {
      setState(() {
        _gpsStatus = 'GPS error: $e';
        _isInsideGeofence = false;
      });
    }
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing || _cameraController == null) return;

    // Check geofence
    if (!_isInsideGeofence) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda harus berada di dalam area lokasi untuk mengambil foto.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isCapturing = true);
    HapticFeedback.mediumImpact();

    try {
      final cameraService = ref.read(cameraServiceProvider);
      final rawPhoto = await cameraService.capturePhoto();

      setState(() {
        _capturedPhoto = rawPhoto;
        _isCapturing = false;
        _isProcessing = true;
      });

      // Jangan tutup kamera di sini agar tetap terbuka terus
      
      if (mounted) {
        // Run AI validation
        final aiService = ref.read(aiServiceProvider);
        final validationResult = await aiService.validatePhoto(rawPhoto);

        setState(() {
          _isProcessing = false;
          _validationPassed = validationResult.isValid;
          _validationMessage = validationResult.isValid
              ? 'Foto valid ✓'
              : validationResult.issues.join('\n');
        });
      }
    } catch (e) {
      setState(() {
        _isCapturing = false;
        _isProcessing = false;
        _validationMessage = 'Error: $e';
      });
    }
  }

  Future<void> _acceptPhoto() async {
    if (_capturedPhoto == null) return;

    setState(() => _isProcessing = true);

    try {
      final user = ref.read(currentUserProvider);
      final audit = await ref.read(auditDetailProvider(widget.auditId).future);
      final parts = await ref.read(auditPartsProvider(widget.auditId).future);

      if (user == null || audit == null || widget.partIndex >= parts.length) return;

      final part = parts[widget.partIndex];
      final cameraService = ref.read(cameraServiceProvider);
      final photoId = cameraService.generatePhotoId();

      // Get location info
      final locationRepo = ref.read(locationRepositoryProvider);
      final location = await locationRepo.getLocation(audit.locationId);

      // Add watermark
      final watermarked = await cameraService.savePhotoWithWatermark(
        originalPhoto: _capturedPhoto!,
        auditorName: user.fullName,
        locationName: location?.name ?? 'Unknown',
        partName: part.partName,
        timestamp: DateTime.now(),
        latitude: _currentLat,
        longitude: _currentLng,
        qrCodeId: photoId,
      );

      // Generate metadata hash for tamper detection
      final String metadataString = '$photoId|$_currentLat|$_currentLng|${DateTime.now().toIso8601String()}|${user.id}';
      final hash = sha256.convert(utf8.encode(metadataString)).toString();

      // Create photo model
      final photo = PhotoModel(
        id: photoId,
        auditPartId: part.id,
        localPath: watermarked.path,
        timestamp: DateTime.now(),
        gpsLatitude: _currentLat,
        gpsLongitude: _currentLng,
        userId: user.id,
        locationId: audit.locationId,
        partName: part.partName,
        blurScore: null,
        exposureScore: null,
        aiValid: _validationPassed ?? true,
        qrCodeId: photoId,
        synced: false,
        metadataHash: hash,
      );

      // Save photo
      await ref.read(auditRepositoryProvider).savePhoto(photo);

      // Update part's photo list
      part.photoIds = [...part.photoIds, photoId];
      await ref.read(auditRepositoryProvider).updateAuditPart(part);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto berhasil disimpan ✓'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _validationMessage = 'Error menyimpan foto: $e';
      });
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedPhoto = null;
      _validationMessage = null;
      _validationPassed = null;
      _isInitializing = true;
    });
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ─── Camera Preview / Captured Photo ───
            if (_capturedPhoto != null)
              Positioned.fill(
                child: Image.file(
                  _capturedPhoto!,
                  fit: BoxFit.contain,
                ),
              )
            else if (!_isInitializing && _cameraController != null)
              Positioned.fill(
                child: CameraPreview(_cameraController!),
              )
            else
              const Positioned.fill(
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),

            // ─── Top Bar ───
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => context.pop(false),
                    ),
                    const Spacer(),
                    // GPS Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isInsideGeofence
                            ? AppColors.success.withValues(alpha: 0.8)
                            : AppColors.error.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isInsideGeofence
                                ? Icons.gps_fixed
                                : Icons.gps_off,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _gpsStatus ?? 'GPS...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Validation Result ───
            if (_validationMessage != null)
              Positioned(
                bottom: 140,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_validationPassed ?? false)
                        ? AppColors.success.withValues(alpha: 0.9)
                        : AppColors.error.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (_validationPassed ?? false)
                            ? Icons.check_circle_rounded
                            : Icons.warning_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _validationMessage!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ─── Processing Indicator ───
            if (_isProcessing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Memproses foto...',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ─── Bottom Controls ───
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: _capturedPhoto == null
                    ? _buildCaptureControls()
                    : _buildReviewControls(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Capture button
        GestureDetector(
          onTap: _isCapturing ? null : _capturePhoto,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isCapturing ? AppColors.error : Colors.white,
              ),
              child: _isCapturing
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewControls() {
    final bool validationFailed = _validationPassed == false;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Retake
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: 'retake',
              onPressed: _retakePhoto,
              backgroundColor: AppColors.error,
              child: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ulangi',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
        // Accept
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: 'accept',
              onPressed: _acceptPhoto,
              backgroundColor: validationFailed ? AppColors.warning : AppColors.success,
              child: Icon(
                validationFailed ? Icons.warning_amber_rounded : Icons.check_rounded, 
                size: 28
              ),
            ),
            const SizedBox(height: 8),
            Text(
              validationFailed ? 'Simpan Saja' : 'Simpan',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}
