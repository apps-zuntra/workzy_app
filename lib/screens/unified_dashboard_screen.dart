import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:attendance_app/theme/app_theme.dart';
import 'package:attendance_app/utils/app_session.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/location_service.dart';
import 'package:attendance_app/utils/notification_helper.dart';
import 'package:attendance_app/utils/notification_service.dart';
import 'package:attendance_app/screens/auth_wrapper.dart';
import 'package:attendance_app/screens/profile_screen.dart';
import 'package:attendance_app/widgets/live_attendance_builder.dart';
import 'package:attendance_app/widgets/announcements_tab_view.dart';
import 'package:attendance_app/screens/create_announcement_wizard.dart';
import 'package:attendance_app/widgets/calendar_tab_view.dart';
import 'package:attendance_app/widgets/tasks_tab_view.dart';
import 'package:attendance_app/widgets/location_map_card.dart';
import 'package:attendance_app/widgets/full_map_screen.dart';
import 'package:attendance_app/widgets/team_members_view.dart';
import 'package:attendance_app/widgets/team_feed_view.dart';
import 'package:attendance_app/widgets/team_tasks_view.dart';
import 'package:attendance_app/widgets/team_departments_view.dart';
import 'package:attendance_app/widgets/org_overview_tab.dart';
import 'package:attendance_app/widgets/org_policies_tab.dart';
import 'package:attendance_app/widgets/org_reports_tab.dart';
import 'package:attendance_app/screens/attendance/attendance_screen.dart';
import 'package:attendance_app/screens/attendance/admin_attendance_screen.dart';
import 'package:attendance_app/features/leave_management/screens/admin/admin_leave_screen.dart';
import 'package:attendance_app/features/leave_management/screens/admin/admin_leave_tab.dart';
import 'package:attendance_app/features/leave_management/screens/shared/universal_leave_tab.dart';
import 'package:attendance_app/screens/more/universal_more_tab.dart';

class UnifiedDashboardScreen extends StatefulWidget {
  const UnifiedDashboardScreen({super.key});

  @override
  State<UnifiedDashboardScreen> createState() => _UnifiedDashboardScreenState();
}

class _UnifiedDashboardScreenState extends State<UnifiedDashboardScreen> {
  final user = FirebaseAuth.instance.currentUser;
  late final Stream<DocumentSnapshot> _currentUserStream =
      FirestoreService.userStreamByEmail(user?.email ?? '');
  late final Stream<QuerySnapshot> _orgUsersStream;

  // Tabs State
  int _selectedMainTab = 0; // 0: My Space, 1: Team, 2: Organization
  int _selectedSubTab =
      0; // 0: Dashboard, 1: Approvals, 2: Leave, 3: Announcements, 4: Calendar
  int _bottomNavIndex = 0;
  bool _isCreatingAnnouncement = false;

  // Approvals State
  int _selectedApprovalTab =
      0; // 0: All, 1: Shift, 2: Department, 3: Task, 4: Leave, 5: Attendance
  Map<String, dynamic>? _selectedApprovalData;
  DocumentReference? _selectedApprovalRef;

  // Personal Attendance State
  late final CollectionReference<Map<String, dynamic>> _todayRef;
  late final Stream<DocumentSnapshot> _todayAttendanceStream;
  LocationData? _currentLocationData;
  bool _isCheckingInOut = false;
  Timer? _timer;

  late final String orgId;

  // Stored streams – initialized once in initState to prevent rebuild blinking
  late final Stream<int> _allPendingCountStream;
  late final Stream<Map<String, int>> _todayStatsStream;
  late final Stream<List<Map<String, dynamic>>> _recentActivityStream;
  late final Stream<QuerySnapshot> _allTasksStream;
  late final Stream<QuerySnapshot> _employeesStream;
  late final Stream<QuerySnapshot> _myAttendanceStream;

  // Internal subscriptions for stored streams
  StreamSubscription? _subPendingLeaves,
      _subPendingAtt,
      _subPendingShifts,
      _subPendingDepts,
      _subPendingTasks;
  StreamSubscription? _subStatsAtt, _subStatsLeaves;
  StreamSubscription? _subActivityLeaves, _subActivityAtt;

  // Approvals Real-time State
  List<DocumentSnapshot>? _cachedApprovals = [];
  StreamSubscription? _subLeaves, _subAtt, _subShifts, _subDepts, _subTasks;
  StreamSubscription? _subEmployeesMap;
  Map<String, Map<String, dynamic>> _empMap = {};

  @override
  void initState() {
    super.initState();
    orgId = AppSession().companyId ?? '';
    _orgUsersStream = FirestoreService.employeesCol.snapshots();
    final userEmail = user?.email ?? '';
    _todayRef = FirestoreService.userAttendanceCol(userEmail);
    _todayAttendanceStream = _todayRef.doc(_getAttendanceDocId()).snapshots();

    _startLocationUpdates();
    _initApprovalsListeners();
    _initDashboardStreams();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subEmployeesMap?.cancel();
    _subLeaves?.cancel();
    _subAtt?.cancel();
    _subShifts?.cancel();
    _subDepts?.cancel();
    _subTasks?.cancel();
    _subPendingLeaves?.cancel();
    _subPendingAtt?.cancel();
    _subPendingShifts?.cancel();
    _subPendingDepts?.cancel();
    _subPendingTasks?.cancel();
    _subStatsAtt?.cancel();
    _subStatsLeaves?.cancel();
    _subActivityLeaves?.cancel();
    _subActivityAtt?.cancel();
    super.dispose();
  }

  String _getAttendanceDocId() =>
      DateFormat('yyyy-MM-dd').format(DateTime.now());

  void _startLocationUpdates() {
    LocationService().startRealtimeTracking();
    LocationService.getStream().listen((data) {
      if (mounted && data.position != null) {
        setState(() => _currentLocationData = data);
      }
    });
  }

  Future<void> _handleCheckInOut(String status, bool isCheckIn) async {
    if (_isCheckingInOut) return;
    setState(() => _isCheckingInOut = true);
    try {
      final now = DateTime.now();
      final userEmail = user?.email ?? '';
      final isInside = _currentLocationData?.isWithinRadius ?? false;
      final data = {
        'companyId': FirestoreService.companyId,
        'userId': userEmail,
        'status': status,
        if (isCheckIn) 'workMode': isInside ? 'office' : 'wfh',
        if (isCheckIn) 'checkIn': Timestamp.fromDate(now),
        if (isCheckIn)
          'checkInLocation': _currentLocationData?.address ?? 'Unknown',
        if (!isCheckIn) 'checkOut': Timestamp.fromDate(now),
        if (!isCheckIn)
          'checkOutLocation': _currentLocationData?.address ?? 'Unknown',
        'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
        'recordDate': DateFormat('yyyy-MM-dd').format(now),
      };

      await _todayRef
          .doc(_getAttendanceDocId())
          .set(data, SetOptions(merge: true));

      await NotificationHelper.notifyEmployee(
        employeeEmail: userEmail,
        title: isCheckIn ? 'Check-In Successful' : 'Check-Out Successful',
        body:
            'You have successfully ${isCheckIn ? "checked in" : "checked out"} at ${DateFormat('hh:mm a').format(now)}.',
        type: isCheckIn ? 'check_in' : 'check_out',
        extraData: {'userId': user?.uid},
      );

      if (isCheckIn) {
        final eParts = AppSession().shiftEndTime.split(':');
        await NotificationService().scheduleCheckoutReminder(DateTime(now.year,
            now.month, now.day, int.parse(eParts[0]), int.parse(eParts[1])));
      } else {
        await NotificationService().cancelCheckoutReminder();
      }

      if (mounted) _showSuccessModal(isCheckIn ? 'Check In' : 'Check Out', now);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _isCheckingInOut = false);
    }
  }

  void _showSuccessModal(String title, DateTime time) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => ElasticIn(
        child: Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                    color: Color(0xFFECFDF5), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_outline_rounded,
                    color: Color(0xFF10B981), size: 56),
              ),
              const SizedBox(height: 20),
              const Text('Successfully Done',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563))),
              const SizedBox(height: 6),
              Text(title,
                  style: const TextStyle(
                      color: Color(0xFF5C5CFF),
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
              const SizedBox(height: 12),
              Text(DateFormat('hh:mm a').format(time),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937))),
              const SizedBox(height: 4),
              Text(DateFormat('EEEE, dd MMM yyyy').format(time),
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C5CFF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Done',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _initDashboardStreams() {
    // ── Pending Count Stream ─────────────────────────────────────────────────
    int leavePending = 0,
        attPending = 0,
        shiftPending = 0,
        deptPending = 0,
        taskPending = 0;
    int lastPendingCount = 0;
    final pendingController = StreamController<int>.broadcast();
    pendingController.onListen = () {
      pendingController.add(lastPendingCount);
    };

    void emitPending() {
      if (!pendingController.isClosed) {
        lastPendingCount = leavePending +
            attPending +
            shiftPending +
            deptPending +
            taskPending;
        pendingController.add(lastPendingCount);
      }
    }

    _subPendingLeaves = FirestoreService.allLeaveRequestsQuery
        .snapshots()
        .listen((s) {
      leavePending = s.docs.where((d) {
        final data = d.data() as Map;
        return data['status'] == 'pending' && data['companyId'] == orgId;
      }).length;
      emitPending();
    }, onError: (_) {});
    _subPendingAtt = FirestoreService.allAttendanceCorrectionsQuery
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((s) {
      attPending = s.docs.length;
      emitPending();
    }, onError: (_) {});
    _subPendingShifts = FirestoreService.allShiftRequestsQuery
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((s) {
      shiftPending = s.docs.length;
      emitPending();
    }, onError: (_) {});
    _subPendingDepts = FirestoreService.allDepartmentRequestsQuery
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((s) {
      deptPending = s.docs.length;
      emitPending();
    }, onError: (_) {});
    _subPendingTasks = FirestoreService.allTaskRequestsQuery
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((s) {
      taskPending = s.docs.length;
      emitPending();
    }, onError: (_) {});

    _allPendingCountStream = pendingController.stream;

    // ── Today Stats Stream ───────────────────────────────────────────────────
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayDate =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final statsController = StreamController<Map<String, int>>.broadcast();
    Map<String, int> lastStatsMap = {'present': 0, 'wfh': 0, 'onLeave': 0};
    statsController.onListen = () {
      statsController.add(lastStatsMap);
    };
    List<DocumentSnapshot> statAttDocs = [];
    List<DocumentSnapshot> statLeaveDocs = [];

    void emitStats() {
      if (statsController.isClosed) return;
      int present = 0, wfh = 0, onLeave = 0;
      for (final doc in statAttDocs) {
        if (doc.id == todayStr) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          if (data['checkIn'] != null) {
            present++;
            if (data['workMode'] == 'wfh') wfh++;
          }
        }
      }
      for (final doc in statLeaveDocs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        try {
          final fromTs = data['fromDate'] ?? data['from'];
          final toTs = data['toDate'] ?? data['to'];
          if (fromTs == null) continue;
          DateTime? from = fromTs is Timestamp
              ? fromTs.toDate()
              : DateTime.tryParse(fromTs.toString());
          DateTime? to = toTs is Timestamp
              ? toTs.toDate()
              : (toTs != null ? DateTime.tryParse(toTs.toString()) : from);
          if (from != null && to != null) {
            final fromDate = DateTime(from.year, from.month, from.day);
            final toDate = DateTime(to.year, to.month, to.day);
            if (!todayDate.isBefore(fromDate) && !todayDate.isAfter(toDate))
              onLeave++;
          }
        } catch (_) {}
      }
      lastStatsMap = {'present': present, 'wfh': wfh, 'onLeave': onLeave};
      statsController.add(lastStatsMap);
    }

    _subStatsAtt =
        FirestoreService.allAttendanceRecordsCol.snapshots().listen((snap) {
      statAttDocs = snap.docs.where((d) => (d.data() as Map)['companyId'] == orgId).toList();
      emitStats();
    }, onError: (_) {});
    _subStatsLeaves = FirestoreService.allLeaveRequestsQuery
        .snapshots()
        .listen((snap) {
      statLeaveDocs = snap.docs.where((d) {
        final data = d.data() as Map;
        return (data['status'] ?? '').toString().toLowerCase() == 'approved' && data['companyId'] == orgId;
      }).toList();
      emitStats();
    }, onError: (_) {});

    _todayStatsStream = statsController.stream;

    // ── Recent Activity Stream ───────────────────────────────────────────────
    final activityController =
        StreamController<List<Map<String, dynamic>>>.broadcast();
    List<Map<String, dynamic>> actLeaves = [];
    List<Map<String, dynamic>> actAtts = [];
    List<Map<String, dynamic>> actEmployees = [];
    List<Map<String, dynamic>> lastActivityList = [];

    activityController.onListen = () {
      activityController.add(lastActivityList);
    };

    void emitActivity() {
      if (activityController.isClosed) return;
      final combined = [...actLeaves, ...actAtts, ...actEmployees];
      combined.sort((a, b) {
        final ta = a['_ts'] as DateTime?;
        final tb = b['_ts'] as DateTime?;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
      lastActivityList = combined.take(6).toList();
      activityController.add(lastActivityList);
    }

    DateTime? parseTs(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    _subActivityLeaves = FirestoreService.allLeaveRequestsQuery
        .limit(20)
        .snapshots()
        .listen((snap) {
      final validDocs = snap.docs.where((d) => (d.data() as Map)['companyId'] == orgId);
      actLeaves = validDocs.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        final ts = parseTs(d['createdAt'] ?? d['requestDate'] ?? d['applied']);
        final name = d['userName'] ?? d['empName'] ?? d['applicantName'] ?? d['employee'] ?? 'Employee';
        final leaveType = (d['leaveType'] ?? d['type'] ?? 'Leave').toString().toUpperCase();
        final status = (d['status'] ?? 'pending').toString().toLowerCase();
        final statusLabel = status == 'approved'
            ? 'approved'
            : status == 'rejected'
                ? 'rejected'
                : 'applied for';
        return {
          '_ts': ts,
          'text': '$name $statusLabel $leaveType leave',
          'icon': Icons.event_available_outlined,
          'color': status == 'approved'
              ? const Color(0xFF10B981)
              : status == 'rejected'
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFA855F7),
          'bg': status == 'approved'
              ? const Color(0xFFECFDF5)
              : status == 'rejected'
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFFAF5FF),
        };
      }).toList();
      emitActivity();
    }, onError: (_) {});

    _subActivityAtt = FirestoreService.allAttendanceCorrectionsQuery
        .limit(20)
        .snapshots()
        .listen((snap) {
      actAtts = snap.docs.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        final ts = parseTs(d['createdAt'] ?? d['requestDate']);
        final name = d['userName'] ?? d['empName'] ?? 'Employee';
        final status = (d['status'] ?? 'pending').toString().toLowerCase();
        return {
          '_ts': ts,
          'text': status == 'pending'
              ? '$name requested attendance correction'
              : 'Attendance ${status == 'approved' ? 'correction approved for' : 'correction rejected for'} $name',
          'icon': Icons.access_time_rounded,
          'color': status == 'approved'
              ? const Color(0xFF10B981)
              : status == 'rejected'
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFF59E0B),
          'bg': status == 'approved'
              ? const Color(0xFFECFDF5)
              : status == 'rejected'
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFFFFBEB),
        };
      }).toList();
      emitActivity();
    }, onError: (_) {});

    _recentActivityStream = activityController.stream;
    _allTasksStream = FirestoreService.tasksCol.snapshots();
    _employeesStream = FirestoreService.employeesCol.snapshots();

    final userEmail = AppSession().email ?? '';
    _myAttendanceStream = FirestoreService.userAttendanceCol(userEmail).snapshots();
    _subEmployeesMap = _employeesStream.listen((snap) {
      final newMap = <String, Map<String, dynamic>>{};
      
      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: 7));
      actEmployees.clear();
      
      for (final d in snap.docs) {
        final ed = d.data() as Map<String, dynamic>? ?? {};
        final docId = d.id.toLowerCase();
        newMap[docId] = ed;
        if (ed['email'] != null) newMap[ed['email'].toString().toLowerCase()] = ed;
        if (ed['userEmail'] != null) newMap[ed['userEmail'].toString().toLowerCase()] = ed;
        if (ed['userId'] != null) newMap[ed['userId'].toString().toLowerCase()] = ed;
        if (ed['uid'] != null) newMap[ed['uid'].toString().toLowerCase()] = ed;

        final createdAtTs = ed['createdAt'] ?? ed['joinedDate'];
        DateTime? createdAt;
        if (createdAtTs is Timestamp) {
          createdAt = createdAtTs.toDate();
        } else if (createdAtTs is String) {
          createdAt = DateTime.tryParse(createdAtTs);
        }
        
        if (createdAt != null && createdAt.isAfter(oneWeekAgo)) {
          final name = ed['name'] ?? ed['userName'] ?? 'New Employee';
          actEmployees.add({
            '_ts': createdAt,
            'text': '$name joined the team',
            'icon': Icons.person_add_alt_1_rounded,
            'color': const Color(0xFF3B82F6),
            'bg': const Color(0xFFEFF6FF),
          });
        }
      }
      if (mounted) {
        setState(() => _empMap = newMap);
      }
      emitActivity();
    }, onError: (_) {});
  }

  void _initApprovalsListeners() {
    List<DocumentSnapshot> leaves = [];
    List<DocumentSnapshot> attDocs = [];
    List<DocumentSnapshot> shifts = [];
    List<DocumentSnapshot> depts = [];
    List<DocumentSnapshot> tasks = [];

    void update() {
      if (!mounted) return;
      List<DocumentSnapshot> allDocs = [
        ...leaves,
        ...attDocs,
        ...shifts,
        ...depts,
        ...tasks
      ];
      setState(() {
        _cachedApprovals = allDocs;
      });
    }

    _subLeaves = FirestoreService.leaveRequestsCol.snapshots().listen((s) {
      leaves = s.docs;
      update();
    }, onError: (_) {});
    _subAtt =
        FirestoreService.allAttendanceCorrectionsQuery.snapshots().listen((s) {
      attDocs = s.docs;
      update();
    }, onError: (_) {});
    _subShifts = FirestoreService.allShiftRequestsQuery.snapshots().listen((s) {
      shifts = s.docs;
      update();
    }, onError: (_) {});
    _subDepts =
        FirestoreService.allDepartmentRequestsQuery.snapshots().listen((s) {
      depts = s.docs;
      update();
    }, onError: (_) {});
    _subTasks = FirestoreService.allTaskRequestsQuery.snapshots().listen((s) {
      tasks = s.docs;
      update();
    }, onError: (_) {});
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'RA';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: _isCreatingAnnouncement
          ? CreateAnnouncementWizard(
              onClose: () => setState(() => _isCreatingAnnouncement = false),
            )
          : IndexedStack(
              index: _bottomNavIndex,
              children: [
                SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildTopNavigation(),
                _buildSubNavigation(),
                Expanded(
                  child: _selectedMainTab == 0
                      ? (_selectedSubTab == 0
                          ? _buildDashboardView()
                          : (_selectedSubTab == 1
                              ? _buildApprovalsView()
                              : (_selectedSubTab == 2
                                  ? const AdminLeaveTab()
                                  : (_selectedSubTab == 3
                                      ? AnnouncementsTabView(
                                          isAdmin: true,
                                          showBoth: true,
                                          onCreateAnnouncement: () => setState(() => _isCreatingAnnouncement = true),
                                        )
                                      : (_selectedSubTab == 4
                                          ? const CalendarTabView()
                                          : (_selectedSubTab == 5
                                              ? const TasksTabView()
                                              : const Center(
                                                  child: Text(
                                                      'Under Construction'))))))))
                      : _selectedMainTab == 1
                          ? (_selectedSubTab == 0
                              ? const TeamMembersView()
                              : (_selectedSubTab == 1
                                  ? const TeamFeedView()
                                  : (_selectedSubTab == 2
                                      ? AnnouncementsTabView(
                                          isAdmin: true,
                                          isTeamAnnouncements: true,
                                          onCreateAnnouncement: () => setState(() => _isCreatingAnnouncement = true),
                                        )
                                      : (_selectedSubTab == 3
                                          ? const TeamTasksView()
                                          : (_selectedSubTab == 4
                                              ? const TeamDepartmentsView()
                                              : const Center(
                                                  child: Text(
                                                      'Under Construction')))))))
                          : _selectedMainTab == 2
                              ? (_selectedSubTab == 0
                                  ? const OrgOverviewTab()
                                  : (_selectedSubTab == 1
                                      ? const OrgPoliciesTab()
                                      : (_selectedSubTab == 2
                                          ? AnnouncementsTabView(
                                              isAdmin: true,
                                              isTeamAnnouncements: false,
                                              onCreateAnnouncement: () => setState(() => _isCreatingAnnouncement = true),
                                            )
                                          : (_selectedSubTab == 3
                                              ? const OrgReportsTab()
                                              : const Center(
                                                  child: Text(
                                                      'Under Construction'))))))
                              : const Center(child: Text('Under Construction')),
                ),
              ],
            ),
          ),
          AppSession().hasPermission('approve-attendance') ? const AdminAttendanceScreen() : const AttendanceScreen(),
          AppSession().hasPermission('approve-leave') ? const AdminLeaveScreen() : const UniversalLeaveTab(),
          const UniversalMoreTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _currentUserStream,
              builder: (context, snapshot) {
                final data = snapshot.data?.data() as Map<String, dynamic>?;
                String rawName = AppSession().userName ?? 'Admin';
                if (data?['name'] != null &&
                    data!['name'].toString().trim().isNotEmpty) {
                  rawName = data['name'].toString();
                } else if (user?.displayName != null &&
                    user!.displayName!.trim().isNotEmpty) {
                  rawName = user!.displayName!;
                }
                final firstName = rawName.split(' ')[0];
                final greeting = _getGreeting();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, $firstName',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(AppSession().role ?? 'Employee').toUpperCase()} - ${DateFormat('EEEE, d MMMM yyyy').format(DateTime.now())}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      color: Colors.white,
                    ),
                    child: const Icon(Icons.notifications_none_rounded,
                        size: 20, color: Color(0xFF4B5563)),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text('3',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              PopupMenuButton<String>(
                offset: const Offset(0, 40),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (value) async {
                  if (value == 'logout') {
                    await FirebaseAuth.instance.signOut();
                    AppSession().clear();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthWrapper()),
                      (route) => false,
                    );
                  } else if (value == 'profile') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 20),
                        SizedBox(width: 8),
                        Text('Profile'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Logout', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                child: StreamBuilder<DocumentSnapshot>(
                  stream: _currentUserStream,
                  builder: (context, snapshot) {
                    String? imageUrl;
                    String name = AppSession().userName ?? 'Admin';
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>;
                      imageUrl = data['profileImageUrl'];
                      if (data['name'] != null) name = data['name'];
                    }
                    return Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF5C5CFF),
                      ),
                      child: ClipOval(
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? (imageUrl.startsWith('http')
                                ? Image.network(imageUrl, fit: BoxFit.cover)
                                : Image.memory(base64Decode(imageUrl),
                                    fit: BoxFit.cover))
                            : Center(
                                child: Text(_getInitials(name),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold))),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavigation() {
    final List<Widget> tabs = [_buildTopTab('My Space', 0)];
    if (AppSession().hasPermission('team')) {
      tabs.add(_buildTopTab('Team', 1));
    }
    if (AppSession().hasPermission('organization')) {
      tabs.add(_buildTopTab('Organization', 2));
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: tabs,
      ),
    );
  }

  Widget _buildTopTab(String label, int index) {
    final isActive = _selectedMainTab == index;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedMainTab = index;
        _selectedSubTab = 0; // Reset sub tab
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFEEF2FF)
              : Colors.transparent, // Very light blue
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF5C5CFF) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? const Color(0xFF5C5CFF) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildSubNavigation() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _selectedMainTab == 0
            ? Row(
                children: [
                  _buildSubTab('Dashboard', 0),
                  if (AppSession().hasPermission('approvals')) _buildSubTab('Approvals', 1),
                  if (AppSession().hasPermission('dashboard-leave')) _buildSubTab('Leave', 2),
                  if (AppSession().hasPermission('announcements')) _buildSubTab('Announcements', 3),
                  if (AppSession().hasPermission('calendar')) _buildSubTab('Calendar', 4),
                  if (AppSession().hasPermission('tasks')) _buildSubTab('Tasks', 5),
                ],
              )
            : _selectedMainTab == 1
                ? Row(
                    children: [
                      _buildSubTab('Members', 0),
                      _buildSubTab('Feed', 1),
                      if (AppSession().hasPermission('announcements')) _buildSubTab('Announcements', 2),
                      if (AppSession().hasPermission('tasks')) _buildSubTab('Task', 3),
                      if (AppSession().hasPermission('organization')) _buildSubTab('Department', 4),
                    ],
                  )
                : _selectedMainTab == 2
                    ? Row(
                        children: [
                          _buildSubTab('Overview', 0),
                          _buildSubTab('Policies', 1),
                          if (AppSession().hasPermission('announcements')) _buildSubTab('Announcements', 2),
                          if (AppSession().hasPermission('reports')) _buildSubTab('Reports', 3),
                        ],
                      )
                    : const SizedBox(),
      ),
    );
  }

  Widget _buildSubTab(String label, int index) {
    final isActive = _selectedSubTab == index;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedSubTab = index;
        _selectedApprovalData = null; // reset approval view
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFF5C5CFF) : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            color: isActive ? const Color(0xFF5C5CFF) : const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOfficeLocationCard(),
          const SizedBox(height: 16),
          _buildAttendanceTodayCard(),
          const SizedBox(height: 16),
          _buildMonthlyAttendanceCard(),
          const SizedBox(height: 16),
          _buildStatsGrid(),
          const SizedBox(height: 16),
          _buildOrgWideAttendanceCard(),
          const SizedBox(height: 16),
          _buildPendingApprovalsCard(),
          const SizedBox(height: 16),
          _buildMyTasksCard(),
          const SizedBox(height: 16),
          _buildDepartmentHeadcountCard(),
          const SizedBox(height: 16),
          _buildRecentActivityCard(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildApprovalsView() {
    return Column(
      children: [
        _buildApprovalSecondaryTabs(),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        Expanded(
          child: _cachedApprovals == null
              ? const Center(child: CircularProgressIndicator())
              : Builder(builder: (context) {
                  final allDocs = _cachedApprovals!;

                  List<DocumentSnapshot> filteredDocs = allDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>? ?? {};
                    String type = (data['leaveType'] ?? data['type'] ?? 'leave')
                        .toString()
                        .toLowerCase();

                    if (doc.reference.parent.id == 'attendance_corrections')
                      type = 'attendance';
                    if (doc.reference.parent.id == 'shift_requests')
                      type = 'shift';
                    if (doc.reference.parent.id == 'department_requests')
                      type = 'department';
                    if (doc.reference.parent.id == 'task_requests')
                      type = 'task';

                    if (_selectedApprovalTab == 1) return type == 'shift';
                    if (_selectedApprovalTab == 2) return type == 'department';
                    if (_selectedApprovalTab == 3) return type == 'task';
                    if (_selectedApprovalTab == 4) return type == 'attendance';
                    if (_selectedApprovalTab == 5)
                      return type == 'wfh' ||
                          type == 'work from home' ||
                          type == 'remote';
                    if (_selectedApprovalTab == 6)
                      return doc.reference.parent.id == 'leave_requests' &&
                          type != 'wfh' &&
                          type != 'work from home' &&
                          type != 'remote';
                    return true;
                  }).toList();

                  List<Widget> listItems = [];

                  final pendingDocs = filteredDocs.where((d) {
                    final data = d.data() as Map<String, dynamic>? ?? {};
                    final status = (data['status'] ?? 'pending').toString().trim().toLowerCase();
                    return status == 'pending';
                  }).toList();

                  final processedDocs = filteredDocs.where((d) {
                    final data = d.data() as Map<String, dynamic>? ?? {};
                    final status = (data['status'] ?? 'pending').toString().trim().toLowerCase();
                    return status == 'approved' || status == 'rejected';
                  }).toList();

                  if (pendingDocs.isNotEmpty) {
                    listItems.add(Padding(
                      padding: const EdgeInsets.only(bottom: 16, top: 0),
                      child: Text('PENDING · ${pendingDocs.length}',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF6B7280),
                              letterSpacing: 0.5)),
                    ));
                    for (var doc in pendingDocs) {
                      listItems.add(_buildDynamicApprovalCard(doc));
                    }
                  }

                  if (processedDocs.isNotEmpty) {
                    listItems.add(Padding(
                      padding: const EdgeInsets.only(bottom: 16, top: 24),
                      child: Text('PROCESSED · ${processedDocs.length}',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF6B7280),
                              letterSpacing: 0.5)),
                    ));
                    for (var doc in processedDocs) {
                      listItems.add(_buildDynamicApprovalCard(doc));
                    }
                  }

                  if (listItems.isEmpty) {
                    return const Center(
                        child: Text('No requests found',
                            style: TextStyle(color: Colors.grey)));
                  }

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: listItems,
                  );
                }),
        ),
      ],
    );
  }

  Map<String, String> _resolveEmployeeInfo(DocumentSnapshot doc, Map<String, dynamic> data) {
    String? name = (data['applicantName'] ??
            data['employee'] ??
            data['userName'] ??
            data['empName'] ??
            data['name'] ??
            data['fullName'] ??
            data['employeeName'] ??
            data['user'] ??
            data['requestedBy'] ??
            data['appliedBy'])
        ?.toString();
    String? dept = (data['department'] ??
            data['empDept'] ??
            data['dept'] ??
            data['role'] ??
            data['designation'])
        ?.toString();

    String identifier = (data['applicantEmail'] ??
            data['employeeEmail'] ??
            data['userEmail'] ??
            data['email'] ??
            data['userId'] ??
            data['empId'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    if (identifier.isEmpty) {
      final parts = doc.reference.path.split('/');
      final usersIdx = parts.indexOf('users');
      if (usersIdx != -1 && usersIdx + 1 < parts.length) {
        identifier = parts[usersIdx + 1].trim().toLowerCase();
      }
    }

    if (identifier.isNotEmpty && _empMap.containsKey(identifier)) {
      final empData = _empMap[identifier]!;
      if (name == null || name.isEmpty || name == 'Employee') {
        name = (empData['name'] ?? empData['fullName'] ?? empData['userName'] ?? empData['empName'])?.toString();
      }
      if (dept == null || dept.isEmpty || dept == 'Department') {
        dept = (empData['department'] ?? empData['dept'] ?? empData['empDept'] ?? empData['role'])?.toString();
      }
    }

    if (name == null || name.trim().isEmpty || name == 'Employee') {
      if (identifier.contains('@')) {
        final prefix = identifier.split('@').first;
        final words = prefix.replaceAll('.', ' ').replaceAll('_', ' ').replaceAll('-', ' ').split(' ');
        name = words.map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '').join(' ');
      } else if (identifier.isNotEmpty) {
        name = identifier;
      } else {
        name = 'Employee';
      }
    }

    if (dept == null || dept.trim().isEmpty || dept == 'Department') {
      dept = 'General';
    }

    return {'name': name.trim(), 'dept': dept.trim()};
  }

  Widget _buildDynamicApprovalCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final colName = doc.reference.parent.id;

    DateTime? parseApprovalDate(dynamic d) {
      if (d == null) return null;
      if (d is Timestamp) return d.toDate();
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d);
      return null;
    }

    String title = 'Request';
    String details = '';
    String tag = 'Request';
    Color tagColor = const Color(0xFF6B7280);
    Color tagBgColor = const Color(0xFFF3F4F6);
    Color avatarColor = const Color(0xFF6B7280);

    if (colName == 'leave_requests') {
      final rawType = (data['leaveType'] ?? data['type'] ?? 'leave').toString().trim();
      final lowerType = rawType.toLowerCase();
      final isWfh = lowerType == 'wfh' ||
          lowerType == 'work from home' ||
          lowerType == 'remote';
      title = isWfh
          ? 'Work From Home Request'
          : '${rawType.isEmpty ? "Leave" : (rawType[0].toUpperCase() + rawType.substring(1).toLowerCase())} Request';

      final startVal = data['startDate'] ?? data['fromDate'] ?? data['from'];
      final endVal = data['endDate'] ?? data['toDate'] ?? data['to'];

      final startDt = parseApprovalDate(startVal);
      final endDt = parseApprovalDate(endVal);

      final sDate = startDt != null
          ? DateFormat('MMM d, yyyy').format(startDt)
          : (startVal?.toString() ?? '-');
      final eDate = endDt != null
          ? DateFormat('MMM d, yyyy').format(endDt)
          : (endVal?.toString() ?? '-');

      final reason = data['reason']?.toString().trim() ??
          data['notes']?.toString().trim() ??
          '';
      details = '$sDate to $eDate${reason.isNotEmpty ? ' · $reason' : ''}';
      tag = isWfh
          ? 'WFH'
          : (rawType.isEmpty
              ? 'Leave'
              : (rawType[0].toUpperCase() + rawType.substring(1).toLowerCase()));
      avatarColor =
          isWfh ? const Color(0xFF2563EB) : const Color(0xFF10B981);
      tagColor = isWfh ? const Color(0xFF2563EB) : const Color(0xFF10B981);
      tagBgColor =
          isWfh ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5);
    } else if (colName == 'attendance_corrections') {
      title = 'Attendance Correction';

      final attVal = data['attendanceDate'] ?? data['requestedDate'] ?? data['date'];
      final attDt = parseApprovalDate(attVal);
      final aDate = attDt != null
          ? DateFormat('MMM d, yyyy').format(attDt)
          : (attVal?.toString() ?? '-');

      final reason = data['reason']?.toString().trim() ?? '';
      details = '$aDate${reason.isNotEmpty ? ' · Reason: $reason' : ''}';
      tag = 'Attendance';
      avatarColor = const Color(0xFFEF4444);
      tagColor = const Color(0xFFEF4444);
      tagBgColor = const Color(0xFFFEF2F2);
    } else if (colName == 'shift_requests') {
      title = 'Shift Change';
      final reason = data['reason']?.toString().trim() ?? '';
      details = reason.isNotEmpty ? 'Reason: $reason' : 'Shift update request';
      tag = 'Shift';
      avatarColor = const Color(0xFF10B981);
      tagColor = const Color(0xFF10B981);
      tagBgColor = const Color(0xFFECFDF5);
    } else if (colName == 'department_requests') {
      title = 'Department Transfer';
      final reason = data['reason']?.toString().trim() ?? '';
      details = reason.isNotEmpty ? 'Reason: $reason' : 'Transfer request';
      tag = 'Department';
      avatarColor = const Color(0xFF5C5CFF);
      tagColor = const Color(0xFF5C5CFF);
      tagBgColor = const Color(0xFFEEF2FF);
    } else if (colName == 'task_requests') {
      title = 'Task Update';
      final reason = data['reason']?.toString().trim() ?? '';
      details =
          reason.isNotEmpty ? 'Reason: $reason' : 'Task extension request';
      tag = 'Task';
      avatarColor = const Color(0xFFF59E0B);
      tagColor = const Color(0xFFF59E0B);
      tagBgColor = const Color(0xFFFFFBEB);
    }

    final empInfo = _resolveEmployeeInfo(doc, data);
    final empName = empInfo['name'] ?? 'Employee';
    final empDept = empInfo['dept'] ?? 'Department';
    final initials = _getInitials(empName);
    final rawStatus = (data['status'] ?? 'pending').toString().trim().toLowerCase();
    final status = rawStatus.isEmpty ? 'pending' : rawStatus;

    final createdDt = parseApprovalDate(data['createdAt'] ?? data['requestDate'] ?? data['applied']);
    final dateStr = createdDt != null
        ? DateFormat('MMM d').format(createdDt)
        : 'Recent';
    final subtitle = '$empDept · Applied $dateStr';

    Map<String, dynamic> detailData = {
      'title': title,
      'type': tag,
      'details': details,
      'appliedOn': dateStr,
      'status': status.isEmpty
          ? ''
          : '${status[0].toUpperCase()}${status.substring(1).toLowerCase()}',
      'empName': empName,
      'empDept': empDept,
      'initials': initials,
      'avatarColor': avatarColor.value,
      'docData': data,
    };

    Color statusBg;
    Color statusFg;
    String statusLabel;
    if (status == 'approved') {
      statusBg = const Color(0xFFECFDF5);
      statusFg = const Color(0xFF10B981);
      statusLabel = 'Approved';
    } else if (status == 'rejected') {
      statusBg = const Color(0xFFFEF2F2);
      statusFg = const Color(0xFFEF4444);
      statusLabel = 'Rejected';
    } else {
      statusBg = const Color(0xFFFFFBEB);
      statusFg = const Color(0xFFD97706);
      statusLabel = 'Pending';
    }

    void openReview() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _AdminApprovalReviewScreen(
            initialData: detailData,
            docRef: doc.reference,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: openReview,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration:
                      BoxDecoration(color: avatarColor, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(empName,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937))),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF9CA3AF))),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusFg.withOpacity(0.3))),
                  child: Text(statusLabel,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusFg)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937))),
                  const SizedBox(height: 4),
                  Text(details,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: tagBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tagColor.withOpacity(0.3))),
                  child: Text(tag,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: tagColor)),
                ),
                GestureDetector(
                  onTap: openReview,
                  child: Row(
                    children: const [
                      Text('Review',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF5C5CFF))),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward,
                          size: 14, color: Color(0xFF5C5CFF)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalSecondaryTabs() {
    final tabs = [
      'All',
      'Shift',
      'Department',
      'Task',
      'Attendance',
      'WFH',
      'Leave',
    ];
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isActive = _selectedApprovalTab == index;
            return GestureDetector(
              onTap: () => setState(() => _selectedApprovalTab = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF5C5CFF)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF5C5CFF)
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFF5C5CFF).withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    color: isActive ? Colors.white : const Color(0xFF4B5563),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildApprovalDetailView() {
    final data = _selectedApprovalData!;

    String title = data['title']?.toString() ?? 'Request Review';
    String type = data['type']?.toString() ?? 'Request';
    String details = data['details']?.toString() ?? '-';
    String appliedStr = data['appliedOn']?.toString() ?? '-';
    String status = data['status']?.toString() ?? 'Pending';
    String empName = data['empName']?.toString() ?? 'Employee';
    String empDept = data['empDept']?.toString() ?? 'Department';
    String initials = data['initials']?.toString() ?? _getInitials(empName);
    Color avatarColor = data['avatarColor'] != null
        ? Color(data['avatarColor'])
        : const Color(0xFF8B5CF6);

    Color statusBgColor = const Color(0xFFFFFBEB);
    Color statusBorderColor = const Color(0xFFFDE68A);
    Color statusTextColor = const Color(0xFFB45309);

    if (status.toLowerCase() == 'approved') {
      statusBgColor = const Color(0xFFECFDF5);
      statusBorderColor = const Color(0xFF86EFAC);
      statusTextColor = const Color(0xFF047857);
    } else if (status.toLowerCase() == 'rejected') {
      statusBgColor = const Color(0xFFFEF2F2);
      statusBorderColor = const Color(0xFFFCA5A5);
      statusTextColor = const Color(0xFFB91C1C);
    }

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _selectedApprovalData = null),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 12, top: 4, bottom: 4),
                    child: Icon(Icons.arrow_back_ios_new,
                        size: 18, color: Color(0xFF1F2937)),
                  ),
                ),
                Text(title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937))),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Employee Profile Header Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: const Color(0xFFE2E8F0), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: avatarColor,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                empName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                empDept,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: statusBorderColor, width: 1),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: statusTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Request Details Card
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: const Color(0xFFF1F5F9), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'REQUEST DETAILS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildDetailRow('Type', type),
                        const Divider(
                            height: 32,
                            thickness: 1,
                            color: Color(0xFFF1F5F9)),
                        _buildDetailRow('Title', title),
                        const Divider(
                            height: 32,
                            thickness: 1,
                            color: Color(0xFFF1F5F9)),
                        _buildDetailRow('Details', details),
                        const Divider(
                            height: 32,
                            thickness: 1,
                            color: Color(0xFFF1F5F9)),
                        _buildDetailRow('Applied On', appliedStr),
                        const Divider(
                            height: 32,
                            thickness: 1,
                            color: Color(0xFFF1F5F9)),
                        _buildDetailRow('Status', status),
                      ],
                    ),
                  ),
                  if (status.toLowerCase() == 'pending') ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: const Color(0xFF86EFAC), width: 1.5),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _updateApprovalStatus('approved'),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: Text(
                                      'Approve',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF047857),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: const Color(0xFFFCA5A5), width: 1.5),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _updateApprovalStatus('rejected'),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: Text(
                                      'Reject',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFB91C1C),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B))),
        const SizedBox(width: 16),
        Expanded(
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937))),
        ),
      ],
    );
  }

  void _updateApprovalStatus(String status) async {
    if (_selectedApprovalRef == null) {
      // Mock data scenario
      setState(() => _selectedApprovalData = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Mock request ${status} successfully'),
            backgroundColor:
                status == 'approved' ? AppTheme.success : AppTheme.danger));
      }
      return;
    }

    try {
      await _selectedApprovalRef!.update({'status': status});
      setState(() => _selectedApprovalData = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Request $status successfully'),
            backgroundColor:
                status == 'approved' ? AppTheme.success : AppTheme.danger));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: AppTheme.danger));
      }
    }
  }

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: child,
    );
  }

  Widget _buildOfficeLocationCard() {
    final isInside = _currentLocationData?.isWithinRadius ?? false;
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6))),
      child: Column(children: [
        SizedBox(
            height: 130,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              child: LocationMapCard(
                  officeLat: LocationService.officeLat,
                  officeLng: LocationService.officeLng,
                  allowedRadius: LocationService.allowedRadius,
                  userLocation: _currentLocationData?.latLng,
                  userAddress: _currentLocationData?.address,
                  height: 130),
            )),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Office Location',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827))),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: isInside
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(isInside ? 'INSIDE OFFICE RANGE' : 'OUTSIDE OFFICE RANGE',
                    style: TextStyle(
                        fontSize: 10,
                        color: isInside
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3)),
              ]),
            ]),
            GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => FullMapScreen(
                          officeLat: LocationService.officeLat,
                          officeLng: LocationService.officeLng,
                          allowedRadius: LocationService.allowedRadius,
                          userLocation: _currentLocationData?.latLng,
                          userAddress: _currentLocationData?.address))),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: const [
                  Icon(Icons.location_on_outlined,
                      color: Color(0xFF5C5CFF), size: 14),
                  SizedBox(width: 4),
                  Text('View Map',
                      style: TextStyle(
                          color: Color(0xFF5C5CFF),
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildAttendanceTodayCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _todayAttendanceStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final checkIn = data?['checkIn'] as Timestamp?;
        final checkOut = data?['checkOut'] as Timestamp?;
        final status = data?['status'] as String?;
        final isCheckedIn = checkIn != null && checkOut == null;
        final isCheckedOut = checkIn != null && checkOut != null;
        final isPresent = isCheckedIn || isCheckedOut;
        final checkInStr = checkIn != null
            ? DateFormat('hh:mm a').format(checkIn.toDate())
            : '--:-- --';

        String workingStr = "0h 0m";
        String overtimeStr = "0h 0m";

        if (checkIn != null) {
          final diff = (checkOut?.toDate() ?? DateTime.now())
              .difference(checkIn.toDate());
          final h = diff.inHours;
          final m = diff.inMinutes % 60;
          workingStr = '${h}h ${m}m';

          if (h > 9 || (h == 9 && m > 0)) {
            final otMin = diff.inMinutes - (9 * 60);
            final oth = otMin ~/ 60;
            final otm = otMin % 60;
            overtimeStr = '${oth}h ${otm}m';
          }
        }

        return Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF3F4F6))),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ATTENDANCE TODAY',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                            letterSpacing: 0.4)),
                    if (isPresent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    const Color(0xFF10B981).withOpacity(0.3))),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF10B981), size: 13),
                              SizedBox(width: 4),
                              Text('Present',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.w700)),
                            ]),
                      ),
                  ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        isCheckedOut
                            ? 'Checked Out'
                            : isCheckedIn
                                ? 'Checked In'
                                : 'Not Checked In',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827))),
                    const SizedBox(height: 2),
                    Text('$checkInStr  -  General Shift',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: _statPill(checkInStr, 'Check In')),
                      const SizedBox(width: 8),
                      Expanded(child: _statPill(workingStr, 'Working')),
                      const SizedBox(width: 8),
                      Expanded(child: _statPill(overtimeStr, 'Overtime')),
                    ]),
                    const SizedBox(height: 14),
                    if (isCheckedOut)
                      _outlinedActionBtn(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Shift Complete',
                          color: const Color(0xFF10B981),
                          onTap: null)
                    else if (isCheckedIn)
                      _outlinedActionBtn(
                          icon: Icons.logout_rounded,
                          label:
                              _isCheckingInOut ? 'Processing...' : 'Check Out',
                          color: const Color(0xFFEF4444),
                          onTap: _isCheckingInOut
                              ? null
                              : () => _handleCheckInOut('present', false))
                    else
                      SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isCheckingInOut
                                ? null
                                : () => _handleCheckInOut('present', true),
                            icon: _isCheckingInOut
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.login_rounded, size: 18),
                            label: Text(
                                _isCheckingInOut
                                    ? 'Checking In...'
                                    : 'Check In Now',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5C5CFF),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                          )),
                  ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _statPill(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
          color: const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF3F4F6))),
      child: Column(children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827)),
              textAlign: TextAlign.center),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
        ),
      ]),
    );
  }

  Widget _outlinedActionBtn(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4), width: 1.5)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 14, color: color, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _buildMonthlyAttendanceCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MONTHLY ATTENDANCE – ${DateFormat('MMMM yyyy').format(DateTime.now()).toUpperCase()}',
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildLegendItem(
                  const Color(0xFF1D4ED8), '≥9 hrs'), // Dark Blue
              const SizedBox(width: 16),
              _buildLegendItem(
                  const Color(0xFFF59E0B), 'Late (<9 hrs)'), // Orange
              const SizedBox(width: 16),
              _buildLegendItem(const Color(0xFF93C5FD), 'Leave'), // Light Blue
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: StreamBuilder<QuerySnapshot>(
              stream: _myAttendanceStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading chart', style: TextStyle(fontSize: 10, color: Colors.red)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final now = DateTime.now();
                final currentYear = now.year;
                final currentMonth = now.month;

                // Filter locally by current year and month
                final docs = snapshot.data?.docs.where((doc) {
                  final parts = doc.id.split('-');
                  if (parts.length == 3) {
                    return int.tryParse(parts[0]) == currentYear && int.tryParse(parts[1]) == currentMonth;
                  }
                  return false;
                }).toList() ?? [];

                final Map<int, double> hoursByDay = {};
                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final dateStr = doc.id; // 'yyyy-MM-dd'
                  try {
                    final day = int.parse(dateStr.split('-')[2]);
                    final totalHours = (data['totalHours'] ?? 0).toDouble();
                    hoursByDay[day] = totalHours;
                  } catch (e) {}
                }

                final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
                final List<BarChartGroupData> barGroups = [];

                for (int i = 1; i <= daysInMonth; i++) {
                  final hours = hoursByDay[i] ?? 0.0;
                  Color color = Colors.transparent;
                  if (hours >= 9.0) {
                    color = const Color(0xFF1D4ED8);
                  } else if (hours > 0) {
                    color = const Color(0xFFF59E0B);
                  }
                  barGroups.add(_makeBarGroup(i - 1, hours > 10 ? 10 : hours, color));
                }

                return BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 10,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final day = value.toInt() + 1;
                            if (day % 5 != 1 && day != daysInMonth) return const SizedBox.shrink(); // Show 1, 6, 11...
                            return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(day.toString(), style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10)));
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 20,
                          interval: 3,
                          getTitlesWidget: (value, meta) {
                            return Text(value.toInt().toString(),
                                style: const TextStyle(
                                    color: Color(0xFF9CA3AF), fontSize: 10));
                          },
                        ),
                      ),
                      topTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      checkToShowHorizontalLine: (value) => value % 3 == 0,
                      getDrawingHorizontalLine: (value) => FlLine(
                          color: const Color(0xFFF3F4F6),
                          strokeWidth: 1,
                          dashArray: [4, 4]),
                      drawVerticalLine: false,
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: barGroups.isEmpty 
                        ? [_makeBarGroup(0, 0, Colors.transparent)] 
                        : barGroups,
                  ),
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.rectangle)),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 8,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        )
      ],
    );
  }

  Widget _buildStatsGrid() {
    return StreamBuilder<Map<String, int>>(
      stream: _todayStatsStream,
      builder: (context, statsSnap) {
        final stats = statsSnap.data ?? {'present': 0, 'wfh': 0, 'onLeave': 0};
        return StreamBuilder<QuerySnapshot>(
          stream: _orgUsersStream,
          builder: (context, usersSnap) {
            final totalEmp = usersSnap.data?.docs
                    .where((d) => (d.data() as Map)['role'] != 'admin')
                    .length ??
                0;
            final present = stats['present'] ?? 0;
            final wfh = stats['wfh'] ?? 0;
            final onLeave = stats['onLeave'] ?? 0;
            final absent = (totalEmp - present - onLeave - wfh) < 0
                ? 0
                : (totalEmp - present - onLeave - wfh);
            return StreamBuilder<int>(
              stream: _allPendingCountStream,
              builder: (context, pendingSnap) {
                final pending = pendingSnap.data ?? 0;
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.55,
                  children: [
                    _buildStatCard(totalEmp.toString(), 'Total Employees',
                        const Color(0xFFEEF2FF), const Color(0xFF5C5CFF)),
                    _buildStatCard(present.toString(), 'Present Today',
                        const Color(0xFFECFDF5), const Color(0xFF10B981)),
                    _buildStatCard(onLeave.toString(), 'On Leave',
                        const Color(0xFFFAF5FF), const Color(0xFFA855F7)),
                    _buildStatCard(wfh.toString(), 'Working from Home',
                        const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
                    _buildStatCard(absent.toString(), 'Not Marked Today',
                        const Color(0xFFFFFBEB), const Color(0xFFF59E0B)),
                    _buildStatCard(pending.toString(), 'Pending Approvals',
                        const Color(0xFFFEF2F2), const Color(0xFFEF4444)),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(
      String value, String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937))),
        ],
      ),
    );
  }

  Widget _buildOrgWideAttendanceCard() {
    return StreamBuilder<Map<String, int>>(
        stream: _todayStatsStream,
        builder: (context, statsSnap) {
          final stats =
              statsSnap.data ?? {'present': 0, 'wfh': 0, 'onLeave': 0};
          final p = stats['present'] ?? 0;
          final w = stats['wfh'] ?? 0;
          final l = stats['onLeave'] ?? 0;
          return StreamBuilder<QuerySnapshot>(
            stream: _orgUsersStream,
            builder: (context, usersSnap) {
              final total = usersSnap.data?.docs
                      .where((d) => (d.data() as Map)['role'] != 'admin')
                      .length ??
                  0;
              final nm = (total - p - l - w) < 0 ? 0 : (total - p - l - w);

              return _buildCardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ATTENDANCE TODAY (ORG-WIDE)',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF6B7280),
                          letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 20),
                    _buildProgressBar(
                        'Present', p, total, const Color(0xFF10B981)),
                    const SizedBox(height: 16),
                    _buildProgressBar(
                        'On Leave', l, total, const Color(0xFFA855F7)),
                    const SizedBox(height: 16),
                    _buildProgressBar('WFH', w, total, const Color(0xFF2563EB)),
                    const SizedBox(height: 16),
                    _buildProgressBar(
                        'Not Marked', nm, total, const Color(0xFFD1D5DB)),
                  ],
                ),
              );
            },
          );
        });
  }

  Widget _buildProgressBar(String label, int value, int total, Color color) {
    double progress = total == 0 ? 0 : value / total;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500)),
            Text(value.toString(),
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFFF3F4F6),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildPendingApprovalsCard() {
    return StreamBuilder<int>(
      stream: _allPendingCountStream,
      builder: (context, snapshot) {
        final pendingCount = snapshot.data ?? 0;
        final hasData = snapshot.connectionState != ConnectionState.waiting;
        return GestureDetector(
          onTap: () => setState(() {
            _selectedSubTab = 1; // Navigate to Approvals tab
          }),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: pendingCount > 0
                      ? const Color(0xFFFDE68A)
                      : const Color(0xFFE5E7EB)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x05000000),
                    blurRadius: 10,
                    offset: Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: pendingCount > 0
                        ? const Color(0xFFFFFBEB)
                        : const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.pending_actions_rounded,
                    color: pendingCount > 0
                        ? const Color(0xFFD97706)
                        : const Color(0xFF9CA3AF),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pending Approvals',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F2937))),
                      const SizedBox(height: 3),
                      Text(
                        hasData
                            ? (pendingCount == 0
                                ? 'All caught up!'
                                : '$pendingCount request${pendingCount > 1 ? 's' : ''} awaiting action')
                            : 'Loading...',
                        style: TextStyle(
                          fontSize: 11,
                          color: pendingCount > 0
                              ? const Color(0xFFD97706)
                              : const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (pendingCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$pendingCount',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                  ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: Color(0xFF9CA3AF)),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTaskDuration(DateTime start) {
    final diff = DateTime.now().difference(start);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(diff.inHours)}:${twoDigits(diff.inMinutes.remainder(60))}:${twoDigits(diff.inSeconds.remainder(60))}';
  }

  Widget _buildMyTasksCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _allTasksStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return _buildCardContainer(
            child: const Center(
                child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            )),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];
        final userEmail = (user?.email ?? AppSession().email ?? FirebaseAuth.instance.currentUser?.email ?? '').trim().toLowerCase();
        
        final activeDocs = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final s = (data['status'] as String? ?? 'assigned').toLowerCase();
          
          final assignedTo = (data['assignedTo'] ?? data['assignedToEmail'] ?? data['userEmail'] ?? data['email'] ?? '').toString().trim().toLowerCase();
          
          bool isMine = AppSession().isSuperAdmin || (userEmail.isNotEmpty && (assignedTo == userEmail || assignedTo.contains(userEmail) || userEmail.contains(assignedTo)));
          if (!isMine) return false;
          
          return s == 'assigned' || s == 'todo' || s == 'in_progress' || s == 'overdue' || s == 'pending';
        }).toList();

        // Show most recent 4
        final displayDocs = activeDocs.take(4).toList();
        final activeCount = activeDocs.length;

        return _buildCardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('MY TASKS',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF6B7280),
                          letterSpacing: 0.5)),
                  Text(
                    activeCount == 0
                        ? 'No active tasks'
                        : '$activeCount active',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: activeCount > 0
                          ? const Color(0xFF5C5CFF)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                ))
              else if (displayDocs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('No active tasks right now',
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                  ),
                )
              else
                ...List.generate(displayDocs.length, (i) {
                  final doc = displayDocs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final title = data['title'] as String? ?? 'Untitled Task';
                  final status = data['status'] as String? ?? 'assigned';

                  DateTime? parseDate(dynamic d) {
                    if (d == null) return null;
                    if (d is Timestamp) return d.toDate();
                    if (d is DateTime) return d;
                    if (d is String) return DateTime.tryParse(d);
                    return null;
                  }

                  final dueDate = parseDate(data['dueDate']);
                  final timerStart = parseDate(data['timerStart']);

                  String dueDateStr = 'No due date';
                  if (dueDate != null) {
                    dueDateStr =
                        'Due ${DateFormat('MMM d, yyyy').format(dueDate)}';
                  }

                  String? timerStr;
                  if (status == 'in_progress' && timerStart != null) {
                    timerStr = _formatTaskDuration(timerStart);
                  }

                  Color badgeColor;
                  Color badgeBg;
                  String badgeText;
                  switch (status) {
                    case 'in_progress':
                      badgeColor = const Color(0xFFD97706);
                      badgeBg = const Color(0xFFFFFBEB);
                      badgeText = 'In Progress';
                      break;
                    case 'overdue':
                      badgeColor = const Color(0xFFEF4444);
                      badgeBg = const Color(0xFFFEF2F2);
                      badgeText = 'Overdue';
                      break;
                    default:
                      badgeColor = const Color(0xFF5C5CFF);
                      badgeBg = const Color(0xFFEEF2FF);
                      badgeText = 'Assigned';
                  }

                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1F2937)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(dueDateStr,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF),
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          if (timerStr != null) ...[
                            Text(timerStr,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF9CA3AF))),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: badgeColor.withOpacity(0.3)),
                            ),
                            child: Text(badgeText,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: badgeColor)),
                          ),
                        ],
                      ),
                      if (i < displayDocs.length - 1)
                        const Divider(height: 28, color: Color(0xFFF3F4F6)),
                    ],
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Color _deptColor(String dept) {
    const palette = [
      Color(0xFF5C5CFF),
      Color(0xFFA855F7),
      Color(0xFFF59E0B),
      Color(0xFF10B981),
      Color(0xFFEC4899),
      Color(0xFF1D4ED8),
      Color(0xFFEF4444),
      Color(0xFF0EA5E9),
      Color(0xFF14B8A6),
    ];
    return palette[dept.hashCode.abs() % palette.length];
  }

  Widget _buildDepartmentHeadcountCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _employeesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildCardContainer(
            child: const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _buildCardContainer(
            child: const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No employee data yet.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
              ),
            ),
          );
        }

        // Group by department – fall back to 'Unknown' like team_departments_view
        final Map<String, int> deptCount = {};
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          // Skip admin accounts
          if ((data['role'] as String?)?.toLowerCase() == 'admin') continue;
          final dept = ((data['department'] as String?)?.trim().isEmpty ?? true)
              ? 'Unknown'
              : (data['department'] as String).trim();
          deptCount[dept] = (deptCount[dept] ?? 0) + 1;
        }

        final deptList = deptCount.keys.toList()..sort();
        final maxCount = deptCount.values.fold(0, (a, b) => a > b ? a : b);

        if (deptList.isEmpty) {
          return _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DEPARTMENT HEADCOUNT',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.5)),
                const SizedBox(height: 16),
                const Center(
                  child: Text('No department data found',
                      style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                ),
              ],
            ),
          );
        }

        return _buildCardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('DEPARTMENT HEADCOUNT',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF6B7280),
                          letterSpacing: 0.5)),
                  Text('${docs.length} total',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5C5CFF))),
                ],
              ),
              const SizedBox(height: 16),
              ...List.generate(deptList.length, (i) {
                final dept = deptList[i];
                final count = deptCount[dept]!;
                final color = _deptColor(dept);
                final fraction = maxCount == 0 ? 0.0 : count / maxCount;
                return Padding(
                  padding:
                      EdgeInsets.only(bottom: i < deptList.length - 1 ? 14 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: color, shape: BoxShape.circle)),
                              const SizedBox(width: 10),
                              Text(dept,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF374151),
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Text(count.toString(),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: color)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction,
                          backgroundColor: const Color(0xFFF3F4F6),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              color.withOpacity(0.6)),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Widget _buildRecentActivityCard() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _recentActivityStream,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        return _buildCardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('RECENT ACTIVITY',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6B7280),
                      letterSpacing: 0.5)),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                ))
              else if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('No recent activity',
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                  ),
                )
              else
                ...List.generate(items.length, (i) {
                  final item = items[i];
                  final dt = item['_ts'] as DateTime?;
                  final timeStr = dt != null ? _timeAgo(dt) : '';
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                                color: item['bg'] as Color,
                                shape: BoxShape.circle),
                            child: Icon(item['icon'] as IconData,
                                color: item['color'] as Color, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['text'] as String,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1F2937))),
                                if (timeStr.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(timeStr,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF9CA3AF),
                                          fontWeight: FontWeight.w500)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (i < items.length - 1)
                        const Divider(height: 24, color: Color(0xFFF3F4F6)),
                    ],
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x0A000000), offset: Offset(0, -4), blurRadius: 16)
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.home_outlined, Icons.home_filled, 'Home'),
              _navItem(
                  1, Icons.access_time, Icons.access_time_filled, 'Attendance'),
              
              if (AppSession().hasPermission('create-announcement') || AppSession().hasPermission('create-task'))
                GestureDetector(
                  onTap: () => setState(() => _isCreatingAnnouncement = true),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFF5C5CFF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Color(0x405C5CFF),
                            blurRadius: 12,
                            offset: Offset(0, 4))
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                )
              else 
                const SizedBox(width: 48),

              _navItem(2, Icons.calendar_today_outlined, Icons.calendar_today,
                  'Leave'),
              _navItem(3, Icons.more_horiz, Icons.more_horiz, 'More'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
      int index, IconData outlineIcon, IconData filledIcon, String label) {
    bool isSelected = _bottomNavIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _bottomNavIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? filledIcon : outlineIcon,
              size: 24,
              color: isSelected
                  ? const Color(0xFF5C5CFF)
                  : const Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF5C5CFF)
                    : const Color(0xFF9CA3AF),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _AdminApprovalReviewScreen extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final DocumentReference docRef;

  const _AdminApprovalReviewScreen({
    Key? key,
    required this.initialData,
    required this.docRef,
  }) : super(key: key);

  @override
  State<_AdminApprovalReviewScreen> createState() => _AdminApprovalReviewScreenState();
}

class _AdminApprovalReviewScreenState extends State<_AdminApprovalReviewScreen> {
  late Map<String, dynamic> data;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    data = Map<String, dynamic>.from(widget.initialData);
  }

  void _updateApprovalStatus(String status) async {
    setState(() => _isLoading = true);
    try {
      await widget.docRef.update({
        'status': status,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request ${status == 'approved' ? 'approved' : 'rejected'} successfully'),
            backgroundColor: status == 'approved' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ),
        );
        Navigator.of(context).pop(); // Go back to Approvals list
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating request: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = data['title']?.toString() ?? 'Request Review';
    String type = data['type']?.toString() ?? 'Request';
    String details = data['details']?.toString() ?? '-';
    String appliedStr = data['appliedOn']?.toString() ?? '-';
    String status = data['status']?.toString() ?? 'Pending';
    String empName = data['empName']?.toString() ?? 'Employee';
    String empDept = data['empDept']?.toString() ?? 'Department';
    String initials = data['initials']?.toString() ?? 'E';
    Color avatarColor = data['avatarColor'] != null
        ? Color(data['avatarColor'] as int)
        : const Color(0xFF8B5CF6);

    Color statusBgColor = const Color(0xFFFFFBEB);
    Color statusBorderColor = const Color(0xFFFDE68A);
    Color statusTextColor = const Color(0xFFB45309);

    if (status.toLowerCase() == 'approved') {
      statusBgColor = const Color(0xFFECFDF5);
      statusBorderColor = const Color(0xFF86EFAC);
      statusTextColor = const Color(0xFF047857);
    } else if (status.toLowerCase() == 'rejected') {
      statusBgColor = const Color(0xFFFEF2F2);
      statusBorderColor = const Color(0xFFFCA5A5);
      statusTextColor = const Color(0xFFB91C1C);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 12, top: 4, bottom: 4),
                      child: Icon(Icons.arrow_back_ios_new,
                          size: 18, color: Color(0xFF1F2937)),
                    ),
                  ),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937))),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Employee Profile Header Card
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFFE2E8F0), width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: avatarColor,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        empName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        empDept,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusBgColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: statusBorderColor, width: 1),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: statusTextColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Request Details Card
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: const Color(0xFFF1F5F9), width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'REQUEST DETAILS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _buildDetailRow('Type', type),
                                const Divider(
                                    height: 32,
                                    thickness: 1,
                                    color: Color(0xFFF1F5F9)),
                                _buildDetailRow('Title', title),
                                const Divider(
                                    height: 32,
                                    thickness: 1,
                                    color: Color(0xFFF1F5F9)),
                                _buildDetailRow('Details', details),
                                const Divider(
                                    height: 32,
                                    thickness: 1,
                                    color: Color(0xFFF1F5F9)),
                                _buildDetailRow('Applied On', appliedStr),
                                const Divider(
                                    height: 32,
                                    thickness: 1,
                                    color: Color(0xFFF1F5F9)),
                                _buildDetailRow('Status', status),
                              ],
                            ),
                          ),
                          if (status.toLowerCase() == 'pending') ...[
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: const Color(0xFF86EFAC),
                                          width: 1.5),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () =>
                                            _updateApprovalStatus('approved'),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 16),
                                          child: Center(
                                            child: Text(
                                              'Approve',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF047857),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: const Color(0xFFFCA5A5),
                                          width: 1.5),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () =>
                                            _updateApprovalStatus('rejected'),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 16),
                                          child: Center(
                                            child: Text(
                                              'Reject',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFFB91C1C),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B))),
        const SizedBox(width: 16),
        Expanded(
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937))),
        ),
      ],
    );
  }
}

