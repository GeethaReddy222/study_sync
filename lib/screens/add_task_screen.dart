import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:study_sync/models/task_model.dart';
import 'package:study_sync/services/notification/notification_service.dart';
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
  void initState() {
    super.initState();
    NotificationService().initialize();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitTask() async {
    // Reset all error states
    setState(() {
      _showTitleError = _titleController.text.isEmpty;
      _showPriorityError = _priority == null;
      _showCategoryError = _category == null;
      _showDateError = _dueDate == null;
      _showTimeError = _dueTime == null;
      _showDurationError = _taskDuration.inMinutes <= 0;
    });

    if (!_validateTimeForToday()) {
      _showTimeValidationError();
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      DateTime adjustedDueDate = _dueDate!;
      if ((_repeatOption == 'Weekly' || _repeatOption == 'Bi-Weekly') &&
          _selectedWeekday != null &&
          !DateUtils.isSameDay(_dueDate!, DateTime.now())) {
        adjustedDueDate = _calculateNextWeeklyDate();
      }

      final dueDateTime = DateTime(
        adjustedDueDate.year,
        adjustedDueDate.month,
        adjustedDueDate.day,
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
                'You already have a task scheduled during this time.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }

      String recurrence = 'none';
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
      }

      final newTask = Task(
        id: FirebaseFirestore.instance.collection('tasks').doc().id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: dueDateTime,
        priority: _priority!,
        category: _category!,
        repeatOption: _repeatOption == 'Custom...' ? 'custom' : _repeatOption,
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

      final notificationTime = dueDateTime.subtract(
        const Duration(minutes: 10),
      );
      if (notificationTime.isAfter(DateTime.now())) {
        await NotificationService().scheduleTaskNotification(
          taskId: newTask.id,
          title: 'Task Reminder: ${newTask.title}',
          body:
              'Your task "${newTask.title}" is due at ${DateFormat.jm().format(dueDateTime)}',
          scheduledTime: notificationTime,
        );
      }

      if (mounted) {
        debugPrint('✅ TASK ADDED SUCCESSFULLY');
        _showSuccessDialog();
      }
    } catch (e) {
      debugPrint('❌ ERROR ADDING TASK: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              Navigator.pop(context, true);
            },
            child: const Text('OK'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Select Task Duration',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showCustomDurationDialog(context);
                  },
                  child: const Text('Custom Duration'),
                ),
              ),
              const SizedBox(height: 16),
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
                final minutes =
                    int.tryParse(customDurationController.text) ?? 0;
                if (minutes >= 15 && minutes <= 240) {
                  setState(() {
                    _taskDuration = Duration(minutes: minutes);
                    _showDurationError = false;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Duration set to $minutes minutes'),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  });
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a value between 15 and 240'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('OK'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.05),
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.15),
            ],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Task Details',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Task Title *',
                      prefixIcon: Icon(
                        Icons.title_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      errorText: _showTitleError
                          ? 'Please enter a task title'
                          : null,
                      errorStyle: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    onChanged: (value) => setState(() {
                      if (value.isNotEmpty) _showTitleError = false;
                    }),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(
                        Icons.description_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Schedule',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Due Date *',
                              prefixIcon: Icon(
                                Icons.calendar_today_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              errorText: _showDateError
                                  ? 'Please select a date'
                                  : null,
                              errorStyle: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            child: Text(
                              _dueDate == null
                                  ? 'Select Date'
                                  : DateFormat(
                                      'MMM dd, yyyy',
                                    ).format(_dueDate!),
                              style: TextStyle(
                                color: _dueDate == null
                                    ? Theme.of(context).hintColor
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
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
                              labelText: 'Due Time *',
                              prefixIcon: Icon(
                                Icons.access_time_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              errorText: _showTimeError
                                  ? 'Please select a time'
                                  : null,
                              errorStyle: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            child: Text(
                              _dueTime == null
                                  ? 'Select Time'
                                  : _dueTime!.format(context),
                              style: TextStyle(
                                color: _dueTime == null
                                    ? Theme.of(context).hintColor
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
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
                        labelText: 'Task Duration *',
                        prefixIcon: Icon(
                          Icons.timer_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        errorText: _showDurationError
                            ? 'Please select a duration'
                            : null,
                        errorStyle: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      child: Text(
                        '${_taskDuration.inMinutes} minutes',
                        style: TextStyle(
                          color: _taskDuration.inMinutes <= 0
                              ? Theme.of(context).hintColor
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _priority,
                    decoration: InputDecoration(
                      labelText: 'Priority *',
                      prefixIcon: Icon(
                        Icons.priority_high_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorText: _showPriorityError
                          ? 'Please select a priority'
                          : null,
                      errorStyle: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
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
                      labelText: 'Category *',
                      prefixIcon: Icon(
                        Icons.category_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorText: _showCategoryError
                          ? 'Please select a category'
                          : null,
                      errorStyle: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
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
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _repeatOption,
                    decoration: InputDecoration(
                      labelText: 'Repeat',
                      prefixIcon: Icon(
                        Icons.repeat_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                      decoration: InputDecoration(
                        labelText: 'Repeat on',
                        prefixIcon: Icon(
                          Icons.calendar_view_day_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                                decoration: InputDecoration(
                                  labelText: 'Number',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onChanged: (value) => setState(
                                  () => _repeatCount = int.tryParse(value),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: DropdownButtonFormField<String>(
                                value: _selectedUnit,
                                decoration: InputDecoration(
                                  labelText: 'Unit',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
                  const SizedBox(height: 32),
                  Center(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitTask,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Add Task',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
