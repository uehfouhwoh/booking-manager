import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_design.dart';
import '../../core/app_helpers.dart';
import '../../core/responsive_page.dart';
import '../../services/database_service.dart';

class BookingRequestsScreen extends StatefulWidget {
  const BookingRequestsScreen({super.key});

  @override
  State<BookingRequestsScreen> createState() => _BookingRequestsScreenState();
}

class _BookingRequestsScreenState extends State<BookingRequestsScreen> {
  final DatabaseService _dbService = DatabaseService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  String _role = 'student';
  bool _isLoadingRole = true;

  bool get _isAdmin => _role == 'admin';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    if (currentUser != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      if (doc.exists && doc.data()!.containsKey('role')) {
        _role = doc['role'].toString().trim().toLowerCase();
      }
    }

    if (mounted) setState(() => _isLoadingRole = false);
  }

  void _showCancelDialog(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text('Cancel this pending request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await _dbService.cancelServiceRequest(docId);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Request cancelled.')),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not cancel request: $error')),
                );
              }
            },
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(String docId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Booking'),
        content: Text(
          'Approve ${bookingRequesterName(data)} for ${data['department'] ?? 'this service'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _dbService.handleServiceRequest(docId, true);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Booking approved.')),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not approve booking: $error')),
                );
              }
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showDeclineDialog(String docId) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Booking'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason shown to user'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a rejection reason.'),
                  ),
                );
                return;
              }
              try {
                await _dbService.handleServiceRequest(
                  docId,
                  false,
                  declineReason: reasonController.text.trim(),
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Booking rejected.')),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not reject booking: $error')),
                );
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isAdmin ? 'Admin Approvals' : 'My Pending Requests'),
      ),
      body: ResponsivePageFrame(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: AppSectionHeader(
                icon: _isAdmin
                    ? Icons.fact_check_outlined
                    : Icons.pending_actions_outlined,
                title: _isAdmin ? 'Approval queue' : 'Pending requests',
                subtitle: _isAdmin
                    ? 'Review student service and staff facility requests before they become confirmed bookings.'
                    : 'Track requests waiting for admin approval.',
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _isAdmin
                    ? _dbService.getPendingRequests()
                    : _dbService.getUserBookings(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Database error: ${snapshot.error}'),
                    );
                  }

                  var docs = snapshot.data?.docs ?? [];
                  if (!_isAdmin) {
                    docs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return bookingBelongsTo(
                            data,
                            email: currentUser?.email,
                            uid: currentUser?.uid,
                          ) &&
                          data['status'] == 'Pending' &&
                          !bookingHiddenFor(
                            data,
                            email: currentUser?.email,
                            uid: currentUser?.uid,
                          );
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return _EmptyApprovals(isAdmin: _isAdmin);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return _ApprovalCard(
                        data: data,
                        isAdmin: _isAdmin,
                        onApprove: () => _showApproveDialog(doc.id, data),
                        onDecline: () => _showDeclineDialog(doc.id),
                        onCancel: () => _showCancelDialog(doc.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatefulWidget {
  const _ApprovalCard({
    required this.data,
    required this.isAdmin,
    required this.onApprove,
    required this.onDecline,
    required this.onCancel,
  });

  final Map<String, dynamic> data;
  final bool isAdmin;
  final VoidCallback onApprove;
  final VoidCallback onDecline;
  final VoidCallback onCancel;

  @override
  State<_ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends State<_ApprovalCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final scheduled = data['scheduledTime'];
    final timeText = scheduled is Timestamp
        ? DateFormat('EEE, MMM d - h:mm a').format(scheduled.toDate())
        : 'No time selected';
    final startsInMins = scheduled is Timestamp
        ? minutesUntil(scheduled.toDate())
        : (data['minutesUntilAppointment'] as int?) ?? 0;
    final isFacility = data['bookingType'] == 'staffFacility';
    final accent = isFacility ? AppColors.purple : AppColors.primary;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        child: Card(
          margin: const EdgeInsets.only(bottom: 14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        isFacility
                            ? Icons.meeting_room_outlined
                            : Icons.school_outlined,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['department'] ?? 'Booking',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            bookingRequesterName(data),
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const AppPill(label: 'Pending', color: AppColors.amber),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  bookingRequesterEmail(data),
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        timeText,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text('${formatDurationReadable(startsInMins)} until start'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: AppColors.green,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${formatDurationReadable(data['serviceDelayMins'] ?? data['estimatedWaitMins'] ?? 0)} queue delay',
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.auto_graph_outlined,
                      size: 16,
                      color: AppColors.amber,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(data['trafficLevel'] ?? 'Traffic pending'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    data['serviceDetails'] ?? 'No additional details provided.',
                  ),
                ),
                const SizedBox(height: 14),
                if (widget.isAdmin)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.close),
                          label: const Text('Reject'),
                          onPressed: widget.onDecline,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                          onPressed: widget.onApprove,
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel request'),
                      onPressed: widget.onCancel,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyApprovals extends StatelessWidget {
  const _EmptyApprovals({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_outlined,
              size: 72,
            color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              isAdmin
                  ? 'No bookings waiting for approval.'
                  : 'No pending requests.',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              isAdmin
                  ? 'New student and staff requests will appear here.'
                  : 'Your new requests will appear here until admin approves them.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
