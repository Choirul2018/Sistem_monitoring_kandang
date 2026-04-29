import 'dart:io';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../../features/audit/data/audit_model.dart';
import '../../features/audit/data/audit_part_model.dart';
import '../../features/audit/data/photo_model.dart';
import '../../features/audit/data/livestock_sample_model.dart';

class PdfExporter {
  static Future<File> generateReport({
    required AuditModel audit,
    required List<AuditPartModel> parts,
    required List<LivestockSampleModel> samples,
    required Map<String, List<dynamic>> photos,
  }) async {
    final pdf = pw.Document();

    // ─── Cover Page ───
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 60),
              pw.Center(
                child: pw.Text(
                  'LAPORAN AUDIT',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal800,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Sistem Monitoring Kandang',
                  style: pw.TextStyle(fontSize: 14, color: PdfColors.grey600),
                ),
              ),
              pw.SizedBox(height: 40),
              pw.Divider(color: PdfColors.teal800, thickness: 2),
              pw.SizedBox(height: 30),
              _buildInfoRow('Lokasi', audit.locationName ?? '-'),
              _buildInfoRow('Auditor', audit.auditorName ?? '-'),
              _buildInfoRow('Tanggal Audit', '${audit.createdAt.day}/${audit.createdAt.month}/${audit.createdAt.year}'),
              _buildInfoRow('Status', audit.status.toUpperCase()),
              _buildInfoRow('Total Bagian', '${parts.length}'),
              _buildInfoRow('Bagian Baik', '${parts.where((p) => p.condition == "baik").length}'),
              _buildInfoRow('Bagian Cukup', '${parts.where((p) => p.condition == "cukup").length}'),
              _buildInfoRow('Bagian Buruk', '${parts.where((p) => p.condition == "buruk").length}'),
              _buildInfoRow('Tidak Ada', '${parts.where((p) => !p.partExists).length}'),
              pw.SizedBox(height: 30),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 20),
              pw.Text(
                'Laporan ini digenerate secara otomatis oleh Sistem Monitoring Kandang.',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
              ),
            ],
          );
        },
      ),
    );

    // ─── Condition Summary Table ───
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Ringkasan Kondisi',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 16),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal50),
                cellPadding: const pw.EdgeInsets.all(6),
                headers: ['No', 'Bagian', 'Ada', 'Kondisi', 'Foto', 'Catatan'],
                data: parts.map((part) {
                  return [
                    '${part.partIndex + 1}',
                    part.partName,
                    part.partExists ? 'Ya' : 'Tidak',
                    part.condition?.toUpperCase() ?? '-',
                    '${part.photoIds.length}',
                    part.notes ?? '-',
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    // ─── Livestock Samples Table ───
    if (samples.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Data Sampel Ternak',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 16),
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.teal50),
                  cellPadding: const pw.EdgeInsets.all(6),
                  headers: ['No', 'Jenis Hewan', 'Status', 'Catatan'],
                  data: List.generate(samples.length, (index) {
                    final s = samples[index];
                    return [
                      '${index + 1}',
                      s.animalType.toUpperCase(),
                      s.hasDisease ? 'ADA PENYAKIT' : 'SEHAT',
                      s.diseaseNotes ?? '-',
                    ];
                  }),
                ),
              ],
            );
          },
        ),
      );
    }

    // ─── Detail Pages (one per part) ───
    for (final part in parts) {
      final partPhotos = (photos[part.id] ?? []).cast<PhotoModel>();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) {
            final widgets = <pw.Widget>[
              pw.Text(
                'Bagian: ${part.partName}',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Text('Kondisi: ', style: const pw.TextStyle(fontSize: 11)),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: _getConditionColor(part.condition),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      part.condition?.toUpperCase() ?? 'TIDAK ADA',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ],
              ),
              if (part.notes != null && part.notes!.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Text('Catatan: ${part.notes}', style: const pw.TextStyle(fontSize: 11)),
              ],
              pw.SizedBox(height: 16),
            ];

            // Add photos
            if (partPhotos.isNotEmpty) {
              widgets.add(
                pw.Text(
                  'Foto (${partPhotos.length}):',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              );
              widgets.add(pw.SizedBox(height: 8));

              for (final photo in partPhotos) {
                final file = File(photo.localPath);
                if (file.existsSync()) {
                  try {
                    final imageBytes = file.readAsBytesSync();
                    final image = pw.MemoryImage(imageBytes);

                    widgets.add(
                      pw.Container(
                        margin: const pw.EdgeInsets.only(bottom: 12),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.ClipRRect(
                              horizontalRadius: 4,
                              verticalRadius: 4,
                              child: pw.Image(image, width: 400, fit: pw.BoxFit.fitWidth),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'GPS: ${photo.coordinatesString} | '
                              'Waktu: ${photo.timestamp.day}/${photo.timestamp.month}/${photo.timestamp.year} '
                              '${photo.timestamp.hour}:${photo.timestamp.minute.toString().padLeft(2, "0")} | '
                              'ID: ${photo.qrCodeId.substring(0, 8)}',
                              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                            ),
                          ],
                        ),
                      ),
                    );
                  } catch (_) {
                    widgets.add(pw.Text('[Foto tidak dapat dimuat]'));
                  }
                }
              }
            }

            return widgets;
          },
        ),
      );
    }

    // ─── Signature Page ───
    if (audit.signatureData != null) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) {
            pw.Widget signatureWidget;
            try {
              final sigBytes = base64Decode(audit.signatureData!);
              signatureWidget = pw.Image(pw.MemoryImage(sigBytes), width: 200);
            } catch (_) {
              signatureWidget = pw.Text('[Tanda tangan tidak tersedia]');
            }

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Tanda Tangan',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 30),
                pw.Text('Auditor: ${audit.auditorName ?? "-"}'),
                pw.SizedBox(height: 16),
                pw.Container(
                  width: 250,
                  height: 100,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Center(child: signatureWidget),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Ditandatangani pada: ${audit.updatedAt.day}/${audit.updatedAt.month}/${audit.updatedAt.year}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ],
            );
          },
        ),
      );
    }

    // Save to file
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/laporan_audit_${audit.id.substring(0, 8)}.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          ),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 11)),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static PdfColor _getConditionColor(String? condition) {
    switch (condition) {
      case 'baik':
        return PdfColors.green;
      case 'cukup':
        return PdfColors.amber;
      case 'buruk':
        return PdfColors.red;
      default:
        return PdfColors.grey;
    }
  }
}
