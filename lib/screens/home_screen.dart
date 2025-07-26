import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:study_sync/screens/add_task_screen.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<Home> {
  final List<Map<String, dynamic>> _tasks = [
    {
      'id': '1',
      'title': 'Complete Math Assignment',
      'dueDate': DateTime.now().add(const Duration(days: 1)),
      'priority': 'High',
      'category': 'Study',
      'completed': false,
    },
    {
      'id': '2',
      'title': 'Read Chapter 5 of Physics',
      'dueDate': DateTime.now().add(const Duration(days: 2)),
      'priority': 'Medium',
      'category': 'Study',
      'completed': false,
    },
  ];

  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StudySync'),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_today), onPressed: () {}),
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: [
          // Tasks Tab
          _buildTasksTab(),
          // Progress Tab
          _buildProgressTab(),
          // Profile Tab
          _buildProfileTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newTask = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddTaskScreen()),
          );

          if (newTask != null) {
            setState(() {
              _tasks.add(newTask);
            });
          }
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.task), label: 'Tasks'),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Progress',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildTasksTab() {
    final pendingTasks = _tasks.where((task) => !task['completed']).toList();
    final completedTasks = _tasks.where((task) => task['completed']).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting and Date
          _buildHeader(),
          const SizedBox(height: 20),

          // Task Stats
          _buildTaskStats(),
          const SizedBox(height: 20),

          // Pending Tasks
          const Text(
            'Pending Tasks',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...pendingTasks.map((task) => _buildTaskCard(task)).toList(),

          // Completed Tasks (if any)
          if (completedTasks.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Completed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...completedTasks.map((task) => _buildTaskCard(task)).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, Student!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        Text(
          DateFormat('EEEE, MMMM d').format(DateTime.now()),
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildTaskStats() {
    final totalTasks = _tasks.length;
    final completedCount = _tasks.where((task) => task['completed']).length;
    final progress = totalTasks > 0 ? completedCount / totalTasks : 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Productivity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress as double,
              backgroundColor: Colors.blue[100],
              color: Colors.blueAccent,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$completedCount/${_tasks.length} tasks completed',
                  style: TextStyle(fontSize: 14, color: Colors.blue[800]),
                ),
                if (_tasks.isNotEmpty)
                  Text(
                    '${_getUrgentTasksCount()} urgent',
                    style: TextStyle(fontSize: 14, color: Colors.red[600]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final isCompleted = task['completed'] ?? false;
    final dueDate = task['dueDate'] as DateTime?;
    final priority = task['priority'] ?? 'Medium';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Checkbox
            Checkbox(
              value: isCompleted,
              onChanged: (value) {
                setState(() {
                  task['completed'] = value ?? false;
                });
              },
              shape: RoundedCircleBorder(),
            ),

            // Task Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  if (dueDate != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM dd, hh:mm a').format(dueDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(priority).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          priority,
                          style: TextStyle(
                            fontSize: 12,
                            color: _getPriorityColor(priority),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          task['category'] ?? 'General',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // More Options
            IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressTab() {
    return Center(child: Text('Progress Analytics'));
  }

  Widget _buildProfileTab() {
    return Center(child: Text('Profile Settings'));
  }

  int _getUrgentTasksCount() {
    return _tasks.where((task) {
      final dueDate = task['dueDate'] as DateTime?;
      final isUrgent =
          task['priority'] == 'High' &&
          !(task['completed'] ?? false) &&
          dueDate != null &&
          dueDate.difference(DateTime.now()).inDays <= 1;
      return isUrgent;
    }).length;
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }
}

class RoundedCircleBorder extends RoundedRectangleBorder {
  RoundedCircleBorder() : super(borderRadius: BorderRadius.circular(10));
}
