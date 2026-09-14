import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

DateTime malaysiaNow() => DateTime.now();

int minutesUntil(DateTime dateTime) {
  final minutes = dateTime.difference(malaysiaNow()).inMinutes;
  return minutes.clamp(0, 525600).toInt();
}

String formatDurationReadable(int minutes) {
  if (minutes <= 0) return 'Now';
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  if (hours < 24) {
    return mins == 0 ? '$hours hr' : '$hours hr $mins min';
  }
  final days = hours ~/ 24;
  final remainingHours = hours % 24;
  if (remainingHours == 0) return '$days day${days == 1 ? '' : 's'}';
  return '$days day${days == 1 ? '' : 's'} $remainingHours hr';
}

String formatMalaysiaDateTime(DateTime dateTime) {
  return '${DateFormat('EEE, MMM d').format(dateTime)} at ${DateFormat('h:mm a').format(dateTime)}';
}

String bookingRequesterName(Map<String, dynamic> data) {
  return (data['requesterName'] ?? data['studentName'] ?? 'Unknown user')
      .toString();
}

String bookingRequesterEmail(Map<String, dynamic> data) {
  return (data['requesterEmail'] ?? data['studentEmail'] ?? '').toString();
}

String bookingRequesterRole(Map<String, dynamic> data) {
  final role = data['requesterRole'];
  if (role != null) return role.toString().trim().toLowerCase();
  return data['bookingType'] == 'staffFacility' ? 'staff' : 'student';
}

bool bookingBelongsTo(
  Map<String, dynamic> data, {
  required String? email,
  required String? uid,
}) {
  final requesterEmail = data['requesterEmail']?.toString();
  final requesterUid = data['requesterUid']?.toString();
  final legacyEmail = data['studentEmail']?.toString();
  final legacyUid = data['studentUid']?.toString();

  final emailMatches =
      email != null &&
      email.isNotEmpty &&
      (email == requesterEmail || email == legacyEmail);
  final uidMatches =
      uid != null &&
      uid.isNotEmpty &&
      (uid == requesterUid || uid == legacyUid);
  return emailMatches || uidMatches;
}

bool bookingHiddenFor(
  Map<String, dynamic> data, {
  required String? email,
  required String? uid,
}) {
  final hiddenUids = (data['hiddenForUids'] as List?) ?? const [];
  final hiddenEmails = (data['hiddenForEmails'] as List?) ?? const [];
  final uidHidden = uid != null && uid.isNotEmpty && hiddenUids.contains(uid);
  final emailHidden =
      email != null && email.isNotEmpty && hiddenEmails.contains(email);
  return uidHidden || emailHidden;
}

IconData serviceIcon(String service, {String? bookingType}) {
  final cleanService = service.trim();
  if (bookingType == 'staffFacility') {
    return switch (cleanService) {
      'Meeting Room' => Icons.meeting_room_outlined,
      'Computer Lab' => Icons.computer_outlined,
      'Lecture Hall' => Icons.co_present_outlined,
      'Projector Set' => Icons.videocam_outlined,
      'Recording Studio' => Icons.mic_external_on_outlined,
      'Event Space' => Icons.celebration_outlined,
      _ => Icons.business_center_outlined,
    };
  }

  return switch (cleanService) {
    'Academic Advising' => Icons.school_outlined,
    'Admissions' => Icons.how_to_reg_outlined,
    'Career Services' => Icons.work_outline,
    'Finance' => Icons.account_balance_wallet_outlined,
    'Health & Wellness' => Icons.health_and_safety_outlined,
    'Housing & Dorms' => Icons.apartment_outlined,
    'IT Helpdesk' => Icons.support_agent_outlined,
    'Counselling' => Icons.psychology_alt_outlined,
    _ => Icons.domain_outlined,
  };
}

Color serviceColor(String service, {String? bookingType}) {
  final cleanService = service.trim();
  if (bookingType == 'staffFacility') {
    return switch (cleanService) {
      'Meeting Room' => const Color(0xFF7C3AED),
      'Computer Lab' => const Color(0xFF2563EB),
      'Lecture Hall' => const Color(0xFF0891B2),
      'Projector Set' => const Color(0xFFF59E0B),
      'Recording Studio' => const Color(0xFFDB2777),
      'Event Space' => const Color(0xFF059669),
      _ => const Color(0xFF64748B),
    };
  }

  return switch (cleanService) {
    'Academic Advising' => const Color(0xFF2563EB),
    'Admissions' => const Color(0xFF0891B2),
    'Career Services' => const Color(0xFF7C3AED),
    'Finance' => const Color(0xFF059669),
    'Health & Wellness' => const Color(0xFFDC2626),
    'Housing & Dorms' => const Color(0xFFEA580C),
    'IT Helpdesk' => const Color(0xFF0F766E),
    'Counselling' => const Color(0xFF9333EA),
    _ => const Color(0xFF64748B),
  };
}

Color statusColor(String status) {
  return switch (status) {
    'Booked' => const Color(0xFF2563EB),
    'Waitlist' => const Color(0xFFF59E0B),
    'Pending' => const Color(0xFFF59E0B),
    'Serving' => const Color(0xFF7C3AED),
    'Completed' => const Color(0xFF059669),
    'Cancelled' => const Color(0xFFDC2626),
    'Rejected' => const Color(0xFFDC2626),
    _ => const Color(0xFF64748B),
  };
}

String statusMeaning(String status) {
  return switch (status) {
    'Pending' => 'Waiting for admin approval.',
    'Booked' => 'Approved and reserved for the selected time.',
    'Waitlist' => 'Checked in and waiting to be served.',
    'Serving' => 'The user is currently being served.',
    'Completed' => 'The appointment or facility use has finished.',
    'Cancelled' => 'The booking was cancelled.',
    'Rejected' =>
      'Admin rejected the request. Check the reason shown on the booking.',
    _ => 'Current booking status.',
  };
}
