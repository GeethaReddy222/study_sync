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
  final bool isRecurring;
  final DateTime? lastRecurrenceDate;
  final Duration duration;
  bool notificationSent = false;

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
    this.isRecurring = false,
    this.lastRecurrenceDate,
    required this.duration,
    this.notificationSent = false,
  });

  DateTime get endDate => dueDate.add(duration);

  factory Task.fromFireStore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parseTimestamp(Timestamp? timestamp, DateTime fallback) =>
        timestamp?.toDate() ?? fallback;

    final now = DateTime.now();
    final dueDate = parseTimestamp(data['dueDate'] as Timestamp?, now);
    final originalDueDate = parseTimestamp(
      data['originalDueDate'] as Timestamp?,
      dueDate,
    );
    final createdAt = parseTimestamp(data['createdAt'] as Timestamp?, now);
    final lastRecurrenceDate = parseTimestamp(
      data['lastRecurrenceDate'] as Timestamp?,
      dueDate,
    );

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
      isRecurring: data['isRecurring'] as bool? ?? false,
      lastRecurrenceDate: lastRecurrenceDate,
      duration: Duration(minutes: data['durationMinutes'] as int? ?? 30),
      notificationSent: data['notificationSent'] as bool? ?? false,
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
      'notificationSent': notificationSent,
      'createdAt': Timestamp.fromDate(createdAt),
      if (repeatOption != null) 'repeatOption': repeatOption,
      if (repeatDay != null) 'repeatDay': repeatDay,
      if (repeatCount != null) 'repeatCount': repeatCount,
      if (repeatUnit != null) 'repeatUnit': repeatUnit,
      'recurrence': recurrence,
      'originalDueDate': Timestamp.fromDate(originalDueDate),
      'isRecurring': isRecurring,
      if (lastRecurrenceDate != null)
        'lastRecurrenceDate': Timestamp.fromDate(lastRecurrenceDate!),
      'durationMinutes': duration.inMinutes,
    };
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    String? priority,
    String? category,
    String? repeatOption,
    String? repeatDay,
    int? repeatCount,
    String? repeatUnit,
    String? recurrence,
    DateTime? originalDueDate,
    bool? isCompleted,
    DateTime? createdAt,
    bool? isRecurring,
    DateTime? lastRecurrenceDate,
    Duration? duration,
    bool? notificationSent,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      repeatOption: repeatOption ?? this.repeatOption,
      repeatDay: repeatDay ?? this.repeatDay,
      repeatCount: repeatCount ?? this.repeatCount,
      repeatUnit: repeatUnit ?? this.repeatUnit,
      recurrence: recurrence ?? this.recurrence,
      originalDueDate: originalDueDate ?? this.originalDueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      isRecurring: isRecurring ?? this.isRecurring,
      lastRecurrenceDate: lastRecurrenceDate ?? this.lastRecurrenceDate,
      duration: duration ?? this.duration,
      notificationSent: notificationSent ?? this.notificationSent,
    );
  }
}