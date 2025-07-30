import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:study_sync/models/task_model.dart';
import 'package:study_sync/screens/add_task_screen.dart';
import 'package:study_sync/screens/dairy_screen.dart';
import 'package:study_sync/screens/progress_screen.dart';
import 'package:study_sync/widgets/home_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool isLoading = true;
  Map<String, dynamic>? userData;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  List<Task> _tasks = [];
  List<Task> _completedTasks = [];
  bool _isLoadingTasks = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _getUser();
    await _loadTasks();
  }

  Future<void> _getUser() async {
    if (user == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user!.uid)
          .get();

      if (doc.exists) {
        if (mounted) {
          setState(() {
            userData = doc.data();
            isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoading = false);
        debugPrint('User document does not exist');
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      debugPrint('Error fetching user data: $e');
      if (mounted) _showSnackBar('Failed to load user data');
    }
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;
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

    // Convert to UTC for query (account for IST offset)
    final queryStart = DateTime.utc(
      startOfDay.year,
      startOfDay.month,
      startOfDay.day - 1,
      18,
      30,
      0,
    );

    final queryEnd = DateTime.utc(
      endOfDay.year,
      endOfDay.month,
      endOfDay.day,
      18,
      29,
      59,
    );

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('tasks')
          .where(
            'dueDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(queryStart),
          )
          .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(queryEnd))
          .where('isCompleted', isEqualTo: completed)
          .get();

      return query.docs
          .map((doc) {
            try {
              final task = Task.fromFireStore(doc);
              final localDue = task.dueDate;
              return localDue.isAfter(
                        startOfDay.subtract(const Duration(seconds: 1)),
                      ) &&
                      localDue.isBefore(
                        endOfDay.add(const Duration(seconds: 1)),
                      )
                  ? task
                  : null;
            } catch (e) {
              debugPrint('Error parsing task ${doc.id}: $e');
              return null;
            }
          })
          .where((task) => task != null)
          .cast<Task>()
          .toList();
    } catch (e) {
      debugPrint('Error fetching tasks: $e');
      if (e is FirebaseException && e.code == 'failed-precondition') {
        debugPrint('Create composite index for isCompleted and dueDate');
        if (mounted) {
          _showSnackBar('Database index missing - please try again later');
        }
      }
      return [];
    }
  }

  Future<void> _toggleTaskCompletion(Task task, bool newValue) async {
    try {
      if (task.recurrence != 'none' && newValue) {
        await _createNextRecurrence(task);
      }
      await _updateTaskCompletion(task, newValue);
      await _loadTasks();
    } catch (e) {
      if (mounted) _showSnackBar('Failed to update task: ${e.toString()}');
    }
  }

  Future<void> _createNextRecurrence(Task task) async {
    DateTime nextDate;

    switch (task.recurrence) {
      case 'daily':
        nextDate = task.originalDueDate.add(const Duration(days: 1));
        break;
      case 'weekly':
        nextDate = task.originalDueDate.add(const Duration(days: 7));
        break;
      case 'biweekly':
        nextDate = task.originalDueDate.add(const Duration(days: 14));
        break;
      case 'monthly':
        nextDate = DateTime(
          task.originalDueDate.year,
          task.originalDueDate.month + 1,
          min(
            task.originalDueDate.day,
            DateUtils.getDaysInMonth(
              task.originalDueDate.year,
              task.originalDueDate.month + 1,
            ),
          ),
          task.originalDueDate.hour,
          task.originalDueDate.minute,
        );
        break;
      default:
        return;
    }

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .collection("tasks")
        .add({
          'title': task.title,
          'description': task.description,
          'dueDate': Timestamp.fromDate(nextDate),
          'priority': task.priority,
          'category': task.category,
          'isCompleted': false,
          'recurrence': task.recurrence,
          'originalDueDate': Timestamp.fromDate(nextDate),
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });
  }

  Future<void> _updateTaskCompletion(Task task, bool completed) async {
    await FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .collection("tasks")
        .doc(task.id)
        .update({'isCompleted': completed});
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text("StudySync", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {},
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade400, Colors.indigo.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      drawer: const HomeDrawer(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo.shade50, Colors.grey.shade50],
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : userData == null
              ? const Center(child: Text('User data not available'))
              : _getCurrentPage(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTaskScreen()),
          );
          if (result == true && mounted) await _loadTasks();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: Colors.indigo.shade400,
          unselectedItemColor: Colors.grey.shade600,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 10,
          items: [
            _buildBottomNavItem(Icons.home, 'Home', 0),
            _buildBottomNavItem(Icons.bar_chart, 'Progress', 1),
            _buildBottomNavItem(Icons.book, 'Diary', 2),
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
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _currentIndex == index
              ? Colors.indigo.shade50
              : Colors.transparent,
        ),
        child: Icon(
          icon,
          color: _currentIndex == index
              ? Colors.indigo.shade400
              : Colors.grey.shade600,
        ),
      ),
      label: label,
    );
  }

  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const ProgressScreen();
      case 2:
        return const DairyScreen();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeSection(context),
          const SizedBox(height: 24),
          _buildTasksSection(
            context,
            'Pending Tasks',
            _tasks,
            emptyMessage: 'No pending tasks for today',
          ),
          const SizedBox(height: 24),
          _buildTasksSection(
            context,
            'Completed Tasks',
            _completedTasks,
            emptyMessage: 'No completed tasks yet',
            isCompleted: true,
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            'Welcome back',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            userData!["name"] ?? 'User',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('EEEE, MMMM d').format(DateTime.now()),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksSection(
    BuildContext context,
    String title,
    List<Task> tasks, {
    required String emptyMessage,
    bool isCompleted = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade800,
          ),
        ),
        const SizedBox(height: 12),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: Transform.scale(
          scale: 1.3,
          child: Checkbox(
            value: task.isCompleted,
            onChanged: (value) => _toggleTaskCompletion(task, value!),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            activeColor: Colors.indigo.shade400,
          ),
        ),
        title: Text(
          task.title,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: task.isCompleted ? Colors.grey : Colors.indigo.shade300,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTaskDetailRow(
                Icons.access_time,
                DateFormat('h:mm a').format(task.dueDate),
                Colors.grey[800]!,
              ),
              const SizedBox(height: 4),
              _buildTaskDetailRow(
                Icons.flag,
                'Priority: ${task.priority}',
                _getPriorityColor(task.priority),
              ),
              if (task.recurrence != 'none') ...[
                const SizedBox(height: 4),
                _buildTaskDetailRow(
                  Icons.repeat,
                  'Repeats ${task.recurrence}',
                  Colors.indigo.shade400,
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
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red.shade400;
      case 'medium':
        return Colors.orange.shade400;
      case 'low':
        return Colors.green.shade400;
      default:
        return Colors.grey.shade600;
    }
  }
}
