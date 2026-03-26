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

  // Cache patients for "View Patient" navigation and booking sheet
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'appointments_new_fab',
        onPressed: _showBookingSheet,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('New Appointment', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
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
      final dt = DateTime.parse(appt['appointment_time']).toLocal();
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
            const Divider(),
            const SizedBox(height: 4),
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

  void _showBookingSheet() {
    int? selectedPatientId;
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    final TextEditingController purposeController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          final isFormValid = selectedPatientId != null && selectedDate != null && selectedTime != null && purposeController.text.trim().isNotEmpty;

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text('Book New Appointment', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      Text('Schedule an appointment for a patient', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary)),
                      const SizedBox(height: 24),

                      // 1. Patient Dropdown
                      Text('Select Patient', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedPatientId,
                            hint: Text('Choose a patient', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
                            items: _patients.map((p) {
                              return DropdownMenuItem<int>(
                                value: p['id'],
                                child: Text(p['preferred_name'] ?? p['name'] ?? 'Unknown', style: GoogleFonts.inter(color: AppTheme.textPrimary)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setModalState(() => selectedPatientId = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 2. Date Picker
                      Text('Date', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: AppTheme.primaryColor,
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: AppTheme.textPrimary,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setModalState(() => selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: AppTheme.textSecondary, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                selectedDate == null ? 'Select Date' : DateFormat('EEEE, MMMM d, yyyy').format(selectedDate!),
                                style: GoogleFonts.inter(
                                  color: selectedDate == null ? AppTheme.textSecondary : AppTheme.textPrimary,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 3. Time Picker
                      Text('Time', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: AppTheme.primaryColor,
                                    surface: Colors.white,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setModalState(() => selectedTime = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, color: AppTheme.textSecondary, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                selectedTime == null ? 'Select Time' : selectedTime!.format(context),
                                style: GoogleFonts.inter(
                                  color: selectedTime == null ? AppTheme.textSecondary : AppTheme.textPrimary,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4. Purpose
                      Text('Purpose of Visit', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: purposeController,
                        maxLines: 3,
                        onChanged: (_) => setModalState(() {}),
                        style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'E.g., Follow-up consultation, Routine checkup...',
                          hintStyle: GoogleFonts.inter(color: AppTheme.textSecondary),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryColor)),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // 5. Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isFormValid ? () async {
                            final combined = DateTime(
                              selectedDate!.year, selectedDate!.month, selectedDate!.day,
                              selectedTime!.hour, selectedTime!.minute,
                            );
                            final isoString = combined.toUtc().toIso8601String();
                            
                            final patientName = _patients.firstWhere((p) => p['id'] == selectedPatientId)['name'];

                            Navigator.pop(context); // close sheet
                            ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                              content: Row(children: const [SizedBox(height:20, width:20, child:CircularProgressIndicator(color: Colors.white, strokeWidth: 2)), SizedBox(width: 10), Text('Booking appointment...')]),
                              backgroundColor: AppTheme.primaryColor,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              duration: const Duration(seconds: 1),
                            ));

                            final response = await ApiService.bookAppointmentForPatient(
                              userId: selectedPatientId!,
                              appointmentTime: isoString,
                              purpose: purposeController.text.trim(),
                            );
                            
                            if (mounted) {
                              if (response['success'] == true) {
                                _loadData(); // refresh list
                                ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                                  content: Text('Appointment booked with $patientName'),
                                  backgroundColor: AppTheme.success,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ));
                              } else {
                                ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                                  content: const Text('Failed to book appointment'),
                                  backgroundColor: AppTheme.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ));
                              }
                            }
                          } : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Book Appointment', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}
