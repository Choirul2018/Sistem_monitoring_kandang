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
  String? _selectedCondition;
  bool _partExists = true;
  Timer? _autoSaveTimer;
  AuditPartModel? _currentPart;

  @override
  void initState() {
    super.initState();
    _loadPartData();
    _startAutoSave();
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

  void _startAutoSave() {
    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: AppConstants.autoSaveIntervalSeconds),
      (_) => _saveProgress(),
    );
  }

  Future<void> _saveProgress() async {
    if (_currentPart == null) return;

    _currentPart!.partExists = _partExists;
    _currentPart!.condition = _partExists ? _selectedCondition : null;
    _currentPart!.notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    await ref.read(auditRepositoryProvider).updateAuditPart(_currentPart!);
  }

  Future<void> _completePart() async {
    if (_currentPart == null) return;

    // Validation
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

    // Save and mark complete
    final audit = await ref.read(auditDetailProvider(widget.auditId).future);
    if (audit == null) return;
    if (audit.isLocked) return;

    _currentPart!.completed = true;
    _currentPart!.partExists = _partExists;
    _currentPart!.condition = _partExists ? _selectedCondition : null;
    _currentPart!.notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    await ref.read(auditRepositoryProvider).updateAuditPart(_currentPart!);

    if (widget.partIndex == audit.currentPartIndex) {
      audit.currentPartIndex = widget.partIndex + 1;
    }
    
    if (audit.currentPartIndex >= audit.parts.length) {
      audit.status = 'in_progress';
    }
    await ref.read(auditRepositoryProvider).updateAudit(audit);

    ref.invalidate(auditDetailProvider(widget.auditId));
    ref.invalidate(auditPartsProvider(widget.auditId));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_currentPart!.partName} selesai ✓'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _saveProgress();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auditAsync = ref.watch(auditDetailProvider(widget.auditId));
    final partsAsync = ref.watch(auditPartsProvider(widget.auditId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return partsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (parts) {
        if (widget.partIndex >= parts.length) {
          return const Scaffold(body: Center(child: Text('Indeks tidak valid')));
        }
        
        final part = parts[widget.partIndex];
        final photosAsync = ref.watch(partPhotosProvider(part.id));
        final isLocked = auditAsync.valueOrNull?.isLocked ?? false;

        return Scaffold(
          appBar: AppBar(
            title: Text(part.partName),
            actions: [
              if (isLocked)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    child: Chip(
                      label: Text('READ ONLY', style: TextStyle(fontSize: 10, color: Colors.white)),
                      backgroundColor: AppColors.textTertiary,
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Row(
                    children: [
                      Icon(Icons.save_rounded, size: 14, color: AppColors.success),
                      SizedBox(width: 4),
                      Text('Auto-save', style: TextStyle(fontSize: 11, color: AppColors.success)),
                    ],
                  ),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
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
                          value: _partExists,
                          onChanged: isLocked ? null : (v) => setState(() => _partExists = v),
                          activeTrackColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_partExists) ...[
                  Text('Kondisi', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: AppConstants.conditionOptions.map((opt) {
                      final isSel = _selectedCondition == opt.toLowerCase();
                      final color = _getConditionColor(opt.toLowerCase());
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: isLocked ? null : () => setState(() => _selectedCondition = opt.toLowerCase()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSel ? color : AppColors.divider, width: isSel ? 2 : 1),
                                color: isSel ? color.withValues(alpha: 0.1) : null,
                              ),
                              child: Column(
                                children: [
                                  Icon(isSel ? Icons.check_circle : Icons.radio_button_unchecked, color: isSel ? color : AppColors.textTertiary),
                                  Text(opt, style: TextStyle(color: isSel ? color : null, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  photosAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                    data: (photos) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Foto', style: Theme.of(context).textTheme.titleSmall),
                            const Spacer(),
                            Text('${photos.length} foto', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: photos.length + 1,
                            itemBuilder: (ctx, i) {
                              if (i == photos.length) return _buildAddPhotoButton(isLocked, part.id);
                              return _buildPhotoThumbnail(photos[i]);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text('Catatan${part.needsNotes ? ' (Wajib)' : ' (Opsional)'}', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  enabled: !isLocked,
                  onChanged: (_) => _saveProgress(),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: isLocked ? null : _completePart,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                child: const Text('Selesaikan Bagian Ini'),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getConditionColor(String cond) {
    switch (cond) {
      case 'baik': return AppColors.conditionBaik;
      case 'cukup': return AppColors.conditionCukup;
      case 'buruk': return AppColors.conditionBuruk;
      default: return AppColors.textTertiary;
    }
  }

  Widget _buildAddPhotoButton(bool isLocked, String partId) {
    return GestureDetector(
      onTap: isLocked ? null : () async {
        final res = await context.push<bool>('/audit/${widget.auditId}/camera/${widget.partIndex}');
        if (res == true) ref.invalidate(partPhotosProvider(partId));
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, color: AppColors.primary),
            Text('Ambil Foto', style: TextStyle(color: AppColors.primary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail(PhotoModel photo) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: photo.aiValid ? AppColors.success : AppColors.error),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(File(photo.localPath), fit: BoxFit.cover),
      ),
    );
  }
}
