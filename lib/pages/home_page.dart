import 'package:flutter/material.dart';
// import 'package:intl/intl.dart'; // Importation inutile retirée
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task.dart';
import '../services/firebase_task_service.dart'; 
import '../widgets/task_card.dart';
import 'history_page.dart';
import 'login_page.dart';
import '../main.dart'; 
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

// Définition du type de callback
typedef ThemeCallback = void Function(ThemeMode themeMode);

class HomePage extends StatefulWidget {
  final ThemeCallback onThemeChanged;
  final ThemeMode currentThemeMode;

  const HomePage({
    super.key, 
    required this.onThemeChanged, 
    required this.currentThemeMode
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  List<Task> _tasks = [];
  List<Task> _filteredTasks = [];
  bool _isLoading = true;
  String _username = ''; 
  String _selectedFilter = 'All'; 
  String _selectedSort = 'Date'; 
  bool _showCompletedTasks = true;
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserInfo(); 
    _loadTasks();
    
    // FAB animation
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: Curves.easeOut,
      ),
    );
    _fabAnimationController.forward();
  }
  
  void _loadUserInfo() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _username = user.email ?? 'User'; 
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  // ============== DATA LOAD & FILTERING ==============
  
  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
        final activeTasks = await FirebaseTaskService.instance.getActiveTasks();
        final completedTasks = await FirebaseTaskService.instance.getCompletedTasks();
        
        setState(() {
            _tasks = [...activeTasks, ...completedTasks];
            _isLoading = false;
        });
        _applyFiltersAndSorting();
    } catch (e) {
        if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error loading tasks: $e')),
            );
            setState(() => _isLoading = false);
        }
    }
  }

  void _applyFiltersAndSorting() {
    List<Task> results = _tasks.where((task) {
      if (task.isDone && !_showCompletedTasks) return false;
      if (_selectedFilter != 'All' && task.priority != _selectedFilter) return false;
      return true;
    }).toList();

    results.sort((a, b) {
      if (_selectedSort == 'Priority') {
        int aP = _getPriorityValue(a.priority);
        int bP = _getPriorityValue(b.priority);
        return bP.compareTo(aP); // High to Low
      } else if (_selectedSort == 'Alphabetical') {
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
      return b.createdAt.compareTo(a.createdAt); // Default: Date (newest first)
    });

    setState(() {
      _filteredTasks = results;
    });
  }

  int _getPriorityValue(String priority) {
    switch (priority) {
      case 'High':
        return 3;
      case 'Medium':
        return 2;
      case 'Low':
        return 1;
      default:
        return 0;
    }
  }

  // ============== CRUD Operations ==============
  
  Future<void> _addTask(Task task) async {
    try {
        final newId = await FirebaseTaskService.instance.insertTask(task);
        await _loadTasks();
        
        if (task.reminderTime != null && task.reminderTime!.isAfter(DateTime.now())) {
            _scheduleNotification(task.copyWith(id: newId)); 
        }
    } catch (e) {
        if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error adding task: $e')),
            );
        }
    }
  }

  Future<void> _updateTask(Task task) async {
    try {
        await FirebaseTaskService.instance.updateTask(task);
        await _loadTasks(); 

        flutterLocalNotificationsPlugin.cancel(task.id.hashCode); 
        if (task.reminderTime != null && task.reminderTime!.isAfter(DateTime.now())) {
            _scheduleNotification(task);
        }
    } catch (e) {
        if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error updating task: $e')),
            );
        }
    }
  }

  Future<void> _toggleTaskComplete(Task task) async {
    final isDone = !task.isDone;
    final updatedTask = task.copyWith(
      isDone: isDone,
      completedAt: isDone ? DateTime.now() : null,
    );

    try {
        await FirebaseTaskService.instance.updateTask(updatedTask);
        if (isDone) {
             flutterLocalNotificationsPlugin.cancel(task.id.hashCode);
        }
        await _loadTasks();
    } catch (e) {
        if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error updating task status: $e')),
            );
        }
    }
  }

  Future<void> _deleteTask(Task task) async {
    if (task.id == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseTaskService.instance.deleteTask(task.id!);
        flutterLocalNotificationsPlugin.cancel(task.id.hashCode); 
        await _loadTasks();
      } catch (e) {
        if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error deleting task: $e')),
            );
        }
      }
    }
  }
  
  // ============== Navigation & Theme ==============
  
  void _navigateToHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const HistoryPage(),
      ),
    ).then((_) => _loadTasks()); // Reload when returning from history
  }

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username'); 

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => LoginPage(
            onThemeChanged: widget.onThemeChanged,
            currentThemeMode: widget.currentThemeMode,
          ),
        ),
      );
    }
  }

  // Fonction pour basculer le thème
  void _toggleTheme() async {
    final newThemeMode = widget.currentThemeMode == ThemeMode.light 
        ? ThemeMode.dark 
        : ThemeMode.light;
    
    widget.onThemeChanged(newThemeMode);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', newThemeMode.toString().split('.').last);
  }
  
  // ============== Notifications (CORRIGÉ) ==============
  
  Future<void> _scheduleNotification(Task task) async {
    if (task.reminderTime == null) return;

    final scheduledDate = tz.TZDateTime.from(
      task.reminderTime!,
      tz.local,
    );
    
    if (scheduledDate.isBefore(DateTime.now())) return;

    final notificationId = task.id.hashCode; 

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'task_reminder_channel',
        'Task Reminders',
        channelDescription: 'Notifications for task deadlines and reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    // CORRECTION: Utilisation de la signature correcte pour zonedSchedule (événement unique)
    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      'Task Reminder: ${task.title}',
      task.description.isNotEmpty ? task.description : 'Don\'t forget your task!',
      scheduledDate,
      notificationDetails,
      // Pour une notification unique non récurrente à une heure exacte:
      matchDateTimeComponents: null, 
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: task.id,
    );
  }
  
  // ============== UI & Building ==============

  void _showTaskModal({Task? task}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(task == null ? 'Opening Add Task Modal...' : 'Opening Edit Task Modal...')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.currentThemeMode == ThemeMode.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $_username'), 
        actions: [
          // Bouton de recherche
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: TaskSearchDelegate(
                  tasks: _tasks,
                  onToggleComplete: _toggleTaskComplete,
                  onDelete: _deleteTask,
                  onEdit: _updateTask,
                ),
              );
            },
          ),
          
          // Menu contextuel (Filtres, Tri, Histoire, Déconnexion, Thème)
          PopupMenuButton<String>(
            onSelected: (String result) {
              if (result == 'history') {
                _navigateToHistory();
              } else if (result == 'logout') { 
                _handleLogout();
              } else if (result == 'toggle_theme') { 
                _toggleTheme();
              } else if (result.startsWith('filter_')) {
                setState(() {
                  _selectedFilter = result.substring(7);
                  _applyFiltersAndSorting();
                });
              } else if (result.startsWith('sort_')) {
                setState(() {
                  _selectedSort = result.substring(5);
                  _applyFiltersAndSorting();
                });
              } else if (result == 'toggle_completed') {
                setState(() {
                  _showCompletedTasks = !_showCompletedTasks;
                  _applyFiltersAndSorting();
                });
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              // --- Filters ---
              PopupMenuItem<String>(
                value: 'filter_All',
                child: Text('All Priorities', style: TextStyle(fontWeight: _selectedFilter == 'All' ? FontWeight.bold : FontWeight.normal)),
              ),
              PopupMenuItem<String>(
                value: 'filter_High',
                child: Text('High Priority', style: TextStyle(color: Colors.red, fontWeight: _selectedFilter == 'High' ? FontWeight.bold : FontWeight.normal)),
              ),
              PopupMenuItem<String>(
                value: 'filter_Medium',
                child: Text('Medium Priority', style: TextStyle(color: Colors.orange, fontWeight: _selectedFilter == 'Medium' ? FontWeight.bold : FontWeight.normal)),
              ),
              PopupMenuItem<String>(
                value: 'filter_Low',
                child: Text('Low Priority', style: TextStyle(color: Colors.green, fontWeight: _selectedFilter == 'Low' ? FontWeight.bold : FontWeight.normal)),
              ),
              
              const PopupMenuDivider(),
              
              // --- Sorting ---
              PopupMenuItem<String>(
                value: 'sort_Date',
                child: Text('Sort by Date', style: TextStyle(fontWeight: _selectedSort == 'Date' ? FontWeight.bold : FontWeight.normal)),
              ),
              PopupMenuItem<String>(
                value: 'sort_Priority',
                child: Text('Sort by Priority', style: TextStyle(fontWeight: _selectedSort == 'Priority' ? FontWeight.bold : FontWeight.normal)),
              ),
              PopupMenuItem<String>(
                value: 'sort_Alphabetical',
                child: Text('Sort by Title', style: TextStyle(fontWeight: _selectedSort == 'Alphabetical' ? FontWeight.bold : FontWeight.normal)),
              ),

              const PopupMenuDivider(),
              
              // --- Toggle Completed ---
              PopupMenuItem<String>(
                value: 'toggle_completed',
                child: Row(
                  children: [
                    Icon(_showCompletedTasks ? Icons.visibility_off : Icons.visibility),
                    const SizedBox(width: 8),
                    Text(_showCompletedTasks ? 'Hide Completed' : 'Show Completed'),
                  ],
                ),
              ),
              
              const PopupMenuDivider(),
              
              // --- History & Theme ---
              const PopupMenuItem<String>(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history),
                    SizedBox(width: 8),
                    Text('History'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              
              // Nouvelle option de thème
              PopupMenuItem<String>(
                value: 'toggle_theme',
                child: Row(
                  children: [
                    Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
                    const SizedBox(width: 8),
                    Text(isDarkMode ? 'Light Mode' : 'Dark Mode'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              
              // Option de déconnexion
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredTasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 100,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tasks matching filters',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try adjusting your filters or adding a new task',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredTasks.length,
                    itemBuilder: (context, index) {
                      final task = _filteredTasks[index];
                      return TaskCard(
                        key: ValueKey(task.id),
                        task: task,
                        onToggleComplete: () => _toggleTaskComplete(task),
                        onEdit: () => _showTaskModal(task: task),
                        onDelete: () => _deleteTask(task),
                      );
                    },
                  ),
                ),
      
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton(
          onPressed: () => _showTaskModal(),
          tooltip: 'Add New Task',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

// ============== Search Delegate ==============

class TaskSearchDelegate extends SearchDelegate<Task?> {
  final List<Task> tasks;
  final Function(Task) onToggleComplete;
  final Function(Task) onDelete;
  final Function(Task) onEdit;

  TaskSearchDelegate({
    required this.tasks,
    required this.onToggleComplete,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        // Utilisation de .onSurface.withOpacity(0.5) est obsolète
        hintStyle: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.5),
        ),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final searchResults = tasks.where((task) {
      final queryLower = query.toLowerCase();
      return task.title.toLowerCase().contains(queryLower) ||
          task.description.toLowerCase().contains(queryLower);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.builder(
        itemCount: searchResults.length,
        itemBuilder: (context, index) {
          final task = searchResults[index];
          return TaskCard(
            key: ValueKey(task.id),
            task: task,
            onToggleComplete: () {
              onToggleComplete(task);
            },
            onEdit: () {
              onEdit(task);
              close(context, task); 
            },
            onDelete: () {
              onDelete(task);
            },
          );
        },
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestionList = tasks.where((task) {
      final queryLower = query.toLowerCase();
      return task.title.toLowerCase().contains(queryLower) ||
          task.description.toLowerCase().contains(queryLower);
    }).toList();

    return ListView.builder(
      itemCount: suggestionList.length,
      itemBuilder: (context, index) {
        final task = suggestionList[index];
        return ListTile(
          leading: Icon(task.isDone ? Icons.check_circle : Icons.circle_outlined),
          title: Text(task.title),
          subtitle: task.description.isNotEmpty ? Text(task.description, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
          onTap: () {
            query = task.title;
            showResults(context);
          },
        );
      },
    );
  }
}