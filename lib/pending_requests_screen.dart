import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:doctor_portal/theme.dart';
import 'package:doctor_portal/api_service.dart';

class DoctorPendingRequestsScreen extends StatefulWidget {
  const DoctorPendingRequestsScreen({super.key});

  @override
  State<DoctorPendingRequestsScreen> createState() => _DoctorPendingRequestsScreenState();
}

class _DoctorPendingRequestsScreenState extends State<DoctorPendingRequestsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    final requests = await ApiService.getPendingRequests();
    if (mounted) {
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    }
  }

  Future<void> _withdrawRequest(int requestId, String patientName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Withdraw Request', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'Cancel your care team request to $patientName?',
          style: GoogleFonts.inter(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Withdraw', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.withdrawRequest(requestId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Request withdrawn successfully.'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ));
          _loadRequests();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Failed to withdraw request.'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text(
          'Pending Requests',
          style: GoogleFonts.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.hourglass_empty, size: 64, color: AppTheme.textSecondary.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text('No pending requests', style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final req = _requests[index];
                    final patientName = req['patient_name'] ?? 'Unknown Patient';
                    final reqId = req['id'];

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
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.amber.withOpacity(0.15),
                            child: const Icon(Icons.hourglass_top, color: Colors.amber),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(patientName, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                const SizedBox(height: 4),
                                Text('Awaiting patient approval...', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _withdrawRequest(reqId, patientName),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.error,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: Text('Withdraw', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                          )
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}