import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_portal/theme.dart';
import 'package:doctor_portal/api_service.dart';
import 'package:doctor_portal/records_screen.dart';
import 'package:doctor_portal/pdf_generator.dart';

class PatientDetailScreen extends StatefulWidget {
  final Map<String, dynamic> patient;

  const PatientDetailScreen({super.key, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _metrics = [];
  List<Map<String, dynamic>> _medications = [];
  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;

  final Map<String, bool> _expandedCharts = {};
  
  final GlobalKey _hrKey     = GlobalKey();
  final GlobalKey _bpKey     = GlobalKey();
  final GlobalKey _glucoseKey = GlobalKey();
  final GlobalKey _spo2Key   = GlobalKey();
  final GlobalKey _weightKey  = GlobalKey();

  int get _userId => widget.patient['id'] ?? 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ApiService.getPatientMetrics(_userId),
      ApiService.getPatientMedications(_userId),
      ApiService.getAppointments(),
      ApiService.getRecords(userId: _userId),
    ]);

    if (mounted) {
      setState(() {
        _metrics    = results[0] as List<Map<String, dynamic>>;
        _medications = results[1] as List<Map<String, dynamic>>;
        _appointments = (results[2] as List<Map<String, dynamic>>)
            .where((a) => a['user_id'] == _userId)
            .toList();
        _records = results[3] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    }
  }

  // ═══════════════════════════════════════════
  // PDF GENERATION & HIDDEN CHARTS
  // ═══════════════════════════════════════════
  Future<Uint8List?> _captureChart(GlobalKey key) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _downloadReport() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Generating report...'),
        ]),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 15),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 300));

    final chartImages = {
      'heart_rate':        await _captureChart(_hrKey),
      'blood_pressure':    await _captureChart(_bpKey),
      'blood_glucose':     await _captureChart(_glucoseKey),
      'oxygen_saturation': await _captureChart(_spo2Key),
      'body_weight':       await _captureChart(_weightKey),
    };

    final prefs = await SharedPreferences.getInstance();
    final doctor = {
      'name':           prefs.getString('doctor_name') ?? '',
      'preferred_name': prefs.getString('preferred_name') ?? '',
      'specialisation': '',
      'clinic_name':    '',
    };

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    await DoctorPdfGenerator.generateAndDownload(
      patient:      widget.patient,
      metrics:      _metrics,
      medications:  _medications,
      appointments: _appointments,
      doctor:       doctor,
      chartImages:  chartImages,
      context:      context,
    );
  }

  Widget _buildHiddenCharts() {
    if (_metrics.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        RepaintBoundary(
          key: _hrKey,
          child: Container(color: Colors.white, width: 500, height: 180,
              child: _buildRawChart('heart_rate', const Color(0xFFEF4444))),
        ),
        RepaintBoundary(
          key: _bpKey,
          child: Container(color: Colors.white, width: 500, height: 180,
              child: _buildRawBPChart()),
        ),
        RepaintBoundary(
          key: _glucoseKey,
          child: Container(color: Colors.white, width: 500, height: 180,
              child: _buildRawChart('blood_glucose', const Color(0xFFF59E0B))),
        ),
        RepaintBoundary(
          key: _spo2Key,
          child: Container(color: Colors.white, width: 500, height: 180,
              child: _buildRawChart('oxygen_saturation', const Color(0xFF3B82F6))),
        ),
        RepaintBoundary(
          key: _weightKey,
          child: Container(color: Colors.white, width: 500, height: 180,
              child: _buildRawChart('body_weight', const Color(0xFF10B981))),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // MAIN BUILD
  // ═══════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final name          = widget.patient['name'] ?? 'Unknown';
    final preferredName = widget.patient['preferred_name'] ?? '';
    final gender        = widget.patient['gender'] ?? 'N/A';
    final dob           = widget.patient['dob'] ?? 'N/A';
    final bloodType     = widget.patient['blood_type'] ?? 'N/A';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(preferredName.isNotEmpty ? preferredName : name),
        backgroundColor: AppTheme.background,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.download, color: AppTheme.primaryColor),
              tooltip: 'Download Report',
              onPressed: _downloadReport,
            ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(left: -9999, child: _buildHiddenCharts()),
          Column(
            children: [
              // Profile Header
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _infoBadge('DOB: $dob'),
                              _infoBadge(gender),
                              _infoBadge('🩸 $bloodType'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppTheme.primaryColor,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
                  tabs: const [
                    Tab(text: 'Metrics'),
                    Tab(text: 'Medication'),
                    Tab(text: 'Appointments'),
                    Tab(text: 'Records'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Tab Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildMetricsTab(),
                          _buildMedicationsTab(),
                          _buildAppointmentsTab(),
                          _buildRecordsTab(),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(text, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
    );
  }

  // ═══════════════════════════════════════════
  // HEALTH METRICS TAB
  // ═══════════════════════════════════════════
  Widget _buildMetricsTab() {
    if (_metrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.monitor_heart_outlined, size: 48, color: AppTheme.textSecondary.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text('No health data recorded yet', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    // Find the most recent non-null value for each metric across all 30 readings
    Map<String, dynamic>? latestForKey(String key) {
      for (final m in _metrics) {
        if (m[key] != null) return m;
      }
      return null;
    }

    final hrData   = latestForKey('heart_rate');
    final bpData   = latestForKey('blood_pressure_systolic');
    final bgData   = latestForKey('blood_glucose');
    final spo2Data = latestForKey('oxygen_saturation');
    final bwData   = latestForKey('body_weight');

    final metricCards = <Widget>[];

    if (hrData != null) {
      metricCards.add(_buildExpandableMetricCard(
        'Heart Rate', hrData['heart_rate'].toString(), 'bpm',
        Icons.favorite, const Color(0xFFEF4444), hrData['timestamp'], 'heart_rate',
      ));
    }
    if (bpData != null) {
      metricCards.add(_buildExpandableMetricCard(
        'Blood Pressure',
        '${bpData['blood_pressure_systolic']}/${bpData['blood_pressure_diastolic']}',
        'mmHg', Icons.speed, const Color(0xFF8B5CF6), bpData['timestamp'], 'blood_pressure',
        isBP: true,
      ));
    }
    if (bgData != null) {
      metricCards.add(_buildExpandableMetricCard(
        'Blood Glucose', bgData['blood_glucose'].toString(), 'mg/dL',
        Icons.water_drop, const Color(0xFFF59E0B), bgData['timestamp'], 'blood_glucose',
      ));
    }
    if (spo2Data != null) {
      metricCards.add(_buildExpandableMetricCard(
        'O₂ Saturation', spo2Data['oxygen_saturation'].toString(), '%',
        Icons.air, const Color(0xFF3B82F6), spo2Data['timestamp'], 'oxygen_saturation',
      ));
    }
    if (bwData != null) {
      metricCards.add(_buildExpandableMetricCard(
        'Body Weight', bwData['body_weight'].toString(), 'kg',
        Icons.monitor_weight, const Color(0xFF10B981), bwData['timestamp'], 'body_weight',
      ));
    }

    if (metricCards.isEmpty) {
      return Center(
        child: Text('No health data recorded yet', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      children: metricCards,
    );
  }

  Widget _buildExpandableMetricCard(
    String label, String value, String unit,
    IconData icon, Color color, String timestamp, String key,
    {bool isBP = false}
  ) {
    String formattedTime = '';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      formattedTime = DateFormat('d MMM yyyy · h:mm a').format(dt);
    } catch (_) {
      formattedTime = timestamp;
    }

    final isExpanded = _expandedCharts[key] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _expandedCharts[key] = !isExpanded),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(value, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                              const SizedBox(width: 4),
                              Text(unit, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(formattedTime, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary.withOpacity(0.6))),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: AppTheme.textSecondary.withOpacity(0.5),
                    ),
                  ],
                ),

                // Expandable Chart
                AnimatedCrossFade(
                  firstChild: const SizedBox(height: 0),
                  secondChild: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1),
                      ),
                      Text('Trend (Last 30 records)', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 180,
                        child: isBP ? _buildRawBPChart() : _buildRawChart(key, color),
                      ),
                    ],
                  ),
                  crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 250),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRawChart(String metricKey, Color color) {
    var dataPoints = _metrics.where((m) => m[metricKey] != null).toList();
    if (dataPoints.length > 30) dataPoints = dataPoints.sublist(0, 30);
    if (dataPoints.length < 2) {
      return Center(child: Text('Not enough data', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)));
    }
    dataPoints = dataPoints.reversed.toList();
    final spots = <FlSpot>[];
    for (int i = 0; i < dataPoints.length; i++) {
      spots.add(FlSpot(i.toDouble(), (dataPoints[i][metricKey] as num).toDouble()));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      child: LineChart(LineChartData(
        minX: 0,
        maxX: (dataPoints.length - 1).toDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(radius: 3, color: Colors.white, strokeWidth: 2, strokeColor: color),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondary)),
            ),
          ),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(color: AppTheme.border.withOpacity(0.5), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.white,
            tooltipRoundedRadius: 8,
            getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
              '${s.y.toInt()}',
              GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            )).toList(),
          ),
        ),
      )),
    );
  }

  Widget _buildRawBPChart() {
    var dataPoints = _metrics
        .where((m) => m['blood_pressure_systolic'] != null && m['blood_pressure_diastolic'] != null)
        .toList();
    if (dataPoints.length > 30) dataPoints = dataPoints.sublist(0, 30);
    if (dataPoints.length < 2) {
      return Center(child: Text('Not enough data', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)));
    }
    dataPoints = dataPoints.reversed.toList();
    final sysSpots = <FlSpot>[];
    final diaSpots = <FlSpot>[];
    for (int i = 0; i < dataPoints.length; i++) {
      sysSpots.add(FlSpot(i.toDouble(), (dataPoints[i]['blood_pressure_systolic'] as num).toDouble()));
      diaSpots.add(FlSpot(i.toDouble(), (dataPoints[i]['blood_pressure_diastolic'] as num).toDouble()));
    }
    const sysColor = Color(0xFF8B5CF6);
    const diaColor = Color(0xFF10B981);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      child: LineChart(LineChartData(
        minX: 0,
        maxX: (dataPoints.length - 1).toDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: sysSpots, isCurved: true, color: sysColor, barWidth: 3, isStrokeCapRound: true,
            dotData: FlDotData(show: true, getDotPainter: (s, p, b, i) => FlDotCirclePainter(radius: 3, color: Colors.white, strokeWidth: 2, strokeColor: sysColor)),
          ),
          LineChartBarData(
            spots: diaSpots, isCurved: true, color: diaColor, barWidth: 3, isStrokeCapRound: true,
            dotData: FlDotData(show: true, getDotPainter: (s, p, b, i) => FlDotCirclePainter(radius: 3, color: Colors.white, strokeWidth: 2, strokeColor: diaColor)),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 35,
              getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondary)),
            ),
          ),
        ),
        gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: AppTheme.border.withOpacity(0.5), strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.white,
            tooltipRoundedRadius: 8,
            getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
              '${s.barIndex == 0 ? "Sys" : "Dia"}: ${s.y.toInt()}',
              GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: s.barIndex == 0 ? sysColor : diaColor),
            )).toList(),
          ),
        ),
      )),
    );
  }

  // ═══════════════════════════════════════════
  // MEDICATIONS TAB
  // ═══════════════════════════════════════════
  Widget _buildMedicationsTab() {
    if (_medications.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.medication_outlined, size: 48, color: AppTheme.textSecondary.withOpacity(0.3)),
        const SizedBox(height: 12),
        Text('No medications recorded', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _medications.length,
      itemBuilder: (context, index) {
        final med          = _medications[index];
        final name         = med['name'] ?? '';
        final dosage       = med['dosage'] ?? '';
        final unit         = med['unit'] ?? 'pills';
        final inventory    = (med['inventory'] ?? 0).toDouble();
        final times        = List<String>.from(med['times'] ?? []);
        final dosesTaken   = med['doses_taken_today'] ?? 0;
        final inventoryPercent = (inventory / 30).clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.cardShadow),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.medication, color: AppTheme.accent, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                Text('$dosage $unit · $dosesTaken taken today', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
              ])),
            ]),
            if (times.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, children: times.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.border)),
                child: Text(t, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
              )).toList()),
            ],
            const SizedBox(height: 10),
            Text('Inventory: ${inventory.toStringAsFixed(0)} $unit', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
              value: inventoryPercent, backgroundColor: AppTheme.border,
              valueColor: AlwaysStoppedAnimation<Color>(inventoryPercent > 0.3 ? AppTheme.success : AppTheme.error),
              minHeight: 6,
            )),
          ]),
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // APPOINTMENTS TAB
  // ═══════════════════════════════════════════
  Widget _buildAppointmentsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _showBookingSheet,
              icon: const Icon(Icons.add, size: 18, color: AppTheme.primaryColor),
              label: Text('Book Appointment', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
            ),
          ),
        ),
        Expanded(
          child: _appointments.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.calendar_today, size: 48, color: AppTheme.textSecondary.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Text('No appointments with this patient', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _appointments.length,
                  itemBuilder: (context, index) => _buildAppointmentCard(_appointments[index], index),
                ),
        ),
      ],
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appt, int index) {
    final purpose = appt['purpose'] ?? 'No purpose specified';
    final status  = appt['status'] ?? 'Unknown';
    String formattedTime = '';
    try {
      final dt = DateTime.parse(appt['appointment_time']).toLocal();
      formattedTime = DateFormat('EEEE, d MMM · h:mm a').format(dt);
    } catch (_) {}

    Color statusColor = AppTheme.textSecondary;
    if (status == 'Upcoming')  statusColor = AppTheme.success;
    if (status == 'Cancelled') statusColor = AppTheme.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.cardShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(formattedTime, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(status, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(purpose, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
        if (status == 'Upcoming') ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _updateAppointmentStatus(appt, index, 'Completed'),
                icon: const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.success),
                label: Text('Complete', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.success)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.success), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 8)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _updateAppointmentStatus(appt, index, 'Cancelled'),
                icon: const Icon(Icons.cancel_outlined, size: 16, color: AppTheme.error),
                label: Text('Cancel', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.error)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.error), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 8)),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Future<void> _updateAppointmentStatus(Map<String, dynamic> appt, int index, String newStatus) async {
    final id = appt['id'];
    if (id == null) return;
    final success = await ApiService.updateAppointmentStatus(id, newStatus);
    if (mounted) {
      if (success) {
        setState(() => _appointments[index]['status'] = newStatus);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Appointment marked as $newStatus'),
          backgroundColor: newStatus == 'Completed' ? AppTheme.success : AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Failed to update appointment'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  void _showBookingSheet() {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    final purposeController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Book Appointment', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Date', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
                subtitle: Text(DateFormat('EEEE, d MMM yyyy').format(selectedDate), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                onTap: () async {
                  final picked = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (picked != null) setSheetState(() => selectedDate = picked);
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Time', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
                subtitle: Text(selectedTime.format(ctx), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.access_time, color: AppTheme.primaryColor),
                onTap: () async {
                  final picked = await showTimePicker(context: ctx, initialTime: selectedTime);
                  if (picked != null) setSheetState(() => selectedTime = picked);
                },
              ),
              const Divider(),
              const SizedBox(height: 8),
              Text('Purpose', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: purposeController,
                decoration: InputDecoration(
                  hintText: 'e.g. Follow-up, Consultation...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    if (purposeController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: const Text('Please enter a purpose'), backgroundColor: AppTheme.warning, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                      return;
                    }
                    Navigator.pop(ctx);
                    final dt = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                    final result = await ApiService.bookAppointmentForPatient(
                      userId: _userId,
                      appointmentTime: dt.toUtc().toIso8601String(),
                      purpose: purposeController.text.trim(),
                    );
                    if (mounted) {
                      if (result['success'] == true) {
                        _loadData();
                        ApiService.appointmentRefreshTrigger.value++;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Appointment booked'), backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Failed to book'), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: Text('Confirm Booking', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
            ])),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════
  // RECORDS TAB
  // ═══════════════════════════════════════════
  Widget _buildRecordsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(
                  builder: (context) => RecordsScreen(preselectedPatient: widget.patient),
                ));
                _loadData();
              },
              icon: const Icon(Icons.upload, size: 18, color: AppTheme.primaryColor),
              label: Text('Upload Record', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
            ),
          ),
        ),
        Expanded(
          child: _records.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.description_outlined, size: 48, color: AppTheme.textSecondary.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Text('No records uploaded yet', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _records.length,
                  itemBuilder: (context, index) => _buildRecordCard(_records[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final fileName    = record['file_name'] ?? 'Unknown';
    final recordType  = record['record_type'] ?? 'Other';
    final description = record['description'] ?? '';
    
    String formattedDate = '';
    try {
      formattedDate = DateFormat('d MMM yyyy').format(DateTime.parse(record['created_at']).toLocal());
    } catch (_) {}

    Color typeColor = AppTheme.textSecondary;
    IconData typeIcon = Icons.description;
    switch (recordType) {
      case 'Lab Report':        typeColor = const Color(0xFF3B82F6); typeIcon = Icons.science;    break;
      case 'Prescription':      typeColor = const Color(0xFF10B981); typeIcon = Icons.medication; break;
      case 'Imaging':           typeColor = const Color(0xFF8B5CF6); typeIcon = Icons.image;      break;
      case 'Discharge Summary': typeColor = const Color(0xFFF59E0B); typeIcon = Icons.summarize;  break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.cardShadow),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          // ==========================================
          // UPDATED: SECURE DOWNLOAD LOGIC
          // ==========================================
          onTap: () async {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Fetching secure link for $fileName...'),
              duration: const Duration(seconds: 1),
            ));
            
            try {
              final urlData = await ApiService.getDownloadUrl(record['id']);
              if (urlData != null && urlData['download_url'] != null) {
                final uri = Uri.parse(urlData['download_url']);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  throw Exception("Could not launch browser");
                }
              } else {
                throw Exception("Failed to get secure URL");
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Error opening file: $e'),
                  backgroundColor: AppTheme.error,
                ));
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(typeIcon, color: typeColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(fileName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(recordType, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: typeColor)),
                  ),
                  const Spacer(),
                  Text(formattedDate, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                ]),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(description, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ])),
              const SizedBox(width: 8),
              Icon(Icons.open_in_new, size: 16, color: AppTheme.textSecondary.withOpacity(0.5)),
            ]),
          ),
        ),
      ),
    );
  }
}