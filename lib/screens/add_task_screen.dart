import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:study_sync/models/task_model.dart';
import 'package:study_sync/services/notifications/notification_service.dart';
import 'package:study_sync/services/task_service.dart';

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
  bool _showDateError = false;
  bool _showTimeError = false;
  Duration _taskDuration = const Duration(minutes: 30);
  bool _showDurationError = false;
  final List<int> _durationOptions = [15, 30, 45, 60, 90, 120, 180, 240];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final User? user = FirebaseAuth.instance.currentUser!;
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
      _showTitleError = _titleController.text.isEmpty;
      _showPriorityError = _priority == null;
      _showCategoryError = _category == null;
      _showDateError = _dueDate == null;
      _showTimeError = _dueTime == null;
      _showDurationError = _taskDuration.inMinutes <= 0;
    });

    if (!_formKey.currentState!.validate() ||
        _titleController.text.isEmpty ||
        _priority == null ||
        _category == null ||
        _dueDate == null ||
        _dueTime == null ||
        _taskDuration.inMinutes <= 0) {
      debugPrint('FORM VALIDATION FAILED');
      return;
    }

    if (!_validateTimeForToday()) {
      debugPrint('INVALID TIME SELECTED FOR TODAY');
      _showTimeValidationError();
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if ((_repeatOption == 'Weekly' || _repeatOption == 'Bi-Weekly') &&
          _selectedWeekday != null) {
        final today = DateTime.now();
        if (!DateUtils.isSameDay(_dueDate!, today)) {
          _dueDate = _calculateNextWeeklyDate();
        }
      }

      final dueDateTime = DateTime(
        _dueDate!.year,
        _dueDate!.month,
        _dueDate!.day,
        _dueTime!.hour,
        _dueTime!.minute,
      );

      if (await _hasTimeConflict(dueDateTime, _taskDuration)) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Time Conflict'),
              content: const Text(
                'You already have a task scheduled during this time period.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      if ((_repeatOption == 'Weekly' || _repeatOption == 'Bi-Weekly') &&
          _selectedWeekday != null) {
        final bool shouldContinue = await _showRepeatConfirmationDialog();
        if (!shouldContinue) {
          setState(() => _isSubmitting = false);
          return;
        }
      }

      String recurrence;
      bool isRecurring = false;
      switch (_repeatOption) {
        case 'Daily':
          recurrence = 'daily';
          isRecurring = true;
          break;
        case 'Weekly':
          recurrence = 'weekly';
          isRecurring = true;
          break;
        case 'Bi-Weekly':
          recurrence = 'biweekly';
          isRecurring = true;
          break;
        case 'Monthly':
          recurrence = 'monthly';
          isRecurring = true;
          break;
        default:
          recurrence = 'none';
      }

      final newTask = Task(
        id: FirebaseFirestore.instance.collection('tasks').doc().id,
        title: _titleController.text,
        description: _descriptionController.text,
        dueDate: dueDateTime,
        priority: _priority!,
        category: _category!,
        repeatOption: _repeatOption == 'Custom...' ? 'custom' : null,
        repeatDay: _selectedWeekday,
        repeatCount: _repeatCount,
        repeatUnit: _selectedUnit,
        recurrence: recurrence,
        originalDueDate: dueDateTime,
        isCompleted: false,
        createdAt: DateTime.now(),
        isRecurring: isRecurring,
        duration: _taskDuration,
      );

      await TaskService().addTask(newTask);

      // Schedule notification 30 minutes before the task is due
      final notificationTime = dueDateTime.subtract(const Duration(minutes: 30));
      await NotificationService().scheduleTaskNotification(
        taskId: newTask.id,
        title: 'Task Reminder: ${newTask.title}',
        body:
            'Your task "${newTask.title}" is due at ${DateFormat.jm().format(dueDateTime)}',
        scheduledTime: notificationTime,
      );

      if (mounted) {
        debugPrint('TASK ADDED SUCCESSFULLY');
        _showSuccessDialog();
      }
    } catch (e) {
      debugPrint('ERROR ADDING TASK: $e');
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<bool> _showRepeatConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Recurring Task'),
            content: Text(
              'Task will repeat $_repeatOption on $_selectedWeekday',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _hasTimeConflict(DateTime newTime, Duration duration) async {
    if (user == null) return false;

    final startRange = newTime;
    final endRange = newTime.add(duration);

    try {
      // Check for tasks that overlap with the new task's time range
      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('tasks')
          .where('isCompleted', isEqualTo: false)
          .get();

      for (final doc in query.docs) {
        final task = Task.fromFireStore(doc);
        final taskStart = task.dueDate;
        final taskEnd = task.dueDate.add(task.duration);

        // Check if the new task overlaps with any existing task
        if ((startRange.isBefore(taskEnd) && endRange.isAfter(taskStart)) ||
            (taskStart.isBefore(endRange) && taskEnd.isAfter(startRange))) {
          debugPrint('Found conflicting task:');
          debugPrint(' - ${task.title} @ ${task.dueDate.toLocal()}');
          debugPrint(' - Duration: ${task.duration.inMinutes} minutes');
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error checking time conflict: $e');
      return false;
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
    final currentWeekday = today.weekday % 7; // 0=Sunday, 6=Saturday
    final targetIndex = _weekdays.indexOf(_selectedWeekday!);

    // Check if today is the selected weekday
    if (currentWeekday == targetIndex) {
      // If time is still in the future, use today
      if (_dueTime != null) {
        final nowTime = TimeOfDay.now();
        if (_dueTime!.hour > nowTime.hour ||
            (_dueTime!.hour == nowTime.hour &&
                _dueTime!.minute > nowTime.minute)) {
          return today;
        }
      }
    }

    // Otherwise calculate next occurrence
    int daysUntilNext = (targetIndex - currentWeekday + 7) % 7;
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
          ));
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
              Navigator.pop(context, true);
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
        content: Text('Failed to add task: ${error.toString()}'),
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
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
        _showDateError = false;
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
    if (picked != null && picked != _dueTime) {
      setState(() {
        _dueTime = picked;
        _showTimeError = false;
      });
    }
  }

  void _showDurationPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Select Task Duration',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _durationOptions.length,
                  itemBuilder: (context, index) {
                    final minutes = _durationOptions[index];
                    return ListTile(
                      title: Text('$minutes minutes'),
                      onTap: () {
                        setState(() {
                          _taskDuration = Duration(minutes: minutes);
                          _showDurationError = false;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showCustomDurationDialog(context);
                  },
                  child: const Text('Custom Duration'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCustomDurationDialog(BuildContext context) {
    final customDurationController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Custom Duration'),
          content: TextField(
            controller: customDurationController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Duration in minutes',
              hintText: 'Enter duration (15-240)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final minutes = int.tryParse(customDurationController.text) ?? 0;
                if (minutes >= 15 && minutes <= 240) {
                  setState(() {
                    _taskDuration = Duration(minutes: minutes);
                    _showDurationError = false;
                  });
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a value between 15 and 240'),
                    ),
                  );
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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
                    errorText: _showTitleError ? 'Please enter a task title' : null,
                  ),
                  onChanged: (value) => setState(() {
                    if (value.isNotEmpty) _showTitleError = false;
                  }),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return null; // Handled by _showTitleError
                    }
                    if (value.length > 100) {
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
                            errorText: _showDateError ? 'Please select a date' : null,
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
                            errorText: _showTimeError ? 'Please select a time' : null,
                          ),
                          child: Text(
                            _dueTime == null ? 'Select Time' : _dueTime!.format(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _showDurationPicker(context),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Task Duration',
                      prefixIcon: const Icon(Icons.timer),
                      errorText: _showDurationError ? 'Please select a duration' : null,
                    ),
                    child: Text(
                      '${_taskDuration.inMinutes} minutes',
                    ),
                  ),
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
                      if ((_repeatOption == 'Weekly' || _repeatOption == 'Bi-Weekly') &&
                          _dueDate != null) {
                        _selectedWeekday = _weekdays[_dueDate!.weekday % 7];
                      }
                    });
                  },
                ),
                if (_repeatOption == 'Weekly' || _repeatOption == 'Bi-Weekly') ...[
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _selectedWeekday ?? _weekdays[DateTime.now().weekday % 7],
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
                                  () => _repeatCount = int.tryParse(value)),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
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
                    errorText: _showPriorityError ? 'Please select a priority' : null,
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
                    errorText: _showCategoryError ? 'Please select a category' : null,
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
                    width: 200,
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