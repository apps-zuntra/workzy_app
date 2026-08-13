import 'package:flutter/material.dart';

class FaqsScreen extends StatefulWidget {
  const FaqsScreen({super.key});

  @override
  State<FaqsScreen> createState() => _FaqsScreenState();
}

class _FaqsScreenState extends State<FaqsScreen> {
  final Map<String, bool> _expandedState = {};

  final List<Map<String, dynamic>> _faqCategories = [
    {
      'category': 'ATTENDANCE ISSUES',
      'items': [
        {
          'q': 'How do I correct a missing check-out?',
          'a': 'Go to Attendance -> Requests tab or tap the center (+) button on your navbar and select "Raise Correction" to submit a correction request to your manager.'
        },
        {
          'q': 'Why is my check-in showing as Late?',
          'a': 'Check-ins logged past your scheduled shift start time (with company grace period) are automatically marked as Late according to company attendance policy.'
        },
      ]
    },
    {
      'category': 'LEAVE POLICY',
      'items': [
        {
          'q': 'How do I apply for leave?',
          'a': 'Tap the (+) button on bottom navbar and choose "Apply Leave" or navigate to the Leave tab and click "Apply Leave". Fill in leave type, dates, and reason.'
        },
        {
          'q': 'Can I cancel an approved leave?',
          'a': 'Yes, you can request leave cancellation from your Leave History list before the start date. It will be sent to HR/Manager for review.'
        },
      ]
    },
    {
      'category': 'TASK MANAGEMENT',
      'items': [
        {
          'q': 'How do I update task progress?',
          'a': 'Open My Tasks on your home dashboard or tasks tab, tap on your assigned task, and use the progress slider or complete button.'
        },
      ]
    },
    {
      'category': 'PAYROLL QUERIES',
      'items': [
        {
          'q': 'When is salary credited?',
          'a': 'Monthly salary is processed and credited on the last working day of every calendar month. Payslips are updated in Documents section.'
        },
      ]
    },
    {
      'category': 'PROFILE UPDATE',
      'items': [
        {
          'q': 'How do I update my contact information?',
          'a': 'Go to More -> Profile -> Edit Profile to update phone number, address, or emergency contacts.'
        },
      ]
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1F2937), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'FAQs',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        centerTitle: false,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _faqCategories.length,
        itemBuilder: (context, catIndex) {
          final category = _faqCategories[catIndex];
          final String catTitle = category['category'];
          final List<Map<String, String>> items = List<Map<String, String>>.from(category['items']);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF3F4F6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    catTitle,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(items.length, (i) {
                    final item = items[i];
                    final String question = item['q']!;
                    final String answer = item['a']!;
                    final bool isExpanded = _expandedState[question] ?? false;

                    return Column(
                      children: [
                        if (i > 0) const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _expandedState[question] = !isExpanded;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        question,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      isExpanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_right_rounded,
                                      color: const Color(0xFF9CA3AF),
                                      size: 20,
                                    ),
                                  ],
                                ),
                                if (isExpanded) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    answer,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF4B5563),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
