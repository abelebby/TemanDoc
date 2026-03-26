import 'dart:typed_data';
import 'package:flutter/material.dart' show BuildContext, ScaffoldMessenger, SnackBar, Text, Colors, SnackBarBehavior, AppTheme;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';

class DoctorPdfGenerator {
  static final PdfColor _teal = PdfColor.fromHex('#0D6E6E');
  static final PdfColor _navy = PdfColor.fromHex('#1A3C5E');
  static final PdfColor _accent = PdfColor.fromHex('#14919B');
  static final PdfColor _success = PdfColor.fromHex('#16A34A');
  static final PdfColor _warning = PdfColor.fromHex('#F59E0B');
  static final PdfColor _error = PdfColor.fromHex('#DC2626');
  static final PdfColor _grey = PdfColor.fromHex('#F3F4F6');
  
  static String _classify(String key, dynamic value) {
    if (value == null) return '-';
    // Clean value (e.g. might be "120/80")
    String vStr = value.toString();
    if (vStr.contains('/')) vStr = vStr.split('/').first;
    final v = double.tryParse(vStr) ?? 0;

    switch (key) {
      case 'heart_rate':
        if (v < 60) return '⚠ Low';
        if (v <= 100) return '✓ Normal';
        return '⚠ High';
      case 'blood_pressure':
        if (v < 90) return '⚠ Low';
        if (v <= 120) return '✓ Normal';
        if (v <= 139) return '⚠ Elevated';
        return '🔴 High';
      case 'blood_glucose':
        if (v < 70) return '⚠ Low';
        if (v <= 99) return '✓ Normal';
        if (v <= 125) return '⚠ Pre-diabetic';
        return '🔴 High';
      case 'oxygen_saturation':
        if (v >= 95) return '✓ Normal';
        if (v >= 90) return '⚠ Low';
        return '🔴 Critical';
      default: return '-';
    }
  }

  static PdfColor _statusColor(String status) {
    if (status.contains('Normal')) return _success;
    if (status.contains('Elevated') || status.contains('Low') || status.contains('Pre')) return _warning;
    if (status.contains('High') || status.contains('Critical')) return _error;
    return PdfColors.black;
  }

  static String _formatTime(String? ts) {
    if (ts == null || ts.isEmpty) return '-';
    try {
      return DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(ts).toLocal());
    } catch (_) {
      return ts;
    }
  }

  static Future<void> generateAndDownload({
    required Map<String, dynamic> patient,
    required List<Map<String, dynamic>> metrics,
    required List<Map<String, dynamic>> medications,
    required List<Map<String, dynamic>> appointments,
    required Map<String, dynamic> doctor,
    required Map<String, Uint8List?> chartImages,
    required BuildContext context,
  }) async {
    final pdf = pw.Document();
    
    // Load Fonts & Assets
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();
    final fontItalic = await PdfGoogleFonts.openSansItalic();
    
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/img/TemanU.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    final dateStr = DateFormat('MMMM d, yyyy').format(DateTime.now());
    final patientName = patient['name'] ?? 'Unknown';

    // ==========================================
    // PAGE 1: SUMMARY
    // ==========================================
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold, italic: fontItalic),
        build: (pw.Context ctx) {
          return [
            // HEADER
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoImage != null)
                  pw.Image(logoImage, height: 40)
                else
                  pw.Text('TemanU', style: pw.TextStyle(color: _teal, fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('COMPREHENSIVE PATIENT REPORT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _navy, fontSize: 14)),
                    pw.Text(dateStr, style: pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
                    pw.Text('Prepared by: Dr. ${doctor['name']}', style: pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: _teal, thickness: 2),
            pw.SizedBox(height: 20),

            // PATIENT INFO BOX
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: _grey,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(patientName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: _navy)),
                        pw.SizedBox(height: 5),
                        pw.Text('Username: ${patient['username'] ?? '-'}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('DOB: ${patient['dob'] ?? '-'}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Gender: ${patient['gender'] ?? '-'}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Blood Type: ${patient['blood_type'] ?? '-'}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // LATEST HEALTH METRICS
            pw.Text('Latest Health Metrics', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: _navy)),
            pw.SizedBox(height: 10),
            if (metrics.isEmpty)
              pw.Text('No health metrics recorded.', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey700))
            else
              pw.Table.fromTextArray(
                context: ctx,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: pw.BoxDecoration(color: _teal),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellPadding: const pw.EdgeInsets.all(6),
                data: [
                  ['Metric', 'Value', 'Unit', 'Status'],
                  ['Heart Rate', metrics.first['heart_rate']?.toString() ?? '-', 'bpm', _classify('heart_rate', metrics.first['heart_rate'])],
                  ['Blood Pressure', 
                   (metrics.first['blood_pressure_systolic'] != null && metrics.first['blood_pressure_diastolic'] != null)
                     ? '${metrics.first['blood_pressure_systolic']}/${metrics.first['blood_pressure_diastolic']}' : '-',
                   'mmHg', _classify('blood_pressure', metrics.first['blood_pressure_systolic'])],
                  ['Blood Glucose', metrics.first['blood_glucose']?.toString() ?? '-', 'mg/dL', _classify('blood_glucose', metrics.first['blood_glucose'])],
                  ['Oxygen Saturation', metrics.first['oxygen_saturation']?.toString() ?? '-', '%', _classify('oxygen_saturation', metrics.first['oxygen_saturation'])],
                  ['Body Weight', metrics.first['body_weight']?.toString() ?? '-', 'kg', '-'],
                ].map((row) {
                  // Custom row mapping to apply colors to Status
                   return row.map((cell) {
                     if (row.indexOf(cell) == 3 && cell != 'Status' && cell != '-') {
                       return cell; // Handled in cellBuilder manually if we wanted rich text, but textArray is simple.
                     }
                     return cell;
                   }).toList();
                }).toList(),
              ),

            pw.SizedBox(height: 30),

            // ACTIVE MEDICATIONS
            pw.Text('Active Medications', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: _navy)),
            pw.SizedBox(height: 10),
            if (medications.isEmpty)
              pw.Text('No active medications recorded.', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey700))
            else
              pw.Table.fromTextArray(
                context: ctx,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: pw.BoxDecoration(color: _navy),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellPadding: const pw.EdgeInsets.all(6),
                data: <List<String>>[
                  ['Medication', 'Dosage', 'Schedule', 'Inventory', 'Adherence', 'Taken Today'],
                  ...medications.map((m) => [
                    m['name'] ?? '-',
                    m['dosage'] ?? '-',
                    m['schedule'] ?? '-',
                    '${m['inventory_amount'] ?? '-'} ${m['unit'] ?? ''}',
                    '${m['adherence_rate'] ?? 0}%',
                    m['taken_today'] == true ? 'Yes' : 'No'
                  ]),
                ],
              ),

            pw.SizedBox(height: 30),

            // APPOINTMENTS
            pw.Text('Appointment History', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: _navy)),
            pw.SizedBox(height: 10),
            if (appointments.isEmpty)
              pw.Text('No appointments found.', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey700))
            else
              pw.Table.fromTextArray(
                context: ctx,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: pw.BoxDecoration(color: _accent),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellPadding: const pw.EdgeInsets.all(6),
                data: <List<String>>[
                  ['Date & Time', 'Purpose', 'Status'],
                  ...appointments.map((a) => [
                    _formatTime(a['appointment_time']),
                    a['purpose'] ?? '-',
                    a['status'] ?? '-',
                  ]),
                ],
              ),

            pw.Spacer(),

            // DOCTOR FOOTER
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _teal),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Prepared By: Dr. ${doctor['name']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _teal, fontSize: 11)),
                      if (doctor['specialisation'] != null && doctor['specialisation'].toString().isNotEmpty)
                        pw.Text(doctor['specialisation'], style: const pw.TextStyle(fontSize: 10)),
                      if (doctor['clinic_name'] != null && doctor['clinic_name'].toString().isNotEmpty)
                        pw.Text(doctor['clinic_name'], style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ];
        },
      ),
    );

    // ==========================================
    // PAGE 2: CHARTS
    // ==========================================
    bool hasAnyChart = chartImages.values.any((img) => img != null);
    if (hasAnyChart) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold, italic: fontItalic),
          build: (context) {
            return [
              pw.Text('Metric Trends (Last 30 Readings)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: _navy)),
              pw.SizedBox(height: 20),
              if (chartImages['heart_rate'] != null)
                _buildChartBlock('Heart Rate (bpm)', '#EF4444', chartImages['heart_rate']!),
              if (chartImages['blood_pressure'] != null)
                 _buildChartBlock('Blood Pressure (mmHg)', '#8B5CF6', chartImages['blood_pressure']!),
              if (chartImages['blood_glucose'] != null)
                 _buildChartBlock('Blood Glucose (mg/dL)', '#F59E0B', chartImages['blood_glucose']!),
              if (chartImages['oxygen_saturation'] != null)
                 _buildChartBlock('O₂ Saturation (%)', '#3B82F6', chartImages['oxygen_saturation']!),
              if (chartImages['body_weight'] != null)
                 _buildChartBlock('Body Weight (kg)', '#10B981', chartImages['body_weight']!),
            ];
          },
        ),
      );
    }

    // ==========================================
    // PAGE 3: FULL HISTORY TABLE
    // ==========================================
    if (metrics.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold, italic: fontItalic),
          build: (context) {
            final takeCount = metrics.length > 30 ? 30 : metrics.length;
            final historyData = metrics.take(takeCount).toList();
            return [
              pw.Text('Full Reading History ($takeCount readings)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: _navy)),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                headerDecoration: pw.BoxDecoration(color: _teal),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellPadding: const pw.EdgeInsets.all(5),
                data: <List<String>>[
                  ['Timestamp', 'HR', 'BP', 'Glucose', 'SpO₂', 'Weight'],
                  ...historyData.map((m) => [
                    _formatTime(m['timestamp']),
                    m['heart_rate']?.toString() ?? '-',
                    (m['blood_pressure_systolic'] != null && m['blood_pressure_diastolic'] != null)
                      ? '${m['blood_pressure_systolic']}/${m['blood_pressure_diastolic']}' : '-',
                    m['blood_glucose']?.toString() ?? '-',
                    m['oxygen_saturation']?.toString() ?? '-',
                    m['body_weight']?.toString() ?? '-',
                  ]),
                ],
              ),
            ];
          },
        ),
      );
    }

    final bytes = await pdf.save();
    final safeName = patientName.replaceAll(' ', '_');
    final dateFileStr = DateFormat('yyyyMMdd').format(DateTime.now());
    final fileName = 'TemanU_${safeName}_$dateFileStr.pdf';

    try {
      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: bytes,
          mimeType: MimeType.pdf,
        );
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Report saved to ${file.path}'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not download PDF report.'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  static pw.Widget _buildChartBlock(String title, String hexCol, Uint8List imageBytes) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(width: 8, height: 8, decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColor.fromHex(hexCol))),
              pw.SizedBox(width: 8),
              pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Image(pw.MemoryImage(imageBytes), height: 120, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.grey300),
        ],
      )
    );
  }
}
