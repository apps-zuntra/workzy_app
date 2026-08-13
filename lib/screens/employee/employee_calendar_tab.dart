import 'package:flutter/material.dart';
import 'package:attendance_app/widgets/calendar_tab_view.dart';

class EmployeeCalendarTab extends StatelessWidget {
  const EmployeeCalendarTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Calendar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: const CalendarTabView(),
    );
  }
}
