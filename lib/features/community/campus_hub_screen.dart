import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_design.dart';
import '../../core/responsive_page.dart';
import '../../services/database_service.dart';

class CampusHubScreen extends StatefulWidget {
  const CampusHubScreen({super.key});

  @override
  State<CampusHubScreen> createState() => _CampusHubScreenState();
}

class _CampusHubScreenState extends State<CampusHubScreen> {
  final DatabaseService _dbService = DatabaseService();
  String _role = 'student';
  String _displayName = 'Campus user';
  bool _loading = true;

  bool get _isAdmin => _role == 'admin';
  bool get _isStaff => _role == 'staff' || _role == 'lecturer';
  bool get _canManageAnnouncements => _isAdmin || _isStaff;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _displayName = user.displayName ?? user.email?.split('@').first ?? 'User';
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _role = (data['role'] ?? 'student').toString().trim().toLowerCase();
        _displayName = (data['name'] ?? _displayName).toString();
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Campus Hub'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.campaign_outlined), text: 'Info'),
              Tab(icon: Icon(Icons.article_outlined), text: 'Blog'),
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
              Tab(icon: Icon(Icons.rate_review_outlined), text: 'Feedback'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AnnouncementsTab(
              dbService: _dbService,
              canManage: _canManageAnnouncements,
              currentUid: FirebaseAuth.instance.currentUser?.uid ?? '',
              currentEmail: FirebaseAuth.instance.currentUser?.email ?? '',
              isAdmin: _isAdmin,
              onCreate: () => _showAnnouncementSheet(),
              onEdit: _showAnnouncementSheet,
            ),
            _BlogTab(
              dbService: _dbService,
              canManage: true,
              currentUid: FirebaseAuth.instance.currentUser?.uid ?? '',
              currentEmail: FirebaseAuth.instance.currentUser?.email ?? '',
              isAdmin: _isAdmin,
              onCreate: () => _showBlogSheet(),
              onEdit: _showBlogSheet,
            ),
            _ChatTab(
              dbService: _dbService,
              authorName: _displayName,
              authorUid: FirebaseAuth.instance.currentUser?.uid ?? '',
              authorEmail: FirebaseAuth.instance.currentUser?.email ?? '',
              authorRole: _role,
            ),
            _FeedbackTab(
              dbService: _dbService,
              isAdmin: _isAdmin,
              isStaff: _isStaff,
              authorName: _displayName,
              authorUid: FirebaseAuth.instance.currentUser?.uid ?? '',
              authorEmail: FirebaseAuth.instance.currentUser?.email ?? '',
              authorRole: _role,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAnnouncementSheet([
    String? docId,
    Map<String, dynamic>? existing,
  ]) async {
    final titleController = TextEditingController(
      text: existing?['title']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: existing?['description']?.toString() ?? '',
    );
    var type = existing?['type']?.toString() ?? 'Announcement';
    DateTime? eventDate = existing?['eventDate'] is Timestamp
        ? (existing!['eventDate'] as Timestamp).toDate()
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              shrinkWrap: true,
              children: [
                Text(
                  docId == null ? 'Create Campus Info' : 'Edit Campus Info',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleController,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.title_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: const ['Announcement', 'Event', 'Artist', 'Notice']
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) => setModalState(() => type = value!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Details',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Event date'),
                  subtitle: Text(
                    eventDate == null
                        ? 'Optional'
                        : DateFormat('EEE, MMM d, yyyy').format(eventDate!),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2035),
                      initialDate: eventDate ?? DateTime.now(),
                    );
                    if (picked != null) {
                      setModalState(() => eventDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty ||
                        descriptionController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill in all fields.'),
                        ),
                      );
                      return;
                    }
                    try {
                      await _dbService.saveAnnouncement(
                        docId: docId,
                        title: titleController.text.trim(),
                        description: descriptionController.text.trim(),
                        type: type,
                        authorName: _displayName,
                        authorUid: FirebaseAuth.instance.currentUser?.uid ?? '',
                        authorEmail:
                            FirebaseAuth.instance.currentUser?.email ?? '',
                        authorRole: _role,
                        eventDate: eventDate,
                      );
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Announcement saved.')),
                      );
                    } catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not save announcement: $error'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBlogSheet([String? docId, Map<String, dynamic>? existing]) {
    final titleController = TextEditingController(
      text: existing?['title']?.toString() ?? '',
    );
    final bodyController = TextEditingController(
      text: existing?['body']?.toString() ?? '',
    );
    final imageController = TextEditingController(
      text: existing?['imageUrl']?.toString() ?? '',
    );
    var visibility = existing?['visibility']?.toString() ?? 'Public';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              shrinkWrap: true,
              children: [
                Text(
                  docId == null ? 'New Blog Post' : 'Edit Blog Post',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleController,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.title_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: imageController,
                  keyboardType: TextInputType.url,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: const InputDecoration(
                    labelText: 'Picture URL',
                    prefixIcon: Icon(Icons.image_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: visibility,
                  decoration: const InputDecoration(
                    labelText: 'Visibility',
                    prefixIcon: Icon(Icons.visibility_outlined),
                  ),
                  items: const ['Public', 'Friends only', 'Private']
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setModalState(() => visibility = value!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  minLines: 5,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Post details',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.publish_outlined),
                  label: const Text('Publish'),
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty ||
                        bodyController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please write a title and post.'),
                        ),
                      );
                      return;
                    }
                    try {
                      await _dbService.saveBlogPost(
                        docId: docId,
                        title: titleController.text.trim(),
                        body: bodyController.text.trim(),
                        imageUrl: imageController.text.trim(),
                        visibility: visibility,
                        authorName: _displayName,
                        authorUid: FirebaseAuth.instance.currentUser?.uid ?? '',
                        authorEmail:
                            FirebaseAuth.instance.currentUser?.email ?? '',
                        authorRole: _role,
                      );
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Blog post published.')),
                      );
                    } catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not publish post: $error'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnnouncementsTab extends StatelessWidget {
  const _AnnouncementsTab({
    required this.dbService,
    required this.canManage,
    required this.currentUid,
    required this.currentEmail,
    required this.isAdmin,
    required this.onCreate,
    required this.onEdit,
  });

  final DatabaseService dbService;
  final bool canManage;
  final String currentUid;
  final String currentEmail;
  final bool isAdmin;
  final VoidCallback onCreate;
  final void Function(String docId, Map<String, dynamic> data) onEdit;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: dbService.getAnnouncements(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        return ResponsiveListView(
          children: [
            _HubHero(
              icon: Icons.campaign_outlined,
              title: 'Campus announcements',
              body:
                  'Events, artist visits, notices, and UniKL campus updates stay visible here.',
              actionLabel: canManage ? 'Add info' : null,
              onAction: canManage ? onCreate : null,
            ),
            const SizedBox(height: 14),
            if (docs.isEmpty)
              const _EmptyState(
                icon: Icons.campaign_outlined,
                title: 'No announcements yet',
                body: 'Campus information will appear here.',
              )
            else
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final ownsAnnouncement =
                    data['authorUid'] == currentUid ||
                    data['authorEmail'] == currentEmail;
                return _ContentCard(
                  icon: Icons.campaign_outlined,
                  accent: const Color(0xFF2563EB),
                  title: data['title'] ?? 'Announcement',
                  subtitle: _dateText(data['eventDate'], data['createdAt']),
                  body: data['description'] ?? '',
                  chip: data['type'] ?? 'Info',
                  menu: canManage && (ownsAnnouncement || isAdmin)
                      ? PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') onEdit(doc.id, data);
                            if (value == 'delete') {
                              await dbService.deleteAnnouncement(doc.id);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        )
                      : null,
                );
              }),
          ],
        );
      },
    );
  }
}

class _BlogTab extends StatelessWidget {
  const _BlogTab({
    required this.dbService,
    required this.canManage,
    required this.currentUid,
    required this.currentEmail,
    required this.isAdmin,
    required this.onCreate,
    required this.onEdit,
  });

  final DatabaseService dbService;
  final bool canManage;
  final String currentUid;
  final String currentEmail;
  final bool isAdmin;
  final VoidCallback onCreate;
  final void Function(String docId, Map<String, dynamic> data) onEdit;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: dbService.getBlogPosts(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final visibleDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final visibility = data['visibility']?.toString() ?? 'Public';
          final ownsPost =
              data['authorUid'] == currentUid ||
              data['authorEmail'] == currentEmail;
          return visibility != 'Private' || ownsPost || isAdmin;
        }).toList();
        return ResponsiveListView(
          children: [
            _HubHero(
              icon: Icons.article_outlined,
              title: 'Campus blog',
              body:
                  'Students can share helpful notes, event stories, and campus updates.',
              actionLabel: canManage ? 'Write post' : null,
              onAction: canManage ? onCreate : null,
            ),
            const SizedBox(height: 14),
            if (visibleDocs.isEmpty)
              const _EmptyState(
                icon: Icons.article_outlined,
                title: 'No posts yet',
                body: 'Published blog posts will show here.',
              )
            else
              ...visibleDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final ownsPost =
                    data['authorUid'] == currentUid ||
                    data['authorEmail'] == currentEmail;
                return _ContentCard(
                  icon: Icons.article_outlined,
                  accent: const Color(0xFF059669),
                  title: data['title'] ?? 'Blog post',
                  subtitle:
                      '${data['authorName'] ?? 'Campus user'} - ${_dateText(null, data['createdAt'])}',
                  body: data['body'] ?? '',
                  chip: data['visibility'] ?? 'Public',
                  imageUrl: data['imageUrl']?.toString() ?? '',
                  menu: (canManage && (ownsPost || isAdmin))
                      ? PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') onEdit(doc.id, data);
                            if (value == 'delete') {
                              await dbService.deleteBlogPost(doc.id);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        )
                      : null,
                );
              }),
          ],
        );
      },
    );
  }
}

class _ChatTab extends StatefulWidget {
  const _ChatTab({
    required this.dbService,
    required this.authorName,
    required this.authorUid,
    required this.authorEmail,
    required this.authorRole,
  });

  final DatabaseService dbService;
  final String authorName;
  final String authorUid;
  final String authorEmail;
  final String authorRole;

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePageFrame(
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _HubHero(
              icon: Icons.forum_outlined,
              title: 'Realtime group chat',
              body:
                  'Everyone can ask questions, coordinate bookings, and share quick updates.',
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.dbService.getGroupMessages(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'No messages yet',
                    body: 'Start the campus conversation below.',
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final mine =
                        data['authorUid'] == widget.authorUid ||
                        data['authorEmail'] == widget.authorEmail;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 380),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: mine
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: mine
                              ? null
                              : Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['authorName'] ?? 'Campus user',
                              style: TextStyle(
                                color: mine
                                    ? Colors.white70
                                    : const Color(0xFF64748B),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data['message'] ?? '',
                              style: TextStyle(
                                color: mine
                                    ? Colors.white
                                    : const Color(0xFF111827),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 3,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: const InputDecoration(
                        hintText: 'Message everyone',
                        prefixIcon: Icon(Icons.chat_bubble_outline),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send_outlined),
                    onPressed: () async {
                      final text = _messageController.text.trim();
                      if (text.isEmpty) return;
                      _messageController.clear();
                      try {
                        await widget.dbService.sendGroupMessage(
                          message: text,
                          authorName: widget.authorName,
                          authorUid: widget.authorUid,
                          authorEmail: widget.authorEmail,
                          authorRole: widget.authorRole,
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not send message: $error'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackTab extends StatefulWidget {
  const _FeedbackTab({
    required this.dbService,
    required this.isAdmin,
    required this.isStaff,
    required this.authorName,
    required this.authorUid,
    required this.authorEmail,
    required this.authorRole,
  });

  final DatabaseService dbService;
  final bool isAdmin;
  final bool isStaff;
  final String authorName;
  final String authorUid;
  final String authorEmail;
  final String authorRole;

  @override
  State<_FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<_FeedbackTab> {
  final TextEditingController _messageController = TextEditingController();
  String _category = 'Facility';

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveListView(
      children: [
        _HubHero(
          icon: Icons.rate_review_outlined,
          title: widget.isAdmin
              ? 'Feedback tracking'
              : 'Feedback and complaints',
          body: widget.isAdmin
              ? 'Track monthly staff feedback, complaints, and facility issues.'
              : 'Staff can report facility issues, complaints, and improvement ideas.',
        ),
        if (widget.isStaff) ...[
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: const ['Facility', 'Service', 'Complaint', 'Idea']
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _category = value!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _messageController,
                    minLines: 4,
                    maxLines: 7,
                    decoration: const InputDecoration(
                      labelText: 'Feedback or complaint',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Submit feedback'),
                    onPressed: () async {
                      if (_messageController.text.trim().isEmpty) return;
                      try {
                        await widget.dbService.submitFeedback(
                          category: _category,
                          message: _messageController.text.trim(),
                          authorName: widget.authorName,
                          authorUid: widget.authorUid,
                          authorEmail: widget.authorEmail,
                          authorRole: widget.authorRole,
                        );
                        _messageController.clear();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Feedback submitted.')),
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not submit feedback: $error'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot>(
          stream: widget.dbService.getFeedback(),
          builder: (context, snapshot) {
            var docs = snapshot.data?.docs ?? [];
            if (!widget.isAdmin) {
              docs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['authorUid'] == widget.authorUid ||
                    data['authorEmail'] == widget.authorEmail;
              }).toList();
            }
            if (docs.isEmpty) {
              return const _EmptyState(
                icon: Icons.rate_review_outlined,
                title: 'No feedback yet',
                body: 'Submitted reports will appear here.',
              );
            }
            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] ?? 'Open';
                return _ContentCard(
                  icon: Icons.report_problem_outlined,
                  accent: status == 'Resolved'
                      ? const Color(0xFF059669)
                      : const Color(0xFFF59E0B),
                  title: data['category'] ?? 'Feedback',
                  subtitle:
                      '${data['authorName'] ?? 'Staff'} - ${_dateText(null, data['createdAt'])}',
                  body: data['message'] ?? '',
                  chip: status,
                  menu: widget.isAdmin
                      ? PopupMenuButton<String>(
                          onSelected: (value) => widget.dbService
                              .updateFeedbackStatus(doc.id, value),
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'Open', child: Text('Open')),
                            PopupMenuItem(
                              value: 'In progress',
                              child: Text('In progress'),
                            ),
                            PopupMenuItem(
                              value: 'Resolved',
                              child: Text('Resolved'),
                            ),
                          ],
                        )
                      : null,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _HubHero extends StatelessWidget {
  const _HubHero({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft(),
      ),
      child: AppSectionHeader(
        icon: icon,
        title: title,
        subtitle: body,
        action: actionLabel != null && onAction != null
            ? FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
              )
            : null,
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.chip,
    this.imageUrl = '',
    this.menu,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String body;
  final String chip;
  final String imageUrl;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.trim().isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    imageUrl.trim(),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFF1F5F9),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                _SmallChip(label: chip, color: accent),
                ?menu,
              ],
            ),
            const SizedBox(height: 12),
            Text(body, style: const TextStyle(height: 1.48)),
          ],
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
        fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Icon(icon, size: 38, color: AppColors.primary),
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

String _dateText(dynamic eventDate, dynamic createdAt) {
  final date = eventDate is Timestamp
      ? eventDate.toDate()
      : createdAt is Timestamp
      ? createdAt.toDate()
      : null;
  if (date == null) return 'Just now';
  return DateFormat('MMM d, yyyy').format(date);
}
