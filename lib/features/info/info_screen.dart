import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  String _role = 'student';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    if (Firebase.apps.isEmpty) {
      _loading = false;
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data()!.containsKey('role')) {
          _role = doc['role'].toString().trim().toLowerCase();
        }
      }
    } catch (_) {
      _role = 'student';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isAdmin = _role == 'admin';
    final isStaff = _role == 'staff';
    final heroIcon = isAdmin
        ? Icons.admin_panel_settings_outlined
        : isStaff
        ? Icons.meeting_room_outlined
        : Icons.eco_outlined;
    final heroTitle = isAdmin
        ? 'Admin control center for campus flow'
        : isStaff
        ? 'Staff facilities without paper forms'
        : 'Smarter campus bookings for sustainable student services';
    final heroBody = isAdmin
        ? 'Review approvals, manage booking records, monitor traffic, and keep student services and staff facilities organised.'
        : isStaff
        ? 'Reserve rooms, labs, and equipment digitally while admin keeps approvals organised.'
        : 'Book campus services, see your appointment timing clearly, and reduce unnecessary walk-ins.';

    return Scaffold(
      appBar: AppBar(title: const Text('FlowSlot Campus')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(heroIcon, color: const Color(0xFF34D399), size: 36),
                const SizedBox(height: 16),
                Text(
                  heroTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  heroBody,
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _InfoCard(
            icon: Icons.flag_outlined,
            title: 'SDG Alignment',
            body:
                'Aligned with SDG 11: Sustainable Cities and Communities. FlowSlot reduces crowding, saves repeated trips, and makes campus services easier to access.',
          ),
          const SizedBox(height: 16),
          _RoleSummaryPanel(role: _role),
          const SizedBox(height: 12),
          _InfoCard(
            icon: isAdmin
                ? Icons.fact_check_outlined
                : isStaff
                ? Icons.meeting_room_outlined
                : Icons.edit_calendar_outlined,
            title: isAdmin
                ? 'Admin Approval Flow'
                : isStaff
                ? 'Staff Facility Flow'
                : 'Student Booking Flow',
            body: isAdmin
                ? 'Open Approvals to accept or reject requests. Use Manage to update records, mark Serving, and mark Completed when the appointment is done.'
                : isStaff
                ? 'Choose a facility, preferred time, and purpose. Admin approves it, then the booking appears as Booked.'
                : 'Choose a department, preferred time, and reason. Admin approves it, then the booking appears as Booked.',
          ),
          if (isAdmin) ...[
            const SizedBox(height: 12),
            const _InfoCard(
              icon: Icons.manage_accounts_outlined,
              title: 'Role Management',
              body:
                  'Public sign-up creates Student accounts only. Staff and Admin access is assigned in Firestore by changing the user role field.',
            ),
          ],
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.calculate_outlined,
            title: 'Timing Calculation',
            body:
                'Starts in = real Malaysia time until your appointment. Queue delay = active bookings ahead in the same department or facility hour. Peak traffic = a separate busy-hour prediction.',
          ),
        ],
      ),
    );
  }
}

class _RoleSummaryPanel extends StatelessWidget {
  const _RoleSummaryPanel({required this.role});

  final String role;

  bool get _isAdmin => role == 'admin';
  bool get _isStaff => role == 'staff';

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return _DashboardPanel(
        title: _isStaff ? 'Staff workspace' : 'Student workspace',
        color: _isStaff ? const Color(0xFF7C3AED) : const Color(0xFF059669),
        items: _isStaff
            ? const [
                _PanelItem('Book', 'Facilities', Icons.meeting_room_outlined),
                _PanelItem('Track', 'Approval', Icons.fact_check_outlined),
                _PanelItem('Review', 'Insights', Icons.query_stats_outlined),
              ]
            : const [
                _PanelItem('Book', 'Departments', Icons.school_outlined),
                _PanelItem('Track', 'Status', Icons.event_available_outlined),
                _PanelItem('View', 'Impact', Icons.eco_outlined),
              ],
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('queue').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final pending = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'Pending';
        }).length;
        final active = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'];
          return status == 'Pending' ||
              status == 'Booked' ||
              status == 'Serving' ||
              status == 'Waitlist';
        }).length;
        final today = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final scheduled = data['scheduledTime'];
          if (scheduled is! Timestamp) return false;
          final date = scheduled.toDate();
          final now = DateTime.now();
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        }).length;

        if (_isAdmin) {
          return _DashboardPanel(
            title: 'Admin booking overview',
            color: const Color(0xFF2563EB),
            items: [
              _PanelItem(
                'Need approval',
                '$pending',
                Icons.pending_actions_outlined,
              ),
              _PanelItem('Today', '$today', Icons.today_outlined),
              _PanelItem('Active', '$active', Icons.bolt_outlined),
              _PanelItem(
                'Total records',
                '${docs.length}',
                Icons.list_alt_outlined,
              ),
            ],
          );
        }

        return _DashboardPanel(
          title: _isStaff ? 'Staff workspace' : 'Student workspace',
          color: _isStaff ? const Color(0xFF7C3AED) : const Color(0xFF059669),
          items: _isStaff
              ? const [
                  _PanelItem('Book', 'Facilities', Icons.meeting_room_outlined),
                  _PanelItem('Track', 'Approval', Icons.fact_check_outlined),
                  _PanelItem('Review', 'Insights', Icons.query_stats_outlined),
                ]
              : const [
                  _PanelItem('Book', 'Departments', Icons.school_outlined),
                  _PanelItem('Track', 'Status', Icons.event_available_outlined),
                  _PanelItem('View', 'Impact', Icons.eco_outlined),
                ],
        );
      },
    );
  }
}

class _PanelItem {
  const _PanelItem(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.title,
    required this.color,
    required this.items,
  });

  final String title;
  final Color color;
  final List<_PanelItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: items
                      .map(
                        (item) => SizedBox(
                          width: itemWidth,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(item.icon, color: color),
                                const SizedBox(height: 10),
                                Text(
                                  item.value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatefulWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  State<_InfoCard> createState() => _InfoCardState();
}

class _InfoCardState extends State<_InfoCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1,
        duration: const Duration(milliseconds: 160),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(widget.title),
              content: Text(widget.body),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.icon,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.body,
                          style: const TextStyle(
                            color: Color(0xFF4B5563),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.touch_app_outlined,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
