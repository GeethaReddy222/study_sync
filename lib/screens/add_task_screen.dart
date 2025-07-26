import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

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
    "Assignments",
    "Contests",
    "Projects",
    "Exams",
    "Revision",
    "Other",
  ];
  final List<String> _priorities = ["High", "Medium", "Low"];

  InputDecoration _inputDecoration(String labelText, {IconData? icon, String? errorText}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 15),
      errorText: errorText,
      errorStyle: const TextStyle(fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.indigo, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.red[300]!),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.red[300]!),
      ),
      filled: true,
      fillColor: Colors.grey[50],
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey[600]) : null,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitTask() async {
    // Set all error states to true initially
    setState(() {
      _showTitleError = true;
      _showPriorityError = true;
      _showCategoryError = true;
    });

    // Validate form fields
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate required fields
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

    if ((_repeatOption == 'Weekly' || _repeatOption == 'Bi-Weekly') &&
        _selectedWeekday != null) {
      DateTime nextDate = _calculateNextWeeklyDate();
      setState(() {
        _dueDate = DateTime(nextDate.year, nextDate.month, nextDate.day);
      });
      await _showRepeatConfirmationDialog();
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await Future.delayed(const Duration(seconds: 1));
      _showSuccessDialog();
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  bool _validateTimeForToday() {
    if (_dueDate != null && DateUtils.isSameDay(_dueDate!, DateTime.now()) && _dueTime != null) {
      final nowTime = TimeOfDay.now();
      return !(_dueTime!.hour < nowTime.hour ||
          (_dueTime!.hour == nowTime.hour && _dueTime!.minute <= nowTime.minute));
    }
    return true;
  }

  DateTime _calculateNextWeeklyDate() {
    final today = DateTime.now();
    int currentIndex = today.weekday % 7;
    int targetIndex = _weekdays.indexOf(_selectedWeekday!);
    int daysUntilNext = (targetIndex - currentIndex + 7) % 7;
    daysUntilNext = daysUntilNext == 0 ? 7 : daysUntilNext;
    return today.add(Duration(days: daysUntilNext + (_repeatOption == 'Bi-Weekly' ? 7 : 0)));
  }

  void _showTimeValidationError() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Invalid Time'),
          content: const Text('Please select a future time for today'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRepeatConfirmationDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Repeat Task'),
          content: Text('Task will repeat $_repeatOption on $_selectedWeekday'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success'),
          content: const Text('Task has been added successfully!'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to add task: $error'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.all(0),
          content: SizedBox(
            height: 300,
            width: 300,
            child: CalendarDatePicker(
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime(2100),
              onDateChanged: (DateTime date) => Navigator.pop(context, date),
            ),
          ),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showDialog<TimeOfDay>(
      context: context,
      builder: (BuildContext context) {
        TimeOfDay initialTime = TimeOfDay.now();
        return AlertDialog(
          contentPadding: const EdgeInsets.all(0),
          content: SizedBox(
            height: 200,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              initialDateTime: DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
                initialTime.hour,
                initialTime.minute,
              ),
              onDateTimeChanged: (DateTime date) {
                initialTime = TimeOfDay.fromDateTime(date);
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context, initialTime),
            ),
          ],
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dueTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.indigo.shade400,
        title: const Text(
          'Add New Task',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, size: 24),
            onPressed: _isSubmitting ? null : _submitTask,
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Task Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  decoration: _inputDecoration(
                    'Task Title',
                    icon: Icons.title,
                    errorText: _showTitleError && (_titleController.text.isEmpty) 
                      ? 'Please enter a task title' 
                      : null,
                  ).copyWith(hintText: 'Enter task title'),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      setState(() {
                        _showTitleError = false;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return null; // Handled by errorText
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
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  decoration: _inputDecoration(
                    'Description',
                    icon: Icons.description,
                  ).copyWith(
                    hintText: 'Enter task description',
                    alignLabelWithHint: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: _inputDecoration(
                            'Due Date',
                            icon: Icons.calendar_today,
                            errorText: _dueDate == null && _showTitleError
                              ? 'Please select a date'
                              : null,
                          ),
                          child: Text(
                            _dueDate == null
                                ? 'Select Date'
                                : DateFormat('MMM dd, yyyy').format(_dueDate!),
                            style: TextStyle(
                              fontSize: 14,
                              color: _dueDate == null ? Colors.grey[400] : Colors.black87,
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
                          decoration: _inputDecoration(
                            'Due Time',
                            icon: Icons.access_time,
                            errorText: _dueTime == null && _showTitleError
                              ? 'Please select a time'
                              : null,
                          ),
                          child: Text(
                            _dueTime == null
                                ? 'Select Time'
                                : _dueTime!.format(context),
                            style: TextStyle(
                              fontSize: 14,
                              color: _dueTime == null ? Colors.grey[400] : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _repeatOption,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  decoration: _inputDecoration('Repeat', icon: Icons.repeat),
                  items: _repeatOptions.map((String option) {
                    return DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _repeatOption = newValue!;
                      if (_repeatOption != 'Custom...') {
                        _repeatCount = null;
                      }
                      if ((_repeatOption == 'Weekly' || _repeatOption == 'Bi-Weekly') &&
                          _dueDate != null) {
                        _selectedWeekday = _weekdays[_dueDate!.weekday % 7];
                      }
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a repeat option';
                    }
                    return null;
                  },
                ),
                if (_repeatOption == 'Weekly' || _repeatOption == 'Bi-Weekly') ...[
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _selectedWeekday ?? _weekdays[DateTime.now().weekday % 7],
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    decoration: _inputDecoration(
                      'Repeat on',
                      icon: Icons.calendar_view_day,
                    ),
                    items: _weekdays.map((String day) {
                      return DropdownMenuItem<String>(
                        value: day,
                        child: Text(day),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedWeekday = newValue!;
                      });
                    },
                    validator: (value) {
                      if ((_repeatOption == 'Weekly' || _repeatOption == 'Bi-Weekly') &&
                          (value == null || value.isEmpty)) {
                        return 'Please select a weekday';
                      }
                      return null;
                    },
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
                          style: TextStyle(color: Colors.grey[600], fontSize: 15),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                              decoration: _inputDecoration(
                                'Number',
                              ).copyWith(labelText: null),
                              onChanged: (value) {
                                setState(() {
                                  _repeatCount = int.tryParse(value);
                                });
                              },
                              validator: (value) {
                                if (_repeatOption == 'Custom...' &&
                                    (value == null || value.isEmpty)) {
                                  return 'Required';
                                }
                                final parsedValue = int.tryParse(value ?? '');
                                if (parsedValue == null || parsedValue <= 0) {
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
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                              decoration: _inputDecoration(
                                'Unit',
                              ).copyWith(labelText: null),
                              items: _units.map((String unit) {
                                return DropdownMenuItem<String>(
                                  value: unit,
                                  child: Text(unit),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedUnit = newValue!;
                                });
                              },
                              validator: (value) {
                                if (_repeatOption == 'Custom...' &&
                                    (value == null || value.isEmpty)) {
                                  return 'Required';
                                }
                                return null;
                              },
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
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  decoration: _inputDecoration(
                    'Priority',
                    icon: Icons.priority_high,
                    errorText: _showPriorityError && _priority == null
                      ? 'Please select a priority'
                      : null,
                  ),
                  items: _priorities.map((String priority) {
                    return DropdownMenuItem<String>(
                      value: priority,
                      child: Text(priority),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _priority = newValue!;
                      _showPriorityError = false;
                    });
                  },
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _category,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  decoration: _inputDecoration(
                    'Category',
                    icon: Icons.category,
                    errorText: _showCategoryError && _category == null
                      ? 'Please select a category'
                      : null,
                  ),
                  items: _categories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _category = newValue!;
                      _showCategoryError = false;
                    });
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Add Task',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
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