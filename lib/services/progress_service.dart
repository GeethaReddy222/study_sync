import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:study_sync/models/progress_model.dart';
import 'package:study_sync/models/task_model.dart';

class ProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _userProgressRef {
    final userId = _auth.currentUser?.uid;
    return _firestore.collection('users').doc(userId).collection('progress');
  }

  // Save daily progress
  Future<void> saveDailyProgress(DailyProgress progress) async {
    await _userProgressRef
        .doc(_formatDate(progress.date))
        .set(progress.toMap());
  }

  // Get progress for a specific date
  Future<DailyProgress?> getDailyProgress(DateTime date) async {
    final doc = await _userProgressRef.doc(_formatDate(date)).get();
    if (doc.exists) {
      return DailyProgress.fromMap(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  // Get progress for a date range
  Future<List<DailyProgress>> getProgressRange(
    DateTime start,
    DateTime end,
  ) async {
    final query = _userProgressRef
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date', descending: true);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      return DailyProgress.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();
  }

  // Calculate weekly progress
  Future<ProgressSummary> getWeeklyProgress(DateTime weekStart) async {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final progressList = await getProgressRange(weekStart, weekEnd);

    return _calculateSummary(progressList, 7);
  }

  // Calculate monthly progress
  Future<ProgressSummary> getMonthlyProgress(DateTime monthStart) async {
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0);
    final progressList = await getProgressRange(monthStart, monthEnd);

    final daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;
    return _calculateSummary(progressList, daysInMonth);
  }

  ProgressSummary _calculateSummary(
    List<DailyProgress> progressList,
    int totalDays,
  ) {
    int totalCompleted = 0;
    int totalTasks = 0;
    int totalStudyMinutes = 0;
    int daysWithData = progressList.length;

    for (final progress in progressList) {
      totalCompleted += progress.completedTasks;
      totalTasks += progress.totalTasks;
      totalStudyMinutes += progress.studyMinutes;
    }

    return ProgressSummary(
      averageCompletion: totalTasks > 0
          ? (totalCompleted / totalTasks) * 100
          : 0,
      totalStudyMinutes: totalStudyMinutes,
      daysWithData: daysWithData,
      consistencyScore: (daysWithData / totalDays) * 100,
      totalTasksCompleted: totalCompleted,
      totalTasks: totalTasks,
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // Update daily progress (call this when tasks change)
  Future<void> updateDailyProgress() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Get today's tasks
    final tasks = await _getTasksForDate(today, false);
    final completedTasks = await _getCompletedTasksForDate(today);

    // Calculate study minutes (placeholder - implement your own tracking)
    final studyMinutes = _calculateStudyMinutes(tasks, completedTasks);

    final progress = DailyProgress(
      date: today,
      completedTasks: completedTasks.length,
      totalTasks: tasks.length + completedTasks.length,
      studyMinutes: studyMinutes,
    );

    await saveDailyProgress(progress);
  }

  Future<List<Task>> _getTasksForDate(DateTime date, bool completed) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    try {
      QuerySnapshot query;

      if (completed) {
        query = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('tasks')
            .where('isCompleted', isEqualTo: true)
            .get();
      } else {
        query = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('tasks')
            .where('isCompleted', isEqualTo: false)
            .get();
      }

      final tasks = query.docs
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

      // Filter by due date
      if (!completed) {
        tasks.removeWhere((task) {
          final dueDate = task.dueDate.toLocal();
          return !(dueDate.isAfter(startOfDay) && dueDate.isBefore(endOfDay));
        });
      }

      return tasks;
    } catch (e) {
      return [];
    }
  }

  Future<List<Task>> _getCompletedTasksForDate(DateTime date) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
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
              return completionDate.year == date.year &&
                  completionDate.month == date.month &&
                  completionDate.day == date.day;
            }
            return false;
          })
          .cast<Task>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  int _calculateStudyMinutes(List<Task> tasks, List<Task> completedTasks) {
    // Simple calculation - 30 minutes per task
    // Replace with your actual study time tracking
    return (tasks.length + completedTasks.length) * 30;
  }
}
