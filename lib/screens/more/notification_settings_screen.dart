import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/firestore_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  // Notification Switch States (Default ON except System Alerts and Email Digest)
  bool _leaveNotifications = true;
  bool _attendanceAlerts = true;
  bool _eventReminders = true;
  bool _taskStatusUpdates = true;
  bool _teamAnnouncements = true;
  bool _systemAlerts = false;
  bool _pushNotifications = true;
  bool _emailDigest = false;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? AppSession().email ?? '';
    if (userEmail.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirestoreService.userNotificationsCol(userEmail).doc('settings').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _leaveNotifications = data['leaveNotifications'] ?? true;
          _attendanceAlerts = data['attendanceAlerts'] ?? true;
          _eventReminders = data['eventReminders'] ?? true;
          _taskStatusUpdates = data['taskStatusUpdates'] ?? true;
          _teamAnnouncements = data['teamAnnouncements'] ?? true;
          _systemAlerts = data['systemAlerts'] ?? false;
          _pushNotifications = data['pushNotifications'] ?? true;
          _emailDigest = data['emailDigest'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? AppSession().email ?? '';
    if (userEmail.isEmpty) return;

    try {
      await FirestoreService.userNotificationsCol(userEmail).doc('settings').set({
        'leaveNotifications': _leaveNotifications,
        'attendanceAlerts': _attendanceAlerts,
        'eventReminders': _eventReminders,
        'taskStatusUpdates': _taskStatusUpdates,
        'teamAnnouncements': _teamAnnouncements,
        'systemAlerts': _systemAlerts,
        'pushNotifications': _pushNotifications,
        'emailDigest': _emailDigest,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving notification settings: $e');
    }
  }

  void _turnOffAllNotifications() {
    setState(() {
      final anyOn = _leaveNotifications ||
          _attendanceAlerts ||
          _eventReminders ||
          _taskStatusUpdates ||
          _teamAnnouncements ||
          _systemAlerts ||
          _pushNotifications ||
          _emailDigest;

      final targetState = !anyOn;

      _leaveNotifications = targetState;
      _attendanceAlerts = targetState;
      _eventReminders = targetState;
      _taskStatusUpdates = targetState;
      _teamAnnouncements = targetState;
      _systemAlerts = targetState;
      _pushNotifications = targetState;
      _emailDigest = targetState;
    });
    _saveSettings();
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
          'Notification Settings',
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
                  // Top Banner Matching Mockup Screenshot 4
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Configure which notifications you receive. Changes are saved automatically.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5C5CFF),
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. WORK NOTIFICATIONS
                  _buildSectionCard(
                    title: 'WORK NOTIFICATIONS',
                    items: [
                      _buildSwitchItem(
                        title: 'Leave Notifications',
                        subtitle: 'Approvals, balance alerts, rejections',
                        value: _leaveNotifications,
                        onChanged: (val) {
                          setState(() => _leaveNotifications = val);
                          _saveSettings();
                        },
                      ),
                      _buildSwitchItem(
                        title: 'Attendance Alerts',
                        subtitle: 'Check-in reminders, late marks, corrections',
                        value: _attendanceAlerts,
                        onChanged: (val) {
                          setState(() => _attendanceAlerts = val);
                          _saveSettings();
                        },
                      ),
                      _buildSwitchItem(
                        title: 'Event Reminders',
                        subtitle: 'Company events, meetings, holidays',
                        value: _eventReminders,
                        onChanged: (val) {
                          setState(() => _eventReminders = val);
                          _saveSettings();
                        },
                      ),
                      _buildSwitchItem(
                        title: 'Task Status Updates',
                        subtitle: 'Assigned tasks, deadlines, completions',
                        value: _taskStatusUpdates,
                        onChanged: (val) {
                          setState(() => _taskStatusUpdates = val);
                          _saveSettings();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. TEAM & COMMUNICATION
                  _buildSectionCard(
                    title: 'TEAM & COMMUNICATION',
                    items: [
                      _buildSwitchItem(
                        title: 'Team Announcements',
                        subtitle: 'HR posts, team updates, notices',
                        value: _teamAnnouncements,
                        onChanged: (val) {
                          setState(() => _teamAnnouncements = val);
                          _saveSettings();
                        },
                      ),
                      _buildSwitchItem(
                        title: 'System Alerts',
                        subtitle: 'Maintenance, downtime, critical alerts',
                        value: _systemAlerts,
                        onChanged: (val) {
                          setState(() => _systemAlerts = val);
                          _saveSettings();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. DELIVERY CHANNELS
                  _buildSectionCard(
                    title: 'DELIVERY CHANNELS',
                    items: [
                      _buildSwitchItem(
                        title: 'Push Notifications',
                        subtitle: 'Receive alerts on this device',
                        value: _pushNotifications,
                        onChanged: (val) {
                          setState(() => _pushNotifications = val);
                          _saveSettings();
                        },
                      ),
                      _buildSwitchItem(
                        title: 'Email Digest',
                        subtitle: 'Daily summary sent to your email',
                        value: _emailDigest,
                        onChanged: (val) {
                          setState(() => _emailDigest = val);
                          _saveSettings();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Bottom Button: Turn Off All Notifications
                  TextButton(
                    onPressed: _turnOffAllNotifications,
                    child: const Text(
                      'Turn Off All Notifications',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> items,
  }) {
    return Container(
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(items.length, (i) {
            return Column(
              children: [
                if (i > 0) const Divider(height: 1, color: Color(0xFFF3F4F6)),
                items[i],
              ],
            );
          }),
        ],
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
