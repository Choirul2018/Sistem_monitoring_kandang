import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:sistem_monitoring_kandang/features/audit/data/photo_model.dart';
import 'package:sistem_monitoring_kandang/features/audit/presentation/providers/audit_provider.dart';
import 'package:sistem_monitoring_kandang/features/audit/data/livestock_sample_model.dart';
import 'package:sistem_monitoring_kandang/app/theme/app_colors.dart';
import 'package:sistem_monitoring_kandang/local_db/hive_service.dart';
import 'package:sistem_monitoring_kandang/features/audit/presentation/camera_capture_screen.dart';

class LivestockSamplingScreen extends ConsumerStatefulWidget {
  final String auditId;
  const LivestockSamplingScreen({super.key, required this.auditId});

  @override
  ConsumerState<LivestockSamplingScreen> createState() =>
      _LivestockSamplingScreenState();
}

class _LivestockSamplingScreenState
    extends ConsumerState<LivestockSamplingScreen> {
  final _uuid = const Uuid();

  Future<void> _openForm([LivestockSampleModel? existing]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _SampleFormScreen(
          auditId: widget.auditId,
          sampleId: existing?.id ?? _uuid.v4(),
          existing: existing,
        ),
      ),
    );
    ref.invalidate(auditLivestockSamplesProvider(widget.auditId));
  }

  Future<void> _deleteSample(LivestockSampleModel sample) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus Sampel?'),
        content: const Text('Data sampel dan foto terkait akan dihapus.'),
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
      await ref.read(auditRepositoryProvider).deleteLivestockSample(sample.id);
      ref.invalidate(auditLivestockSamplesProvider(widget.auditId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final samplesAsync = ref.watch(auditLivestockSamplesProvider(widget.auditId));

    return Scaffold(
      appBar: AppBar(title: const Text('Sampel Ternak')),
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
              child: const Text('Selesai Sampling'),
            ),
          ),
        ),
      ),
      body: samplesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (samples) {
          if (samples.isEmpty) return const _EmptySamplesView();
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: samples.length,
            itemBuilder: (_, i) => _SampleCard(
              sample: samples[i],
              onEdit: () => _openForm(samples[i]),
              onDelete: () => _deleteSample(samples[i]),
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

class _EmptySamplesView extends StatelessWidget {
  const _EmptySamplesView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.pets_rounded, size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          const Text('Belum ada sampel ternak didokumentasikan'),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// FORM SCREEN — OPTIMIZED UNTUK PERFORMANCE KEYBOARD (PHASE 3)
// ════════════════════════════════════════════════════════════════

class _SampleFormScreen extends StatefulWidget {
  final String auditId;
  final String sampleId;
  final LivestockSampleModel? existing;

  const _SampleFormScreen({
    required this.auditId,
    required this.sampleId,
    this.existing,
  });

  @override
  State<_SampleFormScreen> createState() => _SampleFormScreenState();
}

class _SampleFormScreenState extends State<_SampleFormScreen> {
  late String _type;
  late bool _hasDisease;
  final _notesFocus = FocusNode();
  final _notesController = TextEditingController();
  final _scrollController = ScrollController();
  late final ValueNotifier<List<PhotoModel>> _photosNotifier;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.existing?.animalType ?? 'ayam';
    _hasDisease = widget.existing?.hasDisease ?? false;
    _notesController.text = widget.existing?.diseaseNotes ?? '';
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

    final sample = LivestockSampleModel(
      id: widget.sampleId,
      auditId: widget.auditId,
      animalType: _type,
      hasDisease: _hasDisease,
      diseaseNotes: _hasDisease ? _notesController.text.trim() : null,
      photoIds: _photosNotifier.value.map((p) => p.id).toList(),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    await HiveService.livestockSamples.put(sample.id, sample);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // KEMBALI KE STANDAR
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.existing != null ? 'Edit Sampel' : 'Tambah Sampel'),
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
            // ── Jenis Hewan ──
            const Text('Jenis Hewan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TypeTile(
                    label: 'Ayam', icon: Icons.pets_rounded, 
                    selected: _type == 'ayam', 
                    onTap: () => setState(() => _type = 'ayam')
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TypeTile(
                    label: 'Bebek', icon: Icons.water_rounded, 
                    selected: _type == 'bebek', 
                    onTap: () => setState(() => _type = 'bebek')
                  ),
                ),
              ],
            ),
      
            const SizedBox(height: 24),
      
            // ── Status Kesehatan ──
            const Text('Status Kesehatan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                title: const Text('Terdeteksi Penyakit?', style: TextStyle(fontSize: 14)),
                subtitle: Text(_hasDisease ? 'Ada gejala penyakit' : 'Kondisi sehat', style: const TextStyle(fontSize: 12)),
                value: _hasDisease,
                activeThumbColor: AppColors.error,
                onChanged: (v) => setState(() => _hasDisease = v),
              ),
            ),
      
            if (_hasDisease) ...[
              const SizedBox(height: 16),
              // Isolasi cursor animation
              RepaintBoundary(
                child: TextField(
                  controller: _notesController,
                  focusNode: _notesFocus,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Penyakit',
                    hintText: 'Tuliskan gejala...',
                    border: OutlineInputBorder(),
                  ),
                  scrollPadding: EdgeInsets.zero,
                ),
              ),
            ],
      
            const SizedBox(height: 20),
      
            // FOTO SECTION (Selalu tampilkan agar tidak ada beban rebuild)
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

class _KeyboardPlaceholder extends StatelessWidget {
  const _KeyboardPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.image_outlined, color: AppColors.textTertiary),
          SizedBox(width: 12),
          Text('Foto disembunyikan agar mengetik lebih lancar...', 
               style: TextStyle(fontSize: 12, color: AppColors.textTertiary, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeTile({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primary : AppColors.divider, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textTertiary, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: selected ? AppColors.primary : null, fontWeight: selected ? FontWeight.bold : null)),
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

class _SampleCard extends StatelessWidget {
  final LivestockSampleModel sample;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SampleCard({required this.sample, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
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
                Icon(sample.animalType == 'ayam' ? Icons.egg_rounded : Icons.waves_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(sample.animalType.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                IconButton(icon: const Icon(Icons.edit_rounded, size: 18), onPressed: onEdit),
                IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error), onPressed: onDelete),
              ],
            ),
            if (sample.hasDisease && sample.diseaseNotes != null && sample.diseaseNotes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Catatan: ${sample.diseaseNotes}',
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
