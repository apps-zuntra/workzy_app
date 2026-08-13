import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _profileVisibility = true;
  bool _showContactInfo = false;
  bool _showBirthday = true;
  bool _showDepartment = true;
  bool _locationPermission = true;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? AppSession().email ?? '';
    if (userEmail.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirestoreService.userNotificationsCol(userEmail).doc('privacy').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _profileVisibility = data['profileVisibility'] ?? true;
          _showContactInfo = data['showContactInfo'] ?? false;
          _showBirthday = data['showBirthday'] ?? true;
          _showDepartment = data['showDepartment'] ?? true;
          _locationPermission = data['locationPermission'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('Error loading privacy settings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePrivacySettings() async {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? AppSession().email ?? '';
    if (userEmail.isEmpty) return;

    try {
      await FirestoreService.userNotificationsCol(userEmail).doc('privacy').set({
        'profileVisibility': _profileVisibility,
        'showContactInfo': _showContactInfo,
        'showBirthday': _showBirthday,
        'showDepartment': _showDepartment,
        'locationPermission': _locationPermission,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving privacy settings: $e');
    }
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
          'Privacy Settings',
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
                      children: [
                        _buildSwitchItem(
                          title: 'Profile Visibility',
                          value: _profileVisibility,
                          onChanged: (val) {
                            setState(() => _profileVisibility = val);
                            _savePrivacySettings();
                          },
                        ),
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        _buildSwitchItem(
                          title: 'Show Contact Information',
                          value: _showContactInfo,
                          onChanged: (val) {
                            setState(() => _showContactInfo = val);
                            _savePrivacySettings();
                          },
                        ),
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        _buildSwitchItem(
                          title: 'Show Birthday',
                          value: _showBirthday,
                          onChanged: (val) {
                            setState(() => _showBirthday = val);
                            _savePrivacySettings();
                          },
                        ),
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        _buildSwitchItem(
                          title: 'Show Department',
                          value: _showDepartment,
                          onChanged: (val) {
                            setState(() => _showDepartment = val);
                            _savePrivacySettings();
                          },
                        ),
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        _buildSwitchItem(
                          title: 'Location Permission',
                          value: _locationPermission,
                          onChanged: (val) {
                            setState(() => _locationPermission = val);
                            _savePrivacySettings();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSwitchItem({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
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
