import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_helpers.dart';

class BookingEstimate {
  const BookingEstimate({
    required this.serviceDelayMins,
    required this.minutesUntilAppointment,
    required this.peopleAheadCount,
    required this.sameSlotCount,
    required this.peakLabel,
    required this.trafficLevel,
    required this.availabilityLabel,
    required this.isFullyBooked,
    required this.co2SavedKg,
  });

  final int serviceDelayMins;
  final int minutesUntilAppointment;
  final int peopleAheadCount;
  final int sameSlotCount;
  final String peakLabel;
  final String trafficLevel;
  final String availabilityLabel;
  final bool isFullyBooked;
  final double co2SavedKg;
}

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const List<String> defaultDepartments = [
    'Academic Advising',
    'Admissions',
    'Career Services',
    'Health & Wellness',
    'Housing & Dorms',
    'IT Helpdesk',
    'Counselling',
    'Finance',
  ];

  List<String> _cleanOptions(List<dynamic> values, List<String> fallback) {
    final cleaned = values
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    return cleaned.isEmpty ? fallback : cleaned;
  }

  DateTime _slotStart(DateTime time) {
    return DateTime(time.year, time.month, time.day, time.hour);
  }

  String _bookingSlotId({
    required String bookingType,
    required String service,
    required DateTime requestedTime,
  }) {
    final cleanService = Uri.encodeComponent(
      service.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
    );
    return '${bookingType.trim()}_${cleanService}_${_slotStart(requestedTime).millisecondsSinceEpoch}';
  }

  bool _isInactiveStatus(String status) {
    return status == 'Cancelled' ||
        status == 'Rejected' ||
        status == 'Completed';
  }

  bool _isActiveReservationStatus(String? status) {
    return status == 'Pending' ||
        status == 'Booked' ||
        status == 'Serving' ||
        status == 'Waitlist';
  }

  bool _isSameBookingHour(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day &&
        first.hour == second.hour;
  }

  String _slotTakenMessage(String bookingType) {
    return bookingType == 'staffFacility'
        ? 'This facility is already booked for that hour. Choose another time.'
        : 'This service is already booked for that hour. Choose another time.';
  }

  Future<bool> _hasDuplicateBooking({
    required String department,
    required DateTime requestedTime,
    required String bookingType,
    String? uid,
    required String email,
  }) async {
    final snapshot = await _firestore.collection('queue').get();
    return snapshot.docs.any((doc) {
      final data = doc.data();
      final scheduled = data['scheduledTime'];
      if (scheduled is! Timestamp) return false;
      final sameSlot = _isSameBookingHour(scheduled.toDate(), requestedTime);
      final sameDepartment = data['department'] == department;
      final sameBookingType =
          (data['bookingType'] ?? 'studentService') == bookingType;
      final sameUser =
          (uid != null &&
              uid.isNotEmpty &&
              (data['requesterUid'] == uid || data['studentUid'] == uid)) ||
          (email.isNotEmpty &&
              (data['requesterEmail'] == email ||
                  data['studentEmail'] == email));
      return sameSlot &&
          sameDepartment &&
          sameBookingType &&
          sameUser &&
          _isActiveReservationStatus(data['status']?.toString());
    });
  }

  String? _reservationSlotIdFromData(Map<String, dynamic> data) {
    final storedSlotId =
        data['bookingSlotId']?.toString() ?? data['facilitySlotId']?.toString();
    if (storedSlotId != null && storedSlotId.isNotEmpty) {
      return storedSlotId;
    }

    final scheduled = data['scheduledTime'];
    final service = data['department']?.toString();
    if (scheduled is! Timestamp || service == null || service.trim().isEmpty) {
      return null;
    }

    return _bookingSlotId(
      bookingType: data['bookingType']?.toString() ?? 'studentService',
      service: service,
      requestedTime: scheduled.toDate(),
    );
  }

  Future<void> _releaseReservationSlot(
    Map<String, dynamic> data, {
    required String bookingId,
  }) async {
    final slotId = _reservationSlotIdFromData(data);
    if (slotId == null || slotId.isEmpty) {
      return;
    }
    final slotRef = _firestore.collection('bookingSlots').doc(slotId);
    final slotSnapshot = await slotRef.get();
    if (!slotSnapshot.exists) return;
    final slotBookingId = slotSnapshot.data()?['bookingId']?.toString();
    if (slotBookingId != bookingId) return;
    await slotRef.delete();
  }

  Future<void> _deleteReservationSlotById({
    required String slotId,
    required String bookingId,
  }) async {
    if (slotId.isEmpty) return;
    final slotRef = _firestore.collection('bookingSlots').doc(slotId);
    final slotSnapshot = await slotRef.get();
    if (!slotSnapshot.exists) return;
    final slotBookingId = slotSnapshot.data()?['bookingId']?.toString();
    if (slotBookingId != bookingId) return;
    await slotRef.delete();
  }

  Future<void> _updateReservationSlotStatus(
    Map<String, dynamic> data,
    String status,
    String bookingId,
  ) async {
    final slotId = _reservationSlotIdFromData(data);
    if (slotId == null || slotId.isEmpty) {
      return;
    }
    final scheduled = data['scheduledTime'];
    if (scheduled is! Timestamp) {
      return;
    }
    final bookingType = data['bookingType']?.toString() ?? 'studentService';
    final service = data['department']?.toString() ?? 'Campus service';
    final slotRef = _firestore.collection('bookingSlots').doc(slotId);
    final slotSnapshot = await slotRef.get();
    final existingSlotData = slotSnapshot.data();
    final belongsToAnotherBooking =
        slotSnapshot.exists && existingSlotData?['bookingId'] != bookingId;
    final slotStatus = existingSlotData?['status']?.toString() ?? 'Pending';
    if (belongsToAnotherBooking && !_isInactiveStatus(slotStatus)) {
      throw StateError(_slotTakenMessage(bookingType));
    }

    final slotData = <String, dynamic>{
      'bookingId': bookingId,
      'bookingType': bookingType,
      'resource': service,
      'department': service,
      'facility': bookingType == 'staffFacility' ? service : null,
      'requesterUid': data['requesterUid'] ?? data['studentUid'],
      'requesterEmail': data['requesterEmail'] ?? data['studentEmail'],
      'slotStart': _slotStart(scheduled.toDate()),
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _firestore
        .collection('bookingSlots')
        .doc(slotId)
        .set(slotData, SetOptions(merge: true));
  }

  Stream<QuerySnapshot> getLiveQueue() {
    return _firestore
        .collection('queue')
        .orderBy('joinedAt', descending: false)
        .snapshots();
  }

  Stream<QuerySnapshot> getUserBookings() {
    return _firestore
        .collection('queue')
        .orderBy('joinedAt', descending: false)
        .snapshots();
  }

  Stream<QuerySnapshot> getQueueForRole({
    required String role,
    required String email,
  }) {
    if (role == 'admin') {
      return getLiveQueue();
    }
    return getUserBookings();
  }

  Future<int> getActiveWaitlistCount() async {
    final snapshot = await _firestore
        .collection('queue')
        .where('status', isEqualTo: 'Waitlist')
        .get();
    return snapshot.docs.length;
  }

  Future<BookingEstimate> calculateEstimate({
    required String department,
    required DateTime requestedTime,
    String bookingType = 'studentService',
  }) async {
    final snapshot = await _firestore.collection('queue').get();
    final docs = snapshot.docs;
    final now = malaysiaNow();

    final peopleAheadCount = docs.where((doc) {
      final data = doc.data();
      final status = data['status'];
      final scheduled = data['scheduledTime'];
      final isSameDepartment = data['department'] == department;
      final isActiveNow = status == 'Waitlist' || status == 'Serving';
      if (!isSameDepartment || !isActiveNow) return false;
      if (scheduled is! Timestamp) return true;
      final date = scheduled.toDate();
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).length;

    final sameSlotCount = docs.where((doc) {
      final data = doc.data();
      final scheduled = data['scheduledTime'];
      if (scheduled is! Timestamp) return false;
      final date = scheduled.toDate();
      final sameDay =
          date.year == requestedTime.year &&
          date.month == requestedTime.month &&
          date.day == requestedTime.day;
      final sameHour = date.hour == requestedTime.hour;
      final sameDepartment = data['department'] == department;
      final sameBookingType =
          (data['bookingType'] ?? 'studentService') == bookingType;
      final activeStatus = _isActiveReservationStatus(
        data['status']?.toString(),
      );
      return sameDay &&
          sameHour &&
          sameDepartment &&
          sameBookingType &&
          activeStatus;
    }).length;

    final minutesUntilAppointment = minutesUntil(requestedTime);
    const facilityCapacity = 1;
    final isFullyBooked = sameSlotCount >= facilityCapacity;
    final serviceDelayMins = sameSlotCount * 10;
    final peakScore = _campusPeakScore(requestedTime) + sameSlotCount;
    var trafficLevel = 'Light traffic';
    if (peakScore >= 5) {
      trafficLevel = 'High traffic';
    } else if (peakScore >= 3) {
      trafficLevel = 'Moderate traffic';
    }

    var availabilityLabel = 'Available slot';
    if (isFullyBooked) {
      availabilityLabel = 'Fully booked for this slot';
    } else if (sameSlotCount > 0) {
      availabilityLabel =
          '$sameSlotCount booking${sameSlotCount == 1 ? '' : 's'} already in this slot';
    }

    return BookingEstimate(
      serviceDelayMins: serviceDelayMins,
      minutesUntilAppointment: minutesUntilAppointment,
      peopleAheadCount: peopleAheadCount,
      sameSlotCount: sameSlotCount,
      peakLabel: _campusPeakLabel(requestedTime),
      trafficLevel: trafficLevel,
      availabilityLabel: availabilityLabel,
      isFullyBooked: isFullyBooked,
      co2SavedKg: 0.6,
    );
  }

  int _campusPeakScore(DateTime time) {
    final weekday = time.weekday;
    final hour = time.hour;

    if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
      return 1;
    }
    if (hour == 10 || hour == 14) return 5;
    if (hour == 9 || hour == 11 || hour == 15) return 3;
    if (hour == 12 || hour == 13) return 2;
    return 1;
  }

  String _campusPeakLabel(DateTime time) {
    if (time.weekday == DateTime.saturday || time.weekday == DateTime.sunday) {
      return 'Quiet weekend window';
    }
    final hour = time.hour;
    if (hour == 10 || hour == 14) return 'MIIT peak window';
    if (hour >= 9 && hour <= 15) return 'Normal campus service window';
    return 'Quiet service window';
  }

  Future<DocumentReference<Map<String, dynamic>>> joinQueue({
    required String name,
    required String email,
    required String department,
    String? uid,
    String serviceDetails = 'Walk-in queue request',
    String bookingType = 'studentService',
  }) async {
    final estimate = await calculateEstimate(
      department: department,
      requestedTime: malaysiaNow(),
      bookingType: bookingType,
    );
    final requesterRole = bookingType == 'staffFacility' ? 'staff' : 'student';
    return _firestore.collection('queue').add({
      'requesterName': name,
      'requesterEmail': email,
      'requesterUid': uid,
      'requesterRole': requesterRole,
      'studentName': name,
      'studentEmail': email,
      'studentUid': uid,
      'department': department,
      'serviceDetails': serviceDetails,
      'bookingType': bookingType,
      'status': 'Waitlist',
      'estimatedWaitMins': estimate.serviceDelayMins,
      'serviceDelayMins': estimate.serviceDelayMins,
      'minutesUntilAppointment': estimate.minutesUntilAppointment,
      'co2SavedKg': estimate.co2SavedKg,
      'trafficLevel': estimate.trafficLevel,
      'peakLabel': estimate.peakLabel,
      'availabilityLabel': estimate.availabilityLabel,
      'peopleAheadCount': estimate.peopleAheadCount,
      'sameSlotCount': estimate.sameSlotCount,
      'joinedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateVisitStatus(String docId, String newStatus) async {
    final docRef = _firestore.collection('queue').doc(docId);
    final snapshot = await docRef.get();
    final data = snapshot.data();

    await docRef.update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (data != null) {
      if (_isInactiveStatus(newStatus)) {
        await _releaseReservationSlot(data, bookingId: docId);
      } else {
        await _updateReservationSlotStatus(data, newStatus, docId);
      }
    }
  }

  Future<void> updateBooking({
    required String docId,
    required String name,
    required String email,
    required String department,
    required String status,
    String? serviceDetails,
    DateTime? scheduledTime,
    String? bookingType,
    String? statusReason,
  }) async {
    final docRef = _firestore.collection('queue').doc(docId);
    final snapshot = await docRef.get();
    final previousData = snapshot.data();
    final existingBookingType = previousData?['bookingType']?.toString();
    final effectiveBookingType =
        bookingType ?? existingBookingType ?? 'studentService';
    final previousScheduled = previousData?['scheduledTime'];
    DateTime? effectiveScheduledTime = scheduledTime;
    if (effectiveScheduledTime == null && previousScheduled is Timestamp) {
      effectiveScheduledTime = previousScheduled.toDate();
    }
    final nextSlotId = effectiveScheduledTime != null
        ? _bookingSlotId(
            bookingType: effectiveBookingType,
            service: department,
            requestedTime: effectiveScheduledTime,
          )
        : null;

    final updates = <String, dynamic>{
      'requesterName': name,
      'requesterEmail': email,
      'studentName': name,
      'studentEmail': email,
      'department': department,
      'status': status,
      'serviceDetails': serviceDetails ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (bookingType != null) {
      updates['bookingType'] = effectiveBookingType;
    }

    if (scheduledTime != null) {
      updates['scheduledTime'] = scheduledTime;
    }

    if (nextSlotId != null) {
      updates['bookingSlotId'] = nextSlotId;
      if (effectiveBookingType == 'staffFacility') {
        updates['facilitySlotId'] = nextSlotId;
      }
    }

    if (effectiveBookingType != 'staffFacility') {
      updates['facilitySlotId'] = FieldValue.delete();
    }

    if (status == 'Cancelled') {
      updates['cancellationReason'] = statusReason?.trim().isNotEmpty == true
          ? statusReason!.trim()
          : 'Cancelled by admin.';
    }

    if (status == 'Rejected') {
      updates['declineReason'] = statusReason?.trim().isNotEmpty == true
          ? statusReason!.trim()
          : 'Rejected by admin.';
    }

    if (nextSlotId != null && !_isInactiveStatus(status)) {
      final nextSlotSnapshot = await _firestore
          .collection('bookingSlots')
          .doc(nextSlotId)
          .get();
      final nextSlotData = nextSlotSnapshot.data();
      final belongsToAnotherBooking =
          nextSlotSnapshot.exists && nextSlotData?['bookingId'] != docId;
      final nextSlotStatus = nextSlotData?['status']?.toString() ?? 'Pending';
      if (belongsToAnotherBooking && !_isInactiveStatus(nextSlotStatus)) {
        throw StateError(_slotTakenMessage(effectiveBookingType));
      }
    }

    await docRef.update(updates);

    if (previousData == null) return;

    if (_isInactiveStatus(status)) {
      await _releaseReservationSlot(previousData, bookingId: docId);
      return;
    }

    if (nextSlotId != null && effectiveScheduledTime != null) {
      final oldSlotId = _reservationSlotIdFromData(previousData);
      if (oldSlotId != null &&
          oldSlotId.isNotEmpty &&
          oldSlotId != nextSlotId) {
        await _deleteReservationSlotById(slotId: oldSlotId, bookingId: docId);
      }
      await _firestore.collection('bookingSlots').doc(nextSlotId).set({
        'bookingId': docId,
        'bookingType': effectiveBookingType,
        'resource': department,
        'department': department,
        'facility': effectiveBookingType == 'staffFacility' ? department : null,
        'requesterUid':
            previousData['requesterUid'] ?? previousData['studentUid'],
        'requesterEmail': email,
        'slotStart': _slotStart(effectiveScheduledTime),
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> deleteBooking(String docId) async {
    final docRef = _firestore.collection('queue').doc(docId);
    final snapshot = await docRef.get();
    await docRef.delete();
    final data = snapshot.data();
    if (data != null) {
      await _releaseReservationSlot(data, bookingId: docId);
    }
  }

  Future<void> scheduleVisit(
    String name,
    String email,
    String department,
    DateTime scheduledTime,
  ) async {
    await _firestore.collection('queue').add({
      'requesterName': name,
      'requesterEmail': email,
      'requesterRole': 'student',
      'studentName': name,
      'studentEmail': email,
      'department': department,
      'serviceDetails': 'Direct appointment',
      'status': 'Booked',
      'scheduledTime': scheduledTime,
      'estimatedWaitMins': 0,
      'co2SavedKg': 0.6,
      'joinedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> requestService(
    String name,
    String email,
    String department,
    DateTime requestedTime,
    String serviceDetails, {
    String? uid,
    String bookingType = 'studentService',
  }) async {
    final estimate = await calculateEstimate(
      department: department,
      requestedTime: requestedTime,
      bookingType: bookingType,
    );
    if (estimate.isFullyBooked) {
      throw StateError(_slotTakenMessage(bookingType));
    }
    final hasDuplicateBooking = await _hasDuplicateBooking(
      department: department,
      requestedTime: requestedTime,
      bookingType: bookingType,
      uid: uid,
      email: email,
    );
    if (hasDuplicateBooking) {
      throw StateError(
        bookingType == 'staffFacility'
            ? 'You already have a facility request for that hour.'
            : 'You already have a service booking for that department and hour.',
      );
    }

    final requesterRole = bookingType == 'staffFacility' ? 'staff' : 'student';
    final docRef = _firestore.collection('queue').doc();
    final slotId = _bookingSlotId(
      bookingType: bookingType,
      service: department,
      requestedTime: requestedTime,
    );
    final bookingData = <String, dynamic>{
      'requesterName': name,
      'requesterEmail': email,
      'requesterUid': uid,
      'requesterRole': requesterRole,
      'studentName': name,
      'studentEmail': email,
      'studentUid': uid,
      'department': department,
      'serviceDetails': serviceDetails,
      'bookingType': bookingType,
      'status': 'Pending',
      'scheduledTime': requestedTime,
      'estimatedWaitMins': estimate.serviceDelayMins,
      'serviceDelayMins': estimate.serviceDelayMins,
      'minutesUntilAppointment': estimate.minutesUntilAppointment,
      'co2SavedKg': estimate.co2SavedKg,
      'trafficLevel': estimate.trafficLevel,
      'peakLabel': estimate.peakLabel,
      'availabilityLabel': estimate.availabilityLabel,
      'isFullyBooked': estimate.isFullyBooked,
      'peopleAheadCount': estimate.peopleAheadCount,
      'sameSlotCount': estimate.sameSlotCount,
      'joinedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    bookingData['bookingSlotId'] = slotId;
    if (bookingType == 'staffFacility') {
      bookingData['facilitySlotId'] = slotId;
    }

    final slotRef = _firestore.collection('bookingSlots').doc(slotId);
    await _firestore.runTransaction((transaction) async {
      final slotSnapshot = await transaction.get(slotRef);
      if (slotSnapshot.exists) {
        final slotData = slotSnapshot.data();
        final status = slotData?['status']?.toString() ?? 'Pending';
        if (!_isInactiveStatus(status)) {
          throw StateError(_slotTakenMessage(bookingType));
        }
      }

      transaction.set(slotRef, {
        'bookingId': docRef.id,
        'bookingType': bookingType,
        'resource': department,
        'department': department,
        'facility': bookingType == 'staffFacility' ? department : null,
        'requesterUid': uid,
        'requesterEmail': email,
        'slotStart': _slotStart(requestedTime),
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(docRef, bookingData);
    });
  }

  Future<void> handleServiceRequest(
    String docId,
    bool isApproved, {
    String? declineReason,
  }) async {
    final docRef = _firestore.collection('queue').doc(docId);
    final snapshot = await docRef.get();
    final data = snapshot.data();

    if (isApproved) {
      if (data == null) return;

      final slotId = _reservationSlotIdFromData(data);
      if (slotId == null || slotId.isEmpty) {
        await docRef.update({
          'status': 'Booked',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final bookingType = data['bookingType']?.toString() ?? 'studentService';
      final service = data['department']?.toString() ?? 'Campus service';
      final scheduled = data['scheduledTime'];
      if (scheduled is! Timestamp) {
        await docRef.update({
          'status': 'Booked',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final slotRef = _firestore.collection('bookingSlots').doc(slotId);
      await _firestore.runTransaction((transaction) async {
        final slotSnapshot = await transaction.get(slotRef);
        final slotData = slotSnapshot.data();
        final belongsToAnotherBooking =
            slotSnapshot.exists && slotData?['bookingId'] != docId;
        final slotStatus = slotData?['status']?.toString() ?? 'Pending';
        if (belongsToAnotherBooking && !_isInactiveStatus(slotStatus)) {
          throw StateError(_slotTakenMessage(bookingType));
        }

        transaction.update(docRef, {
          'status': 'Booked',
          'bookingSlotId': slotId,
          if (bookingType == 'staffFacility') 'facilitySlotId': slotId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(slotRef, {
          'bookingId': docId,
          'bookingType': bookingType,
          'resource': service,
          'department': service,
          'facility': bookingType == 'staffFacility' ? service : null,
          'requesterUid': data['requesterUid'] ?? data['studentUid'],
          'requesterEmail': data['requesterEmail'] ?? data['studentEmail'],
          'slotStart': _slotStart(scheduled.toDate()),
          'status': 'Booked',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } else {
      await docRef.update({
        'status': 'Rejected',
        'declineReason': declineReason ?? 'No reason provided by admin.',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (data != null) {
        await _releaseReservationSlot(data, bookingId: docId);
      }
    }
  }

  Stream<QuerySnapshot> getPendingRequests() {
    return _firestore
        .collection('queue')
        .where('status', isEqualTo: 'Pending')
        .snapshots();
  }

  Future<void> cancelServiceRequest(String docId) async {
    final docRef = _firestore.collection('queue').doc(docId);
    final snapshot = await docRef.get();
    await docRef.update({
      'status': 'Cancelled',
      'cancellationReason': 'Cancelled by user.',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final data = snapshot.data();
    if (data != null) {
      await _releaseReservationSlot(data, bookingId: docId);
    }
  }

  Future<void> hideBookingForUser({
    required String docId,
    required String uid,
    required String email,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (uid.trim().isNotEmpty) {
      updates['hiddenForUids'] = FieldValue.arrayUnion([uid.trim()]);
    }
    if (email.trim().isNotEmpty) {
      updates['hiddenForEmails'] = FieldValue.arrayUnion([email.trim()]);
    }
    await _firestore.collection('queue').doc(docId).update(updates);
  }

  Future<void> restoreBookingForUser({
    required String docId,
    required String uid,
    required String email,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (uid.trim().isNotEmpty) {
      updates['hiddenForUids'] = FieldValue.arrayRemove([uid.trim()]);
    }
    if (email.trim().isNotEmpty) {
      updates['hiddenForEmails'] = FieldValue.arrayRemove([email.trim()]);
    }
    await _firestore.collection('queue').doc(docId).update(updates);
  }

  Future<void> completeServiceRequest(String docId) async {
    final docRef = _firestore.collection('queue').doc(docId);
    final snapshot = await docRef.get();
    await docRef.update({
      'status': 'Completed',
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final data = snapshot.data();
    if (data != null) {
      await _releaseReservationSlot(data, bookingId: docId);
    }
  }

  Stream<List<String>> getDepartments() {
    return _firestore.collection('settings').doc('campus').snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists && snapshot.data()!.containsKey('departments')) {
        return _cleanOptions(
          snapshot.data()!['departments'],
          defaultDepartments,
        );
      }
      return defaultDepartments;
    });
  }

  Future<List<String>> getDepartmentsOnce() async {
    final doc = await _firestore.collection('settings').doc('campus').get();
    if (doc.exists && doc.data()!.containsKey('departments')) {
      return _cleanOptions(doc.data()!['departments'], defaultDepartments);
    }
    return defaultDepartments;
  }

  Future<void> ensureCampusSettings() async {
    final docRef = _firestore.collection('settings').doc('campus');
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'departments': defaultDepartments,
        'facilities': ['Meeting Room', 'Computer Lab', 'Lecture Hall', 'Projector Set', 'Recording Studio', 'Event Space'],
        'aiSmartRecommendations': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final data = doc.data() ?? {};
    final updates = <String, dynamic>{};

    final departments = data['departments'];
    final facilities = data['facilities'];

    if (departments is! List ||
        departments
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .isEmpty) {
      updates['departments'] = defaultDepartments;
    }

    if (facilities is! List ||
        facilities
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .isEmpty) {
      updates['facilities'] = ['Meeting Room', 'Computer Lab', 'Lecture Hall', 'Projector Set', 'Recording Studio', 'Event Space'];    }

    if (!data.containsKey('aiSmartRecommendations')) {
      updates['aiSmartRecommendations'] = true;
    }

    if (updates.isNotEmpty) {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await docRef.set(updates, SetOptions(merge: true));
    }
  }

  Future<void> addDepartment(String department) async {
    final docRef = _firestore.collection('settings').doc('campus');
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'departments': [...defaultDepartments, department],
        'facilities': ['Meeting Room', 'Computer Lab', 'Lecture Hall', 'Projector Set', 'Recording Studio', 'Event Space'],
        'aiSmartRecommendations': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.update({
        'departments': FieldValue.arrayUnion([department]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> removeDepartment(String department) async {
    await _firestore.collection('settings').doc('campus').update({
      'departments': FieldValue.arrayRemove([department]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getGroupMessages() {
    return _firestore
        .collection('groupMessages')
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots();
  }

  Future<void> sendGroupMessage({
    required String message,
    required String authorName,
    required String authorUid,
    required String authorEmail,
    required String authorRole,
  }) async {
    await _firestore.collection('groupMessages').add({
      'message': message,
      'authorName': authorName,
      'authorUid': authorUid,
      'authorEmail': authorEmail,
      'authorRole': authorRole,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
