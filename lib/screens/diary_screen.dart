import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:study_sync/models/diary_model.dart';
import 'package:study_sync/services/diary_service.dart';
import 'diary_editor.dart'; // Import the DiaryEditor

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final DiaryService _diaryService = DiaryService();
  DiaryEntry? _todaysEntry;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodaysEntry();
  }

  Future<void> _loadTodaysEntry() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final entry = await _diaryService.getTodaysEntry();
      setState(() {
        _todaysEntry = entry;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading today\'s entry: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToEditor() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DiaryEditor()),
    );

    if (result == true) {
      _loadTodaysEntry();
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
        child: Column(
          children: [
            // Header with date
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
              child: Center(
                child: Text(
                  DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),

            // Entry Content or Empty State
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _todaysEntry == null
                  ? _buildEmptyState(theme)
                  : _buildEntryContent(theme),
            ),
          ],
        ),
      ),
      floatingActionButton: _todaysEntry == null
          ? FloatingActionButton(
              onPressed: _navigateToEditor,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No entry for today yet',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to write about your day',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryContent(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_todaysEntry!.title.isNotEmpty) ...[
            Text(
              _todaysEntry!.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            _todaysEntry!.content,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(_todaysEntry!.mood, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              if (_todaysEntry!.isPrivate)
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              const Spacer(),
              Text(
                DateFormat('hh:mm a').format(_todaysEntry!.createdAt),
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'You have already written your diary for today',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
