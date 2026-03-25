import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:doctor_portal/theme.dart';
import 'package:doctor_portal/api_service.dart';
import 'package:doctor_portal/patient_detail_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List<Map<String, dynamic>> _allAppointments = [];
  bool _isLoading = true;
  int _selectedFilter = 0; // 0=Upcoming, 1=Past, 2=All

  // Cache patients for "View Patient" navigation
  List<Map<String, dynamic>> _patients = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final appointments = await ApiService.getAppointments();
    final patients = await ApiService.getPatients();
    if (mounted) {
      setState(() {
        _allAppointments = appointments;
        _patients = patients;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredAppointments {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 0: // Upcoming
        return _allAppointments.where((a) {
          final status = a['status'] ?? '';
          return status == 'Upcoming';
        }).toList();
      case 1: // Past
        return _allAppointments.where((a) {
          final status = a['status'] ?? '';
          return status != 'Upcoming';
        }).toList();
      default:
        return _allAppointments;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_today, color: AppTheme.accent, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Appointments', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    Text('${_allAppointments.length} total appointments', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filter Tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Row(
                children: [
                  _buildFilterChip('Upcoming', 0),
                  _buildFilterChip('Past', 1),
                  _buildFilterChip('All', 2),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Appointment List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                  : _filteredAppointments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_busy, size: 64, color: AppTheme.textSecondary.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              Text('No appointments found', style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: AppTheme.primaryColor,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 100),
                            itemCount: _filteredAppointments.length,
                            itemBuilder: (context, index) {
                              return _buildAppointmentCard(_filteredAppointments[index]);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appt) {
    final patientName = appt['patient_name'] ?? 'Unknown';
    final patientPreferred = appt['patient_preferred_name'] ?? patientName;
    final purpose = appt['purpose'] ?? 'No purpose specified';
    final status = appt['status'] ?? 'Unknown';
    final appointmentId = appt['id'];
    final userId = appt['user_id'];

    String formattedTime = '';
    try {
      final dt = DateTime.parse(appt['appointment_time']);
      formattedTime = DateFormat('EEEE, d MMM · h:mm a').format(dt);
    } catch (_) {}

    Color statusColor = AppTheme.textSecondary;
    IconData statusIcon = Icons.help_outline;
    if (status == 'Upcoming') {
      statusColor = AppTheme.success;
      statusIcon = Icons.schedule;
    } else if (status == 'Completed') {
      statusColor = AppTheme.textSecondary;
      statusIcon = Icons.check_circle_outline;
    } else if (status == 'Cancelled') {
      statusColor = AppTheme.error;
      statusIcon = Icons.cancel_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: statusColor.withOpacity(0.1),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          title: Text(patientPreferred, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 13, color: AppTheme.textSecondary.withOpacity(0.6)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(formattedTime, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(purpose, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary.withOpacity(0.7)), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(status, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
              ),
            ],
          ),
          children: [
            // Full details and action buttons
            const Divider(),
            const SizedBox(height: 4),
            
            // Full purpose text
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notes, size: 16, color: AppTheme.textSecondary.withOpacity(0.6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(purpose, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                if (status == 'Upcoming') ...[
                  Expanded(
                    child: _actionButton('Complete', Icons.check, AppTheme.success, () => _updateStatus(appointmentId, 'Completed')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionButton('Cancel', Icons.close, AppTheme.error, () => _updateStatus(appointmentId, 'Cancelled')),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: _actionButton('View Patient', Icons.person, AppTheme.primaryColor, () {
                    final patient = _patients.firstWhere(
                      (p) => p['id'] == userId,
                      orElse: () => {'id': userId, 'name': patientName, 'preferred_name': patientPreferred},
                    );
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => PatientDetailScreen(patient: patient),
                    ));
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(int id, String status) async {
    final success = await ApiService.updateAppointmentStatus(id, status);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Appointment marked as $status'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _loadData(); // Refresh
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update appointment'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}
