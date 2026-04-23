import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:sistem_monitoring_kandang/features/audit/presentation/providers/audit_provider.dart';
import 'package:sistem_monitoring_kandang/features/audit/data/livestock_sample_model.dart';
import 'package:sistem_monitoring_kandang/app/theme/app_colors.dart';

class LivestockSamplingScreen extends ConsumerStatefulWidget {
  final String auditId;

  const LivestockSamplingScreen({super.key, required this.auditId});

  @override
  ConsumerState<LivestockSamplingScreen> createState() => _LivestockSamplingScreenState();
}

class _LivestockSamplingScreenState extends ConsumerState<LivestockSamplingScreen> {
  final _uuid = const Uuid();

  void _addSample() {
    String selectedType = 'ayam';
    bool hasDisease = false;
    final notesController = TextEditingController();
    List<String> capturedPhotoIds = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tambah Sampel Hewan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              const Text('Jenis Hewan:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                   _TypeOption(
                    label: 'Ayam',
                    isSelected: selectedType == 'ayam',
                    onTap: () => setModalState(() => selectedType = 'ayam'),
                  ),
                  const SizedBox(width: 12),
                  _TypeOption(
                    label: 'Bebek',
                    isSelected: selectedType == 'bebek',
                    onTap: () => setModalState(() => selectedType = 'bebek'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Status Kesehatan:', style: TextStyle(fontWeight: FontWeight.bold)),
              SwitchListTile(
                title: const Text('Terdeteksi Penyakit?'),
                subtitle: Text(hasDisease ? 'Ada gejala penyakit' : 'Hewan sehat'),
                value: hasDisease,
                activeColor: AppColors.error,
                onChanged: (val) => setModalState(() => hasDisease = val),
              ),
              if (hasDisease) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Penyakit',
                    hintText: 'Tuliskan gejala yang ditemukan...',
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Text('Dokumentasi Foto:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    InkWell(
                      onTap: () async {
                        final photoId = _uuid.v4();
                        // Navigate to camera
                        context.push('/audit/${widget.auditId}/camera/0'); // Placeholder index
                        // Note: In real app, we'd handle the callback properly
                        setModalState(() => capturedPhotoIds.add(photoId));
                      },
                      child: Container(
                        width: 80,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: const Icon(Icons.add_a_photo_rounded, color: AppColors.primary),
                      ),
                    ),
                    ...capturedPhotoIds.map((id) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Container(
                        width: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final sample = LivestockSampleModel(
                      id: _uuid.v4(),
                      auditId: widget.auditId,
                      animalType: selectedType,
                      hasDisease: hasDisease,
                      diseaseNotes: hasDisease ? notesController.text : null,
                      photoIds: capturedPhotoIds,
                      createdAt: DateTime.now(),
                    );

                    await ref.read(auditRepositoryProvider).saveLivestockSample(sample);
                    ref.invalidate(auditLivestockSamplesProvider(widget.auditId));
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Simpan Sampel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final samplesAsync = ref.watch(auditLivestockSamplesProvider(widget.auditId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sampel Hewan'),
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
                  const Icon(Icons.pets_rounded, size: 64, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  const Text('Belum ada sampel hewan didokumentasikan'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _addSample,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Ambil Sampel Pertama'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: samples.length,
            itemBuilder: (context, index) {
              final sample = samples[index];
              return _SampleCard(sample: sample);
            },
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () => context.pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Selesai Sampling'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSample,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeOption({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.divider,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SampleCard extends StatelessWidget {
  final LivestockSampleModel sample;

  const _SampleCard({required this.sample});

  @override
  Widget build(BuildContext context) {
    return Card(
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
                    sample.animalType == 'ayam' ? Icons.egg_rounded : Icons.waves_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sample.animalType.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${sample.createdAt.hour}:${sample.createdAt.minute} - ${sample.createdAt.day}/${sample.createdAt.month}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sample.hasDisease ? AppColors.errorLight : AppColors.successLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    sample.hasDisease ? 'PENYAKIT' : 'SEHAT',
                    style: TextStyle(
                      color: sample.hasDisease ? AppColors.error : AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (sample.diseaseNotes != null) ...[
              const SizedBox(height: 12),
              const Text('Catatan Penyakit:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text(sample.diseaseNotes!, style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
