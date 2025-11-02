import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../database/database_helper.dart';
import '../widgets/task_card.dart';
import 'history_page.dart';
import 'login_page.dart';
import '../main.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  List<Task> _tasks = [];
  List<Task> _filteredTasks = [];
  bool _isLoading = true;
  String _username = '';
  String _selectedFilter = 'All'; // All, High, Medium, Low
  String _selectedSort = 'Date'; // Date, Priority, Alphabetical
  bool _showCompletedTasks = true;
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadTasks();
    
    // FAB animation
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? 'User';
    });
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final tasks = await DatabaseHelper.instance.getActiveTasks();
    setState(() {
      _tasks = tasks;
      _applyFiltersAndSort();
      _isLoading = false;
    });
  }

  void _applyFiltersAndSort() {
    var filtered = _tasks.where((task) {
      // Filter by completion status
      if (!_showCompletedTasks && task.isDone) return false;
      
      // Filter by priority
      if (_selectedFilter != 'All' && task.priority != _selectedFilter) {
        return false;
      }
      
      // Filter by search query
      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        return task.title.toLowerCase().contains(query) ||
               task.description.toLowerCase().contains(query);
      }
      
      return true;
    }).toList();

    // Sort tasks
    switch (_selectedSort) {
      case 'Priority':
        filtered.sort((a, b) {
          const priorityOrder = {'High': 0, 'Medium': 1, 'Low': 2};
          return priorityOrder[a.priority]!.compareTo(priorityOrder[b.priority]!);
        });
        break;
      case 'Alphabetical':
        filtered.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'Date':
      default:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    setState(() {
      _filteredTasks = filtered;
    });
  }

  Future<void> _showAddTaskDialog({Task? taskToEdit}) async {
    final titleController = TextEditingController(text: taskToEdit?.title ?? '');
    final descController = TextEditingController(text: taskToEdit?.description ?? '');
    String priority = taskToEdit?.priority ?? 'Medium';
    DateTime? reminderTime = taskToEdit?.reminderTime;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                taskToEdit == null ? Icons.add_task : Icons.edit,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(taskToEdit == null ? 'Add New Task' : 'Edit Task'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Title *',
                    hintText: 'Enter task title',
                    prefixIcon: const Icon(Icons.title),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter task details',
                    prefixIcon: const Icon(Icons.description),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: InputDecoration(
                    labelText: 'Priority',
                    prefixIcon: const Icon(Icons.flag),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: ['Low', 'Medium', 'High'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Row(
                        children: [
                          Icon(
                            Icons.flag,
                            color: value == 'High'
                                ? Colors.red
                                : value == 'Medium'
                                    ? Colors.orange
                                    : Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(value),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      priority = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: reminderTime ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      if (context.mounted) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            reminderTime ?? DateTime.now(),
                          ),
                        );
                        if (time != null) {
                          setDialogState(() {
                            reminderTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.alarm,
                          color: reminderTime != null ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            reminderTime == null
                                ? 'Set reminder (optional)'
                                : DateFormat('MMM dd, yyyy - HH:mm').format(reminderTime!),
                            style: TextStyle(
                              color: reminderTime != null ? Colors.black87 : Colors.grey,
                            ),
                          ),
                        ),
                        if (reminderTime != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              setDialogState(() {
                                reminderTime = null;
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Title is required'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              icon: Icon(taskToEdit == null ? Icons.add : Icons.save),
              label: Text(taskToEdit == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      if (taskToEdit == null) {
        final newTask = Task(
          title: titleController.text.trim(),
          description: descController.text.trim(),
          priority: priority,
          reminderTime: reminderTime,
        );
        final id = await DatabaseHelper.instance.insertTask(newTask);
        
        if (reminderTime != null) {
          await _scheduleNotification(id, newTask);
        }
        
        if (mounted) {
          _showSuccessDialog();
        }
      } else {
        final updatedTask = taskToEdit.copyWith(
          title: titleController.text.trim(),
          description: descController.text.trim(),
          priority: priority,
          reminderTime: reminderTime,
        );
        await DatabaseHelper.instance.updateTask(updatedTask);
        
        if (reminderTime != null) {
          await _scheduleNotification(updatedTask.id!, updatedTask);
        } else {
          await flutterLocalNotificationsPlugin.cancel(updatedTask.id!);
        }
      }
      _loadTasks();
    }
  }

  Future<void> _showSuccessDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                '/images/task_Created_Succesfully.gif',
                width: 200,
                height: 200,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 100,
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Task Created Successfully! 🎉',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your task has been added to the list',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it!'),
              ),
            ],
          ),
        ),
      ),
    );

    // Auto-close after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  Future<void> _scheduleNotification(int id, Task task) async {
    if (task.reminderTime == null) return;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'Task Reminder: ${task.title}',
      task.description.isNotEmpty ? task.description : 'You have a task to complete!',
      tz.TZDateTime.from(task.reminderTime!, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Task Reminders',
          channelDescription: 'Notifications for task reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _toggleTaskComplete(Task task) async {
    final updatedTask = task.copyWith(
      isDone: !task.isDone,
      completedAt: !task.isDone ? DateTime.now() : null,
    );
    await DatabaseHelper.instance.updateTask(updatedTask);
    
    if (updatedTask.isDone) {
      await flutterLocalNotificationsPlugin.cancel(task.id!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task completed! 🎉'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () async {
                final revertTask = updatedTask.copyWith(isDone: false, completedAt: null);
                await DatabaseHelper.instance.updateTask(revertTask);
                _loadTasks();
              },
            ),
          ),
        );
      }
    }
    
    _loadTasks();
  }

  Future<void> _deleteTask(Task task) async {
    await DatabaseHelper.instance.deleteTask(task.id!);
    await flutterLocalNotificationsPlugin.cancel(task.id!);
    _loadTasks();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task deleted'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalTasks = _tasks.length;
    final completedTasks = _tasks.where((t) => t.isDone).length;
    final highPriorityTasks = _tasks.where((t) => t.priority == 'High' && !t.isDone).length;
    final upcomingReminders = _tasks.where((t) => t.reminderTime != null && !t.isDone).length;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Tasks', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              'Hello, $_username! 👋',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: TaskSearchDelegate(_tasks, _toggleTaskComplete, _deleteTask),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryPage()),
              ).then((_) => _loadTasks());
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              } else if (value == 'clear_completed') {
                _clearCompletedTasks();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_completed',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Clear Completed'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Statistics Cards
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total',
                          '$totalTasks',
                          Icons.task,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Completed',
                          '$completedTasks',
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'High Priority',
                          '$highPriorityTasks',
                          Icons.priority_high,
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Reminders',
                          '$upcomingReminders',
                          Icons.alarm,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => _applyFiltersAndSort(),
                    decoration: InputDecoration(
                      hintText: 'Search tasks...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _applyFiltersAndSort();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _selectedFilter == 'All',
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = 'All';
                            _applyFiltersAndSort();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('🔴 High'),
                        selected: _selectedFilter == 'High',
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = selected ? 'High' : 'All';
                            _applyFiltersAndSort();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('🟠 Medium'),
                        selected: _selectedFilter == 'Medium',
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = selected ? 'Medium' : 'All';
                            _applyFiltersAndSort();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('🟢 Low'),
                        selected: _selectedFilter == 'Low',
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = selected ? 'Low' : 'All';
                            _applyFiltersAndSort();
                          });
                        },
                      ),
                      const SizedBox(width: 16),
                      const VerticalDivider(),
                      const SizedBox(width: 16),
                      ChoiceChip(
                        label: const Text('📅 Date'),
                        selected: _selectedSort == 'Date',
                        onSelected: (selected) {
                          setState(() {
                            _selectedSort = 'Date';
                            _applyFiltersAndSort();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('🎯 Priority'),
                        selected: _selectedSort == 'Priority',
                        onSelected: (selected) {
                          setState(() {
                            _selectedSort = 'Priority';
                            _applyFiltersAndSort();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('🔤 A-Z'),
                        selected: _selectedSort == 'Alphabetical',
                        onSelected: (selected) {
                          setState(() {
                            _selectedSort = 'Alphabetical';
                            _applyFiltersAndSort();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Task List
                Expanded(
                  child: _filteredTasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_searchController.text.isEmpty && _selectedFilter == 'All')
                                Image.asset(
                                  './animations/NoTasks.gif',
                                  width: 250,
                                  height: 250,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.task_alt,
                                      size: 100,
                                      color: Colors.grey[300],
                                    );
                                  },
                                )
                              else
                                Icon(
                                  _searchController.text.isNotEmpty
                                      ? Icons.search_off
                                      : Icons.filter_list_off,
                                  size: 100,
                                  color: Colors.grey[300],
                                ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'No tasks found'
                                    : _selectedFilter != 'All'
                                        ? 'No ${_selectedFilter.toLowerCase()} priority tasks'
                                        : 'No tasks yet!',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'Try a different search term'
                                    : _selectedFilter != 'All'
                                        ? 'Create a task or change the filter'
                                        : 'Tap the + button to add your first task',
                                style: TextStyle(color: Colors.grey[500]),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadTasks,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredTasks.length,
                            itemBuilder: (context, index) {
                              final task = _filteredTasks[index];
                              return TaskCard(
                                task: task,
                                onToggleComplete: () => _toggleTaskComplete(task),
                                onEdit: () => _showAddTaskDialog(taskToEdit: task),
                                onDelete: () => _deleteTask(task),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: () => _showAddTaskDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Add Task'),
        ),
      ),
    );
  }

  Future<void> _clearCompletedTasks() async {
    final completedCount = _tasks.where((t) => t.isDone).length;
    if (completedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No completed tasks to clear'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Completed Tasks'),
        content: Text('Remove $completedCount completed task${completedCount > 1 ? 's' : ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (var task in _tasks.where((t) => t.isDone)) {
        await DatabaseHelper.instance.deleteTask(task.id!);
      }
      _loadTasks();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$completedCount task${completedCount > 1 ? 's' : ''} cleared'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// Search Delegate
class TaskSearchDelegate extends SearchDelegate<Task?> {
  final List<Task> tasks;
  final Function(Task) onToggleComplete;
  final Function(Task) onDelete;

  TaskSearchDelegate(this.tasks, this.onToggleComplete, this.onDelete);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final results = tasks.where((task) {
      final queryLower = query.toLowerCase();
      return task.title.toLowerCase().contains(queryLower) ||
             task.description.toLowerCase().contains(queryLower);
    }).toList();

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No tasks found',
              style: TextStyle(color: Colors.grey[600], fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final task = results[index];
        return TaskCard(
          task: task,
          onToggleComplete: () {
            onToggleComplete(task);
            close(context, task);
          },
          onEdit: () => close(context, task),
          onDelete: () {
            onDelete(task);
            close(context, task);
          },
        );
      },
    );
  }
}