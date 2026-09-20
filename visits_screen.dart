import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/app_design.dart';
import '../../core/app_helpers.dart';
import '../../core/responsive_page.dart';
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
  String _statusFilter = 'All';
  String _roleFilter = 'All';

  static const _statusOptions = [
    'All', 'Pending', 'Booked', 'Waitlist', 'Serving', 'Completed',
    'Cancelled', 'Rejected',
  ];
  static const _roleOptions = ['All', 'Student', 'Staff'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> _applyFilters(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      if (_searchQuery.isNotEmpty) {
        final haystack = [
          bookingRequesterName(data),
          bookingRequesterEmail(data),
          bookingRequesterRole(data),
          data['department'],
          data['status'],
        ].join(' ').toLowerCase();
        if (!haystack.contains(_searchQuery)) return false;
      }

      if (_statusFilter != 'All' && data['status'] != _statusFilter) {
        return false;
      }

      if (_roleFilter != 'All') {
        final role = bookingRequesterRole(data);
        if (_roleFilter == 'Staff' && role != 'staff') return false;
        if (_roleFilter == 'Student' && role != 'student') return false;
      }

      return true;
    }).toList();
  }

  Future<void> _exportPdf(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Booking Records Report',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Generated: ${DateFormat('EEE, MMM d yyyy – h:mm a').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.Text(
              'Total records: ${docs.length}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 12),
            pw.Divider(),
          ],
        ),
        build: (_) => docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final scheduled = data['scheduledTime'];
          final dateText = scheduled is Timestamp
              ? DateFormat('EEE, MMM d yyyy – h:mm a').format(scheduled.toDate())
              : 'No scheduled time';
          final status = data['status'] ?? 'Unknown';
          final role = bookingRequesterRole(data);

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      bookingRequesterName(data),
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      status,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: _pdfStatusColor(status),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  bookingRequesterEmail(data),
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Department: ${data['department'] ?? 'N/A'}   '
                  'Role: ${role[0].toUpperCase()}${role.substring(1)}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Scheduled: $dateText',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                if ((data['serviceDetails'] ?? '').toString().isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Details: ${data['serviceDetails']}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  PdfColor _pdfStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return PdfColors.green700;
      case 'Booked':
      case 'Serving':
        return PdfColors.blue700;
      case 'Pending':
      case 'Waitlist':
        return PdfColors.amber700;
      case 'Cancelled':
      case 'Rejected':
        return PdfColors.red700;
      default:
        return PdfColors.grey600;
    }
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
        ? await _dbService.getFacilitiesOnce()
        : await _dbService.getDepartmentsOnce();
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
            return Center(
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
                    const Text(
                      'Update Booking',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
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
                            (dept) => DropdownMenuItem(
                              value: dept,
                              child: Text(dept),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setModalState(() => selectedDepartment = value!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        'Pending', 'Booked', 'Waitlist', 'Serving',
                        'Completed', 'Cancelled', 'Rejected',
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
    return StreamBuilder<QuerySnapshot>(
      stream: _dbService.getLiveQueue(),
      builder: (context, snapshot) {
        final allDocs = snapshot.data?.docs ?? [];
        final filteredDocs = _applyFilters(allDocs);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin Booking Command'),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Export PDF',
                onPressed: filteredDocs.isEmpty
                    ? null
                    : () => _exportPdf(filteredDocs),
              ),
            ],
          ),
          body: ResponsivePageFrame(
            child: Column(
              children: [
                const _AdminDataHeader(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                // Status filter chips
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _statusOptions.map((s) {
                      final selected = _statusFilter == s;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(s),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _statusFilter = s),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                // Role filter chips
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _roleOptions.map((r) {
                      final selected = _roleFilter == r;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(r),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _roleFilter = r),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Builder(
                    builder: (_) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                              'Error loading bookings: ${snapshot.error}'),
                        );
                      }
                      if (filteredDocs.isEmpty) {
                        return const Center(
                          child: Text('No booking records found.'),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _BookingAdminCard(
                            docId: doc.id,
                            data: data,
                            onEdit: () =>
                                _showEditBookingSheet(doc.id, data),
                            onDelete: () => _confirmDelete(
                              doc.id,
                              bookingRequesterName(data),
                            ),
                            onStatusChanged: (status) =>
                                _changeStatus(doc.id, status),
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
      },
    );
  }
}

class _AdminDataHeader extends StatelessWidget {
  const _AdminDataHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: AppSectionHeader(
        icon: Icons.dataset_outlined,
        title: 'Live booking records',
        subtitle:
            'Search, update status, edit details, or delete records for student services and staff facilities.',
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
    final roleColor =
        requesterRole == 'staff' ? AppColors.purple : AppColors.teal;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    requesterRole == 'staff'
                        ? Icons.meeting_room_outlined
                        : Icons.school_outlined,
                    color: roleColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bookingRequesterName(data),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        bookingRequesterEmail(data),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Record actions',
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(label: status, color: _statusColor(status)),
                _Chip(
                  label: requesterRole == 'staff' ? 'Staff' : 'Student',
                  color: roleColor,
                ),
                _Chip(
                  label: data['department'] ?? 'General',
                  color: AppColors.primary,
                ),
                _Chip(label: dateText, color: AppColors.muted),
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
        return AppColors.green;
      case 'Serving':
      case 'Booked':
        return AppColors.primary;
      case 'Pending':
      case 'Waitlist':
        return AppColors.amber;
      case 'Cancelled':
      case 'Rejected':
        return AppColors.red;
      default:
        return AppColors.muted;
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