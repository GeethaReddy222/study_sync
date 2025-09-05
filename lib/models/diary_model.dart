import 'package:cloud_firestore/cloud_firestore.dart';

class DiaryEntry {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String mood;
  final DateTime createdAt;

  DiaryEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.mood,
    required this.createdAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'date': Timestamp.fromDate(date),
      'mood': mood,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Firestore Document
  factory DiaryEntry.fromMap(String id, Map<String, dynamic> map) {
    return DiaryEntry(
      id: id,
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      mood: map['mood'] ?? '😊',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  // Check if this entry is for today
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // Create a new empty entry for today
  factory DiaryEntry.forToday() {
    final now = DateTime.now();
    return DiaryEntry(
      id: '',
      title: '',
      content: '',
      date: DateTime(now.year, now.month, now.day),
      mood: '😊',
      createdAt: now,
    );
  }
}
