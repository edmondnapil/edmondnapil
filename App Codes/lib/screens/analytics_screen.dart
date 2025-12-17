import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/scan_log_service.dart';
import '../models/scan_log.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => AnalyticsScreenState();
}

class AnalyticsScreenState extends State<AnalyticsScreen> {
  final ScanLogService _logService = ScanLogService();
  List<MapEntry<String, int>> _labelCounts = [];
  List<ScanLog> _allLogs = [];
  // All 10 classes from labels.txt
  final List<String> _allClasses = [
    'Watches',
    'Sunglassess',
    'Belts',
    'Handbags',
    'Necklaces',
    'Rings',
    'Wallets',
    'Hats',
    'Earrings',
    'Bracelets',
  ];
  int _totalScans = 0;
  bool _isLoading = true;
  bool _isInitialized = false;
  StreamSubscription<List<ScanLog>>? _logsSubscription;

  @override
  void initState() {
    super.initState();
    // Lazy load - only load when screen is first shown
    _loadAnalyticsLazy();
  }

  @override
  void dispose() {
    _logsSubscription?.cancel();
    super.dispose();
  }

  // Public method to refresh analytics data (only when needed)
  void refresh() {
    if (!_isInitialized) {
      _loadAnalyticsLazy();
    }
    // If already initialized, stream will auto-update
  }

  // Lazy loading - only load once, then use stream for updates
  void _loadAnalyticsLazy() {
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
          _updateAnalyticsFromLogs(logs);
        }
      },
      onError: (error) {
        print('Error in analytics stream: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  void _updateAnalyticsFromLogs(List<ScanLog> logs) {
    // Calculate analytics from logs
    final Map<String, int> labelCounts = {};
    for (var log in logs) {
      final label = log.detectedLabel;
      labelCounts[label] = (labelCounts[label] ?? 0) + 1;
    }

    // Create count map for all classes (including 0 counts)
    final Map<String, int> allClassCounts = {};
    for (var className in _allClasses) {
      allClassCounts[className] = labelCounts[className] ?? 0;
    }

    setState(() {
      _labelCounts = allClassCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      _allLogs = logs;
      _totalScans = logs.length;
      _isLoading = false;
    });
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    final analytics = await _logService.getAnalytics();
    final logs = await _logService.getLogs();

    // Create count map for all classes (including 0 counts)
    final Map<String, int> allClassCounts = {};
    for (var className in _allClasses) {
      allClassCounts[className] = analytics[className] ?? 0;
    }

    setState(() {
      _labelCounts = allClassCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      _allLogs = logs;
      _totalScans = logs.length;
      _isLoading = false;
    });
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
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryBrown,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAnalytics,
                  color: AppTheme.primaryBrown,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Analytics',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                color: AppTheme.darkBrown,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your scanning statistics',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.primaryBrown,
                              ),
                        ),
                        const SizedBox(height: 30),
                        // Summary Cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                context,
                                title: 'Total Scans',
                                value: _totalScans.toString(),
                                icon: Icons.camera_alt,
                                color: AppTheme.primaryBrown,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                context,
                                title: 'Items Found',
                                value: _labelCounts.length.toString(),
                                icon: Icons.label,
                                color: AppTheme.lightBrown,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        // Line Graph - Class Scan Counts
                        if (_labelCounts.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
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
                                Row(
                                  children: [
                                    Icon(
                                      Icons.show_chart,
                                      color: AppTheme.primaryBrown,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Class Scan Counts',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: AppTheme.darkBrown,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Shows how many times each class was scanned',
                                  style: TextStyle(
                                    color: AppTheme.primaryBrown,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  height: 300,
                                  child: _buildClassCountLineGraph(),
                                ),
                                const SizedBox(height: 16),
                                // All Classes - Pill buttons showing each class
                                Text(
                                  'All Classes',
                                  style: TextStyle(
                                    color: AppTheme.darkBrown,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: _allClasses.map((className) {
                                    final count = _labelCounts
                                        .firstWhere(
                                          (e) => e.key == className,
                                          orElse: () => MapEntry(className, 0),
                                        )
                                        .value;
                                    return _buildClassPill(
                                      className,
                                      _getColorForItem(className),
                                      count,
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          )
                        else if (_labelCounts.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.analytics_outlined,
                                    size: 64,
                                    color: AppTheme.tan,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No data yet',
                                    style: TextStyle(
                                      color: AppTheme.primaryBrown,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Start scanning images to see analytics',
                                    style: TextStyle(
                                      color: AppTheme.tan,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 30),
                        // Detailed Data Section
                        if (_labelCounts.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
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
                                Text(
                                  'Detailed Data',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: AppTheme.darkBrown,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                // Table headers
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Item Class',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryBrown,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Scan Count',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryBrown,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                // Data rows
                                ..._labelCounts.map((entry) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Row(
                                          children: [
                                              Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  color: _getColorForItem(entry.key),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                entry.key,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: AppTheme.darkBrown,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                              ),
                                            ),
                                        Expanded(
                                          child: Text(
                                              '${entry.value}x',
                                            textAlign: TextAlign.right,
                                              style: TextStyle(
                                              fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryBrown,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.analytics_outlined,
                                    size: 64,
                                    color: AppTheme.tan,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No data yet',
                                    style: TextStyle(
                                      color: AppTheme.primaryBrown,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Start scanning images to see analytics',
                                    style: TextStyle(
                                      color: AppTheme.tan,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
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

  Widget _buildClassCountLineGraph() {
    if (_labelCounts.isEmpty) {
      return Center(
        child: Text(
          'No scan data available',
          style: TextStyle(
            color: AppTheme.primaryBrown,
            fontSize: 14,
          ),
        ),
      );
    }

    // Get counts for all 10 classes in order
    final classCounts = _allClasses.map((className) {
      final entry = _labelCounts.firstWhere(
        (e) => e.key == className,
        orElse: () => MapEntry(className, 0),
      );
      return entry.value.toDouble();
    }).toList();

    // Get max value for scaling
    final maxValue = classCounts.reduce((a, b) => a > b ? a : b);
    final maxValueForScale = maxValue > 0 ? maxValue : 1.0;

    final graphHeight = 250.0;
    // Use screen width instead of fixed width per class - no horizontal scrolling
    return LayoutBuilder(
      builder: (context, constraints) {
        final graphWidth = constraints.maxWidth;
        return SizedBox(
          width: graphWidth,
          height: graphHeight,
          child: CustomPaint(
            painter: ClassCountLineGraphPainter(
              data: classCounts,
              labels: _allClasses,
              maxValue: maxValueForScale,
              color: AppTheme.primaryBrown,
            ),
          ),
        );
      },
    );
  }

  Color _getColorForItem(String item) {
    final colors = [
      AppTheme.primaryBrown,
      Colors.orange.shade700,
      AppTheme.lightBrown,
      Colors.blue.shade700,
      Colors.green.shade700,
      Colors.purple.shade700,
      Colors.red.shade700,
      Colors.teal.shade700,
    ];
    final index = _labelCounts.indexWhere((e) => e.key == item);
    return colors[index % colors.length];
  }

  Widget _buildClassPill(String label, Color color, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.darkBrown,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: AppTheme.primaryBrown,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for class count line graph
class ClassCountLineGraphPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final double maxValue;
  final Color color;

  ClassCountLineGraphPainter({
    required this.data,
    required this.labels,
    required this.maxValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || labels.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final textStyle = TextStyle(
      color: AppTheme.darkBrown,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    // Increased padding for better spacing, especially on sides
    final paddingLeft = 50.0;
    final paddingRight = 50.0;
    final paddingTop = 50.0;
    final paddingBottom = 80.0; // More space at bottom for labels
    
    final graphWidth = size.width - paddingLeft - paddingRight;
    final graphHeight = size.height - paddingTop - paddingBottom;
    
    // Better spacing: distribute evenly with proper spacing between points
    final stepX = labels.length > 1 
        ? graphWidth / (labels.length - 1) 
        : graphWidth;

    // Calculate points with proper spacing
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = paddingLeft + (i * stepX);
      final y = paddingTop + (graphHeight - (data[i] / maxValue * graphHeight));
      points.add(Offset(x, y));
    }

    // Draw filled area under line
    if (points.length > 1) {
      final path = Path();
      final bottomY = paddingTop + graphHeight;
      path.moveTo(points.first.dx, bottomY);
      for (var point in points) {
        path.lineTo(point.dx, point.dy);
      }
      path.lineTo(points.last.dx, bottomY);
      path.close();
      canvas.drawPath(path, fillPaint);
    }

    // Draw line
    if (points.length > 1) {
      final path = Path();
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    // Draw points and labels
    for (int i = 0; i < points.length; i++) {
      // Draw point
      canvas.drawCircle(points[i], 5, pointPaint);
      
      // Draw value label above point
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${data[i].toInt()}',
          style: textStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          points[i].dx - textPainter.width / 2,
          points[i].dy - 20,
        ),
      );

      // Draw class name label below with better spacing
      final labelText = labels[i].length > 10 
          ? '${labels[i].substring(0, 9)}...' 
          : labels[i];
      
      final labelPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: textStyle.copyWith(fontSize: 8),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      labelPainter.layout();
      
      // Position label below the graph with proper spacing
      final bottomY = paddingTop + graphHeight;
      final labelY = bottomY + 15; // Space below graph line
      
      // Center the label under each point
      canvas.save();
      canvas.translate(points[i].dx, labelY);
      canvas.rotate(-0.4); // Slight rotation for readability
      labelPainter.paint(canvas, Offset(-labelPainter.width / 2, 0));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ClassCountLineGraphPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.labels != labels ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.color != color;
  }
}

