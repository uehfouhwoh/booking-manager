import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  DateTimeRange? _dateRange;

  User? get _user => FirebaseAuth.instance.currentUser;

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  void _clearDateRange() => setState(() => _dateRange = null);

  List<QueryDocumentSnapshot> _applyDateFilter(
      List<QueryDocumentSnapshot> docs) {
    if (_dateRange == null) return docs;
    final start = _dateRange!.start;
    final end = DateTime(
      _dateRange!.end.year,
      _dateRange!.end.month,
      _dateRange!.end.day,
      23,
      59,
      59,
    );
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final scheduled = data['scheduledTime'];
      if (scheduled is! Timestamp) return false;
      final date = scheduled.toDate();
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

  Future<void> _exportPdf(List<QueryDocumentSnapshot> docs) async {
    final filtered = _applyDateFilter(docs);
    if (filtered.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No records in the selected date range.')),
      );
      return;
    }

    final pdf = pw.Document();
    final dateRangeLabel = _dateRange != null
        ? '${DateFormat('MMM d, yyyy').format(_dateRange!.start)} – '
            '${DateFormat('MMM d, yyyy').format(_dateRange!.end)}'
        : 'All dates';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              widget.showHidden ? 'Hidden Bookings' : 'Booking History',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Period: $dateRangeLabel',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.Text(
              'Generated: ${DateFormat('EEE, MMM d yyyy – h:mm a').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.Text(
              'Records: ${filtered.length}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 12),
            pw.Divider(),
          ],
        ),
        build: (_) => filtered.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final scheduled = data['scheduledTime'];
          final dateText = scheduled is Timestamp
              ? DateFormat('EEE, MMM d yyyy – h:mm a')
                  .format(scheduled.toDate())
              : 'No scheduled time';
          final status = data['status'] ?? 'Unknown';
          final service = data['department'] ?? 'General';
          final bookingType = data['bookingType'] ?? 'studentService';
          final isFacility = bookingType == 'staffFacility';

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      service,
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
                  'Type: ${isFacility ? 'Staff Facility' : 'Student Service'}',
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey700),
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
                        fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
                if (data['declineReason'] != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Rejection reason: ${data['declineReason']}',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.red),
                  ),
                ],
                if (data['cancellationReason'] != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Cancellation reason: ${data['cancellationReason']}',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.red),
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
                  const SnackBar(
                      content: Text('Booking hidden from history.')),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Could not hide booking: $error')),
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
                  SnackBar(
                      content: Text('Could not restore booking: $error')),
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

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('queue')
          .orderBy('joinedAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        final allDocs = ((snapshot.data?.docs ?? [])).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final hidden = bookingHiddenFor(
            data,
            email: user?.email,
            uid: user?.uid,
          );
          return bookingBelongsTo(
                data,
                email: user?.email,
                uid: user?.uid,
              ) &&
              hidden == widget.showHidden;
        }).toList();

        allDocs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final timeA = dataA['joinedAt'] as Timestamp?;
          final timeB = dataB['joinedAt'] as Timestamp?;
          if (timeA == null || timeB == null) return 0;
          return timeB.compareTo(timeA);
        });

        final visibleDocs = _applyDateFilter(allDocs);

        return Scaffold(
          appBar: AppBar(
            title: Text(
                widget.showHidden ? 'Hidden Bookings' : 'Booking History'),
            actions: [
              if (allDocs.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  tooltip: 'Export PDF',
                  onPressed: () => _exportPdf(allDocs),
                ),
            ],
          ),
          body: Builder(
            builder: (_) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text('Database error: ${snapshot.error}'));
              }

              return Column(
                children: [
                  // Date filter bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.date_range_outlined,
                                size: 18),
                            label: Text(
                              _dateRange == null
                                  ? 'Filter by date'
                                  : '${DateFormat('MMM d').format(_dateRange!.start)} – '
                                      '${DateFormat('MMM d, yyyy').format(_dateRange!.end)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: _pickDateRange,
                          ),
                        ),
                        if (_dateRange != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Clear date filter',
                            onPressed: _clearDateRange,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_dateRange != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Text(
                        '${visibleDocs.length} of ${allDocs.length} records',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  Expanded(
                    child: visibleDocs.isEmpty
                        ? Center(
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
                                  _dateRange != null
                                      ? 'No bookings in this date range.'
                                      : widget.showHidden
                                          ? 'No hidden bookings.'
                                          : 'No booking history yet.',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                                if (widget.showHidden &&
                                    _dateRange == null) ...[
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Hidden bookings will appear here after you hide them.',
                                    textAlign: TextAlign.center,
                                    style:
                                        TextStyle(color: Color(0xFF64748B)),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: visibleDocs.length,
                            itemBuilder: (context, index) {
                              final doc = visibleDocs[index];
                              final data =
                                  doc.data() as Map<String, dynamic>;
                              return _HistoryCard(
                                data: data,
                                isHiddenView: widget.showHidden,
                                onHide: () => _showHideDialog(doc.id, data),
                                onRestore: () =>
                                    _showRestoreDialog(doc.id, data),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
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
                      isHiddenView
                          ? 'Restore to history'
                          : 'Hide from my view',
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