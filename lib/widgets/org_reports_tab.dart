import 'package:flutter/material.dart';
import 'package:attendance_app/screens/report_detail_screen.dart';

class OrgReportsTab extends StatelessWidget {
  const OrgReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F6F9),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildReportCard(
            context: context,
            title: 'Employee Report',
            subtitle: 'Headcount, joiners, exits',
            icon: Icons.people_alt_rounded,
            iconBgColor: const Color(0xFFEEF2FF),
            iconColor: const Color(0xFF5C5CFF),
            reportType: 'Employee',
          ),
          _buildReportCard(
            context: context,
            title: 'Department Report',
            subtitle: 'Per-department analytics',
            icon: Icons.business_rounded,
            iconBgColor: const Color(0xFFF3E8FF),
            iconColor: const Color(0xFFC084FC),
            reportType: 'Department',
          ),
          _buildReportCard(
            context: context,
            title: 'Attendance Report',
            subtitle: 'Daily and monthly trends',
            icon: Icons.check_circle_outline_rounded,
            iconBgColor: const Color(0xFFECFDF5),
            iconColor: const Color(0xFF10B981),
            reportType: 'Attendance',
          ),
          _buildReportCard(
            context: context,
            title: 'Leave Report',
            subtitle: 'Leave types and balances',
            icon: Icons.beach_access_rounded,
            iconBgColor: const Color(0xFFFFFBEB),
            iconColor: const Color(0xFFF59E0B),
            reportType: 'Leave',
          ),
          _buildReportCard(
            context: context,
            title: 'Announcement Report',
            subtitle: 'Reach and engagement',
            icon: Icons.campaign_rounded,
            iconBgColor: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF3B82F6),
            reportType: 'Announcement',
          ),
          _buildReportCard(
            context: context,
            title: 'Custom Report',
            subtitle: 'Build your own report',
            icon: Icons.tune_rounded,
            iconBgColor: const Color(0xFFEEF2FF),
            iconColor: const Color(0xFF60A5FA),
            reportType: null,
          ),
          _buildReportCard(
            context: context,
            title: 'Schedule Report',
            subtitle: 'Shift and schedule data',
            icon: Icons.schedule_rounded,
            iconBgColor: const Color(0xFFFEF2F2),
            iconColor: const Color(0xFFEF4444),
            reportType: null,
          ),
          _buildReportCard(
            context: context,
            title: 'Export Report',
            subtitle: 'Export as CSV / PDF',
            icon: Icons.download_rounded,
            iconBgColor: const Color(0xFFF3F4F6),
            iconColor: const Color(0xFF6B7280),
            reportType: null,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String? reportType,
  }) {
    return GestureDetector(
      onTap: reportType != null
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportDetailScreen(reportType: reportType),
                ),
              )
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937))),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            Icon(
              reportType != null
                  ? Icons.chevron_right
                  : Icons.lock_outline_rounded,
              size: 16,
              color: const Color(0xFFD1D5DB),
            ),
          ],
        ),
      ),
    );
  }
}
