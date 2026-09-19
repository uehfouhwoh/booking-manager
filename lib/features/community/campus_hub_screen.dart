import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CampusHubScreen extends StatefulWidget {
  const CampusHubScreen({super.key});

  @override
  State<CampusHubScreen> createState() => _CampusHubScreenState();
}

class _CampusHubScreenState extends State<CampusHubScreen> {
  static const _orange = Color(0xFFFF8943);
  static const _aqua = Color(0xFF0DC9C9);
  static const _peach = Color(0xFFFFC3A0);
  static const _charcoal = Color(0xFF2C2E35);

  String _displayName = 'Student';
  String _role = 'student';

  bool get _canManageAnnouncements =>
      _role == 'admin' || _role == 'staff' || _role == 'lecturer';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _displayName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : (user.email?.split('@').first ?? 'Student');

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists) {
      final data = doc.data() ?? {};
      _role = (data['role'] ?? 'student').toString().trim().toLowerCase();
      _displayName = (data['name'] ?? _displayName).toString();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Campus Hub'),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.campaign_outlined), text: 'Info'),
              Tab(icon: Icon(Icons.article_outlined), text: 'Blog'),
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AnnouncementsTab(
              canManage: _canManageAnnouncements,
              currentUid: FirebaseAuth.instance.currentUser?.uid ?? '',
              currentEmail: FirebaseAuth.instance.currentUser?.email ?? '',
              isAdmin: _role == 'admin',
              onCreate: _showAnnouncementSheet,
              onEdit: _showAnnouncementSheet,
            ),
            _BlogTab(
              currentUid: FirebaseAuth.instance.currentUser?.uid ?? '',
              currentEmail: FirebaseAuth.instance.currentUser?.email ?? '',
              isAdmin: _role == 'admin',
              onCreate: _showBlogSheet,
              onEdit: _showBlogSheet,
            ),
            _ChatTab(
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
    String type = existing?['type']?.toString() ?? 'Announcement';
    DateTime? eventDate = existing?['eventDate'] is Timestamp
        ? (existing!['eventDate'] as Timestamp).toDate()
        : null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  docId == null ? 'Create campus info' : 'Edit campus info',
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.title_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const ['Announcement', 'Event', 'Notice', 'Artist']
                      .map((item) => DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setModalState(() => type = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  minLines: 4,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    labelText: 'Details',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Event date'),
                  subtitle: Text(
                    eventDate == null
                        ? 'Optional'
                        : DateFormat('EEE, MMM d, yyyy').format(eventDate!),
                  ),
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
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _orange),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                  onPressed: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;
                    if (titleController.text.trim().isEmpty ||
                        descriptionController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill in all fields.')),
                      );
                      return;
                    }
                    final data = <String, dynamic>{
                      'title': titleController.text.trim(),
                      'description': descriptionController.text.trim(),
                      'type': type,
                      'eventDate': eventDate == null
                          ? null
                          : Timestamp.fromDate(eventDate!),
                      'authorName': _displayName,
                      'authorUid': user.uid,
                      'authorEmail': user.email ?? '',
                      'authorRole': _role,
                      'updatedAt': FieldValue.serverTimestamp(),
                    };
                    try {
                      if (docId == null) {
                        data['createdAt'] = FieldValue.serverTimestamp();
                        await FirebaseFirestore.instance
                            .collection('announcements')
                            .add(data);
                      } else {
                        await FirebaseFirestore.instance
                            .collection('announcements')
                            .doc(docId)
                            .update(data);
                      }
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    } catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not save announcement: $error')),
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showBlogSheet([
    String? docId,
    Map<String, dynamic>? existing,
  ]) async {
    final titleController = TextEditingController(
      text: existing?['title']?.toString() ?? '',
    );
    final bodyController = TextEditingController(
      text: existing?['body']?.toString() ?? '',
    );
    final imageController = TextEditingController(
      text: existing?['imageUrl']?.toString() ?? '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              docId == null ? 'Write a blog post' : 'Edit blog post',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: imageController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Image URL (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyController,
              minLines: 6,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Post details',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _aqua),
              icon: const Icon(Icons.publish_outlined),
              label: Text(docId == null ? 'Publish' : 'Save changes'),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                if (titleController.text.trim().isEmpty ||
                    bodyController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a title and post.')),
                  );
                  return;
                }
                final data = <String, dynamic>{
                  'title': titleController.text.trim(),
                  'body': bodyController.text.trim(),
                  'imageUrl': imageController.text.trim(),
                  'visibility': 'Public',
                  'authorName': _displayName,
                  'authorUid': user.uid,
                  'authorEmail': user.email ?? '',
                  'authorRole': _role,
                  'updatedAt': FieldValue.serverTimestamp(),
                };
                try {
                  if (docId == null) {
                    data['createdAt'] = FieldValue.serverTimestamp();
                    await FirebaseFirestore.instance
                        .collection('blogPosts')
                        .add(data);
                  } else {
                    await FirebaseFirestore.instance
                        .collection('blogPosts')
                        .doc(docId)
                        .update(data);
                  }
                  if (!context.mounted) return;
                  Navigator.pop(context);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not save blog post: $error')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementsTab extends StatelessWidget {
  const _AnnouncementsTab({
    required this.canManage,
    required this.currentUid,
    required this.currentEmail,
    required this.isAdmin,
    required this.onCreate,
    required this.onEdit,
  });

  final bool canManage;
  final String currentUid;
  final String currentEmail;
  final bool isAdmin;
  final VoidCallback onCreate;
  final void Function(String, Map<String, dynamic>) onEdit;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        return _HubList(
          children: [
            _HubHero(
              icon: Icons.campaign_outlined,
              title: 'Campus announcements',
              body: 'Events, notices, and important campus information appear here.',
              buttonLabel: canManage ? 'Add info' : null,
              onButtonPressed: canManage ? onCreate : null,
            ),
            if (docs.isEmpty)
              const _EmptyState(
                icon: Icons.campaign_outlined,
                title: 'No announcements yet',
                body: 'Campus information will appear here.',
              )
            else
              ...docs.map((doc) {
                final data = doc.data();
                final mine = data['authorUid'] == currentUid ||
                    data['authorEmail'] == currentEmail;
                return _ContentCard(
                  icon: Icons.campaign_outlined,
                  accent: const Color(0xFFFF8943),
                  title: data['title']?.toString() ?? 'Announcement',
                  subtitle: _dateText(data['eventDate'], data['createdAt']),
                  body: data['description']?.toString() ?? '',
                  chip: data['type']?.toString() ?? 'Info',
                  trailing: canManage && (mine || isAdmin)
                      ? PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') onEdit(doc.id, data);
                            if (value == 'delete') {
                              await doc.reference.delete();
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
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
    required this.currentUid,
    required this.currentEmail,
    required this.isAdmin,
    required this.onCreate,
    required this.onEdit,
  });

  final String currentUid;
  final String currentEmail;
  final bool isAdmin;
  final VoidCallback onCreate;
  final void Function(String, Map<String, dynamic>) onEdit;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('blogPosts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        return _HubList(
          children: [
            _HubHero(
              icon: Icons.article_outlined,
              title: 'Campus blog',
              body: 'Students can share useful campus notes, stories, and updates.',
              buttonLabel: 'Write post',
              onButtonPressed: onCreate,
            ),
            if (docs.isEmpty)
              const _EmptyState(
                icon: Icons.article_outlined,
                title: 'No posts yet',
                body: 'Published blog posts will appear here.',
              )
            else
              ...docs.map((doc) {
                final data = doc.data();
                final mine = data['authorUid'] == currentUid ||
                    data['authorEmail'] == currentEmail;
                return _ContentCard(
                  icon: Icons.article_outlined,
                  accent: const Color(0xFF0DC9C9),
                  title: data['title']?.toString() ?? 'Blog post',
                  subtitle:
                      '${data['authorName'] ?? 'Campus user'} • ${_dateText(null, data['createdAt'])}',
                  body: data['body']?.toString() ?? '',
                  chip: 'Public',
                  imageUrl: data['imageUrl']?.toString() ?? '',
                  trailing: (mine || isAdmin)
                      ? PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') onEdit(doc.id, data);
                            if (value == 'delete') {
                              await doc.reference.delete();
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
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
    required this.authorName,
    required this.authorUid,
    required this.authorEmail,
    required this.authorRole,
  });

  final String authorName;
  final String authorUid;
  final String authorEmail;
  final String authorRole;

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _HubHero(
            icon: Icons.forum_outlined,
            title: 'Realtime group chat',
            body: 'Ask questions, coordinate bookings, and share quick updates.',
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('groupMessages')
                .orderBy('createdAt', descending: true)
                .limit(80)
                .snapshots(),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  final mine = data['authorUid'] == widget.authorUid ||
                      data['authorEmail'] == widget.authorEmail;
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 380),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: mine ? const Color(0xFF2C2E35) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: mine
                            ? null
                            : Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['authorName']?.toString() ?? 'Campus user',
                            style: TextStyle(
                              color: mine
                                  ? const Color(0xFFFFC3A0)
                                  : const Color(0xFF64748B),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['message']?.toString() ?? '',
                            style: TextStyle(
                              color: mine ? Colors.white : const Color(0xFF111827),
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
                    controller: _controller,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Message everyone',
                      prefixIcon: Icon(Icons.chat_bubble_outline),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8943),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.send_outlined),
                  onPressed: () async {
                    final text = _controller.text.trim();
                    if (text.isEmpty || widget.authorUid.isEmpty) return;
                    _controller.clear();
                    await FirebaseFirestore.instance.collection('groupMessages').add({
                      'message': text,
                      'authorName': widget.authorName,
                      'authorUid': widget.authorUid,
                      'authorEmail': widget.authorEmail,
                      'authorRole': widget.authorRole,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HubList extends StatelessWidget {
  const _HubList({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: children
          .map((child) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: child,
              ))
          .toList(),
    );
  }
}

class _HubHero extends StatelessWidget {
  const _HubHero({
    required this.icon,
    required this.title,
    required this.body,
    this.buttonLabel,
    this.onButtonPressed,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? buttonLabel;
  final VoidCallback? onButtonPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2E35),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.campaign_outlined, color: Color(0xFFFF8943), size: 30),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            style: const TextStyle(color: Color(0xFFE8EAEE), height: 1.4),
          ),
          if (buttonLabel != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF8943),
                foregroundColor: Colors.white,
              ),
              onPressed: onButtonPressed,
              icon: const Icon(Icons.add_outlined),
              label: Text(buttonLabel!),
            ),
          ],
        ],
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
    this.imageUrl,
    this.trailing,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String body;
  final String chip;
  final String? imageUrl;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF2C2E35)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            if ((imageUrl ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl!,
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 170,
                    color: const Color(0xFFF2F4F7),
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC3A0).withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    chip,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(body, style: const TextStyle(color: Color(0xFF374151), height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          children: [
            Icon(icon, size: 42, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}

String _dateText(Object? eventDate, Object? createdAt) {
  final value = eventDate ?? createdAt;
  if (value is Timestamp) {
    return DateFormat('EEE, MMM d, yyyy • h:mm a').format(value.toDate());
  }
  return 'Recently posted';
}
