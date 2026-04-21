import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

class AiService {
  // ═══════════════════════════════════════════
  //  BLUR DETECTION (Laplacian Variance)
  // ═══════════════════════════════════════════

  /// Returns blur score. Higher = sharper. Below threshold = blurry.
  Future<double> detectBlur(File imageFile, {double threshold = 100.0}) async {
    final bytes = await imageFile.readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) return 0;

    // Resize for faster processing
    if (image.width > 640) {
      image = img.copyResize(image, width: 640);
    }

    // Convert to grayscale
    final gray = img.grayscale(image);

    // Apply Laplacian kernel
    // [0, 1, 0]
    // [1,-4, 1]
    // [0, 1, 0]
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

    if (count == 0) return 0;

    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);

    return variance * 10000; // Scale for readability
  }

  /// Check if image is blurry
  Future<BlurResult> checkBlur(File imageFile, {double threshold = 100.0}) async {
    final score = await detectBlur(imageFile, threshold: threshold);
    final isBlurry = score < threshold;

    return BlurResult(
      score: score,
      isBlurry: isBlurry,
      message: isBlurry
          ? 'Foto terlalu kabur, silakan ulangi.'
          : 'Ketajaman foto baik.',
    );
  }

  // ═══════════════════════════════════════════
  //  EXPOSURE CHECK (Histogram Analysis)
  // ═══════════════════════════════════════════

  /// Returns exposure score (0-255). <40 = too dark, >220 = too bright
  Future<ExposureResult> checkExposure(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) {
      return ExposureResult(
        meanBrightness: 0,
        status: ExposureStatus.unknown,
        message: 'Gagal memproses foto.',
      );
    }

    // Resize for faster processing
    if (image.width > 640) {
      image = img.copyResize(image, width: 640);
    }

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

    if (mean < 40) {
      status = ExposureStatus.tooDark;
      message = 'Foto terlalu gelap. Gunakan flash atau cari pencahayaan lebih baik.';
    } else if (mean > 220) {
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

  // ═══════════════════════════════════════════
  //  EMPTY/INVALID IMAGE DETECTION
  // ═══════════════════════════════════════════

  /// Detects blank/uniform images (wall, sky, floor only)
  Future<bool> isEmptyImage(File imageFile, {double minVariance = 15.0}) async {
    final bytes = await imageFile.readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) return true;

    if (image.width > 320) {
      image = img.copyResize(image, width: 320);
    }

    // Calculate color variance
    double rSum = 0, gSum = 0, bSum = 0;
    double rSumSq = 0, gSumSq = 0, bSumSq = 0;
    int count = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
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

  // ═══════════════════════════════════════════
  //  COMBINED VALIDATION
  // ═══════════════════════════════════════════

  Future<PhotoValidationResult> validatePhoto(File imageFile) async {
    final blurResult = await checkBlur(imageFile);
    final exposureResult = await checkExposure(imageFile);
    final isEmpty = await isEmptyImage(imageFile);

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
