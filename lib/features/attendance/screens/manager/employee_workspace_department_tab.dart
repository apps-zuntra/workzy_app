import 'package:flutter/material.dart';

class EmployeeWorkspaceDepartmentTab extends StatelessWidget {
  final Map<String, dynamic> employeeData;

  const EmployeeWorkspaceDepartmentTab({super.key, required this.employeeData});

  @override
  Widget build(BuildContext context) {
    final department = employeeData['department'] ?? 'Design';
    final deptHead = employeeData['departmentHead'] ?? 'Sarah Mitchell';
    final manager = employeeData['managerName'] ?? 'Rahul Mehta';
    final teamSize = employeeData['teamSize'] ?? '6 members';

    // Mock team members for the department view
    final teamMembers = [
      {'name': 'Emma Wilson', 'role': 'Product Designer', 'status': 'Late'},
      {'name': 'Raj Patel', 'role': 'Product Designer', 'status': 'Present'},
      {'name': 'Olivia Smith', 'role': 'Associate Designer', 'status': 'WFH'},
      {'name': 'Daniel Carter', 'role': 'Associate Designer', 'status': 'On Leave'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'DEPARTMENT',
            children: [
              _buildInfoRow('Department Name', department),
              _buildDivider(),
              _buildInfoRow('Department Head', deptHead),
              _buildDivider(),
              _buildInfoRow('Reporting Manager', manager),
              _buildDivider(),
              _buildInfoRow('Team Size', teamSize),
            ],
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'TEAM MEMBERS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9CA3AF),
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...teamMembers.map((member) => _buildTeamMemberCard(member)).toList(),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9CA3AF),
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, color: Color(0xFFF3F4F6), indent: 20, endIndent: 20);
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '??';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFFEF4444),
      const Color(0xFF3B82F6),
      const Color(0xFFEC4899),
    ];
    int hash = name.hashCode.abs();
    return colors[hash % colors.length];
  }

  Widget _buildTeamMemberCard(Map<String, String> member) {
    final name = member['name']!;
    final role = member['role']!;
    final status = member['status']!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _getAvatarColor(name),
                child: Text(
                  _getInitials(name),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              if (status == 'Present') // Mock online indicator
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                const SizedBox(height: 2),
                Text(role, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          _buildStatusChip(status),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 16, color: Color(0xFFD1D5DB)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;
    Color borderColor;

    switch (status.toLowerCase()) {
      case 'present':
        bgColor = const Color(0xFFECFDF5);
        textColor = const Color(0xFF059669);
        borderColor = const Color(0xFFA7F3D0);
        break;
      case 'wfh':
        bgColor = const Color(0xFFEFF6FF);
        textColor = const Color(0xFF2563EB);
        borderColor = const Color(0xFFBFDBFE);
        break;
      case 'late':
        bgColor = const Color(0xFFFFFBEB);
        textColor = const Color(0xFFD97706);
        borderColor = const Color(0xFFFDE68A);
        break;
      case 'on leave':
        bgColor = const Color(0xFFF5F3FF);
        textColor = const Color(0xFF7C3AED);
        borderColor = const Color(0xFFDDD6FE);
        break;
      default:
        bgColor = const Color(0xFFF3F4F6);
        textColor = const Color(0xFF6B7280);
        borderColor = const Color(0xFFE5E7EB);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
