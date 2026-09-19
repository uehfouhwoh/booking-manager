import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  static const _charcoal = Color(0xFF2C2E35);
  static const _orange = Color(0xFFFF8943);
  static const _lightAqua = Color(0xFF8BD6D6);
  static const _aqua = Color(0xFF0DC9C9);
  static const _peach = Color(0xFFFFC3A0);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Info'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: user == null
            ? null
            : FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        builder: (context, snapshot) {
          final role = (snapshot.data?.data()?['role'] ?? 'student')
              .toString()
              .trim()
              .toLowerCase();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _charcoal,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: _orange, size: 32),
                    SizedBox(height: 12),
                    Text(
                      'How FlowSlot works',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Use digital bookings to reduce unnecessary waiting and make campus services easier to plan.',
                      style: TextStyle(color: Color(0xFFE8EAEE), height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                color: _orange,
                icon: Icons.edit_calendar_outlined,
                title: 'Student booking flow',
                body:
                    'Choose a department, select a preferred time, enter a reason, and submit the request. Admin approval changes the request from Pending to Booked.',
              ),
              const SizedBox(height: 12),
              _InfoCard(
                color: _aqua,
                icon: Icons.query_stats_outlined,
                title: 'Timing and availability',
                body:
                    'FlowSlot uses the current booking queue and requested time to estimate delay, traffic, and whether the selected hourly slot is already full.',
              ),
              const SizedBox(height: 12),
              _InfoCard(
                color: _lightAqua,
                icon: Icons.lock_clock_outlined,
                title: 'One active booking slot',
                body:
                    'The booking slot system is designed to prevent duplicate active reservations for the same campus service and hour.',
              ),
              const SizedBox(height: 12),
              _InfoCard(
                color: _peach,
                icon: Icons.eco_outlined,
                title: 'SDG 11 connection',
                body:
                    'Digital scheduling can reduce unnecessary campus trips and crowding while making service demand easier to coordinate.',
              ),
              const SizedBox(height: 12),
              _RoleCard(role: role),
            ],
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.info_outline),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(
                    body,
                    style: const TextStyle(color: Color(0xFF4B5563), height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final label = role == 'student'
        ? 'Student'
        : role == 'staff' || role == 'lecturer'
        ? 'Staff'
        : role == 'admin'
        ? 'Admin'
        : role;

    return Card(
      color: const Color(0xFF0DC9C9).withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.verified_user_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Signed in as $label. Public sign-up creates Student accounts; Staff and Admin roles are assigned by the project administrator.',
                style: const TextStyle(color: Color(0xFF374151), height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
