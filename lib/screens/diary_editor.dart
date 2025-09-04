import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:study_sync/models/diary_model.dart';
import 'package:study_sync/services/diary_service.dart';

class DiaryEditor extends StatefulWidget {
  const DiaryEditor({super.key});

  @override
  State<DiaryEditor> createState() => _DiaryEditorState();
}

class _DiaryEditorState extends State<DiaryEditor> {
  final DiaryService _diaryService = DiaryService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String _selectedMood = '😊';
  bool _isPrivate = false;
  final List<String> _moodOptions = ['😊', '😐', '😞', '🎯', '💡'];
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveEntry() async {
    if (_contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something in your diary')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Creating a new entry for today
      final newEntry = DiaryEntry(
        id: '',
        title: _titleController.text,
        content: _contentController.text,
        date: today,
        mood: _selectedMood,
        isPrivate: _isPrivate,
        createdAt: now,
      );

      await _diaryService.createTodayEntry(newEntry);

      Navigator.pop(context, true);
    } catch (e) {
      print('Error saving entry: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save entry: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primaryContainer.withOpacity(0.05),
              theme.colorScheme.primaryContainer.withOpacity(0.15),
            ],
          ),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Header
                  Center(
                    child: Text(
                      'Today - ${DateFormat('EEEE, MMMM d, y').format(DateTime.now())}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title Field
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'Title (optional)',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Content Field
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText:
                          'What happened today?\nHow did you feel?\nWhat did you learn?',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                        fontSize: 16,
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                      height: 1.5,
                    ),
                    keyboardType: TextInputType.multiline,
                  ),

                  const SizedBox(height: 32),

                  // Mood Selector
                  Text(
                    'How was your day?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _moodOptions.map((mood) {
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedMood = mood);
                        },
                        child: Material(
                          borderRadius: BorderRadius.circular(12),
                          elevation: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedMood == mood
                                  ? theme.colorScheme.primary.withOpacity(0.2)
                                  : theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedMood == mood
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline.withOpacity(
                                        0.3,
                                      ),
                                width: _selectedMood == mood ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              mood,
                              style: TextStyle(
                                fontSize: 20,
                                color: _selectedMood == mood
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Privacy Toggle
                  Material(
                    borderRadius: BorderRadius.circular(12),
                    elevation: 2,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isPrivate
                                ? Icons.lock_rounded
                                : Icons.public_rounded,
                            color: _isPrivate
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Private Entry',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Switch(
                            value: _isPrivate,
                            onChanged: (value) =>
                                setState(() => _isPrivate = value),
                            activeColor: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),

            // Back Button
            Positioned(
              top: 40,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _isSaving ? null : () => Navigator.pop(context),
              ),
            ),

            // Save Button
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveEntry,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(
                            'Create Entry',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
