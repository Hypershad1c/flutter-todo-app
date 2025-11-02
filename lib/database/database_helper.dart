import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart';
import 'package:sembast/sembast.dart' as sembast;
import 'package:sembast_web/sembast_web.dart';
import '../models/task.dart';

/// Database helper that automatically switches between sqflite (mobile) and sembast (web)
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  
  // For mobile (sqflite)
  static sqflite.Database? _sqlDatabase;
  
  // For web (sembast)
  static sembast.DatabaseFactory? _databaseFactory;
  static sembast.Database? _sembastDatabase;
  static final sembast.StoreRef<int, Map<String, dynamic>> _taskStore =
      sembast.intMapStoreFactory.store('tasks');

  DatabaseHelper._init();

  /// Get database instance (handles both mobile and web)
  Future<dynamic> get database async {
    if (kIsWeb) {
      if (_sembastDatabase != null) return _sembastDatabase;
      return await _initWebDatabase();
    } else {
      if (_sqlDatabase != null) return _sqlDatabase;
      return await _initMobileDatabase();
    }
  }

  /// Initialize SQLite database for mobile
  Future<sqflite.Database> _initMobileDatabase() async {
    final dbPath = await sqflite.getDatabasesPath();
    final path = join(dbPath, 'todo_app.db');

    _sqlDatabase = await sqflite.openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
    return _sqlDatabase!;
  }

  /// Initialize Sembast database for web
  Future<sembast.Database> _initWebDatabase() async {
    _databaseFactory = databaseFactoryWeb;
    _sembastDatabase = await _databaseFactory!.openDatabase('todo_app.db');
    return _sembastDatabase!;
  }

  /// Create database tables (for mobile)
  Future<void> _createDB(sqflite.Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        priority TEXT NOT NULL,
        isDone INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        completedAt TEXT,
        reminderTime TEXT
      )
    ''');
  }

  /// Insert a new task
  Future<int> insertTask(Task task) async {
    if (kIsWeb) {
      final db = await database as sembast.Database;
      final id = await _taskStore.add(db, task.toMap());
      return id;
    } else {
      final db = await database as sqflite.Database;
      return await db.insert('tasks', task.toMap());
    }
  }

  /// Get all tasks
  Future<List<Task>> getAllTasks() async {
    if (kIsWeb) {
      final db = await database as sembast.Database;
      final finder = sembast.Finder(sortOrders: [sembast.SortOrder('createdAt', false)]);
      final recordSnapshots = await _taskStore.find(db, finder: finder);
      
      return recordSnapshots.map((snapshot) {
        final task = Task.fromMap(snapshot.value);
        task.id = snapshot.key;
        return task;
      }).toList();
    } else {
      final db = await database as sqflite.Database;
      final result = await db.query(
        'tasks',
        orderBy: 'createdAt DESC',
      );
      return result.map((map) => Task.fromMap(map)).toList();
    }
  }

  /// Get active (not done) tasks
  Future<List<Task>> getActiveTasks() async {
    if (kIsWeb) {
      final db = await database as sembast.Database;
      final finder = sembast.Finder(
        filter: sembast.Filter.equals('isDone', 0),
        sortOrders: [sembast.SortOrder('createdAt', false)],
      );
      final recordSnapshots = await _taskStore.find(db, finder: finder);
      
      return recordSnapshots.map((snapshot) {
        final task = Task.fromMap(snapshot.value);
        task.id = snapshot.key;
        return task;
      }).toList();
    } else {
      final db = await database as sqflite.Database;
      final result = await db.query(
        'tasks',
        where: 'isDone = ?',
        whereArgs: [0],
        orderBy: 'createdAt DESC',
      );
      return result.map((map) => Task.fromMap(map)).toList();
    }
  }

  /// Get completed tasks
  Future<List<Task>> getCompletedTasks() async {
    if (kIsWeb) {
      final db = await database as sembast.Database;
      final finder = sembast.Finder(
        filter: sembast.Filter.equals('isDone', 1),
        sortOrders: [sembast.SortOrder('completedAt', false)],
      );
      final recordSnapshots = await _taskStore.find(db, finder: finder);
      
      return recordSnapshots.map((snapshot) {
        final task = Task.fromMap(snapshot.value);
        task.id = snapshot.key;
        return task;
      }).toList();
    } else {
      final db = await database as sqflite.Database;
      final result = await db.query(
        'tasks',
        where: 'isDone = ?',
        whereArgs: [1],
        orderBy: 'completedAt DESC',
      );
      return result.map((map) => Task.fromMap(map)).toList();
    }
  }

  /// Update a task
  Future<int> updateTask(Task task) async {
    if (kIsWeb) {
      final db = await database as sembast.Database;
      await _taskStore.record(task.id!).update(db, task.toMap());
      return task.id!;
    } else {
      final db = await database as sqflite.Database;
      return await db.update(
        'tasks',
        task.toMap(),
        where: 'id = ?',
        whereArgs: [task.id],
      );
    }
  }

  /// Delete a task
  Future<int> deleteTask(int id) async {
    if (kIsWeb) {
      final db = await database as sembast.Database;
      await _taskStore.record(id).delete(db);
      return id;
    } else {
      final db = await database as sqflite.Database;
      return await db.delete(
        'tasks',
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// Clear all completed tasks
  Future<void> clearCompletedTasks() async {
    if (kIsWeb) {
      final db = await database as sembast.Database;
      final finder = sembast.Finder(filter: sembast.Filter.equals('isDone', 1));
      await _taskStore.delete(db, finder: finder);
    } else {
      final db = await database as sqflite.Database;
      await db.delete(
        'tasks',
        where: 'isDone = ?',
        whereArgs: [1],
      );
    }
  }

  /// Close database
  Future<void> close() async {
    if (kIsWeb) {
      await _sembastDatabase?.close();
    } else {
      await _sqlDatabase?.close();
    }
  }
}