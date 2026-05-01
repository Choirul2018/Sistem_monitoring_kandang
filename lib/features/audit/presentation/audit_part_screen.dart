import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'providers/audit_provider.dart';
import '../data/audit_part_model.dart';
import '../data/photo_model.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import 'camera_capture_screen.dart';

/// STRATEGI OPTIMASI TAHAP 3 (DRASTIS):
/// 1. Matikan [resizeToAvoidBottomInset] agar Scaffold tidak ikut resize saat keyboard muncul.
/// 2. Gunakan padding manual di bawah Column yang menyesuaikan dengan tinggi keyboard.
/// 3. Sembunyikan foto sementara saat keyboard terbuka (UX Optimization) jika masih lag.
/// 4. Gunakan [ValueKey] pada widget foto agar Flutter tidak menganggapnya widget baru.
/// 5. Minimalisir penggunaan MediaQuery di widget-widget leaf.

class AuditPartScreen extends ConsumerStatefulWidget {
  final String auditId;
  final int partIndex;

  const AuditPartScreen({
    super.key,
    required this.auditId,
    required this.partIndex,
  });

  @override
  ConsumerState<AuditPartScreen> createState() => _AuditPartScreenState();
}

class _AuditPartScreenState extends ConsumerState<AuditPartScreen> {
  final _notesController = TextEditingController();
  final _notesFocus = FocusNode();
  final _scrollController = ScrollController();
  String? _selectedCondition;
  bool _partExists = true;
  Timer? _debounceTimer;
  AuditPartModel? _currentPart;

  @override
  void initState() {
    super.initState();
    _loadPartData();
  }


  Future<void> _loadPartData() async {
    final parts = await ref.read(auditPartsProvider(widget.auditId).future);
    if (widget.partIndex < parts.length) {
      final part = parts[widget.partIndex];
      setState(() {
        _currentPart = part;
        _partExists = part.partExists;
        _selectedCondition = part.condition;
        _notesController.text = part.notes ?? '';
      });
    }
  }

  void _onNotesChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () => _saveProgress());
  }

  Future<void> _saveProgress() async {
    if (_currentPart == null) return;
    _currentPart!.partExists = _partExists;
    _currentPart!.condition = _partExists ? _selectedCondition : null;
    _currentPart!.notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
    await ref.read(auditRepositoryProvider).updateAuditPart(_currentPart!);
  }

  Future<void> _completePart() async {
    if (_currentPart == null) return;
    if (!_partExists && _notesController.text.trim().isEmpty) {
      _showError('Catatan wajib diisi jika bagian tidak ada.');
      return;
    }
    if (_partExists) {
      if (_selectedCondition == null) {
        _showError('Pilih kondisi bagian terlebih dahulu.');
        return;
      }
      if (_selectedCondition == 'buruk' && _notesController.text.trim().isEmpty) {
        _showError('Catatan wajib diisi untuk kondisi Buruk.');
        return;
      }
      final photos = await ref.read(partPhotosProvider(_currentPart!.id).future);
      if (photos.isEmpty) {
        _showError('Ambil minimal satu foto untuk bagian ini.');
        return;
      }
    }

    final audit = await ref.read(auditDetailProvider(widget.auditId).future);
    if (audit == null || audit.isLocked) return;

    _currentPart!.completed = true;
    _currentPart!.partExists = _partExists;
    _currentPart!.condition = _partExists ? _selectedCondition : null;
    _currentPart!.notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

    await ref.read(auditRepositoryProvider).updateAuditPart(_currentPart!);
    if (widget.partIndex == audit.currentPartIndex) audit.currentPartIndex = widget.partIndex + 1;
    if (audit.currentPartIndex >= audit.parts.length) audit.status = 'in_progress';
    
    await ref.read(auditRepositoryProvider).updateAudit(audit);
    ref.invalidate(auditDetailProvider(widget.auditId));
    ref.invalidate(auditPartsProvider(widget.auditId));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_currentPart!.partName} selesai ✓'), backgroundColor: AppColors.success),
      );
      context.pop();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _saveProgress();
    _notesController.dispose();
    _notesFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      // KEMBALI KE STANDAR: Biarkan sistem yang handle resize
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_currentPart?.partName ?? 'Memuat...'),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final auditAsync = ref.watch(auditDetailProvider(widget.auditId));
              return auditAsync.maybeWhen(
                data: (audit) => audit?.isLocked == true 
                  ? const _ReadOnlyChip() 
                  : const _AutoSaveIndicator(),
                orElse: () => const SizedBox.shrink(),
              );
            },
          ),
        ],
      ),
      body: Consumer(
        builder: (context, ref, _) {
          final partsAsync = ref.watch(auditPartsProvider(widget.auditId));
          return partsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (parts) {
              if (widget.partIndex >= parts.length) return const Center(child: Text('Indeks tidak valid'));
              final part = parts[widget.partIndex];
              
              return Consumer(
                builder: (context, ref, _) {
                  final isLocked = ref.watch(auditDetailProvider(widget.auditId)).valueOrNull?.isLocked ?? false;

                  return SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PartExistsCard(
                          exists: _partExists,
                          isLocked: isLocked,
                          onChanged: (v) => setState(() => _partExists = v),
                        ),
                        
                        const SizedBox(height: 16),

                        if (_partExists) ...[
                          _ConditionSelector(
                            selected: _selectedCondition,
                            isLocked: isLocked,
                            onChanged: (val) => setState(() => _selectedCondition = val),
                          ),
                          
                          const SizedBox(height: 20),

                          _IsolatedPhotoSection(
                            key: ValueKey('photo_section_${part.id}'),
                            partId: part.id,
                            auditId: widget.auditId,
                            partIndex: widget.partIndex,
                            isLocked: isLocked,
                          ),
                        ],

                        const SizedBox(height: 24),

                        RepaintBoundary(
                          child: _NotesField(
                            controller: _notesController,
                            focusNode: _notesFocus,
                            isLocked: isLocked,
                            isRequired: part.needsNotes,
                            onChanged: _onNotesChanged,
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: _KeyboardSensitiveBottomBar(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Consumer(
              builder: (context, ref, _) {
                final isLocked = ref.watch(auditDetailProvider(widget.auditId)).valueOrNull?.isLocked ?? false;
                return _CompleteButton(
                  isLocked: isLocked,
                  onPressed: _completePart,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SUB-WIDGETS UNTUK OPTIMASI PERFORMANCE
// ════════════════════════════════════════════════════════════════

class _KeyboardSensitiveBottomBar extends StatelessWidget {
  final Widget child;
  const _KeyboardSensitiveBottomBar({required this.child});

  @override
  Widget build(BuildContext context) {
    // Hanya widget ini yang rebuild saat keyboard muncul
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return isKeyboardOpen ? const SizedBox.shrink() : child;
  }
}

class _KeyboardActivePlaceholder extends StatelessWidget {
  const _KeyboardActivePlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.image_outlined, size: 16, color: AppColors.textTertiary),
          SizedBox(width: 8),
          Text('Foto disembunyikan saat mengetik...', 
               style: TextStyle(fontSize: 11, color: AppColors.textTertiary, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

class _ReadOnlyChip extends StatelessWidget {
  const _ReadOnlyChip();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(right: 16),
      child: Center(
        child: Chip(
          label: Text('READ ONLY', style: TextStyle(fontSize: 10, color: Colors.white)),
          backgroundColor: AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _AutoSaveIndicator extends StatelessWidget {
  const _AutoSaveIndicator();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(right: 16),
      child: Row(
        children: [
          Icon(Icons.save_rounded, size: 14, color: AppColors.success),
          SizedBox(width: 4),
          Text('Auto-save', style: TextStyle(fontSize: 11, color: AppColors.success)),
        ],
      ),
    );
  }
}

class _PartExistsCard extends StatelessWidget {
  final bool exists;
  final bool isLocked;
  final ValueChanged<bool> onChanged;

  const _PartExistsCard({required this.exists, required this.isLocked, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bagian ini ada?', style: Theme.of(context).textTheme.titleSmall),
                  Text('Jika tidak ada, catatan wajib diisi', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Switch.adaptive(
              value: exists,
              onChanged: isLocked ? null : onChanged,
              activeTrackColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConditionSelector extends StatelessWidget {
  final String? selected;
  final bool isLocked;
  final ValueChanged<String> onChanged;

  const _ConditionSelector({required this.selected, required this.isLocked, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Kondisi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        Row(
          children: AppConstants.conditionOptions.map((opt) {
            final isSel = selected == opt.toLowerCase();
            final color = _getColor(opt.toLowerCase());
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: isLocked ? null : () => onChanged(opt.toLowerCase()),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSel ? color : AppColors.divider, width: isSel ? 2 : 1),
                      color: isSel ? color.withValues(alpha: 0.08) : Colors.transparent,
                    ),
                    child: Column(
                      children: [
                        Icon(isSel ? Icons.check_circle : Icons.radio_button_unchecked, 
                             color: isSel ? color : AppColors.textTertiary, size: 20),
                        const SizedBox(height: 4),
                        Text(opt, style: TextStyle(color: isSel ? color : null, fontSize: 12, fontWeight: isSel ? FontWeight.bold : null)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _getColor(String cond) {
    if (cond == 'baik') return AppColors.conditionBaik;
    if (cond == 'cukup') return AppColors.conditionCukup;
    if (cond == 'buruk') return AppColors.conditionBuruk;
    return AppColors.textTertiary;
  }
}

class _IsolatedPhotoSection extends ConsumerWidget {
  final String partId;
  final String auditId;
  final int partIndex;
  final bool isLocked;

  const _IsolatedPhotoSection({
    super.key,
    required this.partId, 
    required this.auditId, 
    required this.partIndex, 
    required this.isLocked
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dokumentasi Foto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: Consumer(
              builder: (context, ref, child) {
                final photosAsync = ref.watch(partPhotosProvider(partId));
                return photosAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                  data: (photos) => ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    itemCount: photos.length + 1,
                    itemExtent: 110,
                    itemBuilder: (ctx, i) {
                      if (i == photos.length) return _AddPhotoButton(
                        isLocked: isLocked, 
                        auditId: auditId, 
                        partIndex: partIndex, 
                        partId: partId
                      );
                      return _PhotoThumbnail(
                        key: ValueKey('photo_${photos[i].id}'),
                        photo: photos[i], 
                        isLocked: isLocked
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoButton extends ConsumerWidget {
  final bool isLocked;
  final String auditId;
  final int partIndex;
  final String partId;

  const _AddPhotoButton({required this.isLocked, required this.auditId, required this.partIndex, required this.partId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: isLocked ? null : () async {
        final res = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => CameraCaptureScreen(auditId: auditId, partIndex: partIndex),
          ),
        );
        if (res != null) {
          await Future.delayed(const Duration(milliseconds: 300));
          ref.invalidate(partPhotosProvider(partId));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_rounded, color: AppColors.primary),
            SizedBox(height: 4),
            Text('Ambil Foto', style: TextStyle(color: AppColors.primary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumbnail extends ConsumerWidget {
  final PhotoModel photo;
  final bool isLocked;

  const _PhotoThumbnail({super.key, required this.photo, required this.isLocked});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Gunakan provider untuk mendapatkan file agar tidak recreate objek File setiap build
    return Container(
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: photo.aiValid ? AppColors.success : AppColors.error, width: 2),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(photo.localPath),
              fit: BoxFit.cover,
              cacheWidth: 200,
              gaplessPlayback: true,
            ),
          ),
          if (!isLocked)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () async {
                  final ok = await _confirmDelete(context);
                  if (ok == true) {
                    await ref.read(auditRepositoryProvider).deletePhoto(photo.id);
                    ref.invalidate(partPhotosProvider(photo.auditPartId));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus Foto?'),
        content: const Text('Foto ini akan dihapus secara permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _NotesField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLocked;
  final bool isRequired;
  final VoidCallback onChanged;

  const _NotesField({
    required this.controller, 
    required this.focusNode, 
    required this.isLocked, 
    required this.isRequired, 
    required this.onChanged
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Catatan${isRequired ? ' (Wajib)' : ' (Opsional)'}', 
             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          maxLines: 6,
          minLines: 4,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => focusNode.unfocus(),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
            ),
            hintText: 'Tambahkan detail atau catatan di sini...',
            fillColor: Theme.of(context).cardColor,
            filled: true,
          ),
          enabled: !isLocked,
          scrollPadding: EdgeInsets.zero, // Jangan scroll otomatis terlalu banyak
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}

class _CompleteButton extends StatelessWidget {
  final bool isLocked;
  final VoidCallback onPressed;

  const _CompleteButton({required this.isLocked, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLocked ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: const Text('Selesaikan Bagian Ini', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
