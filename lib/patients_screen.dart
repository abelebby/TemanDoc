import 'package:doctor_portal/pending_requests_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:doctor_portal/theme.dart';
import 'package:doctor_portal/api_service.dart';
import 'package:doctor_portal/patient_detail_screen.dart';
import 'package:doctor_portal/screens/add_patient_screen.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _filteredPatients = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _searchController.addListener(_filterPatients);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoading = true);
    final List<Map<String, dynamic>> patients = await ApiService.getPatients();
    final List<Map<String, dynamic>> pending = await ApiService.getPendingRequests();
    if (mounted) {
      setState(() {
        _patients = patients;
        _filteredPatients = patients;
        _pendingRequests = pending;
        _isLoading = false;
      });
    }
  }

  void _filterPatients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPatients = _patients.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final preferredName = (p['preferred_name'] ?? '').toString().toLowerCase();
        final username = (p['username'] ?? '').toString().toLowerCase();
        return name.contains(query) || preferredName.contains(query) || username.contains(query);
      }).toList();
    });
  }

  Future<void> _confirmRemovePatient(Map<String, dynamic> patient) async {
    final patientName = patient['preferred_name'] ?? patient['name'] ?? 'this patient';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove Patient', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        content: Text(
          'Are you sure you want to remove $patientName from your care team?\n\nYou will no longer be able to access their medical records, health metrics, or medications.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 10),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Remove', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.removePatient(patient['id']);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$patientName removed from your care team.'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
          _loadPatients(); 
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Failed to remove patient. Please try again.'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      }
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
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.people, color: AppTheme.primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Patients', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      Text('${_patients.length} patients in your care', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.person_add, color: AppTheme.primaryColor),
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddPatientScreen()));
                      _loadPatients();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppTheme.cardShadow,
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search by name or username...',
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary.withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_pendingRequests.isNotEmpty)
              GestureDetector(
                onTap: () async {
                  // Wait for the doctor to come back from the pending screen, then refresh!
                  await Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const DoctorPendingRequestsScreen())
                  );
                  _loadPatients(); 
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.amber, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You have ${_pendingRequests.length} pending request(s) awaiting patient approval. Tap to view.',
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.amber[800], fontWeight: FontWeight.w500),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.amber, size: 20),
                    ],
                  ),
                ),
              ),

            // Patient List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                  : _filteredPatients.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: AppTheme.textSecondary.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              Text('No patients found', style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary)),
                              const SizedBox(height: 8),
                              Text(
                                'Patients will appear here once they\nadd you to their care team',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary.withOpacity(0.6)),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadPatients,
                          color: AppTheme.primaryColor,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 100),
                            itemCount: _filteredPatients.length,
                            itemBuilder: (context, index) {
                              return _buildPatientCard(_filteredPatients[index]);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final name = patient['name'] ?? 'Unknown';
    final preferredName = patient['preferred_name'] ?? '';
    final gender = patient['gender'];
    final bloodType = patient['blood_type'];

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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PatientDetailScreen(patient: patient),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                      if (preferredName.isNotEmpty && preferredName != name)
                        Text(
                          '"$preferredName"',
                          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (gender != null) _buildBadge(gender, Icons.person_outline),
                          if (gender != null && bloodType != null) const SizedBox(width: 8),
                          if (bloodType != null) _buildBadge(bloodType, Icons.water_drop_outlined),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Remove Patient Button
                IconButton(
                  icon: const Icon(Icons.person_remove, color: AppTheme.error, size: 22),
                  onPressed: () => _confirmRemovePatient(patient),
                  tooltip: 'Remove Patient',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),

                // Arrow
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_right, color: AppTheme.primaryColor, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}