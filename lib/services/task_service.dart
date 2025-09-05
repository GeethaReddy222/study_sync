import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:study_sync/models/task_model.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addTask(Task task) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    debugPrint(
      '📝 ADDING TASK: ${task.title} | Due: ${task.dueDate} | Recurring: ${task.isRecurring}',
    );

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .doc(task.id)
          .set(task.toFireStore());
      debugPrint('✅ TASK ADDED SUCCESSFULLY');
    } catch (e) {
      debugPrint('❌ ERROR ADDING TASK: $e');
      rethrow;
    }
  }

  Future<void> completeTask(Task task) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    debugPrint(
      '✅ COMPLETING TASK: ${task.title} | Recurring: ${task.isRecurring}',
    );

    try {
      if (task.isRecurring) {
        final nextOccurrence = _calculateNextOccurrence(task);
        debugPrint('🔄 CREATING NEXT OCCURRENCE: $nextOccurrence');

        await addTask(
          task.copyWith(
            id: _firestore.collection('tasks').doc().id,
            dueDate: nextOccurrence,
            isCompleted: false,
            createdAt: DateTime.now(),
          ),
        );
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .doc(task.id)
          .update({'isCompleted': true});

      debugPrint('✅ TASK COMPLETED SUCCESSFULLY');
    } catch (e) {
      debugPrint('❌ ERROR COMPLETING TASK: $e');
      rethrow;
    }
  }

  Future<List<Task>> getPendingTasks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    debugPrint(
      '\n🔍 FETCHING PENDING TASKS FOR: ${DateFormat('MMM dd, yyyy').format(now)}',
    );
    debugPrint('📅 Date range: ${todayStart} to ${todayEnd}');

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .where('isCompleted', isEqualTo: false)
          .where('dueDate', isLessThan: Timestamp.fromDate(todayEnd))
          .get();

      final List<Task> pendingTasks = [];
      final List<Future> updates = [];

      debugPrint('📦 TOTAL TASKS FOUND: ${snapshot.docs.length}');

      for (final doc in snapshot.docs) {
        final task = Task.fromFireStore(doc);
        debugPrint('\n🔎 PROCESSING TASK: ${task.title}');
        debugPrint('   - Due: ${task.dueDate}');
        debugPrint('   - Completed: ${task.isCompleted}');
        debugPrint('   - Recurring: ${task.isRecurring} (${task.recurrence})');
        debugPrint(
          '   - Last Occurrence: ${task.lastRecurrenceDate ?? 'None'}',
        );

        pendingTasks.add(task);

        if (task.isRecurring && _needsNewOccurrence(task, now)) {
          final newDueDate = _calculateNextOccurrence(task);
          debugPrint(
            '   🔄 RECURRENCE NEEDED: Creating new occurrence for $newDueDate',
          );

          final newTask = task.copyWith(
            id: _firestore.collection('tasks').doc().id,
            dueDate: newDueDate,
            isCompleted: false,
            createdAt: DateTime.now(),
          );

          updates.add(addTask(newTask));
          updates.add(
            _firestore
                .collection('users')
                .doc(user.uid)
                .collection('tasks')
                .doc(task.id)
                .update({
                  'lastRecurrenceDate': Timestamp.fromDate(now),
                  'isCompleted': true,
                }),
          );
        }
      }

      if (updates.isNotEmpty) {
        debugPrint('\n🛠 PERFORMING ${updates.length} UPDATES');
        await Future.wait(updates);
      }

      debugPrint('\n📋 FINAL PENDING TASKS: ${pendingTasks.length}');
      for (final task in pendingTasks) {
        debugPrint('   - ${task.title} (Due: ${task.dueDate})');
      }

      return pendingTasks;
    } catch (e) {
      debugPrint('❌ ERROR FETCHING TASKS: $e');
      rethrow;
    }
  }

  // Add these methods to your existing TaskService class

  Future<List<Task>> getTasksForToday(bool completed) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _getTasksForDateRange(startOfDay, endOfDay, completed);
  }

  Future<List<Task>> getCompletedTasksForToday() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final now = DateTime.now();
    return _getCompletedTasksForDate(now);
  }

  Future<List<Task>> _getTasksForDateRange(
    DateTime start,
    DateTime end,
    bool completed,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      QuerySnapshot query;

      if (completed) {
        query = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('tasks')
            .where('isCompleted', isEqualTo: true)
            .get();
      } else {
        query = await FirebaseFirestore.instance
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
          return !(dueDate.isAfter(start) && dueDate.isBefore(end));
        });
      }

      return tasks;
    } catch (e) {
      return [];
    }
  }

  Future<List<Task>> _getCompletedTasksForDate(DateTime date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final querySnapshot = await FirebaseFirestore.instance
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

  bool _needsNewOccurrence(Task task, DateTime now) {
    if (!task.isRecurring) return false;

    final lastOccurrence = task.lastRecurrenceDate ?? task.dueDate;
    final today = DateTime(now.year, now.month, now.day);

    bool needsOccurrence = false;
    String reason = '';

    switch (task.recurrence) {
      case 'daily':
        needsOccurrence = today.isAfter(lastOccurrence);
        reason = needsOccurrence
            ? 'Daily recurrence needed'
            : 'Not enough time passed';
        break;
      case 'weekly':
        needsOccurrence =
            now.weekday == task.dueDate.weekday &&
            today.difference(lastOccurrence).inDays >= 7;
        reason = needsOccurrence
            ? 'Weekly recurrence day matched'
            : 'Wrong weekday or not enough time';
        break;
      case 'biweekly':
        needsOccurrence =
            now.weekday == task.dueDate.weekday &&
            today.difference(lastOccurrence).inDays >= 14;
        reason = needsOccurrence
            ? 'Biweekly recurrence day matched'
            : 'Wrong weekday or not enough time';
        break;
      case 'monthly':
        needsOccurrence =
            now.day == task.dueDate.day &&
            (now.month > lastOccurrence.month ||
                now.year > lastOccurrence.year);
        reason = needsOccurrence
            ? 'Monthly recurrence day matched'
            : 'Wrong day or month';
        break;
      default:
        reason = 'Not a recurring task';
    }

    debugPrint('   - Recurrence Check: $reason');
    return needsOccurrence;
  }

  DateTime _calculateNextOccurrence(Task task) {
    final lastOccurrence = task.lastRecurrenceDate ?? task.dueDate;
    final originalTime = TimeOfDay.fromDateTime(task.dueDate);

    DateTime nextDate;

    switch (task.recurrence) {
      case 'daily':
        nextDate = DateTime(
          lastOccurrence.year,
          lastOccurrence.month,
          lastOccurrence.day + 1,
          originalTime.hour,
          originalTime.minute,
        );
        break;
      case 'weekly':
        nextDate = DateTime(
          lastOccurrence.year,
          lastOccurrence.month,
          lastOccurrence.day + 7,
          originalTime.hour,
          originalTime.minute,
        );
        break;
      case 'biweekly':
        nextDate = DateTime(
          lastOccurrence.year,
          lastOccurrence.month,
          lastOccurrence.day + 14,
          originalTime.hour,
          originalTime.minute,
        );
        break;
      case 'monthly':
        nextDate = DateTime(
          lastOccurrence.month == 12
              ? lastOccurrence.year + 1
              : lastOccurrence.year,
          lastOccurrence.month == 12 ? 1 : lastOccurrence.month + 1,
          task.dueDate.day,
          originalTime.hour,
          originalTime.minute,
        );
        break;
      default:
        nextDate = task.dueDate;
    }

    debugPrint('   - Next Occurrence: $nextDate');
    return nextDate;
  }
}
