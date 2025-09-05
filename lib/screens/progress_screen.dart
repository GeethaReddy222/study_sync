import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:study_sync/models/progress_model.dart';
import 'package:study_sync/models/task_model.dart';
import 'package:study_sync/services/progress_service.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ProgressScreen extends StatefulWidget {
  final VoidCallback? onRefresh;

  const ProgressScreen({super.key, this.onRefresh});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  final ProgressService _progressService = ProgressService();
  final User? user = FirebaseAuth.instance.currentUser;
  late TabController _tabController;

  // Today's progress data
  List<Task> _tasks = [];
  List<Task> _completedTasks = [];
  List<Task> _pendingTasks = [];
  bool _isLoadingTasks = false;
  String? _errorMessage;

  // Historical progress data
  List<DailyProgress> _weeklyProgress = [];
  ProgressSummary? _weeklySummary;
  ProgressSummary? _monthlySummary;
  bool _isLoadingHistorical = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _getTasks();
    _loadHistoricalData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTasks = false;
          _errorMessage = 'Unexpected error: $e';
        });
      }
    }
  }

  Future<void> _loadHistoricalData() async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      _weeklyProgress = await _progressService.getProgressRange(
        weekStart.subtract(const Duration(days: 6)),
        now,
      );

      _weeklySummary = await _progressService.getWeeklyProgress(weekStart);
      _monthlySummary = await _progressService.getMonthlyProgress(monthStart);
    } catch (e) {
      print('Error loading progress data: $e');
      // Don't set error message here as it's not critical for the main functionality
    }

    // Check if widget is still mounted before calling setState
    if (mounted) {
      setState(() => _isLoadingHistorical = false);
    }
  }

  Future<List<Task>> _getTasksForToday() async {
    if (user == null) return [];

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
          .where(
            'dueDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      return querySnapshot.docs
          .map((doc) {
            try {
              return Task.fromFireStore(doc);
            } catch (e) {
              return null;
            }
          })
          .where((task) => task != null)
          .cast<Task>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Task>> _getCompletedTasksForToday() async {
    if (user == null) return [];

    final DateTime now = DateTime.now();

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user!.uid)
          .collection("tasks")
          .where('isCompleted', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map((doc) {
            try {
              return Task.fromFireStore(doc);
            } catch (e) {
              return null;
            }
          })
          .where((task) => task != null)
          .where((task) {
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
    } catch (e) {
      return [];
    }
  }

  double get _completionPercentage {
    if (_tasks.isEmpty) return 0.0;
    return _completedTasks.length / _tasks.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _errorMessage != null
          ? _buildErrorState()
          : Column(
              children: [
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Today'),
                    Tab(text: 'Weekly'),
                    Tab(text: 'Monthly'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTodayView(),
                      _buildWeeklyView(),
                      _buildMonthlyView(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Permission Error',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _getTasks, child: const Text('Retry')),
            const SizedBox(height: 8),
            Text(
              'Note: Make sure your Firestore rules allow access to the progress collection',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayView() {
    return _isLoadingTasks
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildProgressCard(),
                const SizedBox(height: 24),
                _buildTasksOverview(),
              ],
            ),
          );
  }

  Widget _buildWeeklyView() {
    return _isLoadingHistorical
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_weeklySummary != null)
                  _buildSummaryCard(_weeklySummary!, 'Weekly'),
                const SizedBox(height: 20),
                if (_weeklyProgress.isNotEmpty)
                  _buildProgressChart(_weeklyProgress, 'Weekly Progress'),
                const SizedBox(height: 20),
                if (_weeklyProgress.isNotEmpty)
                  _buildDailyBreakdown(_weeklyProgress),
                if (_weeklyProgress.isEmpty)
                  _buildEmptyState(
                    Icons.history,
                    'No weekly data available',
                    'Complete some tasks to see your weekly progress',
                  ),
              ],
            ),
          );
  }

  Widget _buildMonthlyView() {
    return _isLoadingHistorical
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_monthlySummary != null)
                  _buildSummaryCard(_monthlySummary!, 'Monthly'),
                const SizedBox(height: 20),
                _buildConsistencyMeter(_monthlySummary?.consistencyScore ?? 0),
                if (_monthlySummary == null)
                  _buildEmptyState(
                    Icons.calendar_today,
                    'No monthly data available',
                    'Complete some tasks to see your monthly progress',
                  ),
              ],
            ),
          );
  }

  Widget _buildProgressCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              'Today\'s Progress',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
              progressColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard(
                    'Completed',
                    _completedTasks.length.toString(),
                    Colors.green,
                  ),
                  _buildStatCard(
                    'Pending',
                    _pendingTasks.length.toString(),
                    Colors.orange,
                  ),
                  _buildStatCard(
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
    );
  }

  Widget _buildTasksOverview() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            'Tasks Overview',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                  indicatorColor: Theme.of(context).colorScheme.primary,
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
                              itemBuilder: (context, index) =>
                                  _buildTaskItem(_completedTasks[index], true),
                            ),
                      _pendingTasks.isEmpty
                          ? _buildEmptyState(
                              Icons.assignment_turned_in,
                              'No pending tasks for today',
                              'All tasks are completed! Great job!',
                            )
                          : ListView.builder(
                              itemCount: _pendingTasks.length,
                              itemBuilder: (context, index) =>
                                  _buildTaskItem(_pendingTasks[index], false),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(ProgressSummary summary, String period) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '$period Summary',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Completion',
                  '${summary.averageCompletion.toStringAsFixed(1)}%',
                ),
                _buildStatItem(
                  'Study Time',
                  '${summary.totalStudyMinutes ~/ 60}h',
                ),
                _buildStatItem(
                  'Consistency',
                  '${summary.consistencyScore.toStringAsFixed(1)}%',
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: summary.averageCompletion / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${summary.totalTasksCompleted} of ${summary.totalTasks} tasks completed',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildProgressChart(List<DailyProgress> progress, String title) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                series: <CartesianSeries<DailyProgress, String>>[
                  LineSeries<DailyProgress, String>(
                    dataSource: progress,
                    xValueMapper: (DailyProgress progress, _) =>
                        DateFormat('E').format(progress.date),
                    yValueMapper: (DailyProgress progress, _) =>
                        progress.completionPercentage,
                    markerSettings: const MarkerSettings(isVisible: true),
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyBreakdown(List<DailyProgress> progress) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Breakdown',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...progress.map((daily) => _buildDailyProgressItem(daily)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyProgressItem(DailyProgress progress) {
    return ListTile(
      leading: Text(
        DateFormat('E').format(progress.date),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      title: LinearProgressIndicator(
        value: progress.completionPercentage / 100,
        backgroundColor: Colors.grey[300],
        valueColor: AlwaysStoppedAnimation<Color>(
          Theme.of(context).colorScheme.primary,
        ),
        minHeight: 8,
        borderRadius: BorderRadius.circular(4),
      ),
      trailing: Text('${progress.completedTasks}/${progress.totalTasks}'),
      subtitle: Text(
        DateFormat('MMM d').format(progress.date),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildConsistencyMeter(double consistency) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Consistency Meter',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            CircularProgressIndicator(
              value: consistency / 100,
              strokeWidth: 10,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${consistency.toStringAsFixed(1)}% consistent',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              consistency >= 80
                  ? 'Excellent consistency! 🎯'
                  : consistency >= 60
                  ? 'Good consistency! 👍'
                  : 'Keep working on your routine! 💪',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
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
