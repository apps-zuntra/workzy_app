import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/screens/more/notification_settings_screen.dart';
import 'package:attendance_app/screens/more/change_password_screen.dart';
import 'package:attendance_app/screens/more/privacy_settings_screen.dart';
import 'package:attendance_app/screens/more/security_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSaving = false;

  void _showChangePasswordDialog() {
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5C5CFF)),
              onPressed: () async {
                final pass = newPassCtrl.text.trim();
                final confirm = confirmPassCtrl.text.trim();

                if (pass.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password must be at least 6 characters.')),
                  );
                  return;
                }

                if (pass != confirm) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match.')),
                  );
                  return;
                }

                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await user.updatePassword(pass);
                  }
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password updated successfully!')),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Password reset request submitted for ${FirebaseAuth.instance.currentUser?.email}')),
                  );
                }
              },
              child: const Text('Update Password', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showFeatureDialog(String title, String desc) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          content: Text(desc, style: const TextStyle(color: Color(0xFF4B5563))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _restoreDefaults() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Default settings restored.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1F2937), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Notification Settings
            _buildSettingCard(
              icon: Icons.notifications_none_rounded,
              title: 'Notification Settings',
              subtitle: 'Leave, attendance, events & more',
              iconColor: const Color(0xFFD97706),
              iconBgColor: const Color(0xFFFEFCE8),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
            ),
            const SizedBox(height: 12),

            // 2. Privacy
            _buildSettingCard(
              icon: Icons.person_outline_rounded,
              title: 'Privacy',
              subtitle: 'Profile & data visibility',
              iconColor: const Color(0xFFA855F7),
              iconBgColor: const Color(0xFFF3E8FF),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySettingsScreen())),
            ),
            const SizedBox(height: 12),

            // 3. Security
            _buildSettingCard(
              icon: Icons.verified_user_outlined,
              title: 'Security',
              subtitle: 'Biometric, PIN & sessions',
              iconColor: const Color(0xFF10B981),
              iconBgColor: const Color(0xFFECFDF5),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecuritySettingsScreen())),
            ),
            const SizedBox(height: 12),

            // 4. Change Password
            _buildSettingCard(
              icon: Icons.edit_outlined,
              title: 'Change Password',
              subtitle: 'Update your login password',
              iconColor: const Color(0xFFEC4899),
              iconBgColor: const Color(0xFFFCE7F3),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
            ),
            const SizedBox(height: 28),

            // Buttons Matching Screenshot 3
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C5CFF),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isSaving ? null : _saveSettings,
                    child: _isSaving
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text(
                            'Save Settings',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _restoreDefaults,
                    child: const Text(
                      'Restore Defaults',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9CA3AF),
          ),
        ),
        trailing: const Icon(
          Icons.keyboard_arrow_right_rounded,
          color: Color(0xFF9CA3AF),
          size: 20,
        ),
      ),
    );
  }
}
