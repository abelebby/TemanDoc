import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:doctor_portal/theme.dart';
import 'package:doctor_portal/api_service.dart';

class RecordsScreen extends StatefulWidget {
  final Map<String, dynamic>? preselectedPatient;
  const RecordsScreen({super.key, this.preselectedPatient});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _records = [];
  Map<String, dynamic>? _selectedPatient;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  void _applyPreselection() {
    if (widget.preselectedPatient != null) {
      final preId = widget.preselectedPatient!['id'];
      for (final p in _patients) {
        if (p['id'] == preId) {
          _selectedPatient = p;
          _loadRecords(p['id']);
          break;
        }
      }
    }
  }

  Future<void> _loadPatients() async {
    final patients = await ApiService.getPatients();
    if (mounted) {
      setState(() {
        _patients = patients;
        _isLoading = false;
      });
      _applyPreselection();
    }
  }

  Future<void> _loadRecords(int userId) async {
    setState(() => _isLoading = true);
    final records = await ApiService.getRecords(userId: userId);
    if (mounted) {
      setState(() {
        _records = records;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'records_fab_${_selectedPatient?['id']}',
        onPressed: _showUploadSheet,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Upload', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
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
                      color: AppTheme.secondaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.folder_shared, color: AppTheme.secondaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Medical Records', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      Text('View and upload patient records', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Patient Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    isExpanded: true,
                    hint: Text('Select a patient...', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary)),
                    value: _selectedPatient,
                    icon: const Icon(Icons.expand_more, color: AppTheme.textSecondary),
                    items: _patients.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text(
                          '${p['preferred_name'] ?? p['name']}',
                          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary),
                        ),
                      );
                    }).toList(),
                    onChanged: (patient) {
                      setState(() => _selectedPatient = patient);
                      if (patient != null) {
                        _loadRecords(patient['id']);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Records List
              Expanded(
                child: _selectedPatient == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open, size: 64, color: AppTheme.textSecondary.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text('Select a patient to view records', style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary)),
                          ],
                        ),
                      )
                    : _isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                        : _records.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.description_outlined, size: 48, color: AppTheme.textSecondary.withOpacity(0.3)),
                                    const SizedBox(height: 12),
                                    Text('No records for this patient', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: () => _loadRecords(_selectedPatient!['id']),
                                color: AppTheme.primaryColor,
                                child: ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 100),
                                  itemCount: _records.length,
                                  itemBuilder: (context, index) => _buildRecordCard(_records[index]),
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final fileName = record['file_name'] ?? 'Unknown';
    final recordType = record['record_type'] ?? 'Other';
    final description = record['description'] ?? '';
    
    String formattedDate = '';
    try {
      final dt = DateTime.parse(record['created_at']).toLocal();
      formattedDate = DateFormat('d MMM yyyy').format(dt);
    } catch (_) {}

    Color typeColor = AppTheme.primaryColor;
    IconData typeIcon = Icons.description;
    switch (recordType) {
      case 'Lab Report': typeColor = const Color(0xFF8B5CF6); typeIcon = Icons.science; break;
      case 'Prescription': typeColor = const Color(0xFF10B981); typeIcon = Icons.medication; break;
      case 'Imaging': typeColor = const Color(0xFF3B82F6); typeIcon = Icons.image; break;
      case 'Discharge Summary': typeColor = const Color(0xFFF59E0B); typeIcon = Icons.summarize; break;
    }

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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fileName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(recordType, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: typeColor)),
                          ),
                          const Spacer(),
                          Text(formattedDate, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(description, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.open_in_new, size: 16, color: AppTheme.textSecondary.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUploadSheet() {
    final descriptionController = TextEditingController();
    String selectedType = 'Lab Report';
    Map<String, dynamic>? uploadPatient = _selectedPatient;
    
    PlatformFile? selectedFile; 
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Upload Record', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // Patient Selector
                  Text('Patient', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>>(
                        isExpanded: true,
                        value: uploadPatient,
                        items: _patients.map((p) => DropdownMenuItem(
                          value: p,
                          child: Text('${p['preferred_name'] ?? p['name']}', style: GoogleFonts.inter(fontSize: 14)),
                        )).toList(),
                        onChanged: (v) => setSheetState(() => uploadPatient = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Record Type
                  Text('Record Type', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedType,
                        items: ['Lab Report', 'Prescription', 'Imaging', 'Discharge Summary', 'Other']
                            .map((t) => DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.inter(fontSize: 14))))
                            .toList(),
                        onChanged: (v) => setSheetState(() => selectedType = v!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Document File Picker
                  Text('Document File', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      FilePickerResult? result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
                        withData: true, 
                      );
                      if (result != null) {
                        setSheetState(() {
                          selectedFile = result.files.single;
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                        color: selectedFile != null ? AppTheme.success.withOpacity(0.1) : AppTheme.background,
                        border: Border.all(color: selectedFile != null ? AppTheme.success : AppTheme.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            selectedFile != null ? Icons.check_circle : Icons.upload_file, 
                            color: selectedFile != null ? AppTheme.success : AppTheme.textSecondary
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedFile != null ? selectedFile!.name : 'Tap to select PDF or Image',
                              style: GoogleFonts.inter(
                                color: selectedFile != null ? AppTheme.success : AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text('Description (optional)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Brief description...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Upload Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isUploading ? null : () async {
                        if (uploadPatient == null || selectedFile == null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text('Please select a patient and a file.'), 
                            backgroundColor: AppTheme.error,
                            behavior: SnackBarBehavior.floating, 
                          ));
                          return;
                        }

                        setSheetState(() => isUploading = true);

                        try {
                          final prefs = await SharedPreferences.getInstance();
                          final doctorId = prefs.getString('doctor_id') ?? '';
                          
                          // Extract name and format directly from the file
                          final fileName = selectedFile!.name;
                          final extension = selectedFile!.extension?.toLowerCase() ?? '';
                          final contentType = extension == 'pdf' ? 'application/pdf' : 'image/$extension';

                          // 1. Get the Ticket
                          final ticketData = await ApiService.getUploadUrl(
                            patientId: uploadPatient!['id'], 
                            fileName: fileName, 
                            fileType: contentType
                          );
                          
                          if (ticketData == null) throw Exception("Failed to get upload ticket from server.");

                          // 2. Upload directly to AWS S3
                          final uploadResponse = await http.put(
                            Uri.parse(ticketData['upload_url']),
                            headers: {'Content-Type': contentType},
                            body: selectedFile!.bytes!, 
                          );

                          if (uploadResponse.statusCode != 200) {
                            throw Exception("AWS rejected the file upload.");
                          }

                          // 3. Save to database
                          final success = await ApiService.saveRecord(
                            doctorId: doctorId,
                            userId: uploadPatient!['id'],
                            fileName: fileName,
                            recordType: selectedType,
                            fileUrl: ticketData['file_key'], 
                            description: descriptionController.text.trim(),
                          );

                          if (context.mounted) {
                            Navigator.pop(context); 
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: const Text('Record uploaded securely to patient vault.'), 
                                backgroundColor: AppTheme.success,
                                behavior: SnackBarBehavior.floating, 
                              ));
                              if (_selectedPatient != null) _loadRecords(_selectedPatient!['id']);
                            } else {
                              throw Exception("Failed to save record metadata.");
                            }
                          }
                        } catch (e) {
                          setSheetState(() => isUploading = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Upload failed: $e'), 
                              backgroundColor: AppTheme.error,
                              behavior: SnackBarBehavior.floating, 
                            ));
                          }
                        }
                      },
                      icon: isUploading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.cloud_upload, size: 20),
                      label: Text(
                        isUploading ? 'Uploading to Secure Vault...' : 'Upload Record', 
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}