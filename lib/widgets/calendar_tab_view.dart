import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';

class CalendarEvent {
  final String title;
  final String type; // 'my_leave', 'team_leave', 'holidays', 'birthdays', 'anniversaries', 'events', 'shift_schedule', 'training'
  final DateTime date;
  final String? status;
  final String? checkIn;
  final String? checkOut;
  final String? hours;
  final String? notes;

  CalendarEvent({
    required this.title,
    required this.type,
    required this.date,
    this.status,
    this.checkIn,
    this.checkOut,
    this.hours,
    this.notes,
  });
}

class CalendarTabView extends StatefulWidget {
  const CalendarTabView({super.key});

  @override
  State<CalendarTabView> createState() => _CalendarTabViewState();
}

class _CalendarTabViewState extends State<CalendarTabView> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final Set<String> _activeFilters = {
    'my_leave',
    'holidays',
    'events',
    'attendance',
  };
  String? _selectedDepartment;
  String? _selectedBranch;

  final Map<String, Color> _filterColors = {
    'my_leave': const Color(0xFF5C5CFF),
    'team_leave': const Color(0xFFA855F7),
    'holidays': const Color(0xFFEF4444),
    'birthdays': const Color(0xFFEAB308),
    'anniversaries': const Color(0xFFEC4899),
    'events': const Color(0xFF22C55E),
    'shift_schedule': const Color(0xFF1E3A8A),
    'training': const Color(0xFF14B8A6),
  };

  final Map<String, String> _filterLabels = {
    'my_leave': 'My Leave',
    'team_leave': 'Team Leave',
    'holidays': 'Holidays',
    'birthdays': 'Birthdays',
    'anniversaries': 'Anniversaries',
    'events': 'Events',
    'shift_schedule': 'Shift Schedule',
    'training': 'Training',
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime? _parseDate(dynamic d) {
    if (d == null) return null;
    if (d is Timestamp) return d.toDate();
    if (d is DateTime) return d;
    if (d is String) return DateTime.tryParse(d);
    return null;
  }

  String _formatTime(dynamic timeVal) {
    if (timeVal == null) return '-';
    if (timeVal is Timestamp) {
      return DateFormat('h:mm a').format(timeVal.toDate());
    }
    if (timeVal is DateTime) {
      return DateFormat('h:mm a').format(timeVal);
    }
    if (timeVal is String) {
      final parsed = DateTime.tryParse(timeVal);
      if (parsed != null) return DateFormat('h:mm a').format(parsed);
      return timeVal;
    }
    return timeVal.toString();
  }

  String _calculateHours(dynamic ci, dynamic co) {
    final start = _parseDate(ci);
    final end = _parseDate(co);
    if (start != null && end != null) {
      final diff = end.difference(start);
      final hrs = diff.inHours;
      final mins = diff.inMinutes.remainder(60);
      return '${hrs}h ${mins}m';
    }
    return '-';
  }

  Map<DateTime, List<CalendarEvent>> _buildEventMap({
    required List<QueryDocumentSnapshot> leaves,
    required List<QueryDocumentSnapshot> attendanceRecords,
    required List<QueryDocumentSnapshot> holidays,
  }) {
    final Map<DateTime, List<CalendarEvent>> map = {};
    final currentUserEmail = (AppSession().email ?? '').toLowerCase().trim();
    final currentUserUid = AppSession().uid;
    final currentCompanyId = AppSession().companyId;

    void addEvent(DateTime date, CalendarEvent event) {
      final norm = _normalizeDate(date);
      map.putIfAbsent(norm, () => []).add(event);
    }

    // 1. Process Approved Leaves
    for (var doc in leaves) {
      final data = doc.data() as Map<String, dynamic>;
      final docCid = data['companyId'] as String?;
      if (docCid != null && currentCompanyId != null && docCid != currentCompanyId) {
        continue;
      }

      // Department Filtering
      if (_selectedDepartment != null) {
        final dept = (data['department'] ?? data['dept'] ?? '').toString().toLowerCase().trim();
        if (dept != _selectedDepartment!.toLowerCase().trim()) continue;
      }

      final status = (data['status'] ?? '').toString().toLowerCase();
      if (status == 'approved') {
        final email = (data['applicantEmail'] ?? data['employeeEmail'] ?? data['email'] ?? '').toString().toLowerCase().trim();
        final uid = data['userId'] ?? data['uid'] ?? '';
        final isMine = (currentUserEmail.isNotEmpty && email == currentUserEmail) ||
            (currentUserUid != null && uid == currentUserUid);
        
        final type = isMine ? 'my_leave' : 'team_leave';

        if (_activeFilters.contains(type)) {
          final from = _parseDate(data['fromDate'] ?? data['startDate'] ?? data['from']);
          final to = _parseDate(data['toDate'] ?? data['endDate'] ?? data['to']) ?? from;
          final leaveType = (data['leaveType'] ?? data['type'] ?? 'Leave').toString();

          if (from != null) {
            DateTime current = from;
            final totalDays = to != null ? to.difference(from).inDays + 1 : 1;
            int dayCount = 1;
            while (!current.isAfter(to ?? from)) {
              addEvent(
                current,
                CalendarEvent(
                  title: '$leaveType (Approved)',
                  type: type,
                  date: current,
                  status: 'Leave',
                  notes: 'Day $dayCount of $totalDays',
                ),
              );
              current = current.add(const Duration(days: 1));
              dayCount++;
            }
          }
        }
      }
    }

    // 2. Process Attendance Records
    for (var doc in attendanceRecords) {
      final data = doc.data() as Map<String, dynamic>;
      final docCid = data['companyId'] as String?;
      if (docCid != null && currentCompanyId != null && docCid != currentCompanyId) {
        continue;
      }

      // Department Filtering
      if (_selectedDepartment != null) {
        final dept = (data['department'] ?? data['dept'] ?? '').toString().toLowerCase().trim();
        if (dept != _selectedDepartment!.toLowerCase().trim()) continue;
      }

      final docEmail = (data['userEmail'] ?? data['email'] ?? doc.reference.parent.parent?.id ?? '').toString().toLowerCase().trim();
      if (currentUserEmail.isNotEmpty && docEmail.isNotEmpty && docEmail != currentUserEmail) continue;

      final date = _parseDate(data['date'] ?? data['recordDate'] ?? data['createdAt'] ?? doc.id);
      if (date != null) {
        final checkInVal = data['checkIn'] ?? data['checkInTime'] ?? data['lastCheckIn'];
        final checkOutVal = data['checkOut'] ?? data['checkOutTime'] ?? data['lastCheckout'];
        final checkInStr = _formatTime(checkInVal);
        final checkOutStr = _formatTime(checkOutVal);
        final hoursStr = _calculateHours(checkInVal, checkOutVal);
        final statusRaw = (data['status'] ?? data['attendanceStatus'] ?? '').toString().toLowerCase();
        final isLate = data['isLate'] == true || statusRaw.contains('late');
        final isWfh = (data['workMode'] ?? '').toString().toLowerCase().contains('wfh');

        final statusLabel = isWfh ? 'WFH' : (isLate ? 'Late' : 'Present');
        final titleLabel = isWfh ? 'Work From Home' : (isLate ? 'Late Check-in' : 'Present');

        addEvent(
          date,
          CalendarEvent(
            title: titleLabel,
            type: 'events',
            date: date,
            status: statusLabel,
            checkIn: checkInStr,
            checkOut: checkOutStr,
            hours: hoursStr,
            notes: (data['reason'] ?? 'Attendance Record').toString(),
          ),
        );
      }
    }

    // 3. Process Holidays
    if (_activeFilters.contains('holidays')) {
      for (var doc in holidays) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Branch Filtering
        if (_selectedBranch != null) {
          final branch = (data['branch'] ?? data['location'] ?? '').toString().toLowerCase().trim();
          if (branch != _selectedBranch!.toLowerCase().trim()) continue;
        }

        final date = _parseDate(data['date']);
        final title = data['name'] ?? data['title'] ?? 'Holiday';
        if (date != null) {
          addEvent(
            date,
            CalendarEvent(
              title: title,
              type: 'holidays',
              date: date,
              status: 'Holiday',
              notes: title,
            ),
          );
        }
      }
    }

    return map;
  }

  void _showFiltersBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Calendar Filters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF3F4F6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF6B7280)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // EVENT TYPES Header
                  const Text(
                    'EVENT TYPES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Wrapped Event Type Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: _filterLabels.keys.map((key) {
                      final label = _filterLabels[key]!;
                      final color = _filterColors[key]!;
                      final isSelected = _activeFilters.contains(key);
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            if (isSelected) {
                              _activeFilters.remove(key);
                            } else {
                              _activeFilters.add(key);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withValues(alpha: 0.08) : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? color : const Color(0xFFE5E7EB),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? color : const Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  // DEPARTMENT Header
                  const Text(
                    'DEPARTMENT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Department Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedDepartment,
                        hint: const Text('Select Department', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                        decoration: const InputDecoration(border: InputBorder.none),
                        items: ['Engineering', 'HR', 'Product', 'Sales', 'Marketing', 'Finance']
                            .map((dept) => DropdownMenuItem(
                                  value: dept,
                                  child: Text(dept, style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937))),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setModalState(() {
                            _selectedDepartment = val;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // BRANCH Header
                  const Text(
                    'BRANCH',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Branch Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedBranch,
                        hint: const Text('Select Branch', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                        decoration: const InputDecoration(border: InputBorder.none),
                        items: ['Headquarters', 'New York Office', 'London Office', 'Remote']
                            .map((branch) => DropdownMenuItem(
                                  value: branch,
                                  child: Text(branch, style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937))),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setModalState(() {
                            _selectedBranch = val;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Action Buttons Row
                  Row(
                    children: [
                      // Clear All Button
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            setModalState(() {
                              _activeFilters.clear();
                              _selectedDepartment = null;
                              _selectedBranch = null;
                            });
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFF3F4F6),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Clear All',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Apply Button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {}); // Rebuild parent list with new selections
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5C5CFF),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Apply',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.leaveRequestsCol.snapshots(),
      builder: (context, leaveSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirestoreService.allAttendanceRecordsCol.snapshots(),
          builder: (context, attSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('organizations')
                  .doc(AppSession().companyId ?? 'default')
                  .collection('holidays')
                  .snapshots(),
              builder: (context, holidaySnap) {
                final leaves = leaveSnap.data?.docs.where((d) => FirestoreService.isDocInCurrentCompany(d)).toList() ?? [];
                final attendance = attSnap.data?.docs.where((d) => FirestoreService.isDocInCurrentCompany(d)).toList() ?? [];
                final holidays = holidaySnap.data?.docs ?? [];

                final eventMap = _buildEventMap(
                  leaves: leaves,
                  attendanceRecords: attendance,
                  holidays: holidays,
                );

                return Container(
                  color: const Color(0xFFF8FAFC),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopControls(),
                        const SizedBox(height: 12),
                        _buildCalendarCard(eventMap),
                        const SizedBox(height: 16),
                        _buildSelectedDayDetailCard(eventMap),
                        const SizedBox(height: 16),
                        _buildLegendCard(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTopControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Month / Week Pill Switcher
        Container(
          height: 38,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              _buildPillButton('Month', CalendarFormat.month),
              _buildPillButton('Week', CalendarFormat.week),
            ],
          ),
        ),
        // Filter Button
        GestureDetector(
          onTap: () => _showFiltersBottomSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.filter_list_rounded, size: 16, color: Color(0xFF5C5CFF)),
                const SizedBox(width: 6),
                Text(
                  'Filters (${_activeFilters.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5C5CFF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPillButton(String label, CalendarFormat format) {
    final isActive = _calendarFormat == format;
    return GestureDetector(
      onTap: () => setState(() => _calendarFormat = format),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF5C5CFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF6B7280),
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarCard(Map<DateTime, List<CalendarEvent>> eventMap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });
        },
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          leftChevronIcon: Icon(Icons.chevron_left_rounded, color: Color(0xFF4B5563), size: 24),
          rightChevronIcon: Icon(Icons.chevron_right_rounded, color: Color(0xFF4B5563), size: 24),
          titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
          headerMargin: EdgeInsets.only(bottom: 12, top: 8),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.w700),
          weekendStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.w700),
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) {
            return _buildCustomDayCell(day, eventMap, isSelected: false);
          },
          selectedBuilder: (context, day, focusedDay) {
            return _buildCustomDayCell(day, eventMap, isSelected: true);
          },
          todayBuilder: (context, day, focusedDay) {
            return _buildCustomDayCell(day, eventMap, isSelected: isSameDay(_selectedDay, day), isToday: true);
          },
        ),
      ),
    );
  }

  Widget _buildCustomDayCell(
    DateTime day,
    Map<DateTime, List<CalendarEvent>> eventMap, {
    required bool isSelected,
    bool isToday = false,
  }) {
    final norm = _normalizeDate(day);
    final events = eventMap[norm] ?? [];

    bool isMyLeave = events.any((e) => e.type == 'my_leave');
    bool isTeamLeave = events.any((e) => e.type == 'team_leave');
    bool isHoliday = events.any((e) => e.type == 'holidays');
    bool isBirthday = events.any((e) => e.type == 'birthdays');
    bool isAnniversary = events.any((e) => e.type == 'anniversaries');
    bool isEvent = events.any((e) => e.type == 'events');
    bool isShift = events.any((e) => e.type == 'shift_schedule');
    bool isTraining = events.any((e) => e.type == 'training');

    Color ringColor = Colors.transparent;
    Color textColor = const Color(0xFF1F2937);
    Color? bottomDotColor;

    if (isMyLeave) {
      ringColor = const Color(0xFF5C5CFF);
      bottomDotColor = const Color(0xFF5C5CFF);
    } else if (isTeamLeave) {
      ringColor = const Color(0xFFA855F7);
    } else if (isHoliday) {
      ringColor = const Color(0xFFEF4444);
      bottomDotColor = const Color(0xFFEF4444);
    } else if (isBirthday) {
      ringColor = const Color(0xFFEAB308);
    } else if (isAnniversary) {
      ringColor = const Color(0xFFEC4899);
    } else if (isEvent) {
      ringColor = const Color(0xFF22C55E);
    } else if (isShift) {
      ringColor = const Color(0xFF1E3A8A);
    } else if (isTraining) {
      ringColor = const Color(0xFF14B8A6);
    }

    if (isSelected) {
      textColor = Colors.white;
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: isSelected
          ? BoxDecoration(
              color: const Color(0xFFEFF6FF), // Soft background highlight
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? const Color(0xFF5C5CFF) : Colors.transparent,
              border: ringColor != Colors.transparent && !isSelected
                  ? Border.all(color: ringColor, width: 1.8)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
          if (bottomDotColor != null)
            Positioned(
              bottom: 2,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : bottomDotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedDayDetailCard(Map<DateTime, List<CalendarEvent>> eventMap) {
    if (_selectedDay == null) return const SizedBox.shrink();

    final norm = _normalizeDate(_selectedDay!);
    final events = eventMap[norm] ?? [];

    final dateTitle = DateFormat('E, MMM d').format(_selectedDay!);
    final dayNumStr = '${_selectedDay!.day}';

    CalendarEvent? primaryEvent;
    if (events.isNotEmpty) {
      primaryEvent = events.first;
    }

    String badgeText = 'Regular';
    Color badgeBg = const Color(0xFFF3F4F6);
    Color badgeFg = const Color(0xFF6B7280);
    Color avatarBg = const Color(0xFFF3F4F6);

    if (primaryEvent != null) {
      final color = _filterColors[primaryEvent.type] ?? const Color(0xFF6B7280);
      badgeText = _filterLabels[primaryEvent.type] ?? 'Event';
      badgeBg = color.withValues(alpha: 0.08);
      badgeFg = color;
      avatarBg = color.withValues(alpha: 0.08);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: avatarBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  dayNumStr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: badgeFg,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: badgeFg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedDay = null),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF6B7280)),
                ),
              ),
            ],
          ),

          // Attendance Metrics Row (Check In / Check Out / Hours)
          if (primaryEvent != null && primaryEvent.type == 'events' && primaryEvent.checkIn != null) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _buildMetricBox(
                    title: primaryEvent.checkIn!,
                    subtitle: 'Check In',
                    bgColor: const Color(0xFFECFDF5),
                    fgColor: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricBox(
                    title: primaryEvent.checkOut ?? '6:15 PM',
                    subtitle: 'Check Out',
                    bgColor: const Color(0xFFEFF6FF),
                    fgColor: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricBox(
                    title: primaryEvent.hours ?? '8h 43m',
                    subtitle: 'Hours',
                    bgColor: const Color(0xFFF5F3FF),
                    fgColor: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
          ],

          // EVENTS Section
          if (events.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'EVENTS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF9CA3AF),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            ...events.map((e) {
              final color = _filterColors[e.type] ?? const Color(0xFF6B7280);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      e.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // NOTES & REMINDERS Section
          const SizedBox(height: 18),
          const Text(
            'NOTES & REMINDERS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          if (primaryEvent != null) ...[
            _buildNoteItem(primaryEvent.title, color: _filterColors[primaryEvent.type] ?? const Color(0xFF6B7280)),
            if (primaryEvent.notes != null) ...[
              const SizedBox(height: 4),
              _buildNoteItem(primaryEvent.notes!, color: const Color(0xFFD97706)),
            ],
          ] else ...[
            _buildNoteItem('Regular working day', color: const Color(0xFF6B7280)),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricBox({
    required String title,
    required String subtitle,
    required Color bgColor,
    required Color fgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: fgColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteItem(String text, {required Color color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.info_outline_rounded, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LEGEND',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: _filterLabels.keys.map((key) {
              final color = _filterColors[key]!;
              final label = _filterLabels[key]!;
              return _buildLegendDot(color, label);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4B5563),
          ),
        ),
      ],
    );
  }
}
