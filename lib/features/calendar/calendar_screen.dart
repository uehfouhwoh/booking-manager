import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_helpers.dart';
import '../../services/database_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final DatabaseService _dbService = DatabaseService();
  DateTime _selectedDate = malaysiaNow();
  String _role = 'student';
  bool _isLoadingRole = true;

  bool get _isStaff => _role == 'staff';
  bool get _isAdmin => _role == 'admin';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
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
    if (mounted) setState(() => _isLoadingRole = false);
  }

  Future<void> _showBookingSheet() async {
    final user = FirebaseAuth.instance.currentUser;
    final nameController = TextEditingController(text: user?.displayName ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final serviceDetailsController = TextEditingController();
    final bookingType = _isStaff ? 'staffFacility' : 'studentService';
    final options = _isStaff
        ? await _dbService.getDepartmentsOnce()
        : await _dbService.getDepartmentsOnce();
    if (options.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No booking options found.')),
        );
      }
      return;
    }
    String selectedService = options.first;
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    BookingEstimate estimate = await _dbService.calculateEstimate(
      department: selectedService,
      requestedTime: _composeDateTime(selectedTime),
      bookingType: bookingType,
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> refreshEstimate() async {
              final nextEstimate = await _dbService.calculateEstimate(
                department: selectedService,
                requestedTime: _composeDateTime(selectedTime),
                bookingType: bookingType,
              );
              if (context.mounted) {
                setModalState(() => estimate = nextEstimate);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    _isStaff ? 'Book Staff Facility' : 'Book Campus Service',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isStaff
                        ? 'Reserve rooms, labs, or equipment. Admin will approve the facility request.'
                        : 'Choose a service and preferred time. Admin approves the request before it becomes booked.',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: _isStaff ? 'Staff Name' : 'Student Name',
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    readOnly: true,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedService,
                    decoration: InputDecoration(
                      labelText: _isStaff ? 'Facility' : 'Department / Service',
                      prefixIcon: Icon(
                        serviceIcon(selectedService, bookingType: bookingType),
                      ),
                    ),
                    isExpanded: true,
                    items: options
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Row(
                              children: [
                                Icon(
                                  serviceIcon(item, bookingType: bookingType),
                                  size: 18,
                                  color: serviceColor(
                                    item,
                                    bookingType: bookingType,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(item),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setModalState(() => selectedService = value!);
                      refreshEstimate();
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: serviceDetailsController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: _isStaff
                          ? 'Purpose / Facility Notes'
                          : 'Reason / Service Details',
                      prefixIcon: const Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: const Icon(Icons.access_time),
                    title: const Text('Preferred Time'),
                    subtitle: const Text('Malaysia time'),
                    trailing: Text(
                      selectedTime.format(context),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setModalState(() => selectedTime = picked);
                        refreshEstimate();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _EstimatePanel(estimate: estimate),
                  if (estimate.isFullyBooked) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'This slot is fully booked. Choose another time to avoid rejection.',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.send_outlined),
                    label: Text(
                      _isStaff
                          ? 'Send Facility Request'
                          : 'Send Booking Request',
                    ),
                    onPressed: estimate.isFullyBooked
                        ? null
                        : () async {
                            if (nameController.text.trim().isEmpty ||
                                emailController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter name and email.'),
                                ),
                              );
                              return;
                            }

                            final appointmentTime = _composeDateTime(
                              selectedTime,
                            );
                            if (!appointmentTime.isAfter(malaysiaNow())) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please choose a future booking time.',
                                  ),
                                ),
                              );
                              return;
                            }

                            try {
                              await _dbService.requestService(
                                nameController.text.trim(),
                                user?.email ?? emailController.text.trim(),
                                selectedService,
                                appointmentTime,
                                serviceDetailsController.text.trim(),
                                uid: user?.uid,
                                bookingType: bookingType,
                              );

                              if (context.mounted) {
                                Navigator.pop(context);
                                _showResultDialog(estimate, appointmentTime);
                              }
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Booking could not be sent: $error',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
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

  DateTime _composeDateTime(TimeOfDay time) {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      time.hour,
      time.minute,
    );
  }

  void _showResultDialog(BookingEstimate estimate, DateTime appointmentTime) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Sent'),
        content: Text(
          'Status: Pending admin approval\n'
          'Appointment: ${formatMalaysiaDateTime(appointmentTime)}\n'
          'Starts in: ${formatDurationReadable(estimate.minutesUntilAppointment)}\n'
          'Queue delay: ${formatDurationReadable(estimate.serviceDelayMins)}\n'
          'Slot: ${estimate.availabilityLabel}\n'
          'Peak traffic: ${estimate.trafficLevel}\n'
          'Sustainability impact: ${estimate.co2SavedKg} kg CO2 saved',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(String docId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Text(
          'Cancel ${data['department'] ?? 'this booking'}? It will remain visible in history as Cancelled.',
        ),
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
                  const SnackBar(content: Text('Booking cancelled.')),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not cancel booking: $error')),
                );
              }
            },
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
  }

  void _showCompleteDialog(String docId, Map<String, dynamic> data) {
    final isFacility = data['bookingType'] == 'staffFacility';
    final service = data['department'] ?? 'this booking';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isFacility ? 'Complete Facility Use' : 'Complete Service'),
        content: Text(
          isFacility
              ? 'Mark $service as completed after you finish using it?'
              : 'Mark $service as completed after your appointment is finished?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _dbService.completeServiceRequest(docId);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isFacility
                          ? 'Facility use marked completed.'
                          : 'Service marked completed.',
                    ),
                  ),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not complete booking: $error')),
                );
              }
            },
            child: Text(isFacility ? 'Done using facility' : 'Service done'),
          ),
        ],
      ),
    );
  }

  void _showSheet(BuildContext context) {
    String type = 'Feedback';
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                items: ['Feedback', 'Complaint']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setModalState(() => type = val!),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('feedback').add({
                    'type': type,
                    'message': controller.text.trim(),
                    'timestamp': FieldValue.serverTimestamp(),
                    'authorUid': FirebaseAuth.instance.currentUser?.uid,
                    'email': FirebaseAuth.instance.currentUser?.email,
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Feedback submitted.')),
                    );
                  }
                },
                child: const Text('Submit'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = FirebaseAuth.instance.currentUser;
    final title = _isStaff ? 'Staff Facilities' : 'Student Booking';
    final bookingType = _isStaff ? 'staffFacility' : 'studentService';
    final optionsStream = _isStaff
        ? _dbService.getDepartments()
        : _dbService.getDepartments();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_isStaff)
            TextButton.icon(
              icon: const Icon(Icons.feedback_outlined),
              onPressed: () => _showSheet(context),
              label: const Text('Provide feedback'),
            ),
        ],
      ),
      body: StreamBuilder<List<String>>(
        stream: optionsStream,
        builder: (context, optionsSnapshot) {
          final serviceOptions =
              optionsSnapshot.data ??
              (_isStaff
                  ? DatabaseService.defaultDepartments
                  : DatabaseService.defaultDepartments);

          return Column(
            children: [
              _RoleBookingHeader(isStaff: _isStaff),
              _DateScroller(
                selectedDate: _selectedDate,
                onChanged: (date) => setState(() => _selectedDate = date),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _dbService.getQueueForRole(
                    role: _role,
                    email: user?.email ?? '',
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data?.docs ?? [];
                    final visibleBookings = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final scheduled = data['scheduledTime'];
                      if (scheduled is! Timestamp) return false;
                      final date = scheduled.toDate();
                      final sameDay =
                          date.year == _selectedDate.year &&
                          date.month == _selectedDate.month &&
                          date.day == _selectedDate.day;
                      if (!sameDay) return false;
                      if (_isAdmin) return true;
                      return bookingBelongsTo(
                            data,
                            email: user?.email,
                            uid: user?.uid,
                          ) &&
                          !bookingHiddenFor(
                            data,
                            email: user?.email,
                            uid: user?.uid,
                          );
                    }).toList();

                    visibleBookings.sort((a, b) {
                      final dataA = a.data() as Map<String, dynamic>;
                      final dataB = b.data() as Map<String, dynamic>;
                      final timeA = dataA['scheduledTime'] as Timestamp;
                      final timeB = dataB['scheduledTime'] as Timestamp;
                      return timeA.compareTo(timeB);
                    });

                    return Column(
                      children: [
                        _AvailabilityStrip(
                          docs: docs,
                          selectedDate: _selectedDate,
                          options: serviceOptions,
                          bookingType: bookingType,
                          isStaff: _isStaff,
                        ),
                        Expanded(
                          child: visibleBookings.isEmpty
                              ? _EmptyBookings(isStaff: _isStaff)
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: visibleBookings.length,
                                  itemBuilder: (context, index) {
                                    final doc = visibleBookings[index];
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    return _BookingCard(
                                      docId: doc.id,
                                      data: data,
                                      canCancel: !_isAdmin,
                                      onCancel: () =>
                                          _showCancelDialog(doc.id, data),
                                      onComplete: () =>
                                          _showCompleteDialog(doc.id, data),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showBookingSheet,
        icon: Icon(_isStaff ? Icons.meeting_room_outlined : Icons.add),
        label: Text(_isStaff ? 'Book Facility' : 'Book Service'),
      ),
    );
  }
}

class _EstimatePanel extends StatelessWidget {
  const _EstimatePanel({required this.estimate});

  final BookingEstimate estimate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showEstimateDetails(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_graph_outlined, color: Color(0xFF047857)),
                SizedBox(width: 10),
                Text(
                  'Live Booking Estimate',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                Spacer(),
                Icon(
                  Icons.touch_app_outlined,
                  size: 18,
                  color: Color(0xFF047857),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _EstimateItem(
                    label: 'Starts in',
                    value: formatDurationReadable(
                      estimate.minutesUntilAppointment,
                    ),
                  ),
                ),
                Expanded(
                  child: _EstimateItem(
                    label: 'Queue delay',
                    value: formatDurationReadable(estimate.serviceDelayMins),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              estimate.availabilityLabel,
              style: TextStyle(
                color: estimate.isFullyBooked
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF047857),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Peak traffic: ${estimate.trafficLevel} - ${estimate.peakLabel}',
              style: const TextStyle(color: Color(0xFF475569)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEstimateDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How this estimate works'),
        content: const Text(
          'Starts in is the real time from now in Malaysia to your selected appointment.\n\n'
          'Queue delay is different. It counts active bookings already in the same department or facility hour. If nobody is ahead in that slot, it is 0 min.\n\n'
          'Peak traffic is a separate prediction for busy campus hours. It helps you choose a better time, but it is not your personal waiting time.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _RoleBookingHeader extends StatelessWidget {
  const _RoleBookingHeader({required this.isStaff});

  final bool isStaff;

  @override
  Widget build(BuildContext context) {
    final color = isStaff ? const Color(0xFF7C3AED) : const Color(0xFF0F766E);
    final accent = isStaff ? const Color(0xFFDB2777) : const Color(0xFF2563EB);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              isStaff ? Icons.meeting_room_outlined : Icons.school_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isStaff ? 'Facility reservations' : 'Campus service booking',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isStaff
                      ? 'Book rooms, labs, equipment, and event spaces from the staff facility list.'
                      : 'Book Academic Advising, IT Helpdesk, Finance, and other student departments.',
                  style: const TextStyle(
                    color: Color(0xFFEFF6FF),
                    height: 1.32,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityStrip extends StatelessWidget {
  const _AvailabilityStrip({
    required this.docs,
    required this.selectedDate,
    required this.options,
    required this.bookingType,
    required this.isStaff,
  });

  final List<QueryDocumentSnapshot> docs;
  final DateTime selectedDate;
  final List<String> options;
  final String bookingType;
  final bool isStaff;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 126,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        scrollDirection: Axis.horizontal,
        children: options.map((service) {
          final bookings = _bookingsFor(service);
          final count = bookings.length;
          final color = serviceColor(service, bookingType: bookingType);

          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showAvailabilityDetails(context, service, bookings),
            child: Container(
              width: 178,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: count == 0
                      ? const Color(0xFFBBF7D0)
                      : const Color(0xFFBFDBFE),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    serviceIcon(service, bookingType: bookingType),
                    color: color,
                  ),
                  const Spacer(),
                  Text(
                    service,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 0
                        ? 'Available today'
                        : '$count booking${count == 1 ? '' : 's'} today',
                    style: TextStyle(
                      color: count == 0
                          ? const Color(0xFF059669)
                          : const Color(0xFF2563EB),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Map<String, dynamic>> _bookingsFor(String service) {
    final bookings = docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .where((data) {
          final scheduled = data['scheduledTime'];
          if (scheduled is! Timestamp) return false;
          final date = scheduled.toDate();
          final sameDay =
              date.year == selectedDate.year &&
              date.month == selectedDate.month &&
              date.day == selectedDate.day;
          final active =
              data['status'] == 'Pending' ||
              data['status'] == 'Booked' ||
              data['status'] == 'Serving';
          return sameDay &&
              active &&
              (data['bookingType'] ?? 'studentService') == bookingType &&
              data['department']?.toString().trim() == service.trim();
        })
        .toList();

    bookings.sort((a, b) {
      final timeA = a['scheduledTime'] as Timestamp;
      final timeB = b['scheduledTime'] as Timestamp;
      return timeA.compareTo(timeB);
    });
    return bookings;
  }

  void _showAvailabilityDetails(
    BuildContext context,
    String service,
    List<Map<String, dynamic>> bookings,
  ) {
    final title = isStaff ? 'Facility availability' : 'Department bookings';
    final emptyText = isStaff
        ? '$service has no active facility bookings for this selected day.'
        : '$service has no active student bookings for this selected day.';
    final bookingLines = bookings
        .take(6)
        .map((data) {
          final scheduled = data['scheduledTime'] as Timestamp;
          final time = DateFormat('h:mm a').format(scheduled.toDate());
          final status = data['status'] ?? 'Pending';
          final requester = bookingRequesterName(data);
          return '$time - $status - $requester';
        })
        .join('\n');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(service),
        content: Text(
          bookings.isEmpty
              ? emptyText
              : '$title\n\n$bookingLines${bookings.length > 6 ? '\n...' : ''}',
        ),
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

class _EstimateItem extends StatelessWidget {
  const _EstimateItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF065F46),
          ),
        ),
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.docId,
    required this.data,
    required this.canCancel,
    required this.onCancel,
    required this.onComplete,
  });

  final String docId;
  final Map<String, dynamic> data;
  final bool canCancel;
  final VoidCallback onCancel;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final scheduled = data['scheduledTime'] as Timestamp;
    final scheduledDate = scheduled.toDate();
    final status = data['status'] ?? 'Pending';
    final service = data['department'] ?? 'Booking';
    final bookingType = data['bookingType'] ?? 'studentService';
    final color = statusColor(status);
    final canCancelBooking =
        canCancel && (status == 'Pending' || status == 'Booked');
    final canCompleteBooking =
        canCancel && (status == 'Booked' || status == 'Serving');
    final startsInMins = minutesUntil(scheduledDate);
    final delayMins =
        (data['serviceDelayMins'] as int?) ??
        (data['estimatedWaitMins'] as int?) ??
        0;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showBookingDetails(context, scheduledDate, service, status),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatMalaysiaDateTime(scheduledDate),
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(label: status, color: color),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                data['serviceDetails'] ?? 'No details provided.',
                style: const TextStyle(color: Color(0xFF334155)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  _MiniInfo(
                    icon: Icons.schedule_outlined,
                    text: '${formatDurationReadable(startsInMins)} until start',
                  ),
                  _MiniInfo(
                    icon: Icons.hourglass_bottom_outlined,
                    text: '${formatDurationReadable(delayMins)} queue delay',
                  ),
                  _MiniInfo(
                    icon: Icons.eco_outlined,
                    text: '${data['co2SavedKg'] ?? 0.6} kg CO2 saved',
                  ),
                ],
              ),
              if (status == 'Rejected' && data['declineReason'] != null) ...[
                const SizedBox(height: 10),
                _ReasonBox(text: 'Admin reason: ${data['declineReason']}'),
              ],
              if (status == 'Cancelled' &&
                  data['cancellationReason'] != null) ...[
                const SizedBox(height: 10),
                _ReasonBox(text: data['cancellationReason']),
              ],
              if (canCancelBooking || canCompleteBooking) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (canCancelBooking)
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancel'),
                          onPressed: onCancel,
                        ),
                      ),
                    if (canCancelBooking && canCompleteBooking)
                      const SizedBox(width: 10),
                    if (canCompleteBooking)
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.task_alt_outlined),
                          label: Text(
                            bookingType == 'staffFacility'
                                ? 'Done using'
                                : 'Service done',
                          ),
                          onPressed: onComplete,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showBookingDetails(
    BuildContext context,
    DateTime scheduled,
    String service,
    String status,
  ) {
    final startsIn = minutesUntil(scheduled);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(service),
        content: Text(
          'Status: $status\n'
          '${statusMeaning(status)}\n\n'
          'Appointment: ${formatMalaysiaDateTime(scheduled)}\n'
          'Starts in: ${formatDurationReadable(startsIn)}\n\n'
          'If this is Pending, admin has not approved it yet.',
        ),
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

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
        ),
      ],
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

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
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyBookings extends StatelessWidget {
  const _EmptyBookings({required this.isStaff});

  final bool isStaff;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isStaff
                  ? Icons.meeting_room_outlined
                  : Icons.event_available_outlined,
              size: 72,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              isStaff
                  ? 'No facility bookings for this day.'
                  : 'No bookings for this day.',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              isStaff
                  ? 'Book a room, lab, or equipment slot.'
                  : 'Book a service and it will appear here immediately.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateScroller extends StatelessWidget {
  const _DateScroller({required this.selectedDate, required this.onChanged});

  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: 31,
        itemBuilder: (context, index) {
          final date = malaysiaNow().add(Duration(days: index));
          final selected =
              date.day == selectedDate.day &&
              date.month == selectedDate.month &&
              date.year == selectedDate.year;
          return GestureDetector(
            onTap: () => onChanged(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 64,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : const Color(0xFFE5E7EB),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(date).toUpperCase(),
                    style: TextStyle(
                      color: selected
                          ? Colors.white70
                          : const Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF111827),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
