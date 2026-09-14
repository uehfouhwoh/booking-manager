import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/app_helpers.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import 'booking_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final DatabaseService _dbService = DatabaseService();

  String _displayName = 'Loading...';
  String _role = 'student';
  String _avatarKey = 'person';
  bool _isLoading = true;

  bool _aiEnabled = true;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (currentUser != null) {
      _displayName =
          currentUser?.displayName ?? currentUser!.email!.split('@')[0];

      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          if (data.containsKey('role')) {
            _role = data['role'].toString().trim().toLowerCase();
          }
          if (data.containsKey('notificationsEnabled')) {
            _notificationsEnabled = data['notificationsEnabled'] == true;
          }
          _avatarKey = (data['avatarKey'] ?? _defaultAvatarKey()).toString();
          if (!_avatarOptions().containsKey(_avatarKey)) {
            _avatarKey = _defaultAvatarKey();
          }
        }
        if (_role == 'admin') {
          try {
            await _dbService.ensureCampusSettings();
          } catch (_) {
            // Admin can still use the app if settings seeding is blocked.
          }
        }

        try {
          final settings = await FirebaseFirestore.instance
              .collection('settings')
              .doc('campus')
              .get();
          if (settings.exists &&
              settings.data()!.containsKey('aiSmartRecommendations')) {
            _aiEnabled = settings['aiSmartRecommendations'] == true;
          }
        } catch (_) {
          _aiEnabled = true;
        }
      } catch (_) {
        _role = 'student';
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  IconData _avatarIcon(String key) {
    return switch (key) {
      'cap' => Icons.school_outlined,
      'book' => Icons.menu_book_outlined,
      'calendar' => Icons.event_available_outlined,
      'briefcase' => Icons.work_outline,
      'facility' => Icons.meeting_room_outlined,
      'support' => Icons.support_agent_outlined,
      'leaf' => Icons.eco_outlined,
      'admin' => Icons.admin_panel_settings_outlined,
      'shield' => Icons.verified_user_outlined,
      _ => Icons.person_outline,
    };
  }

  String _defaultAvatarKey() {
    return switch (_role) {
      'admin' => 'admin',
      'staff' => 'facility',
      _ => 'cap',
    };
  }

  Map<String, String> _avatarOptions() {
    return switch (_role) {
      'admin' => {'admin': 'Admin', 'shield': 'Verified', 'support': 'Control'},
      'staff' => {
        'facility': 'Facility',
        'briefcase': 'Staff',
        'support': 'Support',
      },
      _ => {'cap': 'Student', 'book': 'Learning', 'calendar': 'Booking'},
    };
  }

  Color _roleColor() {
    return switch (_role) {
      'admin' => const Color(0xFF2563EB),
      'staff' => const Color(0xFF7C3AED),
      _ => const Color(0xFF059669),
    };
  }

  void _showAvatarDialog() {
    final avatars = _avatarOptions();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: avatars.entries.map((entry) {
            final selected = entry.key == _avatarKey;
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser!.uid)
                      .update({'avatarKey': entry.key});
                  if (!context.mounted) return;
                  setState(() => _avatarKey = entry.key);
                  Navigator.pop(context);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not update profile picture: $error'),
                    ),
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  color: selected
                      ? _roleColor().withValues(alpha: 0.14)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? _roleColor() : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_avatarIcon(entry.key), color: _roleColor(), size: 32),
                    const SizedBox(height: 8),
                    Text(
                      entry.value,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    final TextEditingController nameController = TextEditingController(
      text: _displayName,
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  try {
                    await currentUser?.updateDisplayName(
                      nameController.text.trim(),
                    );
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser!.uid)
                        .update({'name': nameController.text.trim()});
                    if (!context.mounted) return;
                    setState(() => _displayName = nameController.text.trim());
                    Navigator.pop(context);
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not save profile: $error')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showDepartmentsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Departments'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<List<String>>(
            stream: _dbService.getDepartments(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.deepPurple),
                );
              }

              final departments = snapshot.data ?? [];

              if (departments.isEmpty) {
                return const Center(child: Text("No departments found."));
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: departments.length,
                itemBuilder: (context, index) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.domain, color: Colors.deepPurple),
                  title: Text(
                    departments[index],
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    onPressed: () async {
                      try {
                        await _dbService.removeDepartment(departments[index]);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${departments[index]} deleted.'),
                          ),
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Could not delete department: $error',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _showAddDepartmentDialog();
            },
            child: const Text('Add New'),
          ),
        ],
      ),
    );
  }

  void _showAddDepartmentDialog() {
    final TextEditingController deptController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Department'),
        content: TextField(
          controller: deptController,
          decoration: const InputDecoration(
            labelText: 'Department Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (deptController.text.trim().isNotEmpty) {
                try {
                  await _dbService.addDepartment(deptController.text.trim());
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _showDepartmentsDialog();
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not add department: $error')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // --- HELP & SUPPORT ---
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.support_agent, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Help & Support'),
          ],
        ),
        content: const Text(
          'If you are experiencing issues with your account, booking, cancellation, or admin approval, contact support.\n\n'
          'Email: muhdkhairi1441@gmail.com\n'
          'Phone: +60195340907',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.deepPurple),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showStudentImpactDialog() async {
    final snapshot = await FirebaseFirestore.instance.collection('queue').get();
    final docs = snapshot.docs.where((doc) {
      return bookingBelongsTo(
            doc.data(),
            email: currentUser?.email,
            uid: currentUser?.uid,
          ) &&
          !bookingHiddenFor(
            doc.data(),
            email: currentUser?.email,
            uid: currentUser?.uid,
          );
    }).toList();
    final completed = docs
        .where((doc) => doc.data()['status'] == 'Completed')
        .length;
    final co2Saved = docs
        .fold<double>(0, (total, doc) {
          final value = doc.data()['co2SavedKg'];
          return total + (value is num ? value.toDouble() : 0.6);
        })
        .toStringAsFixed(1);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('My Campus Impact'),
        content: Text(
          'Total bookings: ${docs.length}\n'
          'Completed services: $completed\n'
          'Estimated CO2 saved: $co2Saved kg\n\n'
          'This uses your own Firebase booking records.',
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepPurple),
        ),
      );
    }

    bool isAdmin = _role == 'admin';
    bool isStaff = _role == 'staff';

    String displayRoleName = _role.isNotEmpty
        ? '${_role[0].toUpperCase()}${_role.substring(1)}'
        : 'Student';
    if (_role == 'admin') displayRoleName = 'Campus Admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Campus Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditProfileDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHero(
            displayName: _displayName,
            email: currentUser?.email ?? '',
            roleName: displayRoleName,
            roleColor: _roleColor(),
            avatar: _avatarIcon(_avatarKey),
            onChangePicture: _showAvatarDialog,
          ),
          const SizedBox(height: 32),

          if (isAdmin) ...[
            const Text(
              'Admin Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildSettingsTile(
              context,
              icon: Icons.business_center_outlined,
              title: 'Manage Departments',
              subtitle: 'Add or remove campus departments',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showDepartmentsDialog,
            ),
            _buildSettingsTile(
              context,
              icon: Icons.auto_awesome_outlined,
              title: 'AI Smart Recommendations',
              subtitle: 'Predictive queue analytics',
              trailing: Switch(
                value: _aiEnabled,
                onChanged: (val) async {
                  try {
                    await FirebaseFirestore.instance
                        .collection('settings')
                        .doc('campus')
                        .set({
                          'aiSmartRecommendations': val,
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));
                    if (!context.mounted) return;
                    setState(() => _aiEnabled = val);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          val ? 'AI Engine Activated' : 'AI Engine Deactivated',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not update AI: $error')),
                    );
                  }
                },
                activeThumbColor: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (!isAdmin && !isStaff) ...[
            const Text(
              'Student Workspace',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildSettingsTile(
              context,
              icon: Icons.eco_outlined,
              title: 'My Campus Impact',
              subtitle: 'View your booking count and sustainability result',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showStudentImpactDialog,
            ),
            _buildSettingsTile(
              context,
              icon: Icons.visibility_off_outlined,
              title: 'Hidden Bookings',
              subtitle: 'Restore bookings hidden from your history',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const BookingHistoryScreen(showHidden: true),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],

          const Text(
            'Account',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (!isAdmin && !isStaff)
            _buildSettingsTile(
              context,
              icon: Icons.history,
              title: 'Booking History',
              subtitle: 'Review your department requests and results',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BookingHistoryScreen(),
                  ),
                );
              },
            ),

          _buildSettingsTile(
            context,
            icon: Icons.notifications_active_outlined,
            title: 'Push Notifications',
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (val) async {
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser!.uid)
                      .update({
                        'notificationsEnabled': val,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                  if (!context.mounted) return;
                  setState(() => _notificationsEnabled = val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        val
                            ? 'Push Notifications Enabled'
                            : 'Push Notifications Muted',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not update notifications: $error'),
                    ),
                  );
                }
              },
              activeThumbColor: Colors.deepPurple,
            ),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.help_outline,
            title: 'Help & Support',
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showHelpDialog,
          ),
          _buildSettingsTile(
            context,
            icon: Icons.logout,
            title: 'Log Out',
            titleColor: Colors.red,
            iconColor: Colors.red,
            onTap: () async {
              await AuthService().logOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? titleColor,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap ?? () {},
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? Colors.deepPurple).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor ?? Colors.deepPurple),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: titleColor ?? Colors.black87,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              )
            : null,
        trailing: trailing,
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.displayName,
    required this.email,
    required this.roleName,
    required this.roleColor,
    required this.avatar,
    required this.onChangePicture,
  });

  final String displayName;
  final String email;
  final String roleName;
  final Color roleColor;
  final IconData avatar;
  final VoidCallback onChangePicture;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [roleColor, const Color(0xFF111827)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            height: 104,
            width: 104,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
                width: 4,
              ),
            ),
            child: Icon(avatar, size: 54, color: roleColor),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: onChangePicture,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Change profile picture'),
          ),
          const SizedBox(height: 10),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              roleName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            email,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFE5E7EB)),
          ),
        ],
      ),
    );
  }
}
