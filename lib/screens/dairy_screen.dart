import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NewDiaryEntryScreen extends StatefulWidget {
  const NewDiaryEntryScreen({super.key});

  @override
  State<NewDiaryEntryScreen> createState() => _NewDiaryEntryScreenState();
}

class _NewDiaryEntryScreenState extends State<NewDiaryEntryScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  String _selectedMood = '😊';
  final List<String> _tags = [];
  bool _isPrivate = false;

  final List<String> _moodOptions = ['😊', '😐', '😞', '🎯', '💡'];

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _saveEntry() {
    // TODO: Implement Firestore save logic
    final newEntry = {
      'title': _titleController.text,
      'body': _bodyController.text,
      'date': DateTime.now(),
      'mood': _selectedMood,
      'tags': _tags,
      'isPrivate': _isPrivate,
    };
    print('Saving entry: $newEntry');
    Navigator.pop(context, newEntry);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(DateFormat('MMMM d, y').format(DateTime.now())),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _saveEntry),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Field
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Title (optional)',
                border: InputBorder.none,
                hintStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            // Body Field
            TextField(
              controller: _bodyController,
              maxLines: null,
              decoration: const InputDecoration(
                hintText:
                    'What did you learn today?\nAny struggles?\nGoals for tomorrow?',
                border: InputBorder.none,
              ),
              keyboardType: TextInputType.multiline,
            ),

            const SizedBox(height: 32),

            // Mood Selector
            const Text('Mood:', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: _moodOptions.map((mood) {
                return ChoiceChip(
                  label: Text(mood),
                  selected: _selectedMood == mood,
                  onSelected: (selected) {
                    setState(() => _selectedMood = mood);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Privacy Toggle
            SwitchListTile(
              title: const Text('Private Entry'),
              value: _isPrivate,
              onChanged: (value) => setState(() => _isPrivate = value),
            ),
          ],
        ),
      ),
    );
  }
}
