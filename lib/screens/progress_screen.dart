import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:study_sync/models/task_model.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:intl/intl.dart';

class ProgressScreen extends StatefulWidget {
  final VoidCallback? onRefresh;

  const ProgressScreen({super.key, this.onRefresh});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isLoadingTasks = false;
  List<Task> _tasks = [];
  List<Task> _pendingTasks = [];
  List<Task> _completedTasks = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _getTasks();
  }

  // Make this method public so it can be called from HomeScreen
  Future<void> _getTasks() async {
    if (!mounted || user == null) return;
    setState(() {
      _isLoadingTasks = true;
      _errorMessage = null;
    });

    try {
      final tasks = await _getTasksForToday();
      final completedTasks = await _getCompletedTasksForToday();

      if (mounted) {
        setState(() {
          _tasks = tasks;
          _completedTasks = completedTasks;
          _pendingTasks = tasks
              .where((task) => !completedTasks.any((t) => t.id == task.id))
              .toList();
          _isLoadingTasks = false;
        });
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTasks = false;
          _errorMessage = 'Firestore error: ${e.message}';
        });
        _showSnackBar('Failed to load tasks: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTasks = false;
          _errorMessage = 'Unexpected error: $e';
        });
        _showSnackBar('Failed to load tasks');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<List<Task>> _getTasksForToday() async {
    if (user == null) {
      return [];
    }

    final DateTime now = DateTime.now();
    final DateTime startOfDay = DateTime(now.year, now.month, now.day);
    final DateTime endOfDay = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
    );

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user!.uid)
          .collection("tasks")
          .where('dueDate', isGreaterThanOrEqualTo: startOfDay)
          .where('dueDate', isLessThanOrEqualTo: endOfDay)
          .get();

      return querySnapshot.docs
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
    } on FirebaseException catch (e) {
      debugPrint('Firestore error: ${e.message}');
      setState(() {
        _errorMessage = 'Firestore error: ${e.message}';
      });
      return [];
    } catch (e) {
      debugPrint('Error fetching tasks: $e');
      return [];
    }
  }

  Future<List<Task>> _getCompletedTasksForToday() async {
    if (user == null) {
      return [];
    }

    final DateTime now = DateTime.now();

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user!.uid)
          .collection("tasks")
          .where('isCompleted', isEqualTo: true)
          .get();

      // Filter locally for tasks completed today using lastRecurrenceDate
      return querySnapshot.docs
          .map((doc) {
            try {
              return Task.fromFireStore(doc);
            } catch (e) {
              debugPrint('Error parsing task ${doc.id}: $e');
              return null;
            }
          })
          .where((task) => task != null)
          .where((task) {
            // Check if task was completed today using lastRecurrenceDate
            if (task!.lastRecurrenceDate != null) {
              final completionDate = task.lastRecurrenceDate!;
              return completionDate.year == now.year &&
                  completionDate.month == now.month &&
                  completionDate.day == now.day;
            }
            return false;
          })
          .cast<Task>()
          .toList();
    } on FirebaseException catch (e) {
      debugPrint('Firestore error: ${e.message}');
      setState(() {
        _errorMessage = 'Firestore error: ${e.message}';
      });
      return [];
    } catch (e) {
      debugPrint('Error fetching completed tasks: $e');
      return [];
    }
  }

  double get _completionPercentage {
    if (_tasks.isEmpty) return 0.0;
    return _completedTasks.length / _tasks.length;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: _errorMessage != null
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Permission Error',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _getTasks,
                      child: const Text('Retry'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Note: Make sure your Firestore rules allow access to the "users" collection',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : _isLoadingTasks
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Text(
                              'Today\'s Progress',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            CircularPercentIndicator(
                              radius: 70.0,
                              lineWidth: 13.0,
                              animation: true,
                              percent: _completionPercentage.clamp(0.0, 1.0),
                              center: Text(
                                '${(_completionPercentage * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20.0,
                                ),
                              ),
                              circularStrokeCap: CircularStrokeCap.round,
                              progressColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.2),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              constraints: const BoxConstraints(maxWidth: 300),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStatCard(
                                    context,
                                    'Completed',
                                    _completedTasks.length.toString(),
                                    Colors.green,
                                  ),
                                  _buildStatCard(
                                    context,
                                    'Pending',
                                    _pendingTasks.length.toString(),
                                    Colors.orange,
                                  ),
                                  _buildStatCard(
                                    context,
                                    'Total',
                                    _tasks.length.toString(),
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Tasks Overview',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          TabBar(
                            indicatorColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            labelColor: Theme.of(context).colorScheme.primary,
                            tabs: const [
                              Tab(text: 'Completed'),
                              Tab(text: 'Pending'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _completedTasks.isEmpty
                                    ? _buildEmptyState(
                                        Icons.check_circle_outline,
                                        'No tasks completed today',
                                        'Complete some tasks to see them here',
                                      )
                                    : ListView.builder(
                                        itemCount: _completedTasks.length,
                                        itemBuilder: (context, index) {
                                          final task = _completedTasks[index];
                                          return _buildTaskItem(task, true);
                                        },
                                      ),
                                _pendingTasks.isEmpty
                                    ? _buildEmptyState(
                                        Icons.assignment_turned_in,
                                        'No pending tasks for today',
                                        'All tasks are completed! Great job!',
                                      )
                                    : ListView.builder(
                                        itemCount: _pendingTasks.length,
                                        itemBuilder: (context, index) {
                                          final task = _pendingTasks[index];
                                          return _buildTaskItem(task, false);
                                        },
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskItem(Task task, bool isCompleted) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCompleted
                ? Colors.green.withOpacity(0.2)
                : Colors.orange.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCompleted ? Icons.check : Icons.access_time,
            color: isCompleted ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(task.title),
        subtitle: Text(DateFormat.jm().format(task.dueDate.toLocal())),
        trailing: isCompleted
            ? Text(
                'Completed',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              subtitle,
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
