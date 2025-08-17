import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:study_sync/screens/main_screen.dart';
import 'package:study_sync/screens/progress_screen.dart';
import 'package:study_sync/screens/dairy_screen.dart';
import 'package:study_sync/screens/home_screen.dart';
import 'package:study_sync/screens/settings_screen.dart';

class MenuList extends StatefulWidget {
  const MenuList({super.key});

  @override
  State<MenuList> createState() => _MenuListState();
}

class _MenuListState extends State<MenuList> {
  int _selectedIndex = -1;
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Logout?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'Are you sure you want to Log out?',
          style: TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Wrap(
            spacing: 12,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[400],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  await FirebaseAuth.instance.signOut();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const MainScreen()),
                    (route) => false,
                  );
                },
                child: const Text('Logout'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      children: [
        _buildMenuItem(
          context,
          icon: Icons.dashboard_rounded,
          title: 'Dashboard',
          index: 0,
          onTap: () => _navigateTo(context, const HomeScreen()),
        ),
        const SizedBox(height: 8),
        _buildMenuItem(
          context,
          icon: Icons.bar_chart,
          title: 'Progress',
          index: 1,
          onTap: () => _navigateTo(context, const ProgressScreen()),
        ),
        const SizedBox(height: 8),
        _buildMenuItem(
          context,
          icon: Icons.book_rounded,
          title: 'Diary',
          index: 2,
          onTap: () => _navigateTo(context, const NewDiaryEntryScreen()),
        ),
        const SizedBox(height: 8),
        _buildMenuItem(
          context,
          icon: Icons.settings_rounded,
          title: 'Settings',
          index: 3,
          onTap: () => _navigateTo(context, const SettingsScreen()),
        ),
        const Divider(indent: 10, endIndent: 10),
        _buildMenuItem(
          context,
          icon: Icons.logout,
          title: 'Logout',
          index: 4,
          onTap: () => {_confirmLogout()},
        ),
        const Divider(indent: 10, endIndent: 10),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int index,
    required VoidCallback onTap,
  }) {
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.primaryColor.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() => _selectedIndex = index);
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? theme.primaryColor
                      : theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                  size: 24,
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? theme.primaryColor
                        : theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).pop();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }
}
