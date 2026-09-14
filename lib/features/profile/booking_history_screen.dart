import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_helpers.dart';
import '../../services/database_service.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key, this.showHidden = false});

  final bool showHidden;

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  final DatabaseService _dbService = DatabaseService();

  User? get _user => FirebaseAuth.instance.currentUser;

  void _showHideDialog(String docId, Map<String, dynamic> data) {
    final service = data['department'] ?? 'this booking';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hide Booking'),
        content: Text(
          'Hide $service from your booking history? This only cleans your view. Admin records stay available for reporting.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _dbService.hideBookingForUser(
                  docId: docId,
                  uid: _user?.uid ?? '',
                  email: _user?.email ?? '',
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Booking hidden from history.')),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not hide booking: $error')),
                );
              }
            },
            child: const Text('Hide'),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(String docId, Map<String, dynamic> data) {
    final service = data['department'] ?? 'this booking';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Booking'),
        content: Text(
          'Restore $service to your normal booking history and insights?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep hidden'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _dbService.restoreBookingForUser(
                  docId: docId,
                  uid: _user?.uid ?? '',
                  email: _user?.email ?? '',
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Booking restored.')),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not restore booking: $error')),
                );
              }
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showHidden ? 'Hidden Bookings' : 'Booking History'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('queue')
            .orderBy('joinedAt', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Database error: ${snapshot.error}'));
          }

          final docs = (snapshot.data?.docs ?? []).where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final hidden = bookingHiddenFor(
              data,
              email: user?.email,
              uid: user?.uid,
            );
            return bookingBelongsTo(data, email: user?.email, uid: user?.uid) &&
                hidden == widget.showHidden;
          }).toList();
          docs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final timeA = dataA['joinedAt'] as Timestamp?;
            final timeB = dataB['joinedAt'] as Timestamp?;
            if (timeA == null || timeB == null) return 0;
            return timeB.compareTo(timeA);
          });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_toggle_off,
                    size: 68,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.showHidden
                        ? 'No hidden bookings.'
                        : 'No booking history yet.',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (widget.showHidden) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Hidden bookings will appear here after you hide them.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _HistoryCard(
                data: data,
                isHiddenView: widget.showHidden,
                onHide: () => _showHideDialog(doc.id, data),
                onRestore: () => _showRestoreDialog(doc.id, data),
              );
            },
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.data,
    required this.isHiddenView,
    required this.onHide,
    required this.onRestore,
  });

  final Map<String, dynamic> data;
  final bool isHiddenView;
  final VoidCallback onHide;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'Unknown';
    final service = data['department'] ?? 'General';
    final bookingType = data['bookingType'] ?? 'studentService';
    final details = data['serviceDetails'] ?? 'No details provided';
    final scheduled = data['scheduledTime'];
    final scheduledDate = scheduled is Timestamp ? scheduled.toDate() : null;
    final dateText = scheduled is Timestamp
        ? DateFormat('MMM d, yyyy - h:mm a').format(scheduled.toDate())
        : 'No scheduled time';
    final color = statusColor(status);
    final now = malaysiaNow();
    final today = DateTime(now.year, now.month, now.day);
    final inactive =
        status == 'Completed' || status == 'Cancelled' || status == 'Rejected';
    final canHide =
        inactive || (scheduledDate != null && scheduledDate.isBefore(today));

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showDetails(context),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: serviceColor(
                      service,
                      bookingType: bookingType,
                    ).withValues(alpha: 0.12),
                    child: Icon(
                      serviceIcon(service, bookingType: bookingType),
                      color: serviceColor(service, bookingType: bookingType),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          dateText,
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(details, style: const TextStyle(color: Color(0xFF334155))),
              if (data['declineReason'] != null) ...[
                const SizedBox(height: 12),
                _ReasonBox(text: 'Admin reason: ${data['declineReason']}'),
              ],
              if (data['cancellationReason'] != null) ...[
                const SizedBox(height: 12),
                _ReasonBox(text: data['cancellationReason']),
              ],
              if (canHide || isHiddenView) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    icon: Icon(
                      isHiddenView
                          ? Icons.restore_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    label: Text(
                      isHiddenView ? 'Restore to history' : 'Hide from my view',
                    ),
                    onPressed: isHiddenView ? onRestore : onHide,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final status = data['status'] ?? 'Unknown';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['department'] ?? 'Booking'),
        content: Text(statusMeaning(status)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ReasonBox extends StatelessWidget {
  const _ReasonBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF991B1B),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
