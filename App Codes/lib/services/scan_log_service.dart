import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/scan_log.dart';

/// Service for storing scan logs and analytics in Cloud Firestore.
///
/// Data model:
/// fashion-accessories/{logId}
/// Only 3 fields: Accuracy_rate, ClassType, Time
class ScanLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Use fashion-accessories collection (simple structure)
  CollectionReference<Map<String, dynamic>> get _logsCollection =>
      _firestore.collection('fashion-accessories');

  // Stream for real-time updates (lazy loading)
  Stream<List<ScanLog>> getLogsStream() {
    try {
      return _logsCollection
          .orderBy('Time', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => ScanLog.fromJson(doc.data()))
              .toList());
    } catch (e) {
      print('Error creating logs stream: $e');
      return Stream.value([]);
    }
  }

  Future<List<ScanLog>> getLogs() async {
    try {
      final snapshot = await _logsCollection
          .orderBy('Time', descending: true)
          .get();
      final logs = snapshot.docs
          .map((doc) => ScanLog.fromJson(doc.data()))
          .toList();
      print('Loaded ${logs.length} scan logs');
      return logs;
    } catch (e) {
      print('Error loading scan logs: $e');
      return [];
    }
  }

  Future<void> addLog(ScanLog log) async {
    try {
      // Ensure user is authenticated before saving
      if (_auth.currentUser == null) {
        try {
          await _auth.signInAnonymously();
          print('Signed in anonymously for saving log');
        } catch (authError) {
          print('Failed to sign in anonymously: $authError');
          // Continue anyway - will use 'anonymous' as userId
        }
      }
      
      await _logsCollection.doc(log.id).set(log.toJson());
      print('Scan log saved: ${log.detectedLabel} at ${log.timestamp}');
    } catch (e) {
      print('Error saving scan log: $e');
      rethrow; // Re-throw so caller knows it failed
    }
  }

  Future<void> deleteLog(String logId) async {
    try {
      await _logsCollection.doc(logId).delete();
      print('Scan log deleted: $logId');
    } catch (e) {
      print('Error deleting scan log: $e');
      rethrow;
    }
  }

  Future<void> clearLogs() async {
    try {
      final snapshot = await _logsCollection.get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {
      // ignore for now
    }
  }

  Future<Map<String, int>> getAnalytics() async {
    final logs = await getLogs();
    final Map<String, int> labelCounts = {};

    for (var log in logs) {
      final label = log.detectedLabel;
      labelCounts[label] = (labelCounts[label] ?? 0) + 1;
    }

    return labelCounts;
  }
}

