import 'package:flutter/material.dart';
import 'package:study_sync/screens/tasks_screen.dart';
import 'package:study_sync/screens/dairy_screen.dart';
import 'package:study_sync/screens/home_screen.dart';
import 'package:study_sync/screens/settings_screen.dart';

class MenuList extends StatefulWidget {
  final Map<String, dynamic> userData;

  const MenuList({super.key, required this.userData});

  @override
  State<MenuList> createState() => _MenuListState();
}

class _MenuListState extends State<MenuList> {
  int _selectedIndex = -1;

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
          icon: Icons.task_rounded,
          title: 'Tasks',
          index: 1,
          onTap: () => _navigateTo(context, const TasksScreen()),
        ),
        const SizedBox(height: 8),
        _buildMenuItem(
          context,
          icon: Icons.book_rounded,
          title: 'Diary',
          index: 2,
          onTap: () => _navigateTo(context, const DairyScreen()),
        ),
        const Divider(height: 30, indent: 20, endIndent: 20),
        _buildMenuItem(
          context,
          icon: Icons.settings_rounded,
          title: 'Settings',
          index: 3,
          onTap: () => _navigateTo(
            context,
            SettingsScreen(
              currentName: widget.userData['name'] ?? 'User',
              currentEmail: widget.userData['email'] ?? '',
            ),
          ),
        ),
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
