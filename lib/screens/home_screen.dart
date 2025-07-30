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
      setState(() => isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user!.uid)
          .get();

      if (doc.exists) {
        setState(() {
          userData = doc.data();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        debugPrint('User document does not exist');
      }
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint('Error fetching user data: $e');
      _showSnackBar('Failed to load user data');
    }
  }

  Future<void> _loadTasks() async {
    final tasks = await _getPendingTasksForToday();
    if (mounted) {
      setState(() => _tasks = tasks);
    }
    _debugPrintTaskDates();
  }

  void _debugPrintTaskDates() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    debugPrint('=== DATE RANGES ===');
    debugPrint('Now: $now');
    debugPrint('Local Start of day: $startOfDay');
    debugPrint('Local End of day: $endOfDay');
    debugPrint('UTC Start of day: ${startOfDay.toUtc()}');
    debugPrint('UTC End of day: ${endOfDay.toUtc()}');

    debugPrint('=== TASKS ===');
    for (final task in _tasks) {
      final localDate = task.dueDate.toLocal();
      debugPrint('Task: ${task.title}');
      debugPrint('Due (UTC): ${task.dueDate}');
      debugPrint('Due (Local): $localDate');
      debugPrint(
        'Is today: ${_isDateInRange(localDate, startOfDay, endOfDay)}',
      );
      debugPrint('---');
    }
  }

  bool _isDateInRange(DateTime date, DateTime start, DateTime end) {
    return (date.isAfter(start.subtract(const Duration(seconds: 1)))) &&
        (date.isBefore(end.add(const Duration(seconds: 1))));
  }

  Future<void> _toggleTaskCompletion(Task task, bool newValue) async {
    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user!.uid)
          .collection("tasks")
          .doc(task.id)
          .update({'isCompleted': newValue});

      await _loadTasks();
    } catch (e) {
      _showSnackBar('Failed to update task: $e');
    }
  }

  Future<List<Task>> _getPendingTasksForToday() async {
    if (user == null) return [];

    // Get current date in local timezone (IST)
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Convert to UTC for query (account for IST offset)
    final queryStart = DateTime.utc(
      startOfDay.year,
      startOfDay.month,
      startOfDay.day - 1, // Previous day in UTC
      18,
      30,
      0, // 18:30 UTC = 00:00 IST
    );

    final queryEnd = DateTime.utc(
      endOfDay.year,
      endOfDay.month,
      endOfDay.day,
      18,
      29,
      59, // 18:29 UTC = 23:59 IST
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
          .where('isCompleted', isEqualTo: false)
          .get();

      // Filter to local IST day
      return query.docs.map((doc) => Task.fromFireStore(doc)).where((task) {
        final localDue = task.dueDate.toLocal();
        return localDue.isAfter(
              startOfDay.subtract(const Duration(seconds: 1)),
            ) &&
            localDue.isBefore(endOfDay.add(const Duration(seconds: 1)));
      }).toList();
    } catch (e) {
      debugPrint('Error fetching tasks: $e');
      if (e is FirebaseException && e.code == 'failed-precondition') {
        debugPrint('Create composite index for isCompleted and dueDate');
        _showSnackBar('Database index missing - please try again later');
      }
      return [];
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        backgroundColor: Colors.indigo.shade400,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddTaskScreen()),
          ).then((_) => _loadTasks());
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
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -1),
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
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 10,
          items: [
            BottomNavigationBarItem(
              icon: Icon(
                Icons.home,
                color: _currentIndex == 0
                    ? Colors.indigo.shade400
                    : Colors.grey.shade600,
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.bar_chart,
                color: _currentIndex == 1
                    ? Colors.indigo.shade400
                    : Colors.grey.shade600,
              ),
              label: 'Progress',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.book,
                color: _currentIndex == 2
                    ? Colors.indigo.shade400
                    : Colors.grey.shade600,
              ),
              label: 'Diary',
            ),
          ],
        ),
      ),
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
          _pendingTasksToday(context),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back,',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          userData!["name"] ?? 'User',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade800,
            fontSize: 24,
          ),
        ),
      ],
    );
  }

  Widget _pendingTasksToday(BuildContext context) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            'Pending Tasks for ${DateFormat('MMM d, y').format(now)}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade800,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            'Showing tasks between ${DateFormat('h:mm a').format(startOfDay)} and ${DateFormat('h:mm a').format(endOfDay)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ),
        const SizedBox(height: 16),
        _tasks.isEmpty
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: Text(
                    'No pending tasks for today',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  final task = _tasks[index];
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
                        vertical: 8,
                      ),
                      leading: Transform.scale(
                        scale: 1.3,
                        child: Checkbox(
                          value: task.isCompleted,
                          onChanged: (value) =>
                              _toggleTaskCompletion(task, value!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          activeColor: Colors.indigo.shade400,
                        ),
                      ),
                      title: Text(
                        task.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isCompleted
                              ? Colors.grey
                              : Colors.grey[800],
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat(
                                  'MMM d, h:mm a',
                                ).format(task.dueDate.toLocal()),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.flag,
                                size: 16,
                                color: _getPriorityColor(task.priority),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Priority: ${task.priority}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: _getPriorityColor(task.priority),
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
