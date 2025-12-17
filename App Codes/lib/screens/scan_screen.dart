import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../services/image_detection_service.dart';
import '../services/scan_log_service.dart';
import '../models/scan_log.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final ImageDetectionService _detectionService = ImageDetectionService();
  final ScanLogService _logService = ScanLogService();

  File? _selectedImage;
  String? _detectedLabel;
  double? _confidence;
  Map<String, double>? _allClassScores;
  bool _isScanning = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _detectedLabel = null;
          _confidence = null;
          _allClassScores = null;
        });
        await _detectImage(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _detectImage(XFile imageFile) async {
    setState(() {
      _isScanning = true;
    });

    try {
      final result = await _detectionService.detectImage(imageFile);
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'anonymous';

      // Prepare log id so we can use it for both Firestore and Storage
      final logId = DateTime.now().millisecondsSinceEpoch.toString();

      // Upload image to Firebase Storage
      String? imageUrl;
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('users')
            .child(userId)
            .child('scan_images')
            .child('$logId.jpg');
        await storageRef.putFile(File(imageFile.path));
        imageUrl = await storageRef.getDownloadURL();
      } catch (_) {
        // If upload fails, we still keep local path and log
      }

      if (mounted) {
        setState(() {
          if (result != null) {
            _detectedLabel = result.label;
            _confidence = result.confidence;
            _allClassScores = result.allScores;
          } else {
            _detectedLabel = 'No item detected';
            _confidence = null;
            _allClassScores = null;
          }
          _isScanning = false;
        });

        // Save to Firestore (per-user log)
        try {
          if (result != null) {
            final log = ScanLog(
              id: logId,
              userId: userId,
              imagePath: imageFile.path,
              imageUrl: imageUrl,
              detectedLabel: result.label,
              confidence: result.confidence,
              timestamp: DateTime.now(),
            );
            await _logService.addLog(log);
            
            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Scan saved: ${result.label}'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } else {
            // Still save even if detection failed, but mark as Unknown
            final log = ScanLog(
              id: logId,
              userId: userId,
              imagePath: imageFile.path,
              imageUrl: imageUrl,
              detectedLabel: 'Unknown',
              confidence: 0,
              timestamp: DateTime.now(),
            );
            await _logService.addLog(log);
          }
        } catch (saveError) {
          print('Failed to save scan log: $saveError');
          // Don't show error to user - scan still worked, just didn't save
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error detecting image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _detectionService.dispose();
    super.dispose();
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Scan Image',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: AppTheme.darkBrown,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload or capture an image to detect fashion items',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.primaryBrown,
                      ),
                ),
                const SizedBox(height: 30),
                // Image Display Area
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.chocolate.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _selectedImage == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_outlined,
                                size: 64,
                                color: AppTheme.tan,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No image selected',
                                style: TextStyle(
                                  color: AppTheme.primaryBrown,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                ),
                const SizedBox(height: 30),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isScanning
                            ? null
                            : () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBrown,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isScanning
                            ? null
                            : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.lightBrown,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                // Detection Results
                if (_isScanning)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryBrown,
                        ),
                      ),
                    ),
                  )
                else if (_detectedLabel != null)
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
                              Icons.check_circle,
                              color: Colors.green.shade700,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Detected Item',
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
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Chip(
                              label: Text(
                                _detectedLabel ?? 'Unknown',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              backgroundColor: AppTheme.primaryBrown,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (_confidence != null)
                              Text(
                                '${(_confidence! * 100).toStringAsFixed(1)}% accuracy',
                                style: const TextStyle(
                                  color: AppTheme.primaryBrown,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                // Bar Graph - All Class Predictions
                if (_allClassScores != null && _allClassScores!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 30),
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
                              Icons.bar_chart,
                              color: AppTheme.primaryBrown,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'All Class Predictions',
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
                        const SizedBox(height: 20),
                        // Bar Graph with actual percentages (0-100%)
                        SizedBox(
                          height: 300,
                          child: Builder(
                            builder: (context) {
                              // Filter out zero values and sort
                              final sortedEntries = _allClassScores!.entries
                                  .where((entry) => entry.value > 0) // Remove zero values
                                  .toList()
                                ..sort((a, b) => b.value.compareTo(a.value));
                              
                              if (sortedEntries.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No predictions available',
                                    style: TextStyle(
                                      color: AppTheme.primaryBrown,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              }
                              
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: sortedEntries.map((entry) {
                                  final percentage = entry.value * 100; // Actual percentage 0-100%
                                  final isHighConfidence = entry.value > 0.3;
                                  final isTopPrediction = entry.key == _detectedLabel;
                                  // Bar height based on actual percentage (0-100% = 0-250px)
                                  final barHeight = (percentage / 100 * 250).clamp(20.0, 250.0);
                                  
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 3),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          // Percentage label on top
                                          Text(
                                            '${percentage.toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isHighConfidence
                                                  ? Colors.orange.shade800
                                                  : AppTheme.primaryBrown,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // Bar - actual percentage height
                                          Container(
                                            height: barHeight,
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: isHighConfidence
                                                  ? Colors.orange.shade700
                                                  : isTopPrediction
                                                      ? AppTheme.primaryBrown
                                                      : AppTheme.lightBrown,
                                              borderRadius: const BorderRadius.only(
                                                topLeft: Radius.circular(8),
                                                topRight: Radius.circular(8),
                                              ),
                                            ),
                                            child: isTopPrediction
                                                ? Container(
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin: Alignment.topCenter,
                                                        end: Alignment.bottomCenter,
                                                        colors: [
                                                          AppTheme.primaryBrown.withOpacity(0.9),
                                                          AppTheme.primaryBrown,
                                                        ],
                                                      ),
                                                      borderRadius: const BorderRadius.only(
                                                        topLeft: Radius.circular(8),
                                                        topRight: Radius.circular(8),
                                                      ),
                                                    ),
                                                    alignment: Alignment.topCenter,
                                                    padding: const EdgeInsets.only(top: 4),
                                                    child: Icon(
                                                      Icons.star,
                                                      size: 14,
                                                      color: AppTheme.tan,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(height: 8),
                                          // Class label
                                          Text(
                                            entry.key.length > 10 
                                                ? '${entry.key.substring(0, 9)}...'
                                                : entry.key,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: isTopPrediction
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                              color: isTopPrediction
                                                  ? AppTheme.primaryBrown
                                                  : AppTheme.darkBrown,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Legend
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.tan.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildLegendItem('Top Prediction', AppTheme.primaryBrown, Icons.star),
                              const SizedBox(width: 16),
                              _buildLegendItem('High (>30%)', Colors.orange.shade700, null),
                              const SizedBox(width: 16),
                              _buildLegendItem('Normal', AppTheme.lightBrown, null),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, IconData? icon) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: icon != null
              ? Icon(icon, size: 12, color: AppTheme.tan)
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.darkBrown,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

