import 'package:flutter/material.dart';
import 'employee_workspace_profile_tab.dart';
import 'employee_workspace_department_tab.dart';
import 'employee_workspace_related_data_tab.dart';

class EmployeeWorkspaceScreen extends StatefulWidget {
  final Map<String, dynamic> employeeData;

  const EmployeeWorkspaceScreen({
    super.key,
    required this.employeeData,
  });

  @override
  State<EmployeeWorkspaceScreen> createState() => _EmployeeWorkspaceScreenState();
}

class _EmployeeWorkspaceScreenState extends State<EmployeeWorkspaceScreen> {
  int _selectedTab = 0; // 0: Profile, 1: Department, 2: Related Data

  String _getInitials(String name) {
    if (name.isEmpty) return '??';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFF59E0B), // Orange
      const Color(0xFF10B981), // Green
      const Color(0xFFEF4444), // Red
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFEC4899), // Pink
    ];
    int hash = name.hashCode.abs();
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.employeeData['name'] ?? 'Unknown Employee';
    final role = widget.employeeData['role'] ?? 'Employee';
    final department = widget.employeeData['department'] ?? 'Design';
    final status = widget.employeeData['status'] ?? 'Active';
    
    String uiStatus = 'Present';
    if (status.toString().toLowerCase() == 'on leave') uiStatus = 'On Leave';
    if (status.toString().toLowerCase() == 'inactive') uiStatus = 'Inactive';
    if (status.toString().toLowerCase() == 'wfh') uiStatus = 'WFH';
    if (status.toString().toLowerCase() == 'late') uiStatus = 'Late';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1F2937), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Employee Workspace',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Color(0xFF5C5CFF)),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: _getAvatarColor(name),
                      child: Text(
                        _getInitials(name),
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                      const SizedBox(height: 4),
                      Text('$role · $department', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
                _buildStatusChip(uiStatus),
              ],
            ),
          ),
          
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildTab('Profile', 0),
                _buildTab('Department', 1),
                _buildTab('Related Data', 2),
              ],
            ),
          ),
          
          const SizedBox(height: 1),
          
          Expanded(
            child: _selectedTab == 0
                ? EmployeeWorkspaceProfileTab(employeeData: widget.employeeData)
                : _selectedTab == 1
                    ? EmployeeWorkspaceDepartmentTab(employeeData: widget.employeeData)
                    : EmployeeWorkspaceRelatedDataTab(employeeData: widget.employeeData),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF5C5CFF) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFF5C5CFF) : const Color(0xFF9CA3AF),
            ),
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
