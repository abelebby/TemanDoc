import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:doctor_portal/theme.dart';
import 'package:doctor_portal/api_service.dart';

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
  bool _isLoading = true;

  int get _userId => widget.patient['id'] ?? 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final metrics = await ApiService.getPatientMetrics(_userId);
    final medications = await ApiService.getPatientMedications(_userId);
    final allAppointments = await ApiService.getAppointments();

    if (mounted) {
      setState(() {
        _metrics = metrics;
        _medications = medications;
        // Filter appointments for this patient
        _appointments = allAppointments.where((a) => a['user_id'] == _userId).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.patient['name'] ?? 'Unknown';
    final preferredName = widget.patient['preferred_name'] ?? '';
    final gender = widget.patient['gender'] ?? 'N/A';
    final dob = widget.patient['dob'] ?? 'N/A';
    final bloodType = widget.patient['blood_type'] ?? 'N/A';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(preferredName.isNotEmpty ? preferredName : name),
        backgroundColor: AppTheme.background,
      ),
      body: Column(
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
                      Row(
                        children: [
                          _infoBadge('DOB: $dob'),
                          const SizedBox(width: 8),
                          _infoBadge(gender),
                          const SizedBox(width: 8),
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
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
              tabs: const [
                Tab(text: 'Health Metrics'),
                Tab(text: 'Medications'),
                Tab(text: 'Appointments'),
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
                    ],
                  ),
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

  // ─── HEALTH METRICS TAB ───
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

    // Extract latest values from most recent reading
    final latest = _metrics.first;
    final metricCards = <Widget>[];

    void addMetricCard(String label, String? value, String unit, IconData icon, Color color) {
      if (value != null) {
        metricCards.add(_buildMetricCard(label, value, unit, icon, color, latest['timestamp'] ?? ''));
      }
    }

    addMetricCard('Heart Rate', latest['heart_rate']?.toString(), 'bpm', Icons.favorite, const Color(0xFFEF4444));
    
    if (latest['blood_pressure_systolic'] != null && latest['blood_pressure_diastolic'] != null) {
      metricCards.add(_buildMetricCard(
        'Blood Pressure',
        '${latest['blood_pressure_systolic']}/${latest['blood_pressure_diastolic']}',
        'mmHg', Icons.speed, const Color(0xFF8B5CF6),
        latest['timestamp'] ?? '',
      ));
    }

    addMetricCard('Blood Glucose', latest['blood_glucose']?.toString(), 'mg/dL', Icons.water_drop, const Color(0xFFF59E0B));
    addMetricCard('O₂ Saturation', latest['oxygen_saturation']?.toString(), '%', Icons.air, const Color(0xFF3B82F6));
    addMetricCard('Body Weight', latest['body_weight']?.toString(), 'kg', Icons.monitor_weight, const Color(0xFF10B981));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: metricCards,
    );
  }

  Widget _buildMetricCard(String label, String value, String unit, IconData icon, Color color, String timestamp) {
    String formattedTime = '';
    try {
      final dt = DateTime.parse(timestamp);
      formattedTime = DateFormat('MMM d, yyyy · h:mm a').format(dt);
    } catch (_) {
      formattedTime = timestamp;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
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
        ],
      ),
    );
  }

  // ─── MEDICATIONS TAB ───
  Widget _buildMedicationsTab() {
    if (_medications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication_outlined, size: 48, color: AppTheme.textSecondary.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text('No medications recorded', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _medications.length,
      itemBuilder: (context, index) {
        final med = _medications[index];
        final name = med['name'] ?? '';
        final dosage = med['dosage'] ?? '';
        final unit = med['unit'] ?? 'pills';
        final inventory = (med['inventory'] ?? 0).toDouble();
        final times = List<String>.from(med['times'] ?? []);
        final dosesTaken = med['doses_taken_today'] ?? 0;

        // Inventory bar: assume 30 pills is full for visualization
        final inventoryPercent = (inventory / 30).clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.medication, color: AppTheme.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                        Text('$dosage $unit · $dosesTaken taken today', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              if (times.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: times.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(t, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                  )).toList(),
                ),
              ],
              const SizedBox(height: 10),
              // Inventory bar
              Row(
                children: [
                  Text('Inventory: ${inventory.toStringAsFixed(0)} $unit', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: inventoryPercent,
                  backgroundColor: AppTheme.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    inventoryPercent > 0.3 ? AppTheme.success : AppTheme.error,
                  ),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── APPOINTMENTS TAB ───
  Widget _buildAppointmentsTab() {
    if (_appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 48, color: AppTheme.textSecondary.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text('No appointments with this patient', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _appointments.length,
      itemBuilder: (context, index) {
        final appt = _appointments[index];
        return _buildAppointmentMini(appt);
      },
    );
  }

  Widget _buildAppointmentMini(Map<String, dynamic> appt) {
    final purpose = appt['purpose'] ?? 'No purpose specified';
    final status = appt['status'] ?? 'Unknown';
    String formattedTime = '';
    try {
      final dt = DateTime.parse(appt['appointment_time']);
      formattedTime = DateFormat('EEEE, d MMM · h:mm a').format(dt);
    } catch (_) {}

    Color statusColor = AppTheme.textSecondary;
    if (status == 'Upcoming') statusColor = AppTheme.success;
    if (status == 'Cancelled') statusColor = AppTheme.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(formattedTime, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(status, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(purpose, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
