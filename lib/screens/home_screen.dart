import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:study_sync/models/task_model.dart';
import 'package:study_sync/providers/user_provider.dart';
import 'package:study_sync/screens/add_task_screen.dart';
import 'package:study_sync/screens/diary_screen.dart';
import 'package:study_sync/screens/progress_screen.dart';
import 'package:study_sync/services/notification/notification_service.dart';
import 'package:study_sync/services/progress_service.dart';
import 'package:study_sync/widgets/app_bar.dart';
import 'package:study_sync/widgets/home_drawer.dart';

class HomeScreen extends StatefulWidget {
  final int initialTabIndex;

  const HomeScreen({super.key, required this.initialTabIndex});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late int _currentIndex;
  List<Task> _tasks = [];
  List<Task> _completedTasks = [];
  bool _isLoadingTasks = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _loadTasks();
    _setupProgressTracking();
  }

  void _setupProgressTracking() {
    // Call this when tasks change or at the end of each day
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final progressService = ProgressService();
      await progressService.updateDailyProgress();
    });
  }

  // Handle navigation from drawer
  void _handleNavigationItemSelected(int index) {
    // Close the drawer
    _scaffoldKey.currentState?.openEndDrawer();

    // Navigate to the selected tab
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _loadTasks() async {
    if (!mounted || user == null) return;
    setState(() => _isLoadingTasks = true);

    try {
      final tasks = await _getTasksForToday(false);
      final completedTasks = await _getTasksForToday(true);

      if (mounted) {
        setState(() {
          _tasks = tasks;
          _completedTasks = completedTasks;
          _isLoadingTasks = false;
        });
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() => _isLoadingTasks = false);
        _showSnackBar('Firestore error: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTasks = false);
        _showSnackBar('Failed to load tasks');
      }
    }
  }

  Future<List<Task>> _getTasksForToday(bool completed) async {
    if (user == null) return [];

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    try {
      QuerySnapshot query;

      if (completed) {
        // For completed tasks, use a simpler query to avoid index issues
        query = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('tasks')
            .where('isCompleted', isEqualTo: true)
            .get();

        // Filter locally for tasks completed today
        final allCompletedTasks = query.docs
            .map((doc) {
              try {
                return Task.fromFireStore(doc);
              } catch (e) {
                debugPrint('Error parsing task ${doc.id}: $e');
                return null;
              }
            })
            .where((task) => task != null)
            .cast<Task>()
            .toList();

        // Filter for tasks completed today using lastRecurrenceDate
        return allCompletedTasks.where((task) {
          if (task.lastRecurrenceDate != null) {
            final completionDate = task.lastRecurrenceDate!;
            return completionDate.year == now.year &&
                completionDate.month == now.month &&
                completionDate.day == now.day;
          }
          return false;
        }).toList();
      } else {
        // For pending tasks, get all incomplete tasks and filter locally
        query = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('tasks')
            .where('isCompleted', isEqualTo: false)
            .get();
      }

      final tasks = query.docs
          .map((doc) {
            try {
              return Task.fromFireStore(doc);
            } catch (e) {
              debugPrint('Error parsing task ${doc.id}: $e');
              return null;
            }
          })
          .where((task) => task != null)
          .cast<Task>()
          .toList();

      // For pending tasks, filter by due date or recurrence
      if (!completed) {
        tasks.removeWhere((task) {
          final dueDate = task.dueDate.toLocal();
          final isDueToday =
              dueDate.isAfter(startOfDay) && dueDate.isBefore(endOfDay);
          final isRecurringToday =
              task.isRecurring && _shouldRecurToday(task, now);

          return !isDueToday && !isRecurringToday;
        });
      }

      tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return tasks;
    } on FirebaseException catch (e) {
      debugPrint('Firestore error: ${e.message}');
      _showSnackBar('Failed to fetch tasks');
      return [];
    } catch (e) {
      debugPrint('Error fetching tasks: $e');
      return [];
    }
  }

  bool _shouldRecurToday(Task task, DateTime now) {
    if (!task.isRecurring) return false;

    final today = DateTime(now.year, now.month, now.day);
    final lastRecurrenceDate =
        task.lastRecurrenceDate?.toLocal() ?? task.originalDueDate.toLocal();
    final lastRecurrenceDay = DateTime(
      lastRecurrenceDate.year,
      lastRecurrenceDate.month,
      lastRecurrenceDate.day,
    );

    switch (task.recurrence) {
      case 'daily':
        return today.isAfter(lastRecurrenceDay);
      case 'weekly':
        return now.weekday == task.originalDueDate.toLocal().weekday &&
            today.difference(lastRecurrenceDay).inDays >= 7;
      case 'biweekly':
        return now.weekday == task.originalDueDate.toLocal().weekday &&
            today.difference(lastRecurrenceDay).inDays >= 14;
      case 'monthly':
        // Check if it's the same day of month and we haven't completed it this month
        return now.day == task.originalDueDate.toLocal().day &&
            (now.month > lastRecurrenceDate.month ||
                now.year > lastRecurrenceDate.year);
      default:
        return false;
    }
  }

  Future<void> _toggleTaskCompletion(Task task, bool newValue) async {
    try {
      setState(() => _isLoadingTasks = true);

      if (task.recurrence != 'none') {
        if (newValue) {
          await _createNextRecurrence(task);
        } else {
          await _resetRecurrence(task);
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('tasks')
          .doc(task.id)
          .update({
            'isCompleted': newValue,
            'lastRecurrenceDate': newValue
                ? Timestamp.fromDate(DateTime.now())
                : FieldValue.delete(),
          });

      // Handle notifications
      if (newValue) {
        await NotificationService().cancelNotification(task.id.hashCode);
      } else {
        final now = DateTime.now();
        final notificationTime = task.dueDate.isAfter(now)
            ? task.dueDate.subtract(const Duration(minutes: 30))
            : now.add(const Duration(seconds: 5));

        await NotificationService().scheduleTaskNotification(
          taskId: task.id,
          title: 'Task Reminder: ${task.title}',
          body: 'Your task "${task.title}" is due soon!',
          scheduledTime: notificationTime,
        );
      }

      // Update progress tracking after task completion
      final progressService = ProgressService();
      await progressService.updateDailyProgress();

      await _loadTasks();
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() => _isLoadingTasks = false);
        _showSnackBar('Firestore error: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTasks = false);
        _showSnackBar('Failed to update task');
      }
    }
  }

  Future<void> _resetRecurrence(Task task) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('tasks')
          .doc(task.id)
          .update({'lastRecurrenceDate': FieldValue.delete()});
    } catch (e) {
      debugPrint('Error resetting recurrence: $e');
      rethrow;
    }
  }

  Future<void> _createNextRecurrence(Task task) async {
    final now = DateTime.now();
    DateTime nextDate;

    switch (task.recurrence) {
      case 'daily':
        nextDate = DateTime(
          now.year,
          now.month,
          now.day + 1,
          task.dueDate.hour,
          task.dueDate.minute,
        );
        break;
      case 'weekly':
        nextDate = DateTime(
          now.year,
          now.month,
          now.day + 7,
          task.dueDate.hour,
          task.dueDate.minute,
        );
        break;
      case 'biweekly':
        nextDate = DateTime(
          now.year,
          now.month,
          now.day + 14,
          task.dueDate.hour,
          task.dueDate.minute,
        );
        break;
      case 'monthly':
        final nextMonth = now.month + 1;
        final nextYear = now.year + (nextMonth > 12 ? 1 : 0);
        final adjustedMonth = nextMonth > 12 ? nextMonth - 12 : nextMonth;

        // Ensure we don't exceed days in month
        final maxDay = DateUtils.getDaysInMonth(nextYear, adjustedMonth);
        final day = min(task.originalDueDate.day, maxDay);

        nextDate = DateTime(
          nextYear,
          adjustedMonth,
          day,
          task.dueDate.hour,
          task.dueDate.minute,
        );
        break;
      default:
        return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('tasks')
          .add({
            'title': task.title,
            'description': task.description,
            'dueDate': Timestamp.fromDate(nextDate),
            'priority': task.priority,
            'category': task.category,
            'isCompleted': false,
            'recurrence': task.recurrence,
            'originalDueDate': Timestamp.fromDate(task.originalDueDate),
            'createdAt': Timestamp.fromDate(now),
            'isRecurring': true,
            'lastRecurrenceDate': null,
          });
    } catch (e) {
      debugPrint('Error creating next recurrence: $e');
      rethrow;
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return "StudySync";
      case 1:
        return "Today's Progress";
      case 2:
        return "Diary";
      default:
        return "StudySync";
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: StudySyncAppBar(
        title: _getAppBarTitle(),
        showBackButton: false,
        showMenuButton: true,
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      drawer: HomeDrawer(
        onNavigationItemSelected: _handleNavigationItemSelected,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primaryContainer.withOpacity(0.05),
              theme.colorScheme.primaryContainer.withOpacity(0.15),
            ],
          ),
        ),
        child: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: [
              _buildHomeContent(userProvider),
              ProgressScreen(
                key: ValueKey(_currentIndex),
                onRefresh: _loadTasks,
              ),
              const DiaryScreen(),
            ],
          ),
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              backgroundColor: theme.colorScheme.primary,
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddTaskScreen(),
                  ),
                );
                if (result == true && mounted) await _loadTasks();
              },
              child: Icon(
                Icons.add_rounded,
                color: theme.colorScheme.onPrimary,
              ),
            )
          : null,
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          backgroundColor: theme.colorScheme.surface,
          elevation: 8,
          items: [
            _buildBottomNavItem(Icons.home_rounded, 'Home', 0),
            _buildBottomNavItem(Icons.bar_chart_rounded, 'Progress', 1),
            _buildBottomNavItem(Icons.book_rounded, 'Diary', 2),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildBottomNavItem(
    IconData icon,
    String label,
    int index,
  ) {
    final theme = Theme.of(context);

    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _currentIndex == index
              ? theme.colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Icon(
          icon,
          color: _currentIndex == index
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withOpacity(0.6),
          size: 24,
        ),
      ),
      label: label,
    );
  }

  Widget _buildHomeContent(UserProvider userProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeSection(userProvider),
          const SizedBox(height: 32),
          _buildTasksSection(
            'Today\'s Tasks',
            _tasks,
            emptyMessage: 'No pending tasks for today',
          ),
          const SizedBox(height: 24),
          _buildTasksSection(
            'Completed Today',
            _completedTasks,
            emptyMessage: 'No completed tasks yet',
            isCompleted: true,
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(UserProvider userProvider) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        children: [
          Text(
            'Welcome back',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            userProvider.name.isNotEmpty ? userProvider.name : 'User',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('EEEE, MMMM d').format(DateTime.now()),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksSection(
    String title,
    List<Task> tasks, {
    required String emptyMessage,
    bool isCompleted = false,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 16),
        _isLoadingTasks
            ? _buildLoadingIndicator()
            : tasks.isEmpty
            ? _buildEmptyState(emptyMessage)
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tasks.length,
                itemBuilder: (context, index) => _buildTaskCard(tasks[index]),
              ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    final theme = Theme.of(context);
    final isCompleted = task.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: Transform.scale(
          scale: 1.2,
          child: Checkbox(
            value: isCompleted,
            onChanged: (value) => _toggleTaskCompletion(task, value!),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            activeColor: theme.colorScheme.primary,
          ),
        ),
        title: Text(
          task.title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: isCompleted
                ? theme.colorScheme.onSurface.withOpacity(0.5)
                : theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTaskDetailRow(
                Icons.access_time_rounded,
                DateFormat('h:mm a').format(task.dueDate),
                theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(height: 4),
              _buildTaskDetailRow(
                Icons.flag_rounded,
                'Priority: ${task.priority}',
                _getPriorityColor(task.priority),
              ),
              if (task.recurrence != 'none') ...[
                const SizedBox(height: 4),
                _buildTaskDetailRow(
                  Icons.repeat_rounded,
                  'Repeats ${task.recurrence}',
                  theme.colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskDetailRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }

  Color _getPriorityColor(String priority) {
    final theme = Theme.of(context);

    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return theme.colorScheme.onSurface.withOpacity(0.6);
    }
  }
}
