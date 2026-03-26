import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:doctor_portal/theme.dart';
import 'package:doctor_portal/api_service.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _performSearch("");
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    final results = await ApiService.searchPatients(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _addPatient(int patientId) async {
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
    );
    
    final result = await ApiService.addPatient(patientId);
    
    if (mounted) {
      Navigator.pop(context); // Dismiss loading overlay
      
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request sent to patient!"), backgroundColor: AppTheme.primaryColor)
        );
        _performSearch(_searchController.text); // Refresh to show "Request Sent"
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? "Could not send request."), backgroundColor: Colors.redAccent)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Find Patients', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.primaryColor),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search by username or name...',
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary.withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: _isSearching
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : _searchResults.isEmpty
                ? Center(child: Text("No patients found.", style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final p = _searchResults[index];
                      final name = p['name'] ?? 'Unknown';
                      final preferred = p['preferred_name'] ?? '';
                      final isLinked = p['already_linked'] == true;
                      final isPending = p['request_pending'] == true;
                      final String displayName = preferred.isNotEmpty && preferred != name ? '$name ("$preferred")' : name;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
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
                              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(displayName, style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(p['username'] ?? '', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13)),
                                ],
                              ),
                            ),
                            if (isLinked)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: const Color(0xff16A34A).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: const Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Color(0xff16A34A), size: 14),
                                    SizedBox(width: 4),
                                    Text('Linked', style: TextStyle(color: Color(0xff16A34A), fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )
                            else if (isPending)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: const Row(
                                  children: [
                                    Icon(Icons.access_time, color: Colors.amber, size: 14),
                                    SizedBox(width: 4),
                                    Text('Request Sent', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.person_add, color: AppTheme.primaryColor),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _addPatient(p['id']),
                              )
                          ],
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}
