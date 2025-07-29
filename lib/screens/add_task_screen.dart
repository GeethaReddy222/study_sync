import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:study_sync/models/task_model.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  String _repeatOption = 'Does not repeat';
  int? _repeatCount;
  String? _selectedWeekday;
  String? _priority;
  String? _category;
  String _selectedUnit = 'weeks';
  bool _isSubmitting = false;
  bool _showTitleError = false;
  bool _showPriorityError = false;
  bool _showCategoryError = false;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final List<String> _units = ['days', 'weeks', 'months'];
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<String> _repeatOptions = [
    'Does not repeat',
    'Daily',
    'Weekly',
    'Bi-Weekly',
    'Monthly',
    'Custom...',
  ];
  final List<String> _weekdays = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];
  final List<String> _categories = [
    "Learning",
    "Assignments",
    "Contests",
    "Projects",
    "Exams",
    "Revision",
    "Other",
  ];
  final List<String> _priorities = ["High", "Medium", "Low"];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitTask() async {
    setState(() {
      _showTitleError = true;
      _showPriorityError = true;
      _showCategoryError = true;
    });

    if (!_formKey.currentState!.validate()) return;
    if (_titleController.text.isEmpty ||
        _priority == null ||
        _category == null ||
        _dueDate == null ||
        _dueTime == null) {
      return;
    }

    if (!_validateTimeForToday()) {
      _showTimeValidationError();
      return;
    }

    // Adjust date for weekly/bi-weekly repeats
    if ((_repeatOption == 'Weekly' || _repeatOption == 'Bi-Weekly') &&
        _selectedWeekday != null) {
      _dueDate = _calculateNextWeeklyDate();
      await _showRepeatConfirmationDialog();
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Create Task object
      final newTask = Task(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: DateTime(
          _dueDate!.year,
          _dueDate!.month,
          _dueDate!.day,
          _dueTime!.hour,
          _dueTime!.minute,
        ),
        priority: _priority!,
        category: _category!,
        repeatOption: _repeatOption,
        repeatDay: _selectedWeekday,
        repeatCount: _repeatCount,
        repeatUnit: _selectedUnit,
      );

      // Add task to Firestore using the model's toFirestore() method
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .add(newTask.toFireStore());

      _showSuccessDialog();
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _validateTimeForToday() {
    if (_dueDate != null &&
        DateUtils.isSameDay(_dueDate!, DateTime.now()) &&
        _dueTime != null) {
      final nowTime = TimeOfDay.now();
      return !(_dueTime!.hour < nowTime.hour ||
          (_dueTime!.hour == nowTime.hour &&
              _dueTime!.minute <= nowTime.minute));
    }
    return true;
  }

  DateTime _calculateNextWeeklyDate() {
    final today = DateTime.now();
    int currentIndex = today.weekday % 7;
    int targetIndex = _weekdays.indexOf(_selectedWeekday!);
    int daysUntilNext = (targetIndex - currentIndex + 7) % 7;
    daysUntilNext = daysUntilNext == 0 ? 7 : daysUntilNext;
    return today.add(
      Duration(days: daysUntilNext + (_repeatOption == 'Bi-Weekly' ? 7 : 0)),
    );
  }

  void _showTimeValidationError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invalid Time'),
        content: const Text('Please select a future time for today'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRepeatConfirmationDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Repeat Task'),
        content: Text('Task will repeat $_repeatOption on $_selectedWeekday'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: const Text('Task has been added successfully!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text('Failed to add task: $error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
        if (_repeatOption == 'Weekly' || _repeatOption == 'Bi-Weekly') {
          _selectedWeekday = _weekdays[picked.weekday % 7];
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _dueTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Task'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isSubmitting ? null : _submitTask,
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Task Details',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Task Title',
                    prefixIcon: const Icon(Icons.title),
                    errorText: _showTitleError && _titleController.text.isEmpty
                        ? 'Please enter a task title'
                        : null,
                  ),
                  onChanged: (value) => setState(() => _showTitleError = false),
                  validator: (value) {
                    if (value != null && value.length > 100) {
                      return 'Title should be less than 100 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value != null && value.length > 500) {
                      return 'Description should be less than 500 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Schedule',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Due Date',
                            prefixIcon: const Icon(Icons.calendar_today),
                            errorText: _dueDate == null && _showTitleError
                                ? 'Please select a date'
                                : null,
                          ),
                          child: Text(
                            _dueDate == null
                                ? 'Select Date'
                                : DateFormat('MMM dd, yyyy').format(_dueDate!),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Due Time',
                            prefixIcon: const Icon(Icons.access_time),
                            errorText: _dueTime == null && _showTitleError
                                ? 'Please select a time'
                                : null,
                          ),
                          child: Text(
                            _dueTime == null
                                ? 'Select Time'
                                : _dueTime!.format(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _repeatOption,
                  decoration: const InputDecoration(
                    labelText: 'Repeat',
                    prefixIcon: Icon(Icons.repeat),
                  ),
                  items: _repeatOptions.map((option) {
                    return DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _repeatOption = newValue!;
                      if (_repeatOption != 'Custom...') _repeatCount = null;
                      if ((_repeatOption == 'Weekly' ||
                              _repeatOption == 'Bi-Weekly') &&
                          _dueDate != null) {
                        _selectedWeekday = _weekdays[_dueDate!.weekday % 7];
                      }
                    });
                  },
                ),
                if (_repeatOption == 'Weekly' ||
                    _repeatOption == 'Bi-Weekly') ...[
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value:
                        _selectedWeekday ??
                        _weekdays[DateTime.now().weekday % 7],
                    decoration: const InputDecoration(
                      labelText: 'Repeat on',
                      prefixIcon: Icon(Icons.calendar_view_day),
                    ),
                    items: _weekdays.map((day) {
                      return DropdownMenuItem<String>(
                        value: day,
                        child: Text(day),
                      );
                    }).toList(),
                    onChanged: (newValue) =>
                        setState(() => _selectedWeekday = newValue!),
                  ),
                ],
                if (_repeatOption == 'Custom...') ...[
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 8),
                        child: Text(
                          'Repeat Every',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Number',
                              ),
                              onChanged: (value) => setState(
                                () => _repeatCount = int.tryParse(value),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty)
                                  return 'Required';
                                if (int.tryParse(value) == null ||
                                    int.parse(value) <= 0) {
                                  return 'Enter valid number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 4,
                            child: DropdownButtonFormField<String>(
                              value: _selectedUnit,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                              ),
                              items: _units.map((unit) {
                                return DropdownMenuItem<String>(
                                  value: unit,
                                  child: Text(unit),
                                );
                              }).toList(),
                              onChanged: (newValue) =>
                                  setState(() => _selectedUnit = newValue!),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _priority,
                  decoration: InputDecoration(
                    labelText: 'Priority',
                    prefixIcon: const Icon(Icons.priority_high),
                    errorText: _showPriorityError && _priority == null
                        ? 'Please select a priority'
                        : null,
                  ),
                  items: _priorities.map((priority) {
                    return DropdownMenuItem<String>(
                      value: priority,
                      child: Text(priority),
                    );
                  }).toList(),
                  onChanged: (newValue) => setState(() {
                    _priority = newValue!;
                    _showPriorityError = false;
                  }),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    prefixIcon: const Icon(Icons.category),
                    errorText: _showCategoryError && _category == null
                        ? 'Please select a category'
                        : null,
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (newValue) => setState(() {
                    _category = newValue!;
                    _showCategoryError = false;
                  }),
                ),
                const SizedBox(height: 32),
                Center(
                  child: SizedBox(
                    width: 200, // <-- Set your desired width
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitTask,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Add Task'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
