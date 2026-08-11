import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/utils/firestore_service.dart';
import 'package:attendance_app/utils/app_session.dart';

class TeamFeedView extends StatefulWidget {
  const TeamFeedView({super.key});

  @override
  State<TeamFeedView> createState() => _TeamFeedViewState();
}

class _TeamFeedViewState extends State<TeamFeedView> {
  final TextEditingController _postController = TextEditingController();

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

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

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Future<void> _submitPost() async {
    final text = _postController.text.trim();
    if (text.isEmpty) return;

    final userName = AppSession().userName ?? 'Admin';
    final userEmail = AppSession().email ?? 'admin@company.com';

    final postMap = {
      'companyId': FirestoreService.companyId,
      'name': userName,
      'userName': userName,
      'authorName': userName,
      'sender': userName,
      'userEmail': userEmail,
      'authorEmail': userEmail,
      'senderEmail': userEmail,
      'department': AppSession().userDepartment ?? '',
      'text': text,
      'content': text,
      'message': text,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'likes': 0,
      'comments': 0,
    };

    await Future.wait([
      FirestoreService.companyDoc().collection('feed_posts').add(postMap),
      FirestoreService.companyDoc().collection('feed').add(postMap),
      FirestoreService.companyDoc().collection('posts').add(postMap),
    ]);

    _postController.clear();
  }

  Future<void> _toggleStar(DocumentReference docRef, dynamic likedByData) async {
    final myEmail = AppSession().email ?? '';
    if (myEmail.isEmpty) return;

    final List likedBy = List.from(likedByData is List ? likedByData : []);
    final bool isLiked = likedBy.contains(myEmail);

    if (isLiked) {
      likedBy.remove(myEmail);
      await docRef.update({
        'likes': FieldValue.increment(-1),
        'likedBy': likedBy,
      });
    } else {
      likedBy.add(myEmail);
      await docRef.update({
        'likes': FieldValue.increment(1),
        'likedBy': likedBy,
      });
    }
  }

  void _showCommentsBottomSheet(BuildContext context, DocumentReference docRef) {
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Comments',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: docRef.collection('comments').orderBy('timestamp', descending: false).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final commentsDocs = snapshot.data?.docs ?? [];
                    if (commentsDocs.isEmpty) {
                      return const Center(
                        child: Text('No comments yet. Be the first to comment!', style: TextStyle(color: Color(0xFF9CA3AF))),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: commentsDocs.length,
                      itemBuilder: (context, index) {
                        final cData = commentsDocs[index].data() as Map<String, dynamic>;
                        final cName = cData['userName'] ?? 'Member';
                        final cText = cData['text'] ?? '';
                        final ts = cData['timestamp'] as Timestamp?;
                        final cTime = ts != null ? DateFormat('hh:mm a').format(ts.toDate()) : 'Now';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(cName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937))),
                                  Text(cTime, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(cText, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        decoration: const InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: Color(0xFF5C5CFF), size: 20),
                      onPressed: () async {
                        final text = commentController.text.trim();
                        if (text.isEmpty) return;
                        commentController.clear();
                        await docRef.collection('comments').add({
                          'userName': AppSession().userName ?? 'Member',
                          'userEmail': AppSession().email ?? '',
                          'text': text,
                          'timestamp': FieldValue.serverTimestamp(),
                        });
                        await docRef.update({
                          'comments': FieldValue.increment(1),
                          'commentsCount': FieldValue.increment(1),
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserInitials = _getInitials(AppSession().userName ?? 'Admin');

    return Container(
      color: const Color(0xFFF4F6F9),
      child: Column(
        children: [
          Expanded(child: _buildFeedList()),
          _buildPostInput(currentUserInitials),
        ],
      ),
    );
  }

  Widget _buildFeedList() {
    final myDept = (AppSession().userDepartment ?? '').toString().trim().toLowerCase();

    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.companyDoc().collection('feed_posts').snapshots(),
      builder: (context, snapshot1) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirestoreService.companyDoc().collection('feed').snapshots(),
          builder: (context, snapshot2) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirestoreService.companyDoc().collection('posts').snapshots(),
              builder: (context, snapshot3) {
                if (snapshot1.connectionState == ConnectionState.waiting &&
                    snapshot2.connectionState == ConnectionState.waiting &&
                    snapshot3.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final Map<String, DocumentSnapshot> combinedDocsMap = {};
                for (var d in (snapshot1.data?.docs ?? [])) {
                  combinedDocsMap[d.id] = d;
                }
                for (var d in (snapshot2.data?.docs ?? [])) {
                  combinedDocsMap[d.id] = d;
                }
                for (var d in (snapshot3.data?.docs ?? [])) {
                  combinedDocsMap[d.id] = d;
                }

                final rawDocs = combinedDocsMap.values.toList();
                rawDocs.sort((a, b) {
                  final tA = (a.data() as Map<String, dynamic>?)?['timestamp'] as Timestamp? ??
                      (a.data() as Map<String, dynamic>?)?['createdAt'] as Timestamp?;
                  final tB = (b.data() as Map<String, dynamic>?)?['timestamp'] as Timestamp? ??
                      (b.data() as Map<String, dynamic>?)?['createdAt'] as Timestamp?;
                  if (tA == null || tB == null) return 0;
                  return tB.compareTo(tA);
                });

                final docs = rawDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final dept = (data['department'] ?? '').toString().trim().toLowerCase();
                  if (myDept.isEmpty || AppSession().isSuperAdmin) return true;
                  return dept == myDept || dept.isEmpty;
                }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text('No posts yet for your department.', style: TextStyle(color: Color(0xFF6B7280))));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // padding at bottom for input
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            
            final name = data['name'] ?? 'Unknown';
            final text = data['text'] ?? '';
            final likes = data['likes'] ?? 0;
            final comments = data['comments'] ?? 0;
            final ts = data['timestamp'] as Timestamp?;
            final timeStr = ts != null ? _formatTimeAgo(ts.toDate()) : 'Just now';

            return Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _getAvatarColor(name),
                        child: Text(
                          _getInitials(name),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                          const SizedBox(height: 2),
                          Text(timeStr, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    text,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _toggleStar(docs[index].reference, data['likedBy']),
                        child: Row(
                          children: [
                            Icon(
                              (data['likedBy'] is List && (data['likedBy'] as List).contains(AppSession().email))
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: 20,
                              color: (data['likedBy'] is List && (data['likedBy'] as List).contains(AppSession().email))
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 4),
                            Text('$likes',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: (data['likedBy'] is List && (data['likedBy'] as List).contains(AppSession().email))
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF9CA3AF),
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: () => _showCommentsBottomSheet(context, docs[index].reference),
                        child: Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF9CA3AF)),
                            const SizedBox(width: 4),
                            Text('$comments', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPostInput(String currentUserInitials) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF5C5CFF),
              child: Text(
                currentUserInitials,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _postController,
                        decoration: const InputDecoration(
                          hintText: 'Share something with the team...',
                          hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _submitPost,
                      child: const Icon(Icons.send_rounded, size: 18, color: Color(0xFF9CA3AF)),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
