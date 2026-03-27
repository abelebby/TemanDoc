import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:doctor_portal/theme.dart';
import 'package:doctor_portal/api_service.dart';
import 'package:doctor_portal/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final profile = await ApiService.getProfile();
    if (mounted) {
      if (profile != null && profile.containsKey('error') && profile['error'] == 'session_expired') {
        _handleSessionExpired();
        return;
      }
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    }
  }

  void _handleSessionExpired() async {
    await ApiService.logout();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Session expired. Please sign in again.'),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _handleSignOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to sign out?', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ApiService.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Sign Out', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _handleDeleteAccount() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Account', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.error)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action is permanent and cannot be undone. All your data, appointments, records, and patient links will be deleted.',
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 16),
            Text('Type DELETE to confirm:', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: textController,
              decoration: InputDecoration(
                hintText: 'DELETE',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.error, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (textController.text.trim() == 'DELETE') {
                Navigator.pop(context);
                _showFinalDeleteConfirmation();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please type DELETE exactly to proceed'),
                    backgroundColor: AppTheme.warning,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Continue', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showFinalDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Are you absolutely sure?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.error)),
        content: Text(
          'Your account and all associated data will be permanently erased. This cannot be reversed.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Go Back', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ApiService.deleteAccount();
              if (mounted) {
                if (success) {
                  await ApiService.logout();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Failed to delete account. Please try again.'),
                      backgroundColor: AppTheme.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete My Account', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    if (_profile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.textSecondary.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text('Failed to load profile', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadProfile, child: const Text('Retry')),
          ],
        ),
      );
    }

    final name = _profile!['name'] ?? 'Doctor';
    final specialisation = _profile!['specialisation'] ?? '';
    final imageUrl = _profile!['profile_image_url'] ?? '';

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // --- THE RESPONSIVE MAGIC ---
          // If the screen is wider than 850px, we switch to a 2-column desktop layout.
          bool isWideScreen = constraints.maxWidth > 850;

          if (isWideScreen) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Sidebar: Profile Card & Buttons
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        _buildHeaderCard(name, specialisation, imageUrl),
                        const SizedBox(height: 24),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Right Main Area: The editable details
                  Expanded(
                    flex: 7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPersonalInfoSection(),
                        const SizedBox(height: 24),
                        _buildProfessionalSection(),
                        const SizedBox(height: 24),
                        _buildContactSection(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else {
            // Standard Mobile/Narrow Layout (Everything in a single column)
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 120),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildHeaderCard(name, specialisation, imageUrl),
                  const SizedBox(height: 24),
                  _buildPersonalInfoSection(),
                  const SizedBox(height: 16),
                  _buildProfessionalSection(),
                  const SizedBox(height: 16),
                  _buildContactSection(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  // ==========================================
  // UI HELPER METHODS
  // ==========================================

  Widget _buildHeaderCard(String name, String specialisation, String imageUrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withOpacity(0.2),
            backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
            child: imageUrl.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(height: 14),
          Text(name, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          if (specialisation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(specialisation, style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.9))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return _buildSection('Personal Information', [
      _buildEditableRow('Preferred Name', _profile!['preferred_name'], 'preferred_name', Icons.badge),
      _buildEditableRow('Gender', _profile!['gender'], 'gender', Icons.person_outline),
      _buildEditableRow('Date of Birth', _profile!['dob'], 'dob', Icons.cake),
    ]);
  }

  Widget _buildProfessionalSection() {
    return _buildSection('Professional Details', [
      _buildEditableRow('Education', _profile!['education'], 'education', Icons.school),
      _buildEditableRow('Specialisation', _profile!['specialisation'], 'specialisation', Icons.local_hospital),
      _buildEditableRow('Clinic Name', _profile!['clinic_name'], 'clinic_name', Icons.business),
      _buildEditableRow('Clinic Address', _profile!['clinic_address'], 'clinic_address', Icons.location_on),
    ]);
  }

  Widget _buildContactSection() {
    return _buildSection('Contact Preferences', [
      _buildEditableRow('Platform', _profile!['messaging_platform'], 'messaging_platform', Icons.chat_bubble_outline),
      _buildEditableRow('Platform Link', _profile!['platform_link'], 'platform_link', Icons.link),
    ]);
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _handleSignOut,
            icon: const Icon(Icons.logout, size: 20, color: AppTheme.error),
            label: Text('Sign Out', style: GoogleFonts.inter(color: AppTheme.error, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.error, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _handleDeleteAccount,
            icon: const Icon(Icons.delete_forever, size: 20, color: Colors.white),
            label: Text('Delete Account', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: 0.3)),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildEditableRow(String label, String? value, String fieldKey, IconData icon) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showEditDialog(label, value, fieldKey),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primaryColor.withOpacity(0.6)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      value?.isNotEmpty == true ? value! : 'Not set',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: value?.isNotEmpty == true ? AppTheme.textPrimary : AppTheme.textSecondary.withOpacity(0.5),
                        fontStyle: value?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit, size: 16, color: AppTheme.textSecondary.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(String label, String? currentValue, String fieldKey) {
    final controller = TextEditingController(text: currentValue ?? '');

    // Special handling for messaging_platform — use dropdown
    if (fieldKey == 'messaging_platform') {
      String selected = currentValue ?? 'WhatsApp';
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Select $label', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: ['WhatsApp', 'Telegram', 'Email', 'Other'].map((platform) {
                return RadioListTile<String>(
                  title: Text(platform, style: GoogleFonts.inter()),
                  value: platform,
                  groupValue: selected,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (v) => setDialogState(() => selected = v!),
                );
              }).toList(),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary))),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _saveField(fieldKey, selected);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit $label', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Enter $label'),
          maxLines: fieldKey == 'clinic_address' ? 3 : 1,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _saveField(fieldKey, controller.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveField(String fieldKey, String value) async {
    final success = await ApiService.updateProfile({fieldKey: value});
    if (mounted) {
      if (success) {
        _loadProfile(); // Refresh
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update profile'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}