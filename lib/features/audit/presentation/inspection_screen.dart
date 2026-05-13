import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:sistem_monitoring_kandang/features/audit/data/photo_model.dart';
import 'package:sistem_monitoring_kandang/features/audit/presentation/providers/audit_provider.dart';
import 'package:sistem_monitoring_kandang/features/audit/data/inspection_model.dart';
import 'package:sistem_monitoring_kandang/app/theme/app_colors.dart';
import 'package:sistem_monitoring_kandang/local_db/hive_service.dart';
import 'package:sistem_monitoring_kandang/features/audit/presentation/camera_capture_screen.dart';

class InspectionScreen extends ConsumerStatefulWidget {
  final String auditId;
  const InspectionScreen({super.key, required this.auditId});

  @override
  ConsumerState<InspectionScreen> createState() =>
      _InspectionScreenState();
}

class _InspectionScreenState
    extends ConsumerState<InspectionScreen> {
  final _uuid = const Uuid();

  Future<void> _openForm([InspectionModel? existing]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _InspectionFormScreen(
          auditId: widget.auditId,
          sampleId: existing?.id ?? _uuid.v4(),
          existing: existing,
        ),
      ),
    );
    ref.invalidate(auditInspectionsProvider(widget.auditId));
  }

  Future<void> _deleteInspection(InspectionModel sample) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus Inspeksi?'),
        content: const Text('Data inspeksi dan foto terkait akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      for (final id in sample.photoIds) {
        await ref.read(auditRepositoryProvider).deletePhoto(id);
      }
      await ref.read(auditRepositoryProvider).deleteInspection(sample.id);
      ref.invalidate(auditInspectionsProvider(widget.auditId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final samplesAsync = ref.watch(auditInspectionsProvider(widget.auditId));

    return Scaffold(
      appBar: AppBar(title: const Text('Inspeksi Unit')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      bottomNavigationBar: _KeyboardSensitiveBottomBar(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Selesai Inspeksi'),
            ),
          ),
        ),
      ),
      body: samplesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (samples) {
          if (samples.isEmpty) return const _EmptyInspectionsView();
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: samples.length,
            itemBuilder: (_, i) => _InspectionCard(
              sample: samples[i],
              onEdit: () => _openForm(samples[i]),
              onDelete: () => _deleteInspection(samples[i]),
            ),
          );
        },
      ),
    );
  }
}

class _KeyboardSensitiveBottomBar extends StatelessWidget {
  final Widget child;
  const _KeyboardSensitiveBottomBar({required this.child});

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return isKeyboardOpen ? const SizedBox.shrink() : child;
  }
}

class _EmptyInspectionsView extends StatelessWidget {
  const _EmptyInspectionsView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          const Text('Belum ada inspeksi unit didokumentasikan'),
        ],
      ),
    );
  }
}

class _InspectionFormScreen extends StatefulWidget {
  final String auditId;
  final String sampleId;
  final InspectionModel? existing;

  const _InspectionFormScreen({
    required this.auditId,
    required this.sampleId,
    this.existing,
  });

  @override
  State<_InspectionFormScreen> createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<_InspectionFormScreen> {
  late String _category;
  late bool _isDefective;
  final _notesFocus = FocusNode();
  final _notesController = TextEditingController();
  final _scrollController = ScrollController();
  late final ValueNotifier<List<PhotoModel>> _photosNotifier;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _category = widget.existing?.category ?? 'infrastructure';
    _isDefective = widget.existing?.isDefective ?? false;
    _notesController.text = widget.existing?.issueDetails ?? '';
    _photosNotifier = ValueNotifier<List<PhotoModel>>(_loadPhotosSync());
  }


  List<PhotoModel> _loadPhotosSync() {
    return HiveService.photos.values
        .where((p) => p.auditPartId == widget.sampleId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  @override
  void dispose() {
    _notesFocus.dispose();
    _notesController.dispose();
    _photosNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _reloadPhotos() {
    _photosNotifier.value = _loadPhotosSync();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _photosNotifier.value = _loadPhotosSync();
    });
  }

  Future<void> _openCamera() async {
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CameraCaptureScreen(
          auditId: widget.auditId,
          auditPartId: widget.sampleId,
        ),
      ),
    );

    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 300));
      _reloadPhotos();
    }
  }

  void _deletePhoto(PhotoModel photo) {
    HiveService.photos.delete(photo.id);
    try { File(photo.localPath).delete(); } catch (_) {}
    _photosNotifier.value = _loadPhotosSync();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final sample = InspectionModel(
      id: widget.sampleId,
      auditId: widget.auditId,
      category: _category,
      isDefective: _isDefective,
      issueDetails: _isDefective ? _notesController.text.trim() : null,
      photoIds: _photosNotifier.value.map((p) => p.id).toList(),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    await HiveService.inspections.put(sample.id, sample);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.existing != null ? 'Edit Inspeksi' : 'Tambah Inspeksi'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isSaving)
            TextButton(
              onPressed: _save,
              child: const Text('SIMPAN', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kategori Unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            Column(
              children: [
                _CategoryTile(
                  label: 'Infrastruktur', icon: Icons.business_rounded, 
                  selected: _category == 'infrastructure', 
                  onTap: () => setState(() => _category = 'infrastructure')
                ),
                const SizedBox(height: 8),
                _CategoryTile(
                  label: 'Keamanan / Safety', icon: Icons.security_rounded, 
                  selected: _category == 'safety', 
                  onTap: () => setState(() => _category = 'safety')
                ),
                const SizedBox(height: 8),
                _CategoryTile(
                  label: 'Utilitas / ME', icon: Icons.settings_input_component_rounded, 
                  selected: _category == 'utility', 
                  onTap: () => setState(() => _category = 'utility')
                ),
              ],
            ),
      
            const SizedBox(height: 24),
      
            const Text('Status Kondisi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: const Text('Ditemukan Masalah?', style: TextStyle(fontSize: 14)),
                subtitle: Text(_isDefective ? 'Ada masalah/temuan' : 'Kondisi normal', style: const TextStyle(fontSize: 12)),
                value: _isDefective,
                activeThumbColor: AppColors.error,
                onChanged: (v) => setState(() => _isDefective = v),
              ),
            ),
      
            if (_isDefective) ...[
              const SizedBox(height: 16),
              RepaintBoundary(
                child: TextField(
                  controller: _notesController,
                  focusNode: _notesFocus,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Detail Masalah',
                    hintText: 'Tuliskan temuan masalah...',
                    border: OutlineInputBorder(),
                  ),
                  scrollPadding: EdgeInsets.zero,
                ),
              ),
            ],
      
            const SizedBox(height: 20),
      
            RepaintBoundary(
              child: _PhotoGridSection(
                notifier: _photosNotifier,
                onTakePhoto: _openCamera,
                onDeletePhoto: _deletePhoto,
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primary : AppColors.divider, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textTertiary, size: 24),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: selected ? AppColors.primary : null, fontWeight: selected ? FontWeight.bold : null)),
            const Spacer(),
            if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _PhotoGridSection extends StatelessWidget {
  final ValueNotifier<List<PhotoModel>> notifier;
  final VoidCallback onTakePhoto;
  final ValueChanged<PhotoModel> onDeletePhoto;

  const _PhotoGridSection({required this.notifier, required this.onTakePhoto, required this.onDeletePhoto});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Dokumentasi Foto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        ValueListenableBuilder<List<PhotoModel>>(
          valueListenable: notifier,
          builder: (context, photos, _) {
            return Wrap(
              spacing: 10, runSpacing: 10,
              children: [
                _AddPhotoBox(onTap: onTakePhoto),
                for (final p in photos)
                  _PhotoThumbnail(key: ValueKey(p.id), photo: p, onDelete: () => onDeletePhoto(p)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AddPhotoBox extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPhotoBox({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Icon(Icons.add_a_photo_rounded, color: AppColors.primary),
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final PhotoModel photo;
  final VoidCallback onDelete;
  const _PhotoThumbnail({super.key, required this.photo, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80, height: 80,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(photo.localPath),
              width: 80, height: 80, fit: BoxFit.cover,
              cacheWidth: 160, gaplessPlayback: true,
            ),
          ),
          Positioned(
            top: 4, right: 4,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectionCard extends StatelessWidget {
  final InspectionModel sample;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _InspectionCard({required this.sample, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    IconData getIcon() {
      switch (sample.category) {
        case 'infrastructure': return Icons.business_rounded;
        case 'safety': return Icons.security_rounded;
        case 'utility': return Icons.settings_input_component_rounded;
        default: return Icons.inventory_2_outlined;
      }
    }

    String getLabel() {
      switch (sample.category) {
        case 'infrastructure': return 'Infrastruktur';
        case 'safety': return 'Keamanan';
        case 'utility': return 'Utilitas';
        default: return sample.category.toUpperCase();
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(getIcon(), color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(getLabel(), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                IconButton(icon: const Icon(Icons.edit_rounded, size: 18), onPressed: onEdit),
                IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error), onPressed: onDelete),
              ],
            ),
            if (sample.isDefective && sample.issueDetails != null && sample.issueDetails!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Temuan: ${sample.issueDetails}',
                  style: const TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ),
            ],
            if (sample.photoIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  itemCount: sample.photoIds.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final p = HiveService.photos.get(sample.photoIds[i]);
                    if (p == null) return const SizedBox.shrink();
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(p.localPath), width: 60, height: 60, fit: BoxFit.cover, cacheWidth: 120),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
