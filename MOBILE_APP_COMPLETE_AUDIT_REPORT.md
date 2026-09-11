# MOBILE APP COMPLETE AUDIT REPORT
**Platform:** Attendance HRMS / Workzi SaaS Platform  
**Target Inspected:** Mobile App (Flutter Client — Android / iOS / Web / Desktop)  
**Auditor:** Antigravity AI Senior Architecture & Security Auditor  
**Audit Date:** September 2, 2026  
**Status:** COMPLETE — NO MODIFICATIONS MADE  

---

## 1. Executive Summary

A comprehensive architectural, security, multi-tenancy, data contract, and code audit was conducted on the Mobile Application of the Attendance HRMS / Workzi SaaS platform located at `attendence-management-app/`.

### Key Findings Summary:
1. **Firebase Configuration & Tenant Identity:**  
   The Mobile App is configured to communicate with the exact same Firebase Project ID (`attendence-a56dd`). It resolves tenant organizations through the `approved_users/{email}` global mapping, identical in principle to the Web App.
2. **Critical Security Vulnerability (Multi-Tenant Data Leak):**  
   `FirestoreService.allAttendanceRecordsCol` and `FirestoreService.allLeaveRequestsQuery` execute unfiltered `collectionGroup` queries across the global Firestore database. Because `firestore.rules` permits any user with a manager role to read `attendance` and `leave_requests` collection groups without enforcing `companyId == userCompanyId()`, client devices physically download raw attendance and leave records from **ALL organizations** in the multi-tenant database. The Mobile App relies solely on in-memory Dart filtering (`FirestoreService.isDocInCurrentCompany`) on the user's phone.
3. **Open Security Rules on New Architecture:**  
   Under `match /organizations/{orgId}`, rule `match /{document=**} { allow read, write: if isSignedIn(); }` permits **any signed-in user across the entire Firebase project** to read and write any document in any organization.
4. **Critical Data Destruction Bug (Tasks):**  
   In `lib/widgets/tasks_tab_view.dart` (lines 133–142), inside the Flutter `build()` rendering lifecycle, the app executes `doc.reference.delete()` for any task whose title matches a hardcoded list of demo titles (`Review Q3 Policy Updates`, `Prepare Onboarding Docs`, etc.). If a production organization creates a legitimate task matching any of these names, the Mobile App **silently deletes it from Firestore** immediately upon opening the Tasks tab.
5. **Broken Cross-Platform Data Contracts:**
   - **Attendance:** Web App expects a **triple-write** pattern (`organizations/{cid}/users/{email}/attendance/{date}`, `organizations/{cid}/attendance/{email}_{date}`, and `users/{email}/attendance/{date}`). Mobile writes **only** to `organizations/{cid}/users/{email}/attendance/{date}`. Field schemas, timestamp formats, and status values diverge significantly (e.g., Mobile hardcodes lowercase `'present'` on check-in AND check-out; never sets `'Completed'`, `'Checked Out'`, or `'Late'`).
   - **Leave Requests:** Web App stores leave requests at root-level organization subcollection `organizations/{cid}/leave_requests/{id}`. Mobile writes leave requests to the user-scoped subcollection `organizations/{cid}/users/{email}/leave_requests/{id}`. Web and Mobile **cannot see each other's leave requests**.
6. **Permission Matrix Incompatibility:**  
   Mobile expects keys `'announcements'` and `'calendar'`, which are absent from the Web App's 17-key matrix. When the Web App saves matrix updates, non-admin mobile users lose access to the Announcements and Calendar tabs. Several permissions (`create-announcement`, `my-space`, `create-task`, `team-approval`, `dashboard-approval`) are completely ignored in the Mobile UI.
7. **Compilation Errors in Unused / Dead Files:**  
   `lib/screens/employee/announcement_tab.dart` has missing imports for `FirebaseAuth` and `AppSession`. `lib/screens/register_screen.dart` imports `organization_setup_screen.dart`, which does not exist on disk.

---

## 2. Mobile App Technology Stack

- **Framework:** Flutter (Channel stable, SDK `>=3.0.0 <4.0.0`)
- **Primary Language:** Dart 3.x
- **Firebase Plugins:**
  - `firebase_core: ^2.27.0`
  - `firebase_auth: ^4.17.0`
  - `cloud_firestore: ^4.15.0`
  - `firebase_storage: ^11.7.7`
  - `firebase_messaging: ^14.9.4`
- **Location & Geolocation Engine:**
  - `geolocator: ^10.1.0` (High-accuracy background GPS tracking, distance calculation, geofencing)
  - `geocoding: ^3.0.0` (Reverse geocoding LatLng to physical addresses)
  - `google_maps_flutter: ^2.10.0` (Interactive Google Maps rendering)
- **Push & Local Notifications:**
  - `flutter_local_notifications: ^21.0.0` (Local heads-up reminders, foreground banners)
  - `onesignal_flutter: ^5.5.4` (Targeted push notifications via external user tags)
  - `timezone: ^0.11.0` (Local timezone scheduling for shift checkout reminders)
- **UI & Analytics Componentry:**
  - `google_nav_bar: ^5.0.6` (Floating bottom navigation bar)
  - `table_calendar: ^3.1.3` (Interactive calendar view)
  - `fl_chart: ^0.69.2` (Attendance trend charts, bar graphs, donut charts)
  - `percent_indicator: ^4.2.5` (Circular & linear attendance progress indicators)
  - `slide_to_act: ^2.0.2` (Slide-to-check-in / slide-to-check-out component)
  - `animate_do: ^4.2.0`, `shimmer: ^3.0.0`, `lottie: ^3.3.2`, `confetti: ^0.8.0`
- **File Export & Reporting:**
  - `csv: ^7.1.0` (Tabular CSV generation)
  - `path_provider: ^2.1.5` & `share_plus: ^10.0.0` (Mobile file saving and OS share sheet)
  - HTML Blob downloader bridge for Flutter Web (`file_export_helper_web.dart`)
- **State Management:**
  - In-Memory Singleton: `AppSession()` (`lib/utils/app_session.dart`)
  - Direct Firestore Reactive Streams: `StreamBuilder` and `StreamSubscription`

---

## 3. Complete Project Structure

```
attendence-management-app/
├── android/                        # Android native platform project
├── assets/                         # Graphic assets and application logo
├── ios/                            # iOS native platform project
├── lib/
│   ├── features/                   # Feature-specific legacy/modular code
│   │   ├── attendance/
│   │   │   ├── screens/
│   │   │   │   ├── admin/
│   │   │   │   │   └── admin_attendance_tab.dart
│   │   │   │   └── manager/
│   │   │   │       ├── attendance_correction_screen.dart
│   │   │   │       ├── attendance_status_detail_screen.dart
│   │   │   │       ├── employee_workspace_*.dart (4 files)
│   │   │   │       ├── employees_on_leave_screen.dart
│   │   │   │       ├── late_adjustment_review_screen.dart
│   │   │   │       ├── late_early_exit_screen.dart
│   │   │   │       ├── manager_attendance_*.dart (4 files)
│   │   │   │       ├── monthly_absence_screen.dart
│   │   │   │       ├── overtime_report_screen.dart
│   │   │   │       └── top_employees_screen.dart
│   │   ├── auth/screens/manager/   # Password setup & OTP verification screens
│   │   ├── employee_management/    # Employee directory, add employee screens
│   │   ├── leave_management/       # Admin & manager leave approval screens
│   │   └── settings/screens/       # Manager profile, company settings
│   ├── screens/
│   │   ├── attendance/             # Attendance screens & analytics tabs
│   │   ├── common/                 # Password recovery & notification settings
│   │   ├── employee/               # Employee home, attendance, leave, tasks, calendar, profile
│   │   │   ├── analytics_tab/      # Analytics, monthly summary, work hours breakdown
│   │   │   └── requests_tab/       # Correction form & request detail screens
│   │   ├── more/                   # Settings, security, privacy, FAQ, support, UniversalMoreTab
│   │   ├── profile/                # UniversalProfileScreen
│   │   ├── announcement_detail_screen.dart
│   │   ├── auth_wrapper.dart       # Core session bootstrap & auth state router
│   │   ├── create_announcement_wizard.dart
│   │   ├── department_detail_screen.dart
│   │   ├── employee_profile_detail_screen.dart
│   │   ├── employee_tasks_detail_screen.dart
│   │   ├── login_screen.dart
│   │   ├── pre_login_screen.dart
│   │   ├── profile_screen.dart
│   │   ├── register_screen.dart    # Broken: imports non-existent setup screen
│   │   ├── report_detail_screen.dart
│   │   ├── splash_screen.dart
│   │   └── unified_dashboard_screen.dart # Central 4,252-line unified app screen
│   ├── theme/
│   │   └── app_theme.dart          # Palette tokens, typography, radii, shadows
│   ├── utils/
│   │   ├── app_session.dart        # Global in-memory user session singleton
│   │   ├── file_export_helper.dart # Cross-platform CSV exporter conditional export
│   │   ├── firestore_service.dart  # Static repository for Firestore paths & queries
│   │   ├── location_service.dart   # Geolocator stream & reverse geocoder
│   │   ├── message_helper.dart     # SnackBar & modal alert helpers
│   │   ├── notification_helper.dart# Notification dispatch engine
│   │   ├── notification_service.dart# FCM, OneSignal, LocalNotification coordinator
│   │   └── onesignal_helper.dart   # OneSignal REST API client
│   ├── widgets/
│   │   ├── announcements_tab_view.dart
│   │   ├── calendar_tab_view.dart
│   │   ├── full_map_screen.dart
│   │   ├── live_attendance_builder.dart
│   │   ├── location_map_card.dart
│   │   ├── notification_action.dart
│   │   ├── org_overview_tab.dart
│   │   ├── org_policies_tab.dart
│   │   ├── org_reports_tab.dart
│   │   ├── tasks_tab_view.dart
│   │   ├── team_departments_view.dart
│   │   ├── team_feed_view.dart
│   │   ├── team_members_view.dart
│   │   └── team_tasks_view.dart
│   ├── firebase_options.dart       # Generated Firebase project options
│   └── main.dart                   # Application bootstrap
├── firestore.rules                 # Cloud Firestore security rules
├── firestore.indexes.json          # Collection Group & Composite index definitions
└── pubspec.yaml                    # Dart package dependencies & assets
```

---

## 2. Mobile App Technology Stack

- **Framework:** Flutter (Channel stable, SDK `>=3.0.0 <4.0.0`)
- **Primary Language:** Dart 3.x
- **Firebase Plugins:**
  - `firebase_core: ^2.27.0`
  - `firebase_auth: ^4.17.0`
  - `cloud_firestore: ^4.15.0`
  - `firebase_storage: ^11.7.7`
  - `firebase_messaging: ^14.9.4`
- **Location & Geolocation Engine:**
  - `geolocator: ^10.1.0` (High-accuracy background GPS tracking, distance calculation, geofencing)
  - `geocoding: ^3.0.0` (Reverse geocoding LatLng to physical addresses)
  - `google_maps_flutter: ^2.10.0` (Interactive Google Maps rendering)
- **Push & Local Notifications:**
  - `flutter_local_notifications: ^21.0.0` (Local heads-up reminders, foreground banners)
  - `onesignal_flutter: ^5.5.4` (Targeted push notifications via external user tags)
  - `timezone: ^0.11.0` (Local timezone scheduling for shift checkout reminders)
- **UI & Analytics Componentry:**
  - `google_nav_bar: ^5.0.6` (Floating bottom navigation bar)
  - `table_calendar: ^3.1.3` (Interactive calendar view)
  - `fl_chart: ^0.69.2` (Attendance trend charts, bar graphs, donut charts)
  - `percent_indicator: ^4.2.5` (Circular & linear attendance progress indicators)
  - `slide_to_act: ^2.0.2` (Slide-to-check-in / slide-to-check-out component)
  - `animate_do: ^4.2.0`, `shimmer: ^3.0.0`, `lottie: ^3.3.2`, `confetti: ^0.8.0`
- **File Export & Reporting:**
  - `csv: ^7.1.0` (Tabular CSV generation)
  - `path_provider: ^2.1.5` & `share_plus: ^10.0.0` (Mobile file saving and OS share sheet)
  - HTML Blob downloader bridge for Flutter Web (`file_export_helper_web.dart`)
- **State Management:**
  - In-Memory Singleton: `AppSession()` (`lib/utils/app_session.dart`)
  - Direct Firestore Reactive Streams: `StreamBuilder` and `StreamSubscription`

---

## 3. Complete Project Structure

(See Section 3 above)

---

## 4. Firebase Configuration

- **Firebase Project ID:** `attendence-a56dd` (Verified across Android, iOS, Web, macOS, Windows configurations in `lib/firebase_options.dart`).
- **Web App ID:** `1:128720778231:web:59c324092177f445ebf4f2`
- **Android App ID:** `1:128720778231:android:3f04d1930c29df68ebf4f2`
- **iOS App ID:** `1:128720778231:ios:77f19b389ff49657ebf4f2` (Bundle ID: `com.example.app1`)
- **Storage Bucket:** `attendence-a56dd.firebasestorage.app`
- **Firestore Database Instance:** Default Database (`(default)`)
- **Firebase Auth Configuration:** Email/Password authentication active. No Google Sign-In SDK configured in `pubspec.yaml` or `login_screen.dart`.

---

## 5. Authentication Architecture

### Authentication Pipeline (`lib/screens/auth_wrapper.dart` & `lib/screens/login_screen.dart`):
1. **Entry Point:** `main.dart` initializes Firebase and displays `AuthWrapper()`.
2. **Auth State Listener:** `FirebaseAuth.instance.authStateChanges()` monitors login status.
3. **Session Population Flow:**
   - When a user logs in, `_loadSession(user)` executes.
   - It reads `approved_users/{email.toLowerCase()}`.
   - If found:
     - Extracts `role` (lowercased; default `'employee'`).
     - Extracts `companyId` (checking `d['orgId'] ?? d['companyId']`).
     - If `orgId` is present, attempts `_loadSessionFromOrganizations(user, email, role, orgId)`.
     - Otherwise falls back to legacy path: reads `organizations/{companyId}` and `organizations/{companyId}/users/{email}`.
   - If not found in `approved_users`:
     - Fallback query: Searches `organizations` where `managerEmail == email`. If found, assigns role `'manager'`, sets `companyId`, and auto-provisions `approved_users/{email}`!
     - Fallback query: Searches global `users` collection where `email == email`.
4. **AppSession Initialization:**  
   Populates `AppSession().populate(...)` with `uid`, `email`, `role`, `companyId`, `companyName`, `shiftStartTime`, `shiftEndTime`, `gracePeriod`, `paidLeavesPerYear`, `featurePermissions`, `userName`, `department`, `officeLat`, `officeLng`, `allowedRadius`.
5. **Location Check Gate:**  
   Calls `_checkAndRequestLocation()`. If GPS permission is missing or disabled, blocks navigation and presents `LocationRequiredScreen`.
6. **Main Routing:**  
   Once location is validated, routes to `UnifiedDashboardScreen()`.

---

## 6. Multi-Tenant Architecture

### Tenant Identifier:
- Represented by `companyId` / `orgId`.
- Read from `approved_users/{email}` (`d['companyId']` or `d['orgId']`).
- Stored exclusively in the in-memory singleton `AppSession().companyId`.

### Multi-Tenant Isolation & Critical Vulnerabilities:
1. **Unfiltered Collection Group Queries (CRITICAL LEAK):**
   In `lib/utils/firestore_service.dart`:
   - `allAttendanceRecordsCol` returns `_db.collectionGroup('attendance')` with **NO tenant filter**.
   - `allLeaveRequestsQuery` returns `_db.collectionGroup('leave_requests')` with **NO tenant filter**.
   - `allOvertimeRequestsQuery` returns `_db.collectionGroup('overtime_requests')` with **NO tenant filter**.
   
   In `unified_dashboard_screen.dart` (lines 405–418) and `report_detail_screen.dart` (lines 684–690):
   ```dart
   FirestoreService.allAttendanceRecordsCol.snapshots().listen((snap) {
     statAttDocs = snap.docs
         .where((d) => FirestoreService.isDocInCurrentCompany(d))
         .toList();
     emitStats();
   });
   ```
   **Security Consequence:** Because `firestore.rules` (lines 394–400) permits any user with a manager role to read `attendance` without checking `companyId`, **managers receive attendance and leave documents belonging to competing tenant companies across the entire database**, filtering them only in client Dart memory.
2. **Hardcoded Fallback Organization ID:**  
   In `lib/widgets/calendar_tab_view.dart` (line 547):
   ```dart
   .doc(AppSession().companyId ?? 'default')
   ```
   If `companyId` is null, queries the hardcoded document `'default'` instead of failing safely.

---

## 7. User/Employee Architecture

### User Identity Mapping:
- **Firebase Auth:** UID (`request.auth.uid`)
- **Tenant Document Path:** `organizations/{companyId}/users/{email.toLowerCase()}`
- **Fallback / Alternative Path in Code:** `organizations/{orgId}/members/{uid}` (used in `_loadSessionFromOrganizations`)

### Fields Loaded in Employee Profile:
- `name` / `fullName`: String
- `email`: String (lowercase)
- `role`: `'super_admin'` | `'hr_admin'` | `'manager'` | `'employee'`
- `department`: String
- `designation`: String (read in screens, not stored in `AppSession`)
- `phone` / `contactNumber`: String
- `status`: String (`'approved'` | `'pending'`)
- `paidLeaveBalance`: Number

### Employee Data Retrieval:
`FirestoreService.userStreamByEmail(email)` listens to `organizations/{companyId}/users/{email.toLowerCase()}`. If document does not exist by ID, executes fallback query `.where('email', isEqualTo: normalizedEmail)`.

---

## 8. Role Architecture

### Role Values Recognized in Mobile Code:
- `super_admin` / `superadmin`
- `hr_admin` / `hradmin`
- `manager`
- `employee`

### Discrepancy with Web App:
- **Web App:** Recognizes `admin` as an alias for `super_admin`.
- **Mobile App:** `AppSession.isSuperAdmin` checks:
  ```dart
  bool get isSuperAdmin => role?.toLowerCase() == 'super_admin' || role?.toLowerCase() == 'superadmin';
  ```
  If an organization creator signs in with `role: 'admin'`, `isSuperAdmin` returns **`false`**, `hasAdminAccess` returns **`false`**, and all Super Admin permission bypasses in the app fail.

---

## 9. Permission Matrix Audit

### Key Questions Answered:

| # | Audit Question | Codebase Answer | Status |
|---|---|---|---|
| 1 | Does mobile read `organizations/{companyId}.featurePermissions`? | **YES.** Loaded in `AuthWrapper._loadSession` and `_loadSessionFromOrganizations`. | MATCH |
| 2 | Does it use the SAME Firebase project? | **YES.** `attendence-a56dd`. | MATCH |
| 3 | Does it use the SAME `companyId`? | **YES.** Loaded from `approved_users/{email}`. | MATCH |
| 4 | Does it use the SAME role values? | **PARTIAL.** Handles `super_admin`, `hr_admin`, `manager`, `employee`, but **fails to alias `admin`**. | IMPORTANT DIFFERENCE |
| 5 | Does it use the SAME permission keys? | **NO.** Mobile adds `'announcements'` and `'calendar'`. Ignores `'create-announcement'`, `'my-space'`, `'create-task'`, `'team-approval'`, `'dashboard-approval'`. | BROKEN COMPATIBILITY |
| 6 | Does it react when the Permission Matrix is changed in Web? | **NO (in legacy mode) / PARTIAL (in org mode).** Legacy path does not listen to `companyDoc`. In org mode, updates `AppSession.featurePermissions` but doesn't re-index active sub-tabs. | BROKEN COMPATIBILITY |
| 7 | Is permission data realtime? | **NO** for legacy organizations; **YES** for self-registered orgs via `_orgSubscription`. | IMPORTANT DIFFERENCE |
| 8 | Does mobile hide/disable features according to permissions? | **PARTIALLY.** Only hides sub-tabs in `UnifiedDashboardScreen` and tiles in `UniversalMoreTab`. | MINOR DIFFERENCE |
| 9 | Are mobile actions protected or only UI-hidden? | **UI-HIDDEN ONLY.** No repository, button handler, or service method enforces permissions before writes. Security rules do not check matrix permissions. | IMPORTANT DIFFERENCE |
| 10 | Any hardcoded role/permission logic conflicting with Firestore? | **YES.** Multiple widgets bypass permissions using `isSuperAdmin`, `isManager`, or `isAdminOrManager`. `AnnouncementsTabView` hardcodes `isAdmin: true`. | IMPORTANT DIFFERENCE |
| 11 | Does mobile cache permissions locally? | **IN-MEMORY ONLY.** Stored in `AppSession().featurePermissions`. No persistent local storage (`shared_preferences`, `hive`). | MINOR DIFFERENCE |
| 12 | Can stale permissions remain after Web changes matrix? | **YES.** For users loaded via `_loadSession`, stale permissions persist for the entire app session until logout. | BROKEN COMPATIBILITY |

---

## 10. Firestore Collection Inventory

(See Section 10 in main report)

---

## 11. Complete Firestore Data Contracts

### 1. Attendance Document Contract
- **Document Path:** `organizations/{companyId}/users/{email}/attendance/{yyyy-MM-dd}`
- **Fields Written by Mobile (`lib/screens/unified_dashboard_screen.dart:175-188`):**
  ```json
  {
    "companyId": "string",
    "userId": "string (email)",
    "status": "string ('present')",
    "workMode": "string ('office' | 'wfh')",
    "checkIn": "Timestamp",
    "checkInLocation": "string (reverse geocoded address)",
    "checkOut": "Timestamp (on checkout)",
    "checkOutLocation": "string (on checkout)",
    "date": "Timestamp (midnight)",
    "recordDate": "string ('yyyy-MM-dd')"
  }
  ```
- **Web App Contract Discrepancies:**
  - Missing paths: `organizations/{cid}/attendance/{email}_{date}` and `users/{email}/attendance/{date}`.
  - Missing fields: `email`, `workEmail`, `employeeId`, `name`, `checkInTime`, `checkInTimestamp`, `checkOutTime`, `checkOutTimestamp`, `hoursWorked`, `hoursNum`, `shift`, `location`, `coordinates`, `orgCoordinates`, `orgRadius`, `distanceMeters`, `isOutside`, `updatedAt`, `autoCheckedOut`.
  - Status value is always `'present'` (lowercase). Never writes `'Present'`, `'Late'`, `'WFH'`, `'Completed'`, or `'Checked Out'`.

### 2. Leave Request Document Contract
- **Document Path:** `organizations/{companyId}/users/{email}/leave_requests/{autoId}`
- **Fields Written by Mobile (`lib/screens/employee/apply_leave_screen.dart:102-116`):**
  ```json
  {
    "companyId": "string",
    "userId": "string (Auth UID)",
    "userEmail": "string",
    "userName": "string",
    "department": "string",
    "leaveType": "string ('Sick Leave' | 'Casual Leave' | 'Annual Leave' | 'Comp Off')",
    "fromDate": "DateTime (converted by Firestore to Timestamp)",
    "toDate": "DateTime (converted by Firestore to Timestamp)",
    "durationInDays": "int",
    "reason": "string",
    "status": "string ('pending')",
    "requestDate": "FieldValue.serverTimestamp()",
    "senderRole": "string"
  }
  ```
- **Web App Contract Discrepancy:** Web stores leave at `organizations/{companyId}/leave_requests/{id}`.

### 3. Task Document Contract
- **Document Path:** `organizations/{companyId}/tasks/{taskId}`
- **Fields Read/Updated by Mobile (`lib/widgets/tasks_tab_view.dart` & `task_detail_screen.dart`):**
  ```json
  {
    "companyId": "string",
    "title": "string",
    "description": "string",
    "status": "string ('assigned' | 'in_progress' | 'completed' | 'overdue' | 'archived')",
    "priority": "string ('High' | 'Medium' | 'Low')",
    "dueDate": "Timestamp | string",
    "assignedTo": "string (email or name)",
    "assigneeEmail": "string",
    "assigneeName": "string",
    "comments": "array of maps",
    "completedAt": "FieldValue.serverTimestamp()",
    "startedAt": "FieldValue.serverTimestamp()"
  }
  ```

### 4. Announcement Document Contract
- **Document Paths:** `organizations/{companyId}/announcements/{id}` & `organizations/{companyId}/team_announcements/{id}`
- **Fields Written by Mobile (`lib/screens/create_announcement_wizard.dart:100-112`):**
  ```json
  {
    "companyId": "string",
    "title": "string",
    "message": "string",
    "category": "string",
    "priority": "string ('Normal' | 'Important' | 'Urgent')",
    "audience": "string ('all' | 'custom')",
    "authorName": "string",
    "authorRole": "string",
    "authorEmail": "string",
    "targetTeams": "array of strings",
    "targetEmails": "array of strings",
    "notifyOthers": "string",
    "createdAt": "FieldValue.serverTimestamp()"
  }
  ```

---

## 12. Attendance Architecture

- **Check-In Logic:** Evaluates user coordinates using `LocationService().getLocation()`. Calculates distance from office using `Geolocator.distanceBetween(...)`. Determines `isInside = distance <= allowedRadius`. Sets `workMode: isInside ? 'office' : 'wfh'`. Writes to `organizations/{companyId}/users/{email}/attendance/{yyyy-MM-dd}` with merge option.
- **Check-Out Logic:** Re-evaluates location, writes `checkOut: Timestamp.fromDate(now)` and `checkOutLocation`. Cancels scheduled local checkout reminder.
- **Auto-Checkout:** **NONE.** No background service, WorkManager, or Cloud Function trigger exists in the mobile app for auto-checkout.
- **Offline Behavior:** Relies entirely on Cloud Firestore offline cache. If network is offline, Firestore sets write locally and syncs upon reconnection.
- **Realtime Listeners:** Single employee: `userAttendanceCol(email).doc(today).snapshots()`. Organization wide: `LiveAttendanceBuilder` opens individual realtime listeners for every single employee in the company (`N+1` listeners).

---

## 13. Geofencing / Location Architecture

- **Service File:** `lib/utils/location_service.dart` (Singleton)
- **Permissions:** Requests `LocationPermission.whileInUse` or `always` via `geolocator`.
- **Accuracy Strategy:** Checks `getLastKnownPosition()`; uses if `< 30 seconds old` and accuracy `< 100m`. Falls back to `getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: 10s)`. Secondary fallback to `LocationAccuracy.medium`.
- **Coordinates Resolution:** Reads `officeLat` and `officeLng` from `AppSession()`. Populated from `organizations/{companyId}` (`location.latitude`, `locations[0].latitude`, or root `latitude`).
- **Allowed Radius:** Default `500` meters; overrides with `allowedRadius` field from company document.
- **Multi-Branch Handling:** **Fails.** Mobile picks only the **first entry** from `locations` array and ignores employee-specific branch assignments.

---

## 14. Leave Architecture

- **Path Mismatch:** Mobile writes to `organizations/{companyId}/users/{email}/leave_requests/{id}`, while Web expects `organizations/{companyId}/leave_requests/{id}`.
- **Approval Workflow:** Managed in `lib/features/leave_management/screens/manager/leave_approval_screen.dart` and `UnifiedDashboardScreen` (Approvals tab). Listens via `collectionGroup('leave_requests')`. Extracts employee email from document parent reference path. Updates `status: 'approved' | 'rejected'`, `reviewComment`, `approvedBy`, `reviewedAt`.
- **Cross-Platform Visibility:** **Broken.** Leaves applied on Web do not show in Mobile; leaves applied on Mobile do not show in Web.

---

## 15. Task Architecture

- **Read/Update Path:** `organizations/{companyId}/tasks/{id}` (Matches Web).
- **Task Creation:** **Absent in Mobile.** No UI exists to create new tasks.
- **Task Updating:** Users can change task status (`'assigned'`, `'in_progress'`, `'completed'`), post comments, and record task start/stop timers.
- **Assignee Resolution:** Checks 10 fallback field permutations (`assigneeEmail`, `assignedToEmail`, `employeeEmail`, `email`, `assignee`, `assigneeName`, `assignedTo`, `userEmail`, `userId`, `assignedToUid`).

---

## 16. Notification Architecture

- **Channels:** FCM (foreground listener in `NotificationService`), OneSignal (player tagged by email; push sent via HTTP POST to OneSignal REST API), Local Notifications (Android channel `high_importance_channel`).
- **Collections Used:** User notifications: `organizations/{companyId}/users/{email}/notifications`; Global notifications: `organizations/{companyId}/global_notifications`.
- **Data Pollution Bug:** `change_password_screen.dart`, `notification_settings_screen.dart`, `privacy_settings_screen.dart`, and `security_settings_screen.dart` store user settings documents (`'settings'`, `'privacy'`, `'security'`) inside the `notifications` subcollection!

---

## 17. Realtime Listener Inventory

(Detailed in Section 17 of main report)

---

## 18. Local Storage / Cache Inventory

- **Persistent Key-Value Storage:** **NONE.** (`shared_preferences`, `hive`, `isar`, `sqflite` are not present).
- **In-Memory State:** `AppSession` singleton holding session variables until app terminates.
- **Location Cache:** `LocationService._cachedPosition`, expires after 2 seconds.
- **SDK Caches:** Firebase Auth token persistence; Firestore offline SQLite cache.

---

## 19. Complete Feature Inventory

(Detailed in Section 19 of main report)

---

## 20. Business Workflows

(Detailed in Section 20 of main report)

---

## 21. Security Audit

1. **Client-Side Permission Enforcement Only:** Mobile checks `AppSession().hasPermission` inside Flutter `Widget.build()` methods to toggle UI visibility. No server-side enforcement of feature permissions in Firebase Security Rules.
2. **Firestore Security Rules Exposure:** Under `organizations/{orgId}`, rule `match /{document=**} { allow read, write: if isSignedIn(); }` completely bypasses tenant isolation. Under `collectionGroup('attendance')` and `collectionGroup('leave_requests')`, managers can read records across all tenants.
3. **OneSignal REST API Key Vulnerability:** `lib/utils/onesignal_helper.dart` calls the OneSignal HTTP REST endpoint directly from client application.

---

## 22. Data Consistency Audit

1. **Timestamp Inconsistencies:** Attendance uses `checkIn` (Timestamp), leave uses `requestDate` (`FieldValue.serverTimestamp()`), announcements use `createdAt` (Timestamp), and tasks use `dueDate` (mixed Timestamp / String).
2. **Field Naming Fragmentation:** Task assignee: 10 different field variations handled across widgets. User doc: `name` vs `fullName`, `phone` vs `contactNumber`. Attendance: `checkIn` vs `checkInTime` vs `firstCheckin`.
3. **Status Capitalization:** Attendance writes lowercase `'present'`. Tasks write lowercase `'assigned'`, `'in_progress'`, `'completed'`. Leave writes lowercase `'pending'`, `'approved'`, `'rejected'`. Web App contract expects capitalized `'Present'`, `'Late'`, `'WFH'`, `'Completed'`, `'Checked Out'`.

---

## 23. Performance Audit

1. **N+1 Firestore Stream Subscriptions in `LiveAttendanceBuilder`:** Spawns an independent Firestore realtime stream for every employee in the company.
2. **Global Collection Group Downloads:** `UnifiedDashboardScreen` downloads all attendance and leave records across the entire database to compute dashboard statistics in memory.
3. **High Frequency 1-Second Rebuild Timers:** Both `UnifiedDashboardScreen` and `TasksTabView` run `Timer.periodic(Duration(seconds: 1))` triggering frequent full-widget tree rebuilds.

---

## 24. Bugs Found

(See detailed Bug Inventory & Specifications in Section 24 of main report)

---

## 25. Critical Issues

1. **Production Task Deletion Bug (BUG-01):** Active deletion of Firestore task documents during widget build.
2. **Multi-Tenant Attendance & Leave Data Leak (BUG-02):** Unfiltered collection group queries exposing competing tenant data to mobile clients.
3. **Wide-Open Security Rules (BUG-03):** Global read/write access for any authenticated user under `/organizations/{orgId}`.
4. **Broken Attendance Sync (BUG-09):** Absence of triple-write pattern and hardcoded lowercase `'present'` status breaks cross-platform attendance records.
5. **Broken Leave Sync (BUG-10):** Disconnected path hierarchies isolate mobile leave applications from web administrative dashboards.

---

## 26. Cross-Platform Compatibility Matrix

(See full 36-point matrix in Section 26 of main report)

---

## 27. Web vs Mobile Differences

(Detailed in Section 27 of main report)

---

## 28. Items That Must Be Changed Later

(Detailed in Section 28 of main report)

---

## 29. Items That Should NOT Be Changed

(Detailed in Section 29 of main report)

---

## 30. Recommended Fix Order

(Detailed in Section 30 of main report)

---

```
================================================================================
AUDIT COMPLETE — NO MODIFICATIONS MADE
================================================================================
```
