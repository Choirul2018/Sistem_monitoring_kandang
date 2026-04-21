import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hand_signature/signature.dart';
import 'providers/audit_provider.dart';
import '../../../app/theme/app_colors.dart';

class SignatureScreen extends ConsumerStatefulWidget {
  final String auditId;
  const SignatureScreen({super.key, required this.auditId});

  @override
  ConsumerState<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends ConsumerState<SignatureScreen> {
  final HandSignatureControl _signatureControl = HandSignatureControl();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _signatureControl.dispose();
    super.dispose();
  }

  Future<void> _submitAudit() async {
    if (!_signatureControl.hasActivePath) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanda tangan wajib diisi.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Get signature as PNG bytes
      final byteData = await _signatureControl.toImage(
        color: Colors.black,
        background: Colors.white,
        fit: true,
      );

      if (byteData == null) throw Exception('Gagal membuat tanda tangan');

      final signatureBase64 = base64Encode(byteData.buffer.asUint8List());

      // Submit audit for review
      await ref.read(auditRepositoryProvider).submitForReview(
        widget.auditId,
        signatureBase64,
      );

      // Invalidate providers
      ref.invalidate(auditDetailProvider(widget.auditId));
      ref.invalidate(auditListProvider);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.info),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tanda tangan Anda mengkonfirmasi bahwa semua data audit yang diinput sudah benar dan lengkap.',
                      style: TextStyle(color: AppColors.info, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Tanda Tangan Auditor',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Gunakan jari Anda untuk menandatangani di area di bawah',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),

            // Signature pad
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkDivider : AppColors.divider,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: HandSignature(
                    control: _signatureControl,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Clear button
            Center(
              child: TextButton.icon(
                onPressed: () {
                  _signatureControl.clear();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Hapus & Ulangi'),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitAudit,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Kirim Audit untuk Review'),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
