import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
// Changement: Importation du nouveau service
import '../services/firebase_task_service.dart';
// Suppression de l'ancien: import '../database/database_helper.dart'; 

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Task> _completedTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompletedTasks();
  }

  Future<void> _loadCompletedTasks() async {
    setState(() => _isLoading = true);
    try {
        // Utilisation du service Firebase
        final tasks = await FirebaseTaskService.instance.getCompletedTasks();
        setState(() {
            _completedTasks = tasks;
            _isLoading = false;
        });
    } catch (e) {
        if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error loading history: $e')),
            );
            setState(() => _isLoading = false);
        }
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
          'Are you sure you want to delete all completed tasks? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        // Utilisation du service Firebase
        await FirebaseTaskService.instance.clearCompletedTasks();
        await _loadCompletedTasks();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('History cleared successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error clearing history: $e')),
            );
            setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _restoreTask(Task task) async {
    // task.id est maintenant un String?
    if (task.id == null) return;
    
    final restoredTask = task.copyWith(
      isDone: false,
      completedAt: null,
    );
    
    try {
        // Utilisation du service Firebase
        await FirebaseTaskService.instance.updateTask(restoredTask);
        await _loadCompletedTasks();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task restored to active list'),
              backgroundColor: Colors.blue,
            ),
          );
        }
    } catch (e) {
        if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error restoring task: $e')),
            );
        }
    }
  }

  Future<void> _deleteTask(Task task) async {
    if (task.id == null) return;
    
    try {
        // Utilisation du service Firebase
        await FirebaseTaskService.instance.deleteTask(task.id!);
        await _loadCompletedTasks();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task deleted permanently'),
              backgroundColor: Colors.red,
            ),
          );
        }
    } catch (e) {
        if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error deleting task: $e')),
            );
        }
    }
  }

  // Fonction utilitaire pour la couleur de priorité
  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task History'),
        actions: [
          if (_completedTasks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear History',
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _completedTasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 100,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No completed tasks yet',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Complete some tasks to see them here',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCompletedTasks,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _completedTasks.length,
                    itemBuilder: (context, index) {
                      final task = _completedTasks[index];
                      final completedDate = task.completedAt != null
                          ? DateFormat('MMM dd, yyyy - HH:mm').format(task.completedAt!)
                          : 'Unknown';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.withOpacity(0.2),
                            child: const Icon(
                              Icons.check,
                              color: Colors.green,
                            ),
                          ),
                          title: Text(
                            task.title,
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (task.description.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    task.description,
                                    style: const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.flag,
                                    size: 16,
                                    color: _getPriorityColor(task.priority),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    task.priority,
                                    style: TextStyle(
                                      color: _getPriorityColor(task.priority),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Completed: $completedDate',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'restore') {
                                _restoreTask(task);
                              } else if (value == 'delete') {
                                _deleteTask(task);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'restore',
                                child: Row(
                                  children: [
                                    Icon(Icons.restore),
                                    SizedBox(width: 8),
                                    Text('Restore'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}