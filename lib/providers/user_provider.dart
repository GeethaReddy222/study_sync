import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider with ChangeNotifier {
  String _name = '';
  String _email = '';
  String? _uid;
  bool _isLoading = false;

  String get name => _name;
  String get email => _email;
  String? get uid => _uid;
  bool get isLoading => _isLoading;

  Future<void> loadUserData(User user) async {
    _isLoading = true;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        _name = doc.data()!['name'] ?? user.displayName ?? '';
        _email = doc.data()!['email'] ?? user.email ?? '';
      } else {
        await _createNewUser(user);
      }
      _uid = user.uid;
    } catch (e) {
      debugPrint('Error loading user data: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _createNewUser(User user) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    _name = user.displayName ?? '';
    _email = user.email ?? '';
  }

  Future<void> updateUser(String newName, String newEmail) async {
    if (_uid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await FirebaseFirestore.instance.collection('users').doc(_uid).update({
        'name': newName,
        'email': newEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _name = newName;
      _email = newEmail;
    } catch (e) {
      debugPrint('Error updating user: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearUser() {
    _name = '';
    _email = '';
    _uid = null;
    notifyListeners();
  }
}