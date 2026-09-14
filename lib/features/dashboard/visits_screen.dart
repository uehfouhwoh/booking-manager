import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_helpers.dart';
import '../../services/database_service.dart';

class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key});

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showEditBookingSheet(String docId, Map<String, dynamic> data) async {
    final nameController = TextEditingController(
      text: bookingRequesterName(data),
    );
    final emailController = TextEditingController(
      text: bookingRequesterEmail(data),
    );
    final detailsController = TextEditingController(
      text: data['serviceDetails'] ?? '',
    );
    final reasonController = TextEditingController(
      text: data['declineReason'] ?? data['cancellationReason'] ?? '',
    );
    String selectedDepartment =
        data['department'] ?? DatabaseService.defaultDepartments.first;
    String selectedStatus = data['status'] ?? 'Waitlist';
    final requesterRole = bookingRequesterRole(data);
    final bookingType = data['bookingType'] == 'staffFacility'
        ? 'staffFacility'
        : 'studentService';
    final options = bookingType == 'staffFacility'
        ? await _dbService.getDepartmentsOnce()        : await _dbService.getDepartmentsOnce();
    if (!options.map((item) => item.trim()).contains(selectedDepartment.trim())) {
      selectedDepartment = options.first;
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Text(
                    'Update Booking',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: requesterRole == 'staff'
                          ? 'Staff Name'
                          : 'Student Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: requesterRole == 'staff'
                          ? 'Staff Email'
                          : 'Student Email',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDepartment,
                    decoration: InputDecoration(
                      labelText: bookingType == 'staffFacility'
                          ? 'Facility'
                          : 'Department',
                    ),
                    isExpanded: true,
                    items: options
                        .map(
                          (dept) =>
                              DropdownMenuItem(value: dept, child: Text(dept)),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setModalState(() => selectedDepartment = value!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items:
                        const [
                              'Pending',
                              'Booked',
                              'Waitlist',
                              'Serving',
                              'Completed',
                              'Cancelled',
                              'Rejected',
                            ]
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(status),
                              ),
                            )
                            .toList(),
                    onChanged: (value) =>
                        setModalState(() => selectedStatus = value!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detailsController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Service Details',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Reason shown if rejected/cancelled',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Changes'),
                    onPressed: () async {
                      try {
                        await _dbService.updateBooking(
                          docId: docId,
                          name: nameController.text.trim(),
                          email: emailController.text.trim(),
                          department: selectedDepartment,
                          status: selectedStatus,
                          serviceDetails: detailsController.text.trim(),
                          bookingType: bookingType,
                          statusReason: reasonController.text.trim(),
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Booking updated successfully.'),
                          ),
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not update booking: $error'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(String docId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Booking'),
        content: Text('Delete the booking for $name? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await _dbService.deleteBooking(docId);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Booking deleted.')),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not delete booking: $error')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeStatus(String docId, String status) async {
    try {
      await _dbService.updateVisitStatus(docId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking marked $status.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update booking: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Booking Command')),
      body: Column(
        children: [
          const _AdminDataHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search name, email, department, or status',
              ),
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _dbService.getLiveQueue(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading bookings: ${snapshot.error}'),
                  );
                }

                var docs = snapshot.data?.docs ?? [];
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final haystack = [
                      bookingRequesterName(data),
                      bookingRequesterEmail(data),
                      bookingRequesterRole(data),
                      data['department'],
                      data['status'],
                    ].join(' ').toLowerCase();
                    return haystack.contains(_searchQuery);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return const Center(child: Text('No booking records found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _BookingAdminCard(
                      docId: doc.id,
                      data: data,
                      onEdit: () => _showEditBookingSheet(doc.id, data),
                      onDelete: () => _confirmDelete(
                        doc.id,
                        bookingRequesterName(data),
                      ),
                      onStatusChanged: (status) => _changeStatus(doc.id, status),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminDataHeader extends StatelessWidget {
  const _AdminDataHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        children: [
          Icon(Icons.dataset_outlined, color: Color(0xFF93C5FD), size: 34),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live booking records',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Search, update status, edit details, or delete records for student services and staff facilities.',
                  style: TextStyle(color: Color(0xFFCBD5E1), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingAdminCard extends StatelessWidget {
  const _BookingAdminCard({
    required this.docId,
    required this.data,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
  });

  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'Unknown';
    final requesterRole = bookingRequesterRole(data);
    final scheduledTime = data['scheduledTime'];
    final dateText = scheduledTime is Timestamp
        ? DateFormat('EEE, MMM d - h:mm a').format(scheduledTime.toDate())
        : 'No scheduled time';
    final canComplete = status == 'Booked' || status == 'Serving';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    bookingRequesterName(data),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                    if (value.startsWith('status:')) {
                      onStatusChanged(value.replaceFirst('status:', ''));
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Update data')),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'status:Waitlist',
                      child: Text('Move to Waitlist'),
                    ),
                    PopupMenuItem(
                      value: 'status:Serving',
                      child: Text('Mark Serving'),
                    ),
                    PopupMenuItem(
                      value: 'status:Completed',
                      child: Text('Mark Completed'),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete record'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              bookingRequesterEmail(data),
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(label: status, color: _statusColor(status)),
                _Chip(
                  label: requesterRole == 'staff' ? 'Staff' : 'Student',
                  color: requesterRole == 'staff' ? Colors.purple : Colors.teal,
                ),
                _Chip(
                  label: data['department'] ?? 'General',
                  color: Colors.blue,
                ),
                _Chip(label: dateText, color: Colors.grey),
              ],
            ),
            if ((data['serviceDetails'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                data['serviceDetails'],
                style: const TextStyle(color: Color(0xFF334155)),
              ),
            ],
            if (canComplete) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.task_alt_outlined),
                  label: const Text('Mark completed'),
                  onPressed: () => onStatusChanged('Completed'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Serving':
      case 'Booked':
        return Colors.blue;
      case 'Pending':
      case 'Waitlist':
        return Colors.orange;
      case 'Cancelled':
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
