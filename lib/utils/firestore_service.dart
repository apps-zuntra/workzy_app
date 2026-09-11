import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'app_session.dart';

/// FirestoreService â€” Single source of truth for all Firestore collection
/// and document references.
///
/// **Company-Centric Model:**
/// All operational data (employees, attendance, leave requests, etc.) is stored
/// as subcollections under `organizations/{companyId}/...`.
/// This ensures that when you view a company in the Firestore console, you can
/// see all related employees, attendance, and leave data nested under it.
///
/// Never call `FirebaseFirestore.instance.collection(...)` directly in UI code
/// â€” use the static helpers here instead.
class FirestoreService {
  FirestoreService._(); // No instances needed â€” all members are static.

  static final _db = FirebaseFirestore.instance;

  // â”€â”€ Convenience accessor â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static String get _cid {
    final id = AppSession().companyId;
    assert(id != null, 'AppSession.companyId is null â€” was login completed?');
    return id!;
  }

  /// Public getter for the current tenant's companyId
  static String get companyId => _cid;

  /// Strict multi-tenant guard: returns true ONLY if [doc] belongs to the active company.
  /// Checks both explicit 'companyId' field and document path structure.
  static bool isDocInCurrentCompany(DocumentSnapshot doc) {
    final currentCid = (AppSession().companyId ?? '').trim().toLowerCase();
    if (currentCid.isEmpty) return false;

    final data = doc.data() as Map<String, dynamic>? ?? {};
    final docCid = (data['companyId'] as String?)?.trim().toLowerCase();
    final path = doc.reference.path.toLowerCase();

    // 1. If document explicitly specifies a companyId, it MUST match the active company
    if (docCid != null && docCid.isNotEmpty) {
      return docCid == currentCid;
    }

    // 2. Otherwise, document MUST be stored within organizations/{currentCid}/...
    return path.contains('/organizations/$currentCid/') ||
        path.startsWith('organizations/$currentCid/');
  }

  // â”€â”€ Global (cross-company) refs â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// `approved_users/{email}` â€” global login / company mapping.
  static DocumentReference<Map<String, dynamic>> approvedUserDoc(
          String email) =>
      _db.collection('approved_users').doc(email.toLowerCase());

  /// `organizations/{companyId}` â€” company master document.
  static DocumentReference<Map<String, dynamic>> companyDoc(
          [String? companyId]) =>
      _db.collection('organizations').doc(companyId ?? _cid);

  /// `organization_setup_requests/{requestId}` â€” pre-login organization setup submissions.
  static CollectionReference<Map<String, dynamic>>
      get organizationSetupRequestsCol =>
          _db.collection('organization_setup_requests');

  // â”€â”€ New: Organizations (self-registration flow) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Used when a company admin registers directly via the app.
  // Structure: organizations/{orgId}/members/{uid}
  //                                /departments/{deptId}

  /// `organizations` â€” top-level collection for self-registered companies.
  static CollectionReference<Map<String, dynamic>> get orgCol =>
      _db.collection('organizations');

  /// `organizations/{orgId}` â€” company master document.
  static DocumentReference<Map<String, dynamic>> orgDoc(String orgId) =>
      orgCol.doc(orgId);

  /// `organizations/{orgId}/members` â€” all admin/employee profiles for this org.
  static CollectionReference<Map<String, dynamic>> orgMembersCol(
          String orgId) =>
      orgDoc(orgId).collection('members');

  /// `organizations/{orgId}/members/{uid}` â€” a single member's profile.
  static DocumentReference<Map<String, dynamic>> orgMemberDoc(
          String orgId, String uid) =>
      orgMembersCol(orgId).doc(uid);

  /// `organizations/{orgId}/departments` â€” department list for this org.
  static CollectionReference<Map<String, dynamic>> orgDepartmentsCol(
          String orgId) =>
      orgDoc(orgId).collection('departments');

  /// `organizations/{orgId}/departments/{deptId}`
  static DocumentReference<Map<String, dynamic>> orgDepartmentDoc(
          String orgId, String deptId) =>
      orgDepartmentsCol(orgId).doc(deptId);

  /// `organizations/{orgId}/holidays`
  static CollectionReference<Map<String, dynamic>> orgHolidaysCol(
          String orgId) =>
      orgDoc(orgId).collection('holidays');

  /// `organizations/{orgId}/shifts`
  static CollectionReference<Map<String, dynamic>> orgShiftsCol(String orgId) =>
      orgDoc(orgId).collection('shifts');

  /// `organizations/{orgId}/policies`
  static CollectionReference<Map<String, dynamic>> orgPoliciesCol(
          String orgId) =>
      orgDoc(orgId).collection('policies');

  /// `organizations/{orgId}/policies/{policyId}`
  static DocumentReference<Map<String, dynamic>> orgPolicyDoc(
          String orgId, String policyId) =>
      orgPoliciesCol(orgId).doc(policyId);

  // â”€â”€ Company-Scoped Subcollections â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // All operational data lives UNDER the company document so that
  // Firestore console shows everything nested per company.

  /// `/organizations/{companyId}/users` â€” user profiles
  static CollectionReference<Map<String, dynamic>> get employeesCol =>
      companyDoc().collection('users');

  /// Filtered query for approved employees in the current company
  static Query<Map<String, dynamic>> get companyUsersQuery =>
      employeesCol.where('status', isEqualTo: 'approved');

  /// `/organizations/{companyId}/employees/{email}`
  static DocumentReference<Map<String, dynamic>> employeeDoc(String email) =>
      employeesCol.doc(email.toLowerCase());

  /// Get a stream of the employee document by email.
  /// Primary lookup is by document ID (email), with a fallback query.
  static Stream<DocumentSnapshot<Map<String, dynamic>>> userStreamByEmail(
      String email) {
    final normalizedEmail = email.toLowerCase();
    return employeesCol.doc(normalizedEmail).snapshots().asyncMap((doc) async {
      if (doc.exists) return doc;

      // Fallback: search for a document where the 'email' FIELD matches
      try {
        final qs = await employeesCol
            .where('email', isEqualTo: normalizedEmail)
            .limit(1)
            .get();
        if (qs.docs.isNotEmpty) return qs.docs.first;
      } catch (e) {
        debugPrint('userStreamByEmail fallback query failed: $e');
      }
      return doc; // Return the empty doc if fallback fails
    });
  }

  /// `/organizations/{companyId}/users/{email}/attendance`
  static CollectionReference<Map<String, dynamic>> userAttendanceCol(
          String email) =>
      employeeDoc(email).collection('attendance');

  /// `/organizations/{companyId}/users/{email}/leave_requests`
  static CollectionReference<Map<String, dynamic>> userLeaveRequestsCol(
          String email) =>
      employeeDoc(email).collection('leave_requests');

  /// `/organizations/{companyId}/users/{email}/notifications`
  static CollectionReference<Map<String, dynamic>> userNotificationsCol(
          String email) =>
      employeeDoc(email).collection('notifications');

  /// `/organizations/{companyId}/users/{email}/overtime_requests`
  static CollectionReference<Map<String, dynamic>> userOvertimeRequestsCol(
          String email) =>
      employeeDoc(email).collection('overtime_requests');

  // â”€â”€ Collection Group Queries (Manager Access) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // These allow managers to query all records across all employees in the company.

  /// All attendance records for the current company via collection group query.
  static Query<Map<String, dynamic>> get allAttendanceRecordsCol {
    return _db.collectionGroup('attendance');
  }

  /// All leave requests for the current company via collection group query.
  static Query<Map<String, dynamic>> get allLeaveRequestsQuery {
    return _db.collectionGroup('leave_requests');
  }

  /// All overtime requests for the current company via collection group query.
  static Query<Map<String, dynamic>> get allOvertimeRequestsQuery {
    return _db.collectionGroup('overtime_requests');
  }

  /// All attendance corrections for the current company via collection group query (if sub-collections) or flat
  static Query<Map<String, dynamic>> get allAttendanceIssuesQuery {
    return companyDoc().collection('attendance_issues');
  }

  /// All shift requests for the current company
  static Query<Map<String, dynamic>> get allShiftRequestsQuery {
    return companyDoc().collection('shift_requests');
  }

  /// All department transfer requests for the current company
  static Query<Map<String, dynamic>> get allDepartmentRequestsQuery {
    return companyDoc().collection('department_requests');
  }

  /// All task extension/approval requests for the current company
  static Query<Map<String, dynamic>> get allTaskRequestsQuery {
    return companyDoc().collection('task_requests');
  }

  /// All notifications for the current company via collection group query.
  static Query<Map<String, dynamic>> get allNotificationsQuery {
    return _db
        .collectionGroup('notifications')
        .where('companyId', isEqualTo: _cid);
  }

  /// All tasks for the current company via collection group query.
  static Query<Map<String, dynamic>> get allTasksQuery {
    return _db.collectionGroup('tasks').where('companyId', isEqualTo: _cid);
  }

  /// Alias for backward compatibility
  static Query<Map<String, dynamic>> get companyLeaveRequestsQuery =>
      allLeaveRequestsQuery;

  // â”€â”€ Global Company Notifications â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // These are notifications meant for the entire company, not a specific user.

  /// `/organizations/{companyId}/global_notifications`
  static CollectionReference<Map<String, dynamic>> get globalNotificationsCol =>
      companyDoc().collection('global_notifications');

  /// `/organizations/{companyId}/announcements`
  static CollectionReference<Map<String, dynamic>> get announcementsCol =>
      orgDoc(_cid).collection('announcements');

  /// `/organizations/{companyId}/team_announcements`
  static CollectionReference<Map<String, dynamic>> get teamAnnouncementsCol =>
      orgDoc(_cid).collection('team_announcements');

  /// `/organizations/{companyId}/company_calendar`
  static CollectionReference<Map<String, dynamic>> get companyCalendarCol =>
      companyDoc().collection('company_calendar');

  /// `/organizations/{companyId}/policies`
  static CollectionReference<Map<String, dynamic>> get policiesCol =>
      companyDoc().collection('policies');

  /// `/organizations/{companyId}/tasks`
  static CollectionReference<Map<String, dynamic>> get tasksCol =>
      companyDoc().collection('tasks');

  /// `/organizations/{companyId}/team_feed` — unified feed (was feed_posts, now same as teamFeedCol)
  static CollectionReference<Map<String, dynamic>> get feedPostsCol =>
      companyDoc().collection('team_feed');

  /// `/organizations/{companyId}/team_feed`
  static CollectionReference<Map<String, dynamic>> get teamFeedCol =>
      companyDoc().collection('team_feed');

  // â”€â”€ Legacy / Flat Collections (To be removed after migration) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// @deprecated Use [userAttendanceCol]
  static CollectionReference<Map<String, dynamic>> get attendanceCol =>
      companyDoc().collection('attendance');

  /// @deprecated Use [userAttendanceCol]
  static CollectionReference<Map<String, dynamic>> attendanceRecordsCol(
      String uidOrEmail) {
    // Attempting to maintain some compatibility during transition
    if (uidOrEmail.contains('@')) return userAttendanceCol(uidOrEmail);
    return attendanceCol.doc(uidOrEmail).collection('records');
  }

  /// @deprecated Use [userLeaveRequestsCol]
  static CollectionReference<Map<String, dynamic>> get leaveRequestsCol =>
      companyDoc().collection('leave_requests');

  /// @deprecated Use [userNotificationsCol]
  static CollectionReference<Map<String, dynamic>> get notificationsCol =>
      companyDoc().collection('notifications');

  /// @deprecated Use [userOvertimeRequestsCol]
  static CollectionReference<Map<String, dynamic>> get overtimeRequestsCol =>
      companyDoc().collection('overtime_requests');

  // â”€â”€ Legacy Compatibility Aliases â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // These aliases keep existing UI code working without mass renames.

  /// Alias for `employeesCol` â€” backward compatible with old `usersCol` calls
  static CollectionReference<Map<String, dynamic>> get usersCol => employeesCol;

  /// Alias for `employeeDoc(uid)` â€” backward compatible
  static DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      employeesCol.doc(uid);

  /// Alias for `employeeDoc(email)` â€” backward compatible
  static DocumentReference<Map<String, dynamic>> userDocByEmail(String email) =>
      employeesCol.doc(email.toLowerCase());

  /// Find a company where the given email is the manager.
  /// This is used for login fallback when the manager isn't in 'approved_users'.
  /// Find a company where the given email is the manager.
  /// This is used for login fallback when the manager isn't in 'approved_users'.
  static Future<QuerySnapshot<Map<String, dynamic>>> findCompanyByManagerEmail(
          String email) =>
      _db
          .collection('organizations')
          .where('managerEmail', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();

  /// When an attendance correction request is approved, update the employee's attendance record for that day.
  static Future<void> applyAttendanceCorrectionApproval({
    required Map<String, dynamic> requestData,
  }) async {
    try {
      final email = (requestData['userId'] ??
              requestData['userEmail'] ??
              requestData['email'] ??
              '')
          .toString();
      if (email.isEmpty) return;

      final attDateVal = requestData['attendanceDate'] ??
          requestData['date'] ??
          requestData['requestedDate'];
      DateTime? baseDate;
      if (attDateVal is Timestamp) baseDate = attDateVal.toDate();
      if (attDateVal is String) baseDate = DateTime.tryParse(attDateVal);

      if (baseDate == null) return;

      final docId = DateFormat('yyyy-MM-dd').format(baseDate);

      Timestamp? parseTime(dynamic rawTime, DateTime date) {
        if (rawTime is Timestamp) return rawTime;
        if (rawTime is String && rawTime.isNotEmpty) {
          if (rawTime.contains(':')) {
            final parts = rawTime.split(':');
            final h = int.tryParse(parts[0].trim()) ?? 0;
            final m = int.tryParse(parts[1].trim()) ?? 0;
            return Timestamp.fromDate(
                DateTime(date.year, date.month, date.day, h, m));
          }
          final parsed = DateTime.tryParse(rawTime);
          if (parsed != null) return Timestamp.fromDate(parsed);
        }
        return null;
      }

      final checkInTs = parseTime(
          requestData['correctedCheckIn'] ??
              requestData['checkInTime'] ??
              requestData['checkIn'],
          baseDate);
      final checkOutTs = parseTime(
          requestData['correctedCheckOut'] ??
              requestData['checkOutTime'] ??
              requestData['checkOut'],
          baseDate);

      final Map<String, dynamic> updatePayload = {
        'status': 'present',
        'date': Timestamp.fromDate(
            DateTime(baseDate.year, baseDate.month, baseDate.day)),
        'recordDate': docId,
        'isCorrection': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (checkInTs != null) {
        updatePayload['checkIn'] = checkInTs;
        updatePayload['checkInTime'] = checkInTs;
      }
      if (checkOutTs != null) {
        updatePayload['checkOut'] = checkOutTs;
        updatePayload['checkOutTime'] = checkOutTs;
      }

      await userAttendanceCol(email)
          .doc(docId)
          .set(updatePayload, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error applying attendance correction timing: $e');
    }
  }
}
