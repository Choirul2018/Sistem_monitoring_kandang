import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/audit_provider.dart';
import '../../../app/theme/app_colors.dart';

class SignatureScreen extends ConsumerStatefulWidget {
  final String auditId;
  const SignatureScreen({super.key, required this.auditId});

  @override
  ConsumerState<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends ConsumerState<SignatureScreen> {
  // Daftar garis (setiap garis adalah list of Offset)
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  bool _isSubmitting = false;
  bool _isEmpty = true;

  // Key untuk mengambil gambar dari widget
  final GlobalKey _signaturePadKey = GlobalKey();

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _currentStroke = [details.localPosition];
      _isEmpty = false;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentStroke.add(details.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      if (_currentStroke.isNotEmpty) {
        _strokes.add(List.from(_currentStroke));
        _currentStroke = [];
      }
    });
  }

  void _clearSignature() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
      _isEmpty = true;
    });
  }

  Future<String?> _captureSignatureAsBase64() async {
    try {
      // Render signature ke gambar menggunakan RepaintBoundary
      final RenderRepaintBoundary boundary =
          _signaturePadKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      return base64Encode(byteData.buffer.asUint8List());
    } catch (e) {
      return null;
    }
  }

  Future<void> _submitAudit() async {
    if (_isEmpty || _strokes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tanda tangan wajib diisi sebelum mengirim.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final signatureBase64 = await _captureSignatureAsBase64();

      if (signatureBase64 == null) {
        throw Exception('Gagal mengambil gambar tanda tangan');
      }

      await ref.read(auditRepositoryProvider).submitForReview(
            widget.auditId,
            signatureBase64,
          );

      ref.invalidate(auditDetailProvider(widget.auditId));
      ref.invalidate(auditListProvider);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 48),
            ),
            title: const Text('Audit Terkirim!'),
            content: const Text(
              'Audit berhasil dikirim untuk review.\n'
              'Kabag/Kadiv akan meninjau dan menyetujui laporan Anda.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/home');
                },
                child: const Text('Kembali ke Beranda'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tanda Tangan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Info Banner ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.info_outline,
                        color: AppColors.info, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tanda tangan mengkonfirmasi semua data audit sudah benar dan lengkap.',
                      style: TextStyle(color: AppColors.info, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Tanda Tangan Auditor',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Gunakan jari Anda untuk menandatangani di area putih di bawah',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 12),

            // ─── Signature Pad ───
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isEmpty
                        ? (isDark ? AppColors.darkDivider : AppColors.divider)
                        : AppColors.primary,
                    width: _isEmpty ? 2 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: RepaintBoundary(
                  key: _signaturePadKey,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: CustomPaint(
                        // foregroundPainter: digambar DI ATAS child (bukan di bawah)
                        foregroundPainter: _SignaturePainter(
                          strokes: _strokes,
                          currentStroke: _currentStroke,
                        ),
                        child: Container(
                          color: Colors.white,
                          child: _isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.draw_outlined,
                                          size: 48,
                                          color: Colors.grey[300]),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Area Tanda Tangan',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ─── Action Buttons ───
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearSignature,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey[400]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon:
                        const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Hapus'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitAudit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label:
                        Text(_isSubmitting ? 'Mengirim...' : 'Kirim Audit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// CustomPainter yang menggambar stroke tanda tangan
class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;

  _SignaturePainter({required this.strokes, required this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    // Tidak perlu gambar background — Container child sudah putih
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Gambar semua stroke yang sudah selesai
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, paint);
    }

    // Gambar stroke yang sedang digambar
    if (currentStroke.isNotEmpty) {
      _drawStroke(canvas, currentStroke, paint);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> stroke, Paint paint) {
    if (stroke.isEmpty) return;
    if (stroke.length == 1) {
      // Titik tunggal (tap)
      canvas.drawCircle(stroke[0], paint.strokeWidth / 2, paint);
      return;
    }

    final path = Path();
    path.moveTo(stroke[0].dx, stroke[0].dy);

    for (int i = 1; i < stroke.length; i++) {
      path.lineTo(stroke[i].dx, stroke[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentStroke != currentStroke;
  }
}