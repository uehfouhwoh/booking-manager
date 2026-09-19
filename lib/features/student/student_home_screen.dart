import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../calendar/calendar_screen.dart';
import '../community/campus_hub_screen.dart';
import '../info/info_screen.dart';
import '../profile/booking_history_screen.dart';
import '../../core/app_helpers.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  static const _charcoal = Color(0xFF2C2E35);
  static const _peach = Color(0xFFFFC3A0);
  static const _orange = Color(0xFFFF8943);
  static const _lightAqua = Color(0xFF8BD6D6);
  static const _aqua = Color(0xFF0DC9C9);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : (user?.email?.split('@').first ?? 'Student');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Student Home'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _charcoal,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _orange,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.school_outlined,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Welcome back, $displayName',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Manage your campus services, appointments, and campus updates from one place.',
                    style: TextStyle(color: Color(0xFFE8EAEE), height: 1.45),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _orange,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CalendarScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_task_outlined),
                          label: const Text('Book a service'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: _lightAqua),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CampusHubScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.campaign_outlined),
                          label: const Text('Campus hub'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _UpcomingBookingCard(userId: user?.uid ?? ''),
            const SizedBox(height: 16),
            const Text(
              'Student tools',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ToolCard(
                  title: 'Booking',
                  subtitle: 'Book a campus service',
                  icon: Icons.edit_calendar_outlined,
                  color: _orange,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CalendarScreen()),
                    );
                  },
                ),
                _ToolCard(
                  title: 'History',
                  subtitle: 'View past reservations',
                  icon: Icons.history_outlined,
                  color: _aqua,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BookingHistoryScreen(),
                      ),
                    );
                  },
                ),
                _ToolCard(
                  title: 'Campus info',
                  subtitle: 'Understand the booking flow',
                  icon: Icons.info_outline,
                  color: _lightAqua,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const InfoScreen()),
                    );
                  },
                ),
                _ToolCard(
                  title: 'Community',
                  subtitle: 'Announcements, blog and chat',
                  icon: Icons.forum_outlined,
                  color: _peach,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CampusHubScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _StudentNotesCard(),
          ],
        ),
      ),
    );
  }
}

class _UpcomingBookingCard extends StatelessWidget {
  const _UpcomingBookingCard({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('queue')
          .where('requesterUid', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Could not load your next booking.'),
            ),
          );
        }

        final now = malaysiaNow();
        final active = (snapshot.data?.docs ?? [])
            .map((doc) => doc.data())
            .where((data) {
          final scheduled = data['scheduledTime'];
          if (scheduled is! Timestamp) return false;
          final status = data['status']?.toString() ?? '';
          return scheduled.toDate().isAfter(now) &&
              const {
                'Pending',
                'Booked',
                'Serving',
                'Waitlist',
              }.contains(status);
        }).toList()
          ..sort((a, b) {
            final aTime = (a['scheduledTime'] as Timestamp).toDate();
            final bTime = (b['scheduledTime'] as Timestamp).toDate();
            return aTime.compareTo(bTime);
          });

        if (active.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0DC9C9).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.event_available_outlined),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No upcoming booking',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your next appointment will appear here.',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final booking = active.first;
        final scheduled = (booking['scheduledTime'] as Timestamp).toDate();
        final department = booking['department']?.toString() ?? 'Campus service';
        final status = booking['status']?.toString() ?? 'Pending';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.upcoming_outlined),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Upcoming booking',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8943).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: Color(0xFFE56D2F),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  department,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEE, MMM d, yyyy • h:mm a').format(scheduled),
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 42) / 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF2C2E35)),
                ),
                const SizedBox(height: 12),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF64748B), height: 1.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentNotesCard extends StatelessWidget {
  const _StudentNotesCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF8BD6D6).withValues(alpha: 0.16),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tip: submit your service request early. The system uses the current queue and appointment time to show an estimated delay and availability.',
                style: TextStyle(color: Color(0xFF374151), height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
