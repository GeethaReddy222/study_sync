import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:study_sync/models/diary_model.dart';
import 'package:study_sync/services/diary_service.dart';
import 'diary_editor.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final DiaryService _diaryService = DiaryService();
  DiaryEntry? _todaysEntry;
  bool _isLoading = true;
  int _selectedIndex = 0; // 0 = today, 1 = previous entries

  DiaryEntry? _selectedEntry;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadTodaysEntry();
  }

  Future<void> _loadTodaysEntry() async {
    setState(() => _isLoading = true);
    try {
      final entry = await _diaryService.getTodaysEntry();
      setState(() {
        _todaysEntry = entry;
        _isLoading = false;
        // Set the selected entry to today's entry by default
        if (_selectedIndex == 0 && entry != null) {
          _selectedEntry = entry;
          _selectedDate = DateTime.now();
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToEditor() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DiaryEditor()),
    );
    if (result == true) _loadTodaysEntry();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 0 && _todaysEntry != null) {
        _selectedEntry = _todaysEntry;
        _selectedDate = DateTime.now();
      } else {
        _selectedEntry = null;
        _selectedDate = null;
      }
    });
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
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
              child: Center(
                child: Text(
                  _selectedIndex == 0
                      ? DateFormat('EEEE, MMMM d, y').format(DateTime.now())
                      : 'Previous Diary Entries',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _onItemTapped(0),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedIndex == 0
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surface,
                        foregroundColor: _selectedIndex == 0
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      ),
                      child: const Text("Today's Entry"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _onItemTapped(1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedIndex == 1
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surface,
                        foregroundColor: _selectedIndex == 1
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      ),
                      child: const Text("Previous Entries"),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedIndex == 0
                  ? _buildTodaysView(theme)
                  : _buildPreviousEntriesView(theme),
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedIndex == 0 && _todaysEntry == null
          ? FloatingActionButton(
              onPressed: _navigateToEditor,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildTodaysView(ThemeData theme) {
    return _todaysEntry == null
        ? _buildEmptyState(theme)
        : _buildEntryContent(theme, _todaysEntry!);
  }

  Widget _buildPreviousEntriesView(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
          child: ElevatedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                builder: (BuildContext context, Widget? child) {
                  return Theme(
                    data: ThemeData.light().copyWith(
                      dialogBackgroundColor: Colors.white,
                      colorScheme: ColorScheme.light(
                        primary: theme.colorScheme.primary,
                      ),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.9,
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: child,
                      ),
                    ),
                  );
                },
              );

              if (picked != null) {
                final entry = await _diaryService.getEntryForDate(picked);
                setState(() {
                  _selectedDate = picked;
                  _selectedEntry = entry;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.calendar_month),
            label: const Text("Pick a Date", style: TextStyle(fontSize: 16)),
          ),
        ),

        Expanded(
          child: _selectedEntry != null
              ? _buildEntryContent(theme, _selectedEntry!)
              : _selectedDate != null
              ? Center(
                  child: Text(
                    "No entry for ${DateFormat('MMM d, y').format(_selectedDate!)}",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 64,
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select a date to view entry',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEntryContent(ThemeData theme, DiaryEntry entry) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMM d, y').format(entry.date),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (entry.title.isNotEmpty) ...[
                Text(
                  entry.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                entry.content,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(entry.mood, style: const TextStyle(fontSize: 24)),
                  const Spacer(),
                  Text(
                    DateFormat('MMM d, y • hh:mm a').format(entry.createdAt),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
            "No entry for today yet",
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap the + button to write about your day",
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
