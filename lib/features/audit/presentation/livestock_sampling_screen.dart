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

  /// Buka form sebagai layar penuh melalui Navigator biasa
  /// (bukan GoRouter agar tidak ada konflik extra/callback)
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
    // Setelah form ditutup, refresh daftar
    ref.invalidate(auditLivestockSamplesProvider(widget.auditId));
  }

  Future<void> _deleteSample(LivestockSampleModel sample) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus Sampel?'),
        content: const Text('Data sampel dan foto terkait akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Hapus',
                style: TextStyle(color: AppColors.error)),
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
    final samplesAsync =
        ref.watch(auditLivestockSamplesProvider(widget.auditId));

    return Scaffold(
      appBar: AppBar(title: const Text('Sampel Ternak')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add_rounded),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton(
            onPressed: () => context.pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Selesai Sampling'),
          ),
        ),
      ),
      body: samplesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (samples) {
          if (samples.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.pets_rounded,
                      size: 64, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  const Text('Belum ada sampel ternak didokumentasikan'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Ambil Sampel Pertama'),
                  ),
                ],
              ),
            );
          }
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

// ════════════════════════════════════════════════════════════════
// FORM SCREEN — Anti-lag: TextField selalu di tree (Offstage)
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

  // FocusNode dan controller dibuat sekali — tidak rebuild
  final _notesFocus = FocusNode();
  final _notesController = TextEditingController();
  final List<PhotoModel> _photos = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.existing?.animalType ?? 'ayam';
    _hasDisease = widget.existing?.hasDisease ?? false;
    _notesController.text = widget.existing?.diseaseNotes ?? '';
    _loadPhotos();
  }

  @override
  void dispose() {
    _notesFocus.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadPhotos() {
    final photos = HiveService.photos.values
        .where((p) => p.auditPartId == widget.sampleId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _photos
      ..clear()
      ..addAll(photos);
  }

  /// Membaca ulang foto dari Hive dengan mekanisme retry untuk mencegah race condition
  void _reloadPhotos() {
    _performReload();
    
    // Coba lagi setelah 500ms untuk memastikan data yang baru disimpan sudah terbaca
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _performReload();
    });
  }

  void _performReload() {
    final photos = HiveService.photos.values
        .where((p) => p.auditPartId == widget.sampleId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    if (mounted) {
      setState(() {
        _photos.clear();
        _photos.addAll(photos);
      });
    }
  }

  Future<void> _openCamera() async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    // Tunggu kamera ditutup sepenuhnya
    await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CameraCaptureScreen(
          auditId: widget.auditId,
          auditPartId: widget.sampleId,
        ),
      ),
    );

    // Beri jeda sangat singkat agar Hive selesai menulis ke disk
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 300));
      _reloadPhotos();
    }
  }

  void _deletePhoto(PhotoModel photo) {
    try {
      File(photo.localPath).exists().then((e) {
        if (e) File(photo.localPath).delete();
      });
    } catch (_) {}
    HiveService.photos.delete(photo.id);
    setState(() => _photos.remove(photo));
  }

  Future<void> _save() async {
    if (_isSaving) return;
    // Tutup keyboard sebelum simpan
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final sample = LivestockSampleModel(
      id: widget.sampleId,
      auditId: widget.auditId,
      animalType: _type,
      hasDisease: _hasDisease,
      diseaseNotes: _hasDisease ? _notesController.text.trim() : null,
      photoIds: _photos.map((p) => p.id).toList(),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    await HiveService.livestockSamples.put(sample.id, sample);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Scaffold(
      resizeToAvoidBottomInset: false, // Frame tetap untuk mencegah lag
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Sampel Ternak' : 'Tambah Sampel Ternak'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Simpan',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 40 + MediaQuery.of(context).viewInsets.bottom),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Jenis Hewan ──────────────────────────────────────
            const RepaintBoundary(
              child: Text('Jenis Hewan',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: RepaintBoundary(
                    child: _TypeTile(
                      label: 'Ayam',
                      icon: Icons.pets_rounded,
                      selected: _type == 'ayam',
                      onTap: () => setState(() => _type = 'ayam'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RepaintBoundary(
                    child: _TypeTile(
                      label: 'Bebek',
                      icon: Icons.water_rounded,
                      selected: _type == 'bebek',
                      onTap: () => setState(() => _type = 'bebek'),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Status Kesehatan ─────────────────────────────────
            const RepaintBoundary(
              child: Text('Status Kesehatan',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            const SizedBox(height: 8),
            RepaintBoundary(
              child: Card(
                margin: EdgeInsets.zero,
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: const Text('Terdeteksi Penyakit?'),
                  subtitle: Text(_hasDisease ? 'Ada gejala' : 'Sehat'),
                  value: _hasDisease,
                  activeColor: AppColors.error,
                  onChanged: (v) {
                    setState(() => _hasDisease = v);
                    if (v) {
                      Future.delayed(const Duration(milliseconds: 50), () {
                        if (mounted) _notesFocus.requestFocus();
                      });
                    }
                  },
                ),
              ),
            ),

            // ── Catatan Penyakit ─────────────────────────────────
            RepaintBoundary(
              child: Offstage(
                offstage: !_hasDisease,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: TextField(
                    controller: _notesController,
                    focusNode: _notesFocus,
                    maxLines: 4,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _notesFocus.unfocus(),
                    decoration: const InputDecoration(
                      labelText: 'Catatan Penyakit',
                      hintText: 'Tuliskan gejala yang ditemukan...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Foto ─────────────────────────────────────────────
            const RepaintBoundary(
              child: Text('Dokumentasi Foto',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                RepaintBoundary(
                  child: GestureDetector(
                    onTap: _isSaving ? null : _openCamera,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Icon(Icons.add_a_photo_rounded,
                          color: AppColors.primary),
                    ),
                  ),
                ),
                for (final p in _photos)
                  RepaintBoundary(
                    key: ValueKey('thumb_${p.id}'),
                    child: _PhotoThumb(
                        photo: p, onDelete: () => _deletePhoto(p)),
                  ),
              ],
            ),

            const SizedBox(height: 40),

            // ── Tombol Simpan ─────────────────────────────────────
            RepaintBoundary(
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: Text(isEdit ? 'Simpan Perubahan' : 'Simpan Sampel'),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Widget Pendukung
// ════════════════════════════════════════════════════════════════

class _TypeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeTile(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.08)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
              width: 2),
        ),
        child: Column(
          children: [
            Icon(icon,
                color:
                    selected ? AppColors.primary : AppColors.textTertiary,
                size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                  color: selected
                      ? AppColors.primary
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final PhotoModel photo;
  final VoidCallback onDelete;

  const _PhotoThumb({required this.photo, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(photo.localPath),
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            cacheWidth: 160, // Batasi resolusi decode agar ringan
            errorBuilder: (_, __, ___) => Container(
              width: 80,
              height: 80,
              color: AppColors.error.withOpacity(0.1),
              child: const Icon(Icons.broken_image,
                  size: 24, color: AppColors.error),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _SampleCard extends StatelessWidget {
  final LivestockSampleModel sample;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SampleCard(
      {required this.sample,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      sample.animalType == 'ayam'
                          ? Icons.egg_rounded
                          : Icons.waves_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sample.animalType.toUpperCase(),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '${sample.createdAt.hour.toString().padLeft(2, '0')}:'
                          '${sample.createdAt.minute.toString().padLeft(2, '0')}'
                          ' — ${sample.createdAt.day}/${sample.createdAt.month}/${sample.createdAt.year}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded,
                        size: 20, color: AppColors.primary),
                    onPressed: onEdit,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 20, color: AppColors.error),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: sample.hasDisease
                          ? AppColors.errorLight
                          : AppColors.successLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      sample.hasDisease ? 'PENYAKIT' : 'SEHAT',
                      style: TextStyle(
                        color: sample.hasDisease
                            ? AppColors.error
                            : AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (sample.diseaseNotes != null) ...[
                const SizedBox(height: 10),
                const Text('Catatan Penyakit:',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
                Text(sample.diseaseNotes!,
                    style: const TextStyle(fontSize: 12)),
              ],
              if (sample.photoIds.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: sample.photoIds.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final p =
                          HiveService.photos.get(sample.photoIds[i]);
                      if (p == null) return const SizedBox.shrink();
                      return RepaintBoundary(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(p.localPath),
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            cacheWidth: 128,
                            errorBuilder: (_, __, ___) => Container(
                              width: 64,
                              height: 64,
                              color: AppColors.error.withOpacity(0.1),
                              child: const Icon(Icons.broken_image,
                                  size: 20, color: AppColors.error),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
