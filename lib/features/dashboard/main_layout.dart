import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'visits_screen.dart';
import '../calendar/booking_requests_screen.dart';
import '../calendar/calendar_screen.dart';
import '../profile/profile_screen.dart';
import '../../services/auth_service.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  String _role = 'student';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await AuthService().ensureCurrentUserProfile();
      } catch (_) {
        // If profile repair is blocked, keep the app usable as a student.
      }
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data()!.containsKey('role')) {
        _role = doc['role'].toString().trim().toLowerCase();
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isAdmin = _role == 'admin';
    final isStaff = _role == 'staff';

    final screens = isAdmin
        ? const [VisitsScreen(), BookingRequestsScreen(), ProfileScreen()]
        : isStaff
        ? const [CalendarScreen(), ProfileScreen()]
        : const [CalendarScreen(), ProfileScreen()];

    final items = isAdmin
        ? const [
            BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_outlined),
              label: 'Manage',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fact_check_outlined),
              label: 'Approvals',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ]
        : isStaff
        ? const [
            BottomNavigationBarItem(
              icon: Icon(Icons.meeting_room_outlined),
              label: 'Facilities',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ]
        : const [
            BottomNavigationBarItem(
              icon: Icon(Icons.edit_calendar_outlined),
              label: 'Booking',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        height: 72,
        destinations: items
            .map(
              (item) => NavigationDestination(
                icon: item.icon,
                selectedIcon: item.activeIcon,
                label: item.label ?? '',
              ),
            )
            .toList(),
      ),
    );
  }
}
