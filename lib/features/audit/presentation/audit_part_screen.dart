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
  List<PhotoModel> _photos = [];

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

      // Load photos
      final photos = await ref.read(partPhotosProvider(part.id).future);
      setState(() => _photos = photos);
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
    _currentPart!.condition = _selectedCondition;
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

      if (_photos.isEmpty) {
        _showError('Ambil minimal satu foto untuk bagian ini.');
        return;
      }
    }

    // Save and mark complete
    _currentPart!.completed = true;
    _currentPart!.partExists = _partExists;
    _currentPart!.condition = _selectedCondition;
    _currentPart!.notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    await ref.read(auditRepositoryProvider).updateAuditPart(_currentPart!);

    // Advance audit to next part
    final audit = await ref.read(auditDetailProvider(widget.auditId).future);
    if (audit != null) {
      audit.currentPartIndex = widget.partIndex + 1;
      if (audit.currentPartIndex >= audit.parts.length) {
        audit.status = 'in_progress'; // all parts done
      }
      await ref.read(auditRepositoryProvider).updateAudit(audit);
    }

    // Refresh and go back
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
    _saveProgress(); // Final save
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_currentPart == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPart!.partName),
        actions: [
          // Auto-save indicator
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.save_rounded, size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  'Auto-save',
                  style: TextStyle(fontSize: 11, color: AppColors.success),
                ),
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
            // ─── Part Exists Toggle ───
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bagian ini ada?',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Jika tidak ada, catatan wajib diisi',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _partExists,
                      onChanged: (value) {
                        setState(() {
                          _partExists = value;
                          if (!value) {
                            _selectedCondition = null;
                          }
                        });
                      },
                      activeTrackColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ─── Condition Selector ───
            if (_partExists) ...[
              Text(
                'Kondisi',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: AppConstants.conditionOptions.map((condition) {
                  final isSelected = _selectedCondition == condition.toLowerCase();
                  Color color;
                  switch (condition.toLowerCase()) {
                    case 'baik':
                      color = AppColors.conditionBaik;
                      break;
                    case 'cukup':
                      color = AppColors.conditionCukup;
                      break;
                    case 'buruk':
                      color = AppColors.conditionBuruk;
                      break;
                    default:
                      color = AppColors.textTertiary;
                  }

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: condition != AppConstants.conditionOptions.last ? 8 : 0,
                      ),
                      child: Material(
                        color: isSelected
                            ? color.withValues(alpha: 0.15)
                            : (isDark ? AppColors.darkSurface : AppColors.surface),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCondition = condition.toLowerCase();
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? color
                                    : (isDark ? AppColors.darkDivider : AppColors.divider),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: isSelected ? color : AppColors.textTertiary,
                                  size: 28,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  condition,
                                  style: TextStyle(
                                    color: isSelected ? color : null,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // ─── Photos Section ───
            if (_partExists) ...[
              Row(
                children: [
                  Text(
                    'Foto',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  Text(
                    '${_photos.length} foto',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Photo grid
              if (_photos.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _photos.length) {
                        // Add photo button
                        return _buildAddPhotoButton();
                      }
                      return _buildPhotoThumbnail(_photos[index]);
                    },
                  ),
                )
              else
                _buildAddPhotoButton(fullWidth: true),

              const SizedBox(height: 20),
            ],

            // ─── Notes ───
            Text(
              'Catatan${_currentPart!.needsNotes ? ' (Wajib)' : ' (Opsional)'}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Tulis catatan observasi...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: (_) => _saveProgress(),
            ),

            const SizedBox(height: 100), // Space for bottom button
          ],
        ),
      ),

      // ─── Complete Button ───
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
            onPressed: _completePart,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_rounded, size: 20),
                SizedBox(width: 8),
                Text('Selesaikan Bagian Ini'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddPhotoButton({bool fullWidth = false}) {
    return GestureDetector(
      onTap: () async {
        final result = await context.push<bool>(
          '/audit/${widget.auditId}/camera/${widget.partIndex}',
        );
        if (result == true) {
          _loadPartData(); // Reload photos
        }
      },
      child: Container(
        width: fullWidth ? double.infinity : 120,
        height: fullWidth ? 100 : 120,
        margin: fullWidth ? null : const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 32),
            const SizedBox(height: 8),
            Text(
              'Ambil Foto',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail(PhotoModel photo) {
    final file = File(photo.localPath);

    return Container(
      width: 120,
      height: 120,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: photo.aiValid
              ? AppColors.success.withValues(alpha: 0.5)
              : AppColors.error.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            file.existsSync()
                ? Image.file(file, fit: BoxFit.cover)
                : const Center(child: Icon(Icons.image_not_supported)),
            // AI validation badge
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: photo.aiValid ? AppColors.success : AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  photo.aiValid ? Icons.check : Icons.close,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
