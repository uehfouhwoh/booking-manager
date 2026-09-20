import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'visits_screen.dart';
import '../calendar/booking_requests_screen.dart';
import '../calendar/calendar_screen.dart';
import '../analytics/stats_screen.dart';
import '../community/campus_hub_screen.dart';
import '../profile/profile_screen.dart';
import '../../core/app_design.dart';
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
    final roleLabel = isAdmin
        ? 'Administrator'
        : isStaff
        ? 'Lecturer / Staff'
        : 'Student';

    final screens = isAdmin
        ? const [
            CampusHubScreen(),
            VisitsScreen(),
            BookingRequestsScreen(),
            StatsScreen(),
            ProfileScreen(),
          ]
        : isStaff
        ? const [
            CampusHubScreen(),
            CalendarScreen(),
            StatsScreen(),
            ProfileScreen(),
          ]
        : const [
            CampusHubScreen(),
            CalendarScreen(),
            StatsScreen(),
            ProfileScreen(),
          ];

    final items = isAdmin
        ? const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_customize_outlined),
              label: 'Hub',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_outlined),
              label: 'Manage',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fact_check_outlined),
              label: 'Approvals',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.query_stats_outlined),
              label: 'Insights',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ]
        : isStaff
        ? const [
            BottomNavigationBarItem(
              icon: Icon(Icons.info_outline),
              label: 'Hub',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.meeting_room_outlined),
              label: 'Facilities',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.query_stats_outlined),
              label: 'Insights',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ]
        : const [
            BottomNavigationBarItem(
              icon: Icon(Icons.info_outline),
              label: 'Hub',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.edit_calendar_outlined),
              label: 'Booking',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.query_stats_outlined),
              label: 'Insights',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ];

    final destinations = items
        .map(
          (item) => NavigationDestination(
            icon: item.icon,
            selectedIcon: item.activeIcon,
            label: item.label ?? '',
          ),
        )
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 920;
        if (!useRail) {
          return Scaffold(
            body: screens[_currentIndex],
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: AppShadow.soft(),
                border: const Border(top: BorderSide(color: AppColors.line)),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() => _currentIndex = index);
                },
                height: 72,
                destinations: destinations,
              ),
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(right: BorderSide(color: AppColors.line)),
                ),
                child: NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() => _currentIndex = index);
                  },
                  extended: constraints.maxWidth >= 1180,
                  minExtendedWidth: 214,
                  leading: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 22),
                    child: _RailBrand(
                      extended: constraints.maxWidth >= 1180,
                      roleLabel: roleLabel,
                    ),
                  ),
                  destinations: items
                      .map(
                        (item) => NavigationRailDestination(
                          icon: item.icon,
                          selectedIcon: item.activeIcon,
                          label: Text(item.label ?? ''),
                        ),
                      )
                      .toList(),
                ),
              ),
              Expanded(child: screens[_currentIndex]),
            ],
          ),
        );
      },
    );
  }
}

class _RailBrand extends StatelessWidget {
  const _RailBrand({required this.extended, required this.roleLabel});

  final bool extended;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      height: 46,
      width: 46,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: const Icon(Icons.event_available_outlined, color: Colors.white),
    );

    if (!extended) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FlowSlot',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                roleLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
