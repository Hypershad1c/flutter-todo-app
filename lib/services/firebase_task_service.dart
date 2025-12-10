import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task.dart';

class FirebaseTaskService {
  static final FirebaseTaskService instance = FirebaseTaskService._init();
  FirebaseTaskService._init();

  // Getter pour obtenir l'ID de l'utilisateur Firebase connecté
  String get _currentUserId {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw Exception("User not logged in. Cannot access Firestore tasks.");
    }
    return userId;
  }

  // Référence à la collection Firestore pour les tâches de l'utilisateur actuel
  CollectionReference<Map<String, dynamic>> _taskCollection() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection('tasks');
  }

  // Helper pour convertir un document Firestore en objet Task
  Task _taskFromDocumentSnapshot(
      DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    // Utilise l'ID du document Firestore comme ID de la tâche (String)
    data['id'] = snapshot.id; 
    
    return Task.fromMap(data); 
  }
  
  // ====================
  // CRUD Operations
  // ====================

  /// Insert a new task
  Future<String> insertTask(Task task) async {
    final map = task.toMap();
    map.remove('id');
    final docRef = await _taskCollection().add(map);
    return docRef.id; 
  }

  /// Update a task
  Future<void> updateTask(Task task) async {
    if (task.id == null) {
      throw Exception("Task ID is null. Cannot update task.");
    }
    await _taskCollection().doc(task.id!).update(task.toMap());
  }

  /// Delete a task
  Future<void> deleteTask(String firestoreId) async {
    await _taskCollection().doc(firestoreId).delete();
  }

  /// Get active (not done) tasks
  Future<List<Task>> getActiveTasks() async {
    final snapshot = await _taskCollection()
        .where('isDone', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => _taskFromDocumentSnapshot(doc)).toList();
  }

  /// Get completed tasks
  Future<List<Task>> getCompletedTasks() async {
    final snapshot = await _taskCollection()
        .where('isDone', isEqualTo: true)
        .orderBy('completedAt', descending: true)
        .get();
        
    return snapshot.docs.map((doc) => _taskFromDocumentSnapshot(doc)).toList();
  }

  /// Clear all completed tasks
  Future<void> clearCompletedTasks() async {
    final batch = FirebaseFirestore.instance.batch();
    final snapshot = await _taskCollection().where('isDone', isEqualTo: true).get();

    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
  }
}