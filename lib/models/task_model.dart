import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  final String id;
  final String title;
  final String description;
  final DateTime dueDate;
  final String priority;
  final String category;
  final String? repeatOption;
  final String? repeatDay;
  final int? repeatCount;
  final String? repeatUnit;
  final String recurrence;
  final DateTime originalDueDate;
  final bool isCompleted;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    this.priority = 'Medium',
    this.category = 'Other',
    this.repeatOption,
    this.repeatDay,
    this.repeatCount,
    this.repeatUnit,
    this.recurrence = 'none',
    required this.originalDueDate,
    this.isCompleted = false,
    required this.createdAt,
  });

  factory Task.fromFireStore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    DateTime parseTimestamp(Timestamp? timestamp, DateTime fallback) =>
        timestamp?.toDate() ?? fallback;

    final now = DateTime.now();
    final dueDate = parseTimestamp(data['dueDate'] as Timestamp?, now);
    final originalDueDate = parseTimestamp(data['originalDueDate'] as Timestamp?, dueDate);
    final createdAt = parseTimestamp(data['createdAt'] as Timestamp?, now);

    return Task(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled Task',
      description: data['description'] as String? ?? '',
      dueDate: dueDate,
      priority: data['priority'] as String? ?? 'Medium',
      category: data['category'] as String? ?? 'Other',
      repeatOption: data['repeatOption'] as String?,
      repeatDay: data['repeatDay'] as String?,
      repeatCount: data['repeatCount'] as int?,
      repeatUnit: data['repeatUnit'] as String?,
      recurrence: data['recurrence'] as String? ?? 'none',
      originalDueDate: originalDueDate,
      isCompleted: data['isCompleted'] as bool? ?? false,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toFireStore() {
    return {
      'title': title,
      'description': description,
      'dueDate': Timestamp.fromDate(dueDate),
      'priority': priority,
      'category': category,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      if (repeatOption != null) 'repeatOption': repeatOption,
      if (repeatDay != null) 'repeatDay': repeatDay,
      if (repeatCount != null) 'repeatCount': repeatCount,
      if (repeatUnit != null) 'repeatUnit': repeatUnit,
      'recurrence': recurrence,
      'originalDueDate': Timestamp.fromDate(originalDueDate),
    };
  }
}