import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

class AiService {
  // ═══════════════════════════════════════════
  //  BLUR DETECTION (Laplacian Variance)
  // ═══════════════════════════════════════════

  // ═══════════════════════════════════════════
  //  COMBINED VALIDATION
  // ═══════════════════════════════════════════

  Future<PhotoValidationResult> validatePhoto(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final fullImage = img.decodeImage(bytes);
    
    if (fullImage == null) {
      return PhotoValidationResult(
        isValid: false,
        blurResult: BlurResult(score: 0, isBlurry: true, message: 'Gagal memproses file.'),
        exposureResult: ExposureResult(meanBrightness: 0, status: ExposureStatus.unknown, message: 'Gagal memproses file.'),
        isEmpty: true,
        issues: ['File foto rusak atau tidak terbaca.'],
      );
    }

    // Use a resized version for all AI checks to speed up processing
    final processingImage = fullImage.width > 640 
        ? img.copyResize(fullImage, width: 640) 
        : fullImage;

    final blurResult = await _checkBlur(processingImage);
    final exposureResult = await _checkExposure(processingImage);
    final isEmpty = await _isEmptyImage(processingImage);

    final issues = <String>[];

    if (blurResult.isBlurry) issues.add(blurResult.message);
    if (exposureResult.status != ExposureStatus.good) {
      issues.add(exposureResult.message);
    }
    if (isEmpty) {
      issues.add('Foto tidak valid: hanya menampilkan permukaan kosong.');
    }

    return PhotoValidationResult(
      isValid: issues.isEmpty,
      blurResult: blurResult,
      exposureResult: exposureResult,
      isEmpty: isEmpty,
      issues: issues,
    );
  }

  // ═══════════════════════════════════════════
  //  INTERNAL HELPERS (Optimized)
  // ═══════════════════════════════════════════

  Future<BlurResult> _checkBlur(img.Image image) async {
    final gray = img.grayscale(image);

    double sum = 0;
    double sumSq = 0;
    int count = 0;

    for (int y = 1; y < gray.height - 1; y++) {
      for (int x = 1; x < gray.width - 1; x++) {
        final center = gray.getPixel(x, y).luminance;
        final top = gray.getPixel(x, y - 1).luminance;
        final bottom = gray.getPixel(x, y + 1).luminance;
        final left = gray.getPixel(x - 1, y).luminance;
        final right = gray.getPixel(x + 1, y).luminance;

        final laplacian = (top + bottom + left + right - 4 * center).abs();
        sum += laplacian;
        sumSq += laplacian * laplacian;
        count++;
      }
    }

    final threshold = 100.0;
    if (count == 0) return BlurResult(score: 0, isBlurry: true, message: 'Gagal analisis ketajaman.');

    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    final score = variance * 10000;
    final isBlurry = score < threshold;

    return BlurResult(
      score: score,
      isBlurry: isBlurry,
      message: isBlurry
          ? 'Foto terlalu kabur, silakan ulangi.'
          : 'Ketajaman foto baik.',
    );
  }

  Future<ExposureResult> _checkExposure(img.Image image) async {
    double totalBrightness = 0;
    int count = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final brightness = (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114);
        totalBrightness += brightness;
        count++;
      }
    }

    final mean = totalBrightness / count;

    ExposureStatus status;
    String message;

    if (mean < 30) { // Slightly lower threshold for dark cages
      status = ExposureStatus.tooDark;
      message = 'Foto terlalu gelap. Gunakan flash atau cari pencahayaan lebih baik.';
    } else if (mean > 230) { // Slightly higher threshold
      status = ExposureStatus.tooBright;
      message = 'Foto terlalu terang. Hindari cahaya langsung.';
    } else {
      status = ExposureStatus.good;
      message = 'Pencahayaan foto baik.';
    }

    return ExposureResult(
      meanBrightness: mean,
      status: status,
      message: message,
    );
  }

  Future<bool> _isEmptyImage(img.Image image, {double minVariance = 12.0}) async {
    // Smaller version for variance check
    final small = image.width > 320 ? img.copyResize(image, width: 320) : image;

    double rSum = 0, gSum = 0, bSum = 0;
    double rSumSq = 0, gSumSq = 0, bSumSq = 0;
    int count = 0;

    for (int y = 0; y < small.height; y++) {
      for (int x = 0; x < small.width; x++) {
        final pixel = small.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();

        rSum += r;
        gSum += g;
        bSum += b;
        rSumSq += r * r;
        gSumSq += g * g;
        bSumSq += b * b;
        count++;
      }
    }

    final rVar = (rSumSq / count) - pow(rSum / count, 2);
    final gVar = (gSumSq / count) - pow(gSum / count, 2);
    final bVar = (bSumSq / count) - pow(bSum / count, 2);

    final totalVariance = (rVar + gVar + bVar) / 3;

    return totalVariance < minVariance;
  }
}

// ─── Result Classes ───

class BlurResult {
  final double score;
  final bool isBlurry;
  final String message;

  BlurResult({
    required this.score,
    required this.isBlurry,
    required this.message,
  });
}

enum ExposureStatus { good, tooDark, tooBright, unknown }

class ExposureResult {
  final double meanBrightness;
  final ExposureStatus status;
  final String message;

  ExposureResult({
    required this.meanBrightness,
    required this.status,
    required this.message,
  });
}

class PhotoValidationResult {
  final bool isValid;
  final BlurResult blurResult;
  final ExposureResult exposureResult;
  final bool isEmpty;
  final List<String> issues;

  PhotoValidationResult({
    required this.isValid,
    required this.blurResult,
    required this.exposureResult,
    required this.isEmpty,
    required this.issues,
  });
}
