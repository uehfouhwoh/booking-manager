import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'visits_screen.dart';
import '../calendar/booking_requests_screen.dart';
import '../calendar/calendar_screen.dart';
import '../community/campus_hub_screen.dart';
import '../info/info_screen.dart';
import '../profile/profile_screen.dart';
import '../student/student_home_screen.dart';
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
    final isStaff = _role == 'staff' || _role == 'lecturer';

    final screens = isAdmin
        ? const [VisitsScreen(), BookingRequestsScreen(), ProfileScreen()]
        : isStaff
        ? const [CalendarScreen(), CampusHubScreen(), InfoScreen(), ProfileScreen()]
        : const [
            StudentHomeScreen(),
            CalendarScreen(),
            CampusHubScreen(),
            InfoScreen(),
            ProfileScreen(),
          ];

    final items = isAdmin
        ? const [
            NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings),
              label: 'Manage',
            ),
            NavigationDestination(
              icon: Icon(Icons.fact_check_outlined),
              selectedIcon: Icon(Icons.fact_check),
              label: 'Approvals',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ]
        : isStaff
        ? const [
            NavigationDestination(
              icon: Icon(Icons.meeting_room_outlined),
              selectedIcon: Icon(Icons.meeting_room),
              label: 'Facilities',
            ),
            NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign),
              label: 'Campus Hub',
            ),
            NavigationDestination(
              icon: Icon(Icons.info_outline),
              selectedIcon: Icon(Icons.info),
              label: 'Info',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ]
        : const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.edit_calendar_outlined),
              selectedIcon: Icon(Icons.edit_calendar),
              label: 'Booking',
            ),
            NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign),
              label: 'Campus Hub',
            ),
            NavigationDestination(
              icon: Icon(Icons.info_outline),
              selectedIcon: Icon(Icons.info),
              label: 'Info',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        height: 76,
        destinations: items,
      ),
    );
  }
}
