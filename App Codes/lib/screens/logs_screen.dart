import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
import '../theme/app_theme.dart';
import '../services/scan_log_service.dart';
import '../models/scan_log.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => LogsScreenState();
}

class LogsScreenState extends State<LogsScreen> {
  final ScanLogService _logService = ScanLogService();
  List<ScanLog> _logs = [];
  bool _isLoading = true;
  bool _isInitialized = false;
  StreamSubscription<List<ScanLog>>? _logsSubscription;

  @override
  void initState() {
    super.initState();
    // Lazy load - only load when screen is first shown
    _loadLogsLazy();
  }

  @override
  void dispose() {
    _logsSubscription?.cancel();
    super.dispose();
  }

  // Public method to refresh logs data (only when needed)
  void refresh() {
    if (!_isInitialized) {
      _loadLogsLazy();
    }
    // If already initialized, stream will auto-update
  }

  // Lazy loading - only load once, then use stream for updates
  void _loadLogsLazy() {
    if (_isInitialized) return; // Already loaded, stream will handle updates
    
    setState(() {
      _isLoading = true;
      _isInitialized = true;
    });

    // Use stream for real-time updates (lazy loading)
    _logsSubscription?.cancel();
    _logsSubscription = _logService.getLogsStream().listen(
      (logs) {
        if (mounted) {
          setState(() {
            _logs = logs;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        print('Error in logs stream: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
    });

    final logs = await _logService.getLogs();

    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteLog(ScanLog log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Scan?'),
        content: Text(
          'Are you sure you want to delete this scan of "${log.detectedLabel}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _logService.deleteLog(log.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Scan deleted: ${log.detectedLabel}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting scan: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Logs?'),
        content: const Text(
          'Are you sure you want to delete all scan history? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _logService.clearLogs();
      _loadLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logs cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.beige,
              AppTheme.cream,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan History',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                color: AppTheme.darkBrown,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_logs.length} scans',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.primaryBrown,
                              ),
                        ),
                      ],
                    ),
                    if (_logs.isNotEmpty)
                      IconButton(
                        onPressed: _clearLogs,
                        icon: const Icon(Icons.delete_outline),
                        color: AppTheme.primaryBrown,
                        tooltip: 'Clear logs',
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryBrown,
                          ),
                        ),
                      )
                    : _logs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 64,
                                  color: AppTheme.tan,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No scan history',
                                  style: TextStyle(
                                    color: AppTheme.primaryBrown,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Start scanning images to see history',
                                  style: TextStyle(
                                    color: AppTheme.tan,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadLogs,
                            color: AppTheme.primaryBrown,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              itemCount: _logs.length,
                              itemBuilder: (context, index) {
                                final log = _logs[index];
                                return _buildLogCard(log);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogCard(ScanLog log) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.chocolate.withOpacity(0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Preview: prefer remote URL, fallback to local file
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
            child: log.imageUrl != null
                ? Image.network(
                    log.imageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: AppTheme.tan.withOpacity(0.3),
                        child: const Icon(
                          Icons.broken_image,
                          size: 48,
                          color: AppTheme.primaryBrown,
                        ),
                      );
                    },
                  )
                : log.imagePath.isNotEmpty && File(log.imagePath).existsSync()
                    ? Image.file(
                        File(log.imagePath),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            color: AppTheme.tan.withOpacity(0.3),
                            child: const Icon(
                              Icons.broken_image,
                              size: 48,
                              color: AppTheme.primaryBrown,
                            ),
                          );
                        },
                      )
                    : Container(
                        height: 200,
                        color: AppTheme.tan.withOpacity(0.3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported,
                              size: 48,
                              color: AppTheme.primaryBrown,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No image available',
                              style: TextStyle(
                                color: AppTheme.primaryBrown,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timestamp and Delete button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: AppTheme.primaryBrown,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${dateFormat.format(log.timestamp)} at ${timeFormat.format(log.timestamp)}',
                              style: TextStyle(
                                color: AppTheme.primaryBrown,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _deleteLog(log),
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red.shade400,
                      iconSize: 20,
                      tooltip: 'Delete this scan',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Detected label and confidence
                Row(
                  children: [
                    Chip(
                      label: Text(
                        log.detectedLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: AppTheme.primaryBrown,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(log.confidence * 100).toStringAsFixed(1)}% accuracy',
                      style: TextStyle(
                        color: AppTheme.primaryBrown,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

