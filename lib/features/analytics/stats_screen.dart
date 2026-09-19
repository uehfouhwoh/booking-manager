import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_helpers.dart';
import '../../core/report_exporter.dart';
import '../../core/responsive_page.dart';
import '../../services/database_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  DateTime _selectedDate = malaysiaNow();
  DateTime _fromDate = DateTime(malaysiaNow().year, malaysiaNow().month, 1);
  DateTime _toDate = malaysiaNow();
  String _role = 'student';
  String _adminTypeFilter = 'all';
  bool _isLoadingRole = true;
  final DatabaseService _dbService = DatabaseService();

  bool get _isAdmin => _role == 'admin';
  bool get _isStaff => _role == 'staff' || _role == 'lecturer';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
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

  List<QueryDocumentSnapshot> _docsInReportRange(
    List<QueryDocumentSnapshot> docs,
  ) {
    final from = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final to = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final scheduled = data['scheduledTime'];
      if (scheduled is! Timestamp) return false;
      final date = scheduled.toDate();
      return !date.isBefore(from) && !date.isAfter(to);
    }).toList();
  }

  String _buildReportText(List<QueryDocumentSnapshot> docs) {
    final reportDocs = _docsInReportRange(docs);
    final pending = _statusCount(reportDocs, 'Pending');
    final booked = _statusCount(reportDocs, 'Booked');
    final serving = _statusCount(reportDocs, 'Serving');
    final completed = _statusCount(reportDocs, 'Completed');
    final cancelled = reportDocs.where((doc) {
      final status = (doc.data() as Map<String, dynamic>)['status'];
      return status == 'Cancelled' || status == 'Rejected';
    }).length;
    final staff = reportDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['bookingType'] == 'staffFacility';
    }).length;
    final resourceDemand = _resourceDemand(reportDocs);
    final lines = <String>[
      'FlowSlot Campus Report',
      'Role: ${_isAdmin
          ? 'Admin'
          : _isStaff
          ? 'Staff'
          : 'Student'}',
      'Date from: ${DateFormat('MMM d, yyyy').format(_fromDate)}',
      'Date to: ${DateFormat('MMM d, yyyy').format(_toDate)}',
      'Generated: ${DateFormat('MMM d, yyyy h:mm a').format(malaysiaNow())}',
      '',
      'Summary',
      'Total records: ${reportDocs.length}',
      'Pending approval: $pending',
      'Approved bookings: $booked',
      'Serving: $serving',
      'Completed: $completed',
      'Cancelled or rejected: $cancelled',
      'Student service records: ${reportDocs.length - staff}',
      'Staff facility records: $staff',
      'Estimated CO2 saved: ${_co2Saved(reportDocs)} kg',
      '',
      'Top facilities and services',
    ];

    final resources = resourceDemand.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (resources.isEmpty) {
      lines.add('No records in this date range.');
    } else {
      for (final item in resources.take(10)) {
        lines.add('${item.key}: ${item.value}');
      }
    }

    lines.addAll(['', 'Records']);
    for (final doc in reportDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final scheduled = data['scheduledTime'] as Timestamp;
      lines.add(
        '${DateFormat('yyyy-MM-dd h:mm a').format(scheduled.toDate())} | '
        '${data['status'] ?? 'Unknown'} | '
        '${data['department'] ?? 'General'} | '
        '${bookingRequesterName(data)} | ${bookingRequesterEmail(data)}',
      );
    }
    return lines.join('\n');
  }

  Future<void> _downloadReport(List<QueryDocumentSnapshot> docs) async {
    final content = _buildReportText(docs);
    await downloadTextReport(
      filename:
          'flowslot-report-${DateFormat('yyyy-MM-dd').format(_fromDate)}-to-${DateFormat('yyyy-MM-dd').format(_toDate)}.txt',
      content: content,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Report download started.')));
  }

  Future<void> _printReport(List<QueryDocumentSnapshot> docs) async {
    await printTextReport(_buildReportText(docs));
  }

  void _showMonthlyReportSheet(List<QueryDocumentSnapshot> docs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickDate({required bool isFrom}) async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime(2024),
              lastDate: DateTime(2035),
              initialDate: isFrom ? _fromDate : _toDate,
            );
            if (picked == null) return;
            setState(() {
              if (isFrom) {
                _fromDate = picked;
                if (_fromDate.isAfter(_toDate)) _toDate = picked;
              } else {
                _toDate = picked;
                if (_toDate.isBefore(_fromDate)) _fromDate = picked;
              }
            });
            setModalState(() {});
          }

          final reportDocs = _docsInReportRange(docs);
          final content = _buildReportText(docs);
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.82,
            minChildSize: 0.45,
            maxChildSize: 0.95,
            builder: (context, scrollController) => ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                const Text(
                  'Monthly Report',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  '${reportDocs.length} record${reportDocs.length == 1 ? '' : 's'} from ${DateFormat('MMM d, yyyy').format(_fromDate)} to ${DateFormat('MMM d, yyyy').format(_toDate)}',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range_outlined),
                        label: Text(DateFormat('MMM d').format(_fromDate)),
                        onPressed: () => pickDate(isFrom: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event_available_outlined),
                        label: Text(DateFormat('MMM d').format(_toDate)),
                        onPressed: () => pickDate(isFrom: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Download'),
                        onPressed: () => _downloadReport(docs),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('Print PDF'),
                        onPressed: () => _printReport(docs),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    content,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
        title: Text(_isAdmin ? 'Campus Insights' : 'My Booking Insights'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _dbService.getQueueForRole(
          role: _role,
          email: FirebaseAuth.instance.currentUser?.email ?? '',
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Insights unavailable: ${snapshot.error}'),
            );
          }

          final user = FirebaseAuth.instance.currentUser;
          final allDocs = snapshot.data?.docs ?? [];
          if (_isAdmin) {
            return _buildAdminInsights(allDocs);
          }

          var docs = allDocs;

          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return bookingBelongsTo(data, email: user?.email, uid: user?.uid) &&
                !bookingHiddenFor(data, email: user?.email, uid: user?.uid);
          }).toList();

          final selectedDocs = docs
              .where(
                (doc) => _isSameSelectedDay(doc.data() as Map<String, dynamic>),
              )
              .toList();
          final activeTimingDocs = selectedDocs.where((doc) {
            final status = (doc.data() as Map)['status'];
            return status == 'Pending' ||
                status == 'Booked' ||
                status == 'Serving' ||
                status == 'Waitlist';
          }).toList();
          final selectedTrafficDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'];
            final active = status != 'Cancelled' && status != 'Rejected';
            return active && _isSameSelectedDay(data);
          }).toList();
          final pending = selectedDocs
              .where((doc) => (doc.data() as Map)['status'] == 'Pending')
              .length;
          final approved = selectedDocs
              .where((doc) => (doc.data() as Map)['status'] == 'Booked')
              .length;
          final serving = selectedDocs
              .where((doc) => (doc.data() as Map)['status'] == 'Serving')
              .length;
          final completed = selectedDocs
              .where((doc) => (doc.data() as Map)['status'] == 'Completed')
              .length;
          final cancelled = selectedDocs.where((doc) {
            final status = (doc.data() as Map)['status'];
            return status == 'Cancelled' || status == 'Rejected';
          }).length;

          final averageWait = _averageServiceDelay(activeTimingDocs);
          final nextAppointmentMins = _nextAppointmentMinutes(activeTimingDocs);
          final co2Saved = _co2Saved(selectedDocs);
          final hourlyDemand = _hourlyDemand(selectedTrafficDocs);
          final busiestHour = _busiestHour(hourlyDemand);

          return ResponsiveListView(
            children: [
              _ReportToolbar(
                fromDate: _fromDate,
                toDate: _toDate,
                onOpen: () => _showMonthlyReportSheet(docs),
              ),
              const SizedBox(height: 16),
              _DateHeader(
                selectedDate: _selectedDate,
                onPrevious: () => setState(
                  () => _selectedDate = _selectedDate.subtract(
                    const Duration(days: 1),
                  ),
                ),
                onNext: () => setState(
                  () => _selectedDate = _selectedDate.add(
                    const Duration(days: 1),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _HeroInsight(
                serviceDelay: averageWait,
                nextAppointmentMins: nextAppointmentMins,
                trafficLabel: _trafficLabel(averageWait),
                busiestHour: busiestHour,
                isPersonal: !_isAdmin,
                hasBookings: activeTimingDocs.isNotEmpty,
              ),
              const SizedBox(height: 16),
              ResponsiveGrid(
                children: _isAdmin
                    ? [
                        _MetricCard(
                          title: 'Pending approval',
                          value: '$pending',
                          icon: Icons.pending_actions_outlined,
                          color: Colors.orange,
                        ),
                        _MetricCard(
                          title: 'Approved bookings',
                          value: '$approved',
                          icon: Icons.verified_outlined,
                          color: Colors.blue,
                        ),
                        _MetricCard(
                          title: 'Being served now',
                          value: '$serving',
                          icon: Icons.support_agent_outlined,
                          color: Colors.purple,
                        ),
                        _MetricCard(
                          title: 'Finished today',
                          value: '$completed',
                          icon: Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                      ]
                    : [
                        _MetricCard(
                          title: _isStaff
                              ? 'Facility pending'
                              : 'Waiting approval',
                          value: '$pending',
                          icon: Icons.pending_actions_outlined,
                          color: Colors.orange,
                        ),
                        _MetricCard(
                          title: _isStaff
                              ? 'Facility approved'
                              : 'Approved bookings',
                          value: '$approved',
                          icon: Icons.verified_outlined,
                          color: Colors.blue,
                        ),
                        _MetricCard(
                          title: 'Completed',
                          value: '$completed',
                          icon: Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                        _MetricCard(
                          title: 'Cancelled/rejected',
                          value: '$cancelled',
                          icon: Icons.block_outlined,
                          color: Colors.red,
                        ),
                      ],
              ),
              const SizedBox(height: 20),
              _ImpactCard(
                co2Saved: co2Saved,
                bookingCount: selectedDocs.length,
              ),
              const SizedBox(height: 20),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('settings')
                    .doc('campus')
                    .snapshots(),
                builder: (context, settingsSnapshot) {
                  final settings =
                      settingsSnapshot.data?.data() as Map<String, dynamic>?;
                  final aiEnabled =
                      settings?['aiSmartRecommendations'] != false;
                  if (!aiEnabled) {
                    return const _AiDisabledCard();
                  }
                  return _PeakTrafficCard(
                    hourlyDemand: hourlyDemand,
                    busiestHour: busiestHour,
                    hasBookings: selectedTrafficDocs.isNotEmpty,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAdminInsights(List<QueryDocumentSnapshot> allDocs) {
    final selectedDocs = allDocs
        .where((doc) => _isSameSelectedDay(doc.data() as Map<String, dynamic>))
        .toList();
    final filteredDocs = _adminFilteredDocs(selectedDocs);
    final activeDocs = filteredDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return _isActiveStatus(data['status']);
    }).toList();
    final trafficDocs = filteredDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] != 'Cancelled' && data['status'] != 'Rejected';
    }).toList();
    final pendingDocs =
        filteredDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'Pending';
        }).toList()..sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final timeA = dataA['scheduledTime'];
          final timeB = dataB['scheduledTime'];
          if (timeA is! Timestamp || timeB is! Timestamp) return 0;
          return timeA.compareTo(timeB);
        });

    final pending = pendingDocs.length;
    final booked = _statusCount(filteredDocs, 'Booked');
    final serving = _statusCount(filteredDocs, 'Serving');
    final completed = _statusCount(filteredDocs, 'Completed');
    final cancelled = filteredDocs.where((doc) {
      final status = (doc.data() as Map<String, dynamic>)['status'];
      return status == 'Cancelled' || status == 'Rejected';
    }).length;
    final conflictGroups = _slotConflictCount(activeDocs);
    final hourlyDemand = _hourlyDemand(trafficDocs);
    final busiestHour = _busiestHour(hourlyDemand);
    final co2Saved = _co2Saved(filteredDocs);

    return ResponsiveListView(
      children: [
        _ReportToolbar(
          fromDate: _fromDate,
          toDate: _toDate,
          onOpen: () => _showMonthlyReportSheet(_adminFilteredDocs(allDocs)),
        ),
        const SizedBox(height: 16),
        _DateHeader(
          selectedDate: _selectedDate,
          onPrevious: () => setState(
            () =>
                _selectedDate = _selectedDate.subtract(const Duration(days: 1)),
          ),
          onNext: () => setState(
            () => _selectedDate = _selectedDate.add(const Duration(days: 1)),
          ),
        ),
        const SizedBox(height: 12),
        _AdminFilterBar(
          value: _adminTypeFilter,
          onChanged: (value) => setState(() => _adminTypeFilter = value),
        ),
        const SizedBox(height: 16),
        _AdminHeroInsight(
          pending: pending,
          active: activeDocs.length,
          completed: completed,
          conflictGroups: conflictGroups,
          busiestHour: busiestHour,
          hasBookings: filteredDocs.isNotEmpty,
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          children: [
            _MetricCard(
              title: 'Pending approval',
              value: '$pending',
              icon: Icons.pending_actions_outlined,
              color: Colors.orange,
            ),
            _MetricCard(
              title: 'Approved / serving',
              value: '${booked + serving}',
              icon: Icons.verified_outlined,
              color: Colors.blue,
            ),
            _MetricCard(
              title: 'Completed',
              value: '$completed',
              icon: Icons.check_circle_outline,
              color: Colors.green,
            ),
            _MetricCard(
              title: 'Slot conflicts',
              value: '$conflictGroups',
              icon: Icons.event_busy_outlined,
              color: conflictGroups == 0 ? Colors.teal : Colors.red,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _ImpactCard(co2Saved: co2Saved, bookingCount: filteredDocs.length),
        const SizedBox(height: 20),
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('settings')
              .doc('campus')
              .snapshots(),
          builder: (context, settingsSnapshot) {
            final settings =
                settingsSnapshot.data?.data() as Map<String, dynamic>?;
            final aiEnabled = settings?['aiSmartRecommendations'] != false;
            if (!aiEnabled) return const _AiDisabledCard();
            return _PeakTrafficCard(
              hourlyDemand: hourlyDemand,
              busiestHour: busiestHour,
              hasBookings: trafficDocs.isNotEmpty,
            );
          },
        ),
        const SizedBox(height: 20),
        _ResourceBreakdownCard(
          resourceDemand: _resourceDemand(filteredDocs),
          totalBookings: filteredDocs.length,
        ),
        const SizedBox(height: 20),
        _ActionQueueCard(pendingDocs: pendingDocs, cancelled: cancelled),
      ],
    );
  }

  List<QueryDocumentSnapshot> _adminFilteredDocs(
    List<QueryDocumentSnapshot> docs,
  ) {
    if (_adminTypeFilter == 'staff') {
      return docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['bookingType'] == 'staffFacility';
      }).toList();
    }
    if (_adminTypeFilter == 'student') {
      return docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['bookingType'] != 'staffFacility';
      }).toList();
    }
    return docs;
  }

  bool _isActiveStatus(dynamic status) {
    return status == 'Pending' ||
        status == 'Booked' ||
        status == 'Serving' ||
        status == 'Waitlist';
  }

  int _statusCount(List<QueryDocumentSnapshot> docs, String status) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] == status;
    }).length;
  }

  int _slotConflictCount(List<QueryDocumentSnapshot> docs) {
    final groups = <String, int>{};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final scheduled = data['scheduledTime'];
      final service = data['department']?.toString();
      if (scheduled is! Timestamp || service == null) continue;
      final slotStart = DateTime(
        scheduled.toDate().year,
        scheduled.toDate().month,
        scheduled.toDate().day,
        scheduled.toDate().hour,
      );
      final key =
          '${data['bookingType'] ?? 'studentService'}|$service|${slotStart.millisecondsSinceEpoch}';
      groups[key] = (groups[key] ?? 0) + 1;
    }
    return groups.values.where((slotCount) => slotCount > 1).length;
  }

  Map<String, int> _resourceDemand(List<QueryDocumentSnapshot> docs) {
    final resources = <String, int>{};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final service = data['department']?.toString() ?? 'General';
      resources[service] = (resources[service] ?? 0) + 1;
    }
    return resources;
  }

  bool _isSameSelectedDay(Map<String, dynamic> data) {
    final scheduled = data['scheduledTime'];
    if (scheduled is! Timestamp) return false;
    final date = scheduled.toDate();
    return date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day;
  }

  int _averageServiceDelay(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return 0;
    final waits = docs
        .map(
          (doc) =>
              ((doc.data() as Map)['serviceDelayMins'] ??
                      (doc.data() as Map)['estimatedWaitMins'] ??
                      0)
                  as int,
        )
        .toList();
    return (waits.reduce((a, b) => a + b) / waits.length).round();
  }

  int _nextAppointmentMinutes(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return 0;
    final now = malaysiaNow();
    final futureTimes =
        docs
            .map((doc) => (doc.data() as Map)['scheduledTime'])
            .whereType<Timestamp>()
            .map((timestamp) => timestamp.toDate())
            .where((date) => date.isAfter(now))
            .toList()
          ..sort();
    if (futureTimes.isEmpty) return 0;
    return minutesUntil(futureTimes.first);
  }

  double _co2Saved(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return 0;
    final total = docs.fold<double>(0, (runningTotal, doc) {
      final value = (doc.data() as Map)['co2SavedKg'];
      return runningTotal + (value is num ? value.toDouble() : 0.6);
    });
    return double.parse(total.toStringAsFixed(1));
  }

  Map<int, int> _hourlyDemand(List<QueryDocumentSnapshot> docs) {
    final hours = {for (var hour = 8; hour <= 18; hour++) hour: 0};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final scheduled = data['scheduledTime'];
      if (scheduled is Timestamp) {
        final hour = scheduled.toDate().hour;
        hours[hour] = (hours[hour] ?? 0) + 1;
      }
    }
    return hours;
  }

  int _busiestHour(Map<int, int> hourlyDemand) {
    if (hourlyDemand.values.every((value) => value == 0)) return -1;
    return hourlyDemand.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  String _trafficLabel(int minutes) {
    if (minutes >= 45) return 'High traffic';
    if (minutes >= 20) return 'Moderate traffic';
    if (minutes > 0) return 'Light traffic';
    return 'No queue delay';
  }
}

class _AiDisabledCard extends StatelessWidget {
  const _AiDisabledCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.auto_awesome_outlined,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI recommendations are off',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Admin can turn this back on from Profile to show peak-hour predictions.',
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

class _AdminFilterBar extends StatelessWidget {
  const _AdminFilterBar({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChipButton(
            label: 'All',
            icon: Icons.dashboard_customize_outlined,
            selected: value == 'all',
            onSelected: () => onChanged('all'),
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            label: 'Student',
            icon: Icons.school_outlined,
            selected: value == 'student',
            onSelected: () => onChanged('student'),
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            label: 'Staff facilities',
            icon: Icons.meeting_room_outlined,
            selected: value == 'staff',
            onSelected: () => onChanged('staff'),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      avatar: Icon(icon, size: 18),
      label: Text(label),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w800,
        color: selected ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
      ),
    );
  }
}

class _AdminHeroInsight extends StatelessWidget {
  const _AdminHeroInsight({
    required this.pending,
    required this.active,
    required this.completed,
    required this.conflictGroups,
    required this.busiestHour,
    required this.hasBookings,
  });

  final int pending;
  final int active;
  final int completed;
  final int conflictGroups;
  final int busiestHour;
  final bool hasBookings;

  @override
  Widget build(BuildContext context) {
    final busiestText = busiestHour >= 0
        ? DateFormat('h a').format(DateTime(2026, 1, 1, busiestHour))
        : 'no peak yet';
    final title = pending > 0
        ? '$pending request${pending == 1 ? '' : 's'} need action'
        : 'No pending approvals';
    final detail = hasBookings
        ? '$active active booking${active == 1 ? '' : 's'}, $completed completed, busiest hour: $busiestText.'
        : 'Bookings for this date will appear here when users submit requests.';

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _showAdminDetails(context),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF111827).withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.admin_panel_settings_outlined, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  'Admin operations',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Spacer(),
                Icon(Icons.touch_app_outlined, size: 18, color: Colors.white70),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$detail Slot conflicts: $conflictGroups.',
              style: const TextStyle(color: Color(0xFFE5E7EB), height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdminDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admin insight'),
        content: Text(
          'This panel is based on all Firebase booking records for the selected date.\n\n'
          'Pending approvals are requests waiting for admin action.\n'
          'Active bookings are Pending, Booked, Serving, or Waitlist.\n'
          'Slot conflicts show historical records where more than one active booking still shares the same service/facility hour.\n\n'
          'Current conflicts: $conflictGroups.',
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

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.selectedDate,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime selectedDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  DateFormat('EEEE').format(selectedDate),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(selectedDate),
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _HeroInsight extends StatelessWidget {
  const _HeroInsight({
    required this.serviceDelay,
    required this.nextAppointmentMins,
    required this.trafficLabel,
    required this.busiestHour,
    required this.isPersonal,
    required this.hasBookings,
  });

  final int serviceDelay;
  final int nextAppointmentMins;
  final String trafficLabel;
  final int busiestHour;
  final bool isPersonal;
  final bool hasBookings;

  @override
  Widget build(BuildContext context) {
    var detailText =
        'Book a department or facility first. Peak traffic will update from your Firebase booking records.';
    if (hasBookings && busiestHour >= 0) {
      detailText =
          'Queue delay: ${formatDurationReadable(serviceDelay)}. Peak traffic is separate and currently busiest around ${DateFormat('h a').format(DateTime(2026, 1, 1, busiestHour))}.';
    } else if (hasBookings) {
      detailText =
          'Queue delay: ${formatDurationReadable(serviceDelay)}. Peak hour will appear after scheduled booking times are available.';
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showDetails(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF14B8A6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPersonal ? 'Your booking timing' : 'Campus queue delay',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasBookings
                  ? '${formatDurationReadable(nextAppointmentMins)} until start'
                  : 'No bookings yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: hasBookings ? 25 : 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detailText,
              style: const TextStyle(color: Colors.white, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('What this means'),
        content: Text(
          'Time until start is based on the current Malaysia time.\n\n'
          'Queue delay is the expected extra delay caused by other approved or pending bookings in the same department/facility hour.\n\n'
          'Peak traffic is separate. It predicts which hours are busiest, but it is not automatically your personal waiting time.\n\n'
          'Current result: $trafficLabel.',
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

class _MetricCard extends StatefulWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  State<_MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<_MetricCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.03 : 1,
        duration: const Duration(milliseconds: 160),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(widget.icon, color: widget.color, size: 22),
                const SizedBox(height: 8),
                Text(
                  widget.value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: widget.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class _ImpactCard extends StatelessWidget {
  const _ImpactCard({required this.co2Saved, required this.bookingCount});

  final double co2Saved;
  final int bookingCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.eco_outlined, color: Color(0xFF059669)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sustainability result',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$bookingCount digital bookings saved about $co2Saved kg CO2 from unnecessary walk-ins.',
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

class _ResourceBreakdownCard extends StatelessWidget {
  const _ResourceBreakdownCard({
    required this.resourceDemand,
    required this.totalBookings,
  });

  final Map<String, int> resourceDemand;
  final int totalBookings;

  @override
  Widget build(BuildContext context) {
    final entries = resourceDemand.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = entries.take(6).toList();
    final maxValue = topEntries.isEmpty ? 1 : topEntries.first.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resource usage',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              totalBookings == 0
                  ? 'No service or facility usage recorded for this date.'
                  : 'Top services and facilities for the selected date.',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            if (topEntries.isEmpty)
              const Text('No resources to display yet.')
            else
              ...topEntries.map((entry) {
                final value = entry.value / maxValue;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${entry.value}',
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFE5E7EB),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ActionQueueCard extends StatelessWidget {
  const _ActionQueueCard({required this.pendingDocs, required this.cancelled});

  final List<QueryDocumentSnapshot> pendingDocs;
  final int cancelled;

  @override
  Widget build(BuildContext context) {
    final previewDocs = pendingDocs.take(4).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Approval queue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              pendingDocs.isEmpty
                  ? 'No pending approvals for this date.'
                  : '${pendingDocs.length} pending request${pendingDocs.length == 1 ? '' : 's'}. Open Approvals to accept or reject.',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            if (cancelled > 0) ...[
              const SizedBox(height: 6),
              Text(
                '$cancelled cancelled/rejected record${cancelled == 1 ? '' : 's'} kept for admin audit.',
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            ],
            const SizedBox(height: 12),
            if (previewDocs.isEmpty)
              const Row(
                children: [
                  Icon(Icons.verified_outlined, color: Color(0xFF059669)),
                  SizedBox(width: 10),
                  Expanded(child: Text('Everything is clear for now.')),
                ],
              )
            else
              ...previewDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final scheduled = data['scheduledTime'];
                final timeText = scheduled is Timestamp
                    ? formatMalaysiaDateTime(scheduled.toDate())
                    : 'No time selected';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFFF7ED),
                    child: Icon(
                      data['bookingType'] == 'staffFacility'
                          ? Icons.meeting_room_outlined
                          : Icons.school_outlined,
                      color: const Color(0xFFEA580C),
                    ),
                  ),
                  title: Text(
                    data['department'] ?? 'Booking request',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('${bookingRequesterName(data)} - $timeText'),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ReportToolbar extends StatelessWidget {
  const _ReportToolbar({
    required this.fromDate,
    required this.toDate,
    required this.onOpen,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.summarize_outlined,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'View / Download Monthly Report',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${DateFormat('MMM d').format(fromDate)} - ${DateFormat('MMM d, yyyy').format(toDate)}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }
}

class _PeakTrafficCard extends StatelessWidget {
  const _PeakTrafficCard({
    required this.hourlyDemand,
    required this.busiestHour,
    required this.hasBookings,
  });

  final Map<int, int> hourlyDemand;
  final int busiestHour;
  final bool hasBookings;

  @override
  Widget build(BuildContext context) {
    final realMaxValue = hourlyDemand.values.reduce((a, b) => a > b ? a : b);
    final maxValue = realMaxValue == 0 ? 1 : realMaxValue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Peak traffic by booking hour',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              hasBookings
                  ? 'Based on Firebase bookings for the selected day. It changes as more bookings are added.'
                  : 'No bookings yet for this day, so the chart is waiting for real Firebase data.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 560,
                height: 170,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: hourlyDemand.entries.map((entry) {
                    final isPeak = hasBookings && entry.key == busiestHour;
                    final ratio = entry.value / maxValue;
                    return _TrafficBar(
                      hour: entry.key,
                      ratio: ratio,
                      isPeak: isPeak,
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrafficBar extends StatelessWidget {
  const _TrafficBar({
    required this.hour,
    required this.ratio,
    required this.isPeak,
  });

  final int hour;
  final double ratio;
  final bool isPeak;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isPeak)
            const Icon(Icons.trending_up, size: 16, color: Color(0xFFF59E0B)),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Container(
                width: 22,
                height: 112 * value,
                decoration: BoxDecoration(
                  color: isPeak
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF93C5FD),
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('ha').format(DateTime(2026, 1, 1, hour)).toLowerCase(),
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
