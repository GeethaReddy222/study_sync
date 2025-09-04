import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_sync/models/diary_model.dart';

class DiaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get reference to user's diary collection
  CollectionReference get _userDiaryRef {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    return _firestore.collection('users').doc(userId).collection('diary');
  }

  // Create a new diary entry for today
  Future<void> createTodayEntry(DiaryEntry entry) async {
    // Validate that the entry is for today
    final now = DateTime.now();
    final entryDate = entry.date;

    if (entryDate.year != now.year ||
        entryDate.month != now.month ||
        entryDate.day != now.day) {
      throw Exception('Can only create entries for today');
    }

    // Check if an entry already exists for today
    final existingEntry = await getTodaysEntry();
    if (existingEntry != null) {
      throw Exception('An entry already exists for today');
    }

    // Create the entry
    await _userDiaryRef.add(entry.toMap());
  }

  // Get today's diary entry
  Future<DiaryEntry?> getTodaysEntry() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final querySnapshot = await _userDiaryRef
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final doc = querySnapshot.docs.first;
      return DiaryEntry.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    } catch (e) {
      print('Error getting today\'s diary entry: $e');
      return null;
    }
  }

  // Get diary entry for a specific date
  Future<DiaryEntry?> getEntryForDate(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final querySnapshot = await _userDiaryRef
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final doc = querySnapshot.docs.first;
      return DiaryEntry.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    } catch (e) {
      print('Error getting diary entry for date: $e');
      return null;
    }
  }

  // Get all diary entries
  Stream<List<DiaryEntry>> getAllEntries() {
    return _userDiaryRef
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => DiaryEntry.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
  }

  // Check if entry exists for today
  Future<bool> hasEntryForToday() async {
    final entry = await getTodaysEntry();
    return entry != null;
  }

  // Get entries with dates that have entries
  Future<List<DateTime>> getEntryDates() async {
    try {
      final querySnapshot = await _userDiaryRef
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['date'] as Timestamp;
        return timestamp.toDate();
      }).toList();
    } catch (e) {
      print('Error getting entry dates: $e');
      return [];
    }
  }
}
