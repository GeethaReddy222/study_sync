import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  final String? id;
  final String title;
  final String description;
  final DateTime dueDate;
  final String priority;
  final String category;
  final String repeatOption;
  final bool isCompleted;
  final Timestamp createdAt;
  final String? repeatDay;
  final int? repeatCount;
  final String? repeatUnit;

  Task({
    this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.priority,
    required this.category,
    required this.repeatOption,
    this.isCompleted = false,
    Timestamp? createdAt,
    this.repeatDay,
    this.repeatCount,
    this.repeatUnit,
  }) : createdAt = createdAt ?? Timestamp.now();

  factory Task.fromFireStore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Task(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      priority: data['priority'] ?? 'Medium',
      category: data['category'] ?? 'Other',
      repeatOption: data['repeatOption'] ?? 'Does not repeat',
      isCompleted: data['isCompleted'] ?? false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      repeatDay: data['repeatDay'],
      repeatCount: data['repeatCount'],
      repeatUnit: data['repeatUnit'],
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
      'createdAt': createdAt,
      'repeatOption': repeatOption,
      if (repeatDay != null) 'repeatDay': repeatDay,
      if (repeatCount != null) 'repeatCount': repeatCount,
      if (repeatUnit != null) 'repeatUnit': repeatUnit,
    };
  }
}