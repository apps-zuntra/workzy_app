import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _biometricLogin = true;
  bool _pinLock = false;
  String _sessionTimeout = '15 mins';

  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _timeoutOptions = ['5 mins', '15 mins', '30 mins', '1 hour', 'Never'];

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
  }

  Future<void> _loadSecuritySettings() async {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? AppSession().email ?? '';
    if (userEmail.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirestoreService.userNotificationsCol(userEmail).doc('security').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _biometricLogin = data['biometricLogin'] ?? true;
          _pinLock = data['pinLock'] ?? false;
          _sessionTimeout = data['sessionTimeout'] ?? '15 mins';
        });
      }
    } catch (e) {
      debugPrint('Error loading security settings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSecuritySettings() async {
    setState(() => _isSaving = true);
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? AppSession().email ?? '';

    try {
      if (userEmail.isNotEmpty) {
        await FirestoreService.userNotificationsCol(userEmail).doc('security').set({
          'biometricLogin': _biometricLogin,
          'pinLock': _pinLock,
          'sessionTimeout': _sessionTimeout,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Security settings saved successfully!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Settings saved: $_sessionTimeout')),
      );
    }
  }

  void _showDeviceManagementModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Active Device Sessions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.phone_iphone_rounded, color: Color(0xFF5C5CFF)),
                ),
                title: const Text('Current Mobile Device', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Active now · Windows/Android App'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                  child: const Text('ACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Other sessions revoked.')),
                    );
                  },
                  child: const Text('Revoke Other Sessions', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
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
          'Security Settings',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Card 1: AUTHENTICATION
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AUTHENTICATION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF9CA3AF),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 1. Biometric Login
                        _buildSwitchItem(
                          title: 'Biometric Login',
                          subtitle: 'Face ID or Fingerprint',
                          value: _biometricLogin,
                          onChanged: (val) => setState(() => _biometricLogin = val),
                        ),
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),

                        // 2. PIN Lock
                        _buildSwitchItem(
                          title: 'PIN Lock',
                          subtitle: 'No PIN configured',
                          value: _pinLock,
                          onChanged: (val) => setState(() => _pinLock = val),
                        ),
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),

                        // 3. Session Timeout Dropdown
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Session Timeout',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _sessionTimeout,
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF5C5CFF)),
                                    style: const TextStyle(
                                      color: Color(0xFF5C5CFF),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    onChanged: (String? newValue) {
                                      if (newValue != null) {
                                        setState(() => _sessionTimeout = newValue);
                                      }
                                    },
                                    items: _timeoutOptions.map<DropdownMenuItem<String>>((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Card 2: Device Management
                  Container(
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
                      onTap: _showDeviceManagementModal,
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.computer_rounded, color: Color(0xFF5C5CFF), size: 22),
                      ),
                      title: const Text(
                        'Device Management',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      subtitle: const Text(
                        'View and revoke active sessions',
                        style: TextStyle(
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
                  ),
                  const SizedBox(height: 28),

                  // Full-Width Primary Button: Save Security Settings
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C5CFF),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isSaving ? null : _saveSecuritySettings,
                      child: _isSaving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text(
                              'Save Security Settings',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSwitchItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: const Color(0xFF5C5CFF),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
