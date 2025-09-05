import 'package:cloud_firestore/cloud_firestore.dart';

class DailyProgress {
  final DateTime date;
  final int completedTasks;
  final int totalTasks;
  final int studyMinutes;

  DailyProgress({
    required this.date,
    required this.completedTasks,
    required this.totalTasks,
    required this.studyMinutes,
  });

  double get completionPercentage {
    return totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'completedTasks': completedTasks,
      'totalTasks': totalTasks,
      'studyMinutes': studyMinutes,
    };
  }

  factory DailyProgress.fromMap(Map<String, dynamic> map) {
    return DailyProgress(
      date: (map['date'] as Timestamp).toDate(),
      completedTasks: map['completedTasks'],
      totalTasks: map['totalTasks'],
      studyMinutes: map['studyMinutes'],
    );
  }
}

class ProgressSummary {
  final double averageCompletion;
  final int totalStudyMinutes;
  final int daysWithData;
  final double consistencyScore;
  final int totalTasksCompleted;
  final int totalTasks;

  ProgressSummary({
    required this.averageCompletion,
    required this.totalStudyMinutes,
    required this.daysWithData,
    required this.consistencyScore,
    required this.totalTasksCompleted,
    required this.totalTasks,
  });
}
