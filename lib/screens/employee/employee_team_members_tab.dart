import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/screens/employee/employee_profile_screen.dart';
import 'package:attendance_app/utils/app_session.dart';

class EmployeeTeamMembersTab extends StatefulWidget {
  const EmployeeTeamMembersTab({super.key});

  @override
  State<EmployeeTeamMembersTab> createState() => _EmployeeTeamMembersTabState();
}

class _EmployeeTeamMembersTabState extends State<EmployeeTeamMembersTab> {
  // Helper to fetch today's attendance for a user to determine status
  Stream<DocumentSnapshot> _userAttendanceStream(String email) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return FirestoreService.userAttendanceCol(email).doc(today).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('organizations')
          .doc(FirestoreService.companyId)
          .collection('users')
          .snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirestoreService.leaveRequestsCol.snapshots(),
          builder: (context, leaveSnap) {
            final docs = userSnap.data!.docs;
            final leaves = leaveSnap.data?.docs ?? [];
            final currentUserEmail = (AppSession().email ?? '').toLowerCase();
            String myDept = (AppSession().userDepartment ?? '').toString().trim().toLowerCase();
            if (myDept.isEmpty) {
              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final email = (data['email'] ?? doc.id).toString().toLowerCase();
                if (email == currentUserEmail) {
                  myDept = (data['department'] ?? '').toString().trim().toLowerCase();
                  break;
                }
              }
            }

            DateTime? parseDate(dynamic d) {
              if (d == null) return null;
              if (d is Timestamp) return d.toDate();
              if (d is DateTime) return d;
              if (d is String) return DateTime.tryParse(d);
              return null;
            }

            final todayNorm = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

            bool isUserOnLeaveToday(String email) {
              final userEmail = email.toLowerCase().trim();
              for (var doc in leaves) {
                final data = doc.data() as Map<String, dynamic>;
                final status = (data['status'] ?? '').toString().toLowerCase();
                if (status == 'approved') {
                  final from = parseDate(data['fromDate'] ?? data['startDate'] ?? data['from']);
                  final to = parseDate(data['toDate'] ?? data['endDate'] ?? data['to']) ?? from;
                  final docEmail = (data['applicantEmail'] ?? data['employeeEmail'] ?? data['email'] ?? '').toString().toLowerCase().trim();
                  
                  if (docEmail == userEmail && from != null) {
                    final targetTo = to ?? from;
                    final fromNorm = DateTime(from.year, from.month, from.day);
                    final toNorm = DateTime(targetTo.year, targetTo.month, targetTo.day);
                    if (!todayNorm.isBefore(fromNorm) && !todayNorm.isAfter(toNorm)) {
                      return true;
                    }
                  }
                }
              }
              return false;
            }

            List<Map<String, dynamic>> allUsers = [];

            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final dept = (data['department'] ?? '').toString().trim().toLowerCase();

              // Strict filter: ONLY see members in the exact same department
              if (myDept.isEmpty || dept != myDept) continue;

              allUsers.add({
                'email': data['email'] ?? doc.id,
                'firstName': data['firstName'] ?? data['name'] ?? '',
                'lastName': data['lastName'] ?? '',
                'role': data['role'] ?? data['designation'] ?? 'Employee',
                'department': data['department'] ?? '',
                'reportingManager': data['reportingManager'] ?? '',
              });
            }

            if (allUsers.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: Text(
                    'No members found in your department.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                  ),
                ),
              );
            }

            // Identify team lead (for demo, first user with 'Lead' in role, or just the first user)
            Map<String, dynamic>? lead;
            final members = <Map<String, dynamic>>[];

            for (var u in allUsers) {
              if (lead == null &&
                  u['role'].toString().toLowerCase().contains('lead')) {
                lead = u;
              } else {
                members.add(u);
              }
            }

            if (lead == null && members.isNotEmpty) {
              lead = members.removeAt(0);
            }

            return ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                if (lead != null) _buildLeadCard(lead, isUserOnLeaveToday(lead['email'])),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Team Members (${members.length})',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...members.map((m) => _buildMemberCard(m, isUserOnLeaveToday(m['email']))),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLeadCard(Map<String, dynamic> user, bool isOnLeave) {
    final f = user['firstName'].toString().isNotEmpty ? user['firstName'].toString()[0] : '';
    final l = user['lastName'].toString().isNotEmpty ? user['lastName'].toString()[0] : '';
    final initials = '$f$l'.toUpperCase();

    return StreamBuilder<DocumentSnapshot>(
      stream: _userAttendanceStream(user['email']),
      builder: (context, snapshot) {
        String statusText = 'Not checked in';
        String badgeText = 'Absent';
        Color badgeColor = const Color(0xFF9CA3AF);

        if (isOnLeave) {
          statusText = 'On Leave';
          badgeText = 'On Leave';
          badgeColor = const Color(0xFF8B5CF6);
        } else if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          if (data['checkIn'] != null) {
            DateTime? checkInDt;
            final ciVal = data['checkIn'];
            if (ciVal is Timestamp) checkInDt = ciVal.toDate();
            else if (ciVal is DateTime) checkInDt = ciVal;
            else if (ciVal is int) checkInDt = DateTime.fromMillisecondsSinceEpoch(ciVal);
            else if (ciVal is String) checkInDt = DateTime.tryParse(ciVal);

            final checkInTime = checkInDt != null ? DateFormat('hh:mm a').format(checkInDt) : 'N/A';
            statusText = 'In since $checkInTime';
            
            final isLate = data['isLate'] == true || (data['status'] ?? '').toString().toLowerCase() == 'late';
            if (isLate) {
              badgeText = 'Late';
              badgeColor = const Color(0xFFF59E0B);
            } else if (data['workMode'] == 'wfh') {
              badgeText = 'WFH';
              badgeColor = const Color(0xFF3B82F6);
            } else {
              badgeText = 'Present';
              badgeColor = const Color(0xFF10B981);
            }
          }
        }

        return GestureDetector(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => EmployeeProfileScreen(
                      user: user,
                      statusBadge: badgeText,
                      statusColor: badgeColor))),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF5C5CFF), Color(0xFF4338CA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TEAM LEAD',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                        letterSpacing: 0.5)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white30, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(initials,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: badgeColor,
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
                          Text('${user['firstName']} ${user['lastName']}',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(user['role'],
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70)),
                          const SizedBox(height: 2),
                          Text(statusText,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white60)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                      color: badgeColor,
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Text(badgeText,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Icon(Icons.chevron_right,
                            color: Colors.white54, size: 20),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> user, bool isOnLeave) {
    final f = user['firstName'].toString().isNotEmpty ? user['firstName'].toString()[0] : '';
    final l = user['lastName'].toString().isNotEmpty ? user['lastName'].toString()[0] : '';
    final initials = '$f$l'.toUpperCase();

    final colors = [
      const Color(0xFF5C5CFF),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF3B82F6),
      const Color(0xFFD1D5DB)
    ];
    final avatarColor =
        colors[user['firstName'].toString().length % colors.length];

    return StreamBuilder<DocumentSnapshot>(
      stream: _userAttendanceStream(user['email']),
      builder: (context, snapshot) {
        String badgeText = 'Absent';
        Color badgeColor = const Color(0xFF9CA3AF);
        Color badgeBg = const Color(0xFFF3F4F6);

        if (isOnLeave) {
          badgeText = 'On Leave';
          badgeColor = const Color(0xFF8B5CF6);
          badgeBg = const Color(0xFFF5F3FF);
        } else if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          if (data['checkIn'] != null) {
            final isLate = data['isLate'] == true || (data['status'] ?? '').toString().toLowerCase() == 'late';
            if (isLate) {
              badgeText = 'Late';
              badgeColor = const Color(0xFFF59E0B);
              badgeBg = const Color(0xFFFFFBEB);
            } else if (data['workMode'] == 'wfh') {
              badgeText = 'WFH';
              badgeColor = const Color(0xFF3B82F6);
              badgeBg = const Color(0xFFEFF6FF);
            } else {
              badgeText = 'Present';
              badgeColor = const Color(0xFF10B981);
              badgeBg = const Color(0xFFECFDF5);
            }
          }
        }

        return GestureDetector(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => EmployeeProfileScreen(
                      user: user,
                      statusBadge: badgeText,
                      statusColor: badgeColor))),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: avatarColor,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(initials,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: badgeColor,
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
                      Text('${user['firstName']} ${user['lastName']}',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827))),
                      const SizedBox(height: 2),
                      Text(user['role'],
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(badgeText,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: badgeColor)),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.chevron_right,
                    color: Color(0xFFD1D5DB), size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
