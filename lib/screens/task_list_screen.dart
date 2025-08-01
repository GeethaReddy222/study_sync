import 'package:flutter/material.dart';
import 'package:study_sync/models/task_model.dart';
import 'package:study_sync/services/task_service.dart';
import 'package:study_sync/screens/add_task_screen.dart';
import 'package:intl/intl.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  late Future<List<Task>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _refreshTasks();
  }

  void _refreshTasks() {
    debugPrint('🔄 REFRESHING TASKS');
    setState(() {
      _tasksFuture = TaskService().getPendingTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshTasks,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddTaskScreen()),
              );
              if (result == true) {
                _refreshTasks();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshTasks(),
        child: FutureBuilder<List<Task>>(
          future: _tasksFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (snapshot.hasError) {
              debugPrint('❌ ERROR FETCHING TASKS: ${snapshot.error}');
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            
            final tasks = snapshot.data ?? [];
            
            if (tasks.isEmpty) {
              debugPrint('ℹ️ NO TASKS FOUND');
              return const Center(
                child: Text('No pending tasks for today'),
              );
            }
            
            debugPrint('📋 DISPLAYING ${tasks.length} TASKS');
            return ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return TaskItem(
                  task: task,
                  onComplete: () async {
                    debugPrint('✅ COMPLETING TASK: ${task.title}');
                    await TaskService().completeTask(task);
                    _refreshTasks();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class TaskItem extends StatelessWidget {
  final Task task;
  final VoidCallback onComplete;

  const TaskItem({
    super.key,
    required this.task,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(task.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty) Text(task.description),
            const SizedBox(height: 4),
            Text(
              'Due: ${DateFormat('MMM dd, yyyy - hh:mm a').format(task.dueDate)}',
              style: const TextStyle(color: Colors.grey),
            ),
            if (task.isRecurring)
              Text(
                'Repeats: ${task.recurrence}',
                style: const TextStyle(color: Colors.blue),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.check),
          onPressed: onComplete,
        ),
      ),
    );
  }
}