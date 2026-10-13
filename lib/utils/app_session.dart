/// AppSession â€” Global in-memory state for the authenticated user.
///
/// After a successful login, [companyId], [role], and company location
/// are stored here so every screen can access them without re-querying
/// Firestore on every navigation push.
class AppSession {
  // â”€â”€ Singleton â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static final AppSession _instance = AppSession._internal();
  factory AppSession() => _instance;
  AppSession._internal();

  // â”€â”€ Authenticated User Info â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String? uid;
  String? email;
  String? role; // 'manager' | 'employee'
  String? companyId;
  String? companyName;
  String? userName;
  String? department;
  String? get userDepartment => department;
  bool isDemoMode = false;

  // â”€â”€ Company Office Location (fetched from organizations doc) â”€â”€â”€â”€â”€â”€â”€â”€â”€
  double? officeLat;
  double? officeLng;

  /// Radius (in metres) within which check-in is allowed.
  double allowedRadius = 500;

  /// Shift start time in HH:mm format (24h)
  String shiftStartTime = "09:00";

  /// Shift end time in HH:mm format (24h)
  String shiftEndTime = "18:00";

  /// Grace period in minutes
  int gracePeriod = 15;

  /// Annual paid leave entitlement per employee (days)
  int paidLeavesPerYear = 12;

  // ————————————————————————————————————————————————————————————————

  bool get isSuperAdmin => role?.toLowerCase() == 'super_admin' || role?.toLowerCase() == 'superadmin';
  bool get isHrAdmin => role?.toLowerCase() == 'hr_admin' || role?.toLowerCase() == 'hradmin';
  bool get isManager => role?.toLowerCase() == 'manager';
  bool get isEmployee => role?.toLowerCase() == 'employee';

  /// Grouped getter for administrative dashboards (Super Admin & HR Admin)
  bool get hasAdminAccess => isSuperAdmin || isHrAdmin;

  /// Clean display title for the 4 webapp roles
  String get displayRole {
    final r = (role ?? 'employee').toLowerCase().replaceAll('_', ' ');
    if (r == 'super admin' || r == 'superadmin') return 'Super Admin';
    if (r == 'hr admin' || r == 'hradmin') return 'HR Admin';
    if (r == 'manager') return 'Manager';
    if (r == 'employee') return 'Employee';
    return r.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }

  /// Dynamic Permissions Matrix fetched from Firestore
  Map<String, dynamic> featurePermissions = {};

  bool hasPermission(String featureKey) {
    if (isSuperAdmin) {
      // Super Admin automatically gets full access and settings
      return true;
    }

    final roleKey = role?.toLowerCase() ?? 'employee';
    final List<dynamic> allowed = featurePermissions[roleKey] ?? _getDefaultPermissionsFor(roleKey);
    return allowed.contains(featureKey);
  }

  List<String> _getDefaultPermissionsFor(String roleKey) {
    final r = roleKey.toLowerCase();
    if (r == 'super_admin' || r == 'superadmin') {
      return ["my-space", "dashboard-approval", "dashboard-leave", "team", "team-approval", "create-announcement", "announcements", "calendar", "organization", "attendance", "approve-attendance", "leave", "approve-leave", "tasks", "create-task", "documents", "settings", "support", "approvals", "reports"];
    } else if (r == 'hr_admin' || r == 'hradmin') {
      return ["my-space", "dashboard-approval", "dashboard-leave", "team", "team-approval", "create-announcement", "announcements", "calendar", "organization", "attendance", "approve-attendance", "leave", "approve-leave", "tasks", "create-task", "documents", "support", "approvals", "reports"];
    } else if (r == 'manager') {
      return ["my-space", "dashboard-approval", "dashboard-leave", "team", "team-approval", "create-announcement", "announcements", "calendar", "organization", "attendance", "approve-attendance", "leave", "approve-leave", "tasks", "create-task", "documents", "support", "approvals", "reports"];
    } else {
      return ["my-space", "dashboard-leave", "attendance", "leave", "tasks", "documents", "support", "announcements", "calendar"];
    }
  }

  /// True only when the session has been fully populated after login.
  bool get isReady =>
      uid != null && companyId != null && role != null;

  /// Update office location from Firestore organization/company map
  void updateOfficeLocationFromMap(Map<dynamic, dynamic>? data) {
    if (data == null) return;
    double? parseDouble(dynamic v) =>
        v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

    double? foundLat;
    double? foundLng;

    // 1. Try 'locations' list (array of branch maps)
    final locations = data['locations'];
    if (locations is List && locations.isNotEmpty) {
      for (final item in locations) {
        if (item is Map) {
          final lat = parseDouble(item['latitude'] ?? item['lat']);
          final lng = parseDouble(item['longitude'] ?? item['lng']);
          if (lat != null && lng != null) {
            foundLat = lat;
            foundLng = lng;
            break;
          }
        }
      }
    }

    // 2. Try 'location' object (singular map)
    if (foundLat == null || foundLng == null) {
      final loc = data['location'];
      if (loc is Map) {
        foundLat = parseDouble(loc['latitude'] ?? loc['lat']);
        foundLng = parseDouble(loc['longitude'] ?? loc['lng']);
      }
    }

    // 3. Try root-level fields: latitude / longitude or lat / lng
    if (foundLat == null || foundLng == null) {
      foundLat = parseDouble(data['latitude'] ?? data['lat']);
      foundLng = parseDouble(data['longitude'] ?? data['lng']);
    }

    if (foundLat != null && foundLng != null) {
      officeLat = foundLat;
      officeLng = foundLng;
    }

    if (data.containsKey('allowedRadius')) {
      allowedRadius = parseDouble(data['allowedRadius']) ?? 500;
    }
  }

  /// Populate the session after successful login + approved_users look-up.
  void populate({
    required String uid,
    required String email,
    required String role,
    required String companyId,
    String? companyName,
    String? userName,
    String? department,
    double? officeLat,
    double? officeLng,
    double? allowedRadius,
    String? shiftStartTime,
    String? shiftEndTime,
    int? gracePeriod,
    int? paidLeavesPerYear,
    Map<String, dynamic>? featurePermissions,
  }) {
    this.uid = uid;
    this.email = email;
    this.role = role;
    this.companyId = companyId;
    this.companyName = companyName;
    this.userName = userName;
    this.department = department;
    if (officeLat != null) this.officeLat = officeLat;
    if (officeLng != null) this.officeLng = officeLng;
    if (allowedRadius != null) this.allowedRadius = allowedRadius;
    if (shiftStartTime != null) this.shiftStartTime = shiftStartTime;
    if (shiftEndTime != null) this.shiftEndTime = shiftEndTime;
    if (gracePeriod != null) this.gracePeriod = gracePeriod;
    if (paidLeavesPerYear != null) this.paidLeavesPerYear = paidLeavesPerYear;
    if (featurePermissions != null) this.featurePermissions = featurePermissions;
  }

  /// Clear everything on sign-out.
  void clear() {
    uid = null;
    email = null;
    role = null;
    companyId = null;
    companyName = null;
    userName = null;
    officeLat = null;
    officeLng = null;
    allowedRadius = 500;
    shiftStartTime = "09:00";
    shiftEndTime = "18:00";
    gracePeriod = 15;
    paidLeavesPerYear = 12;
    featurePermissions = {};
    isDemoMode = false;
  }
}
