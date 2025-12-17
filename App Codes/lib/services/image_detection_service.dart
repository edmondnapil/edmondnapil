import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

// Conditional import - only import tflite on mobile platforms
import 'package:tflite_flutter/tflite_flutter.dart' 
    if (dart.library.html) 'package:my_app/services/tflite_stub.dart';

/// Result of a single detection.
class DetectionResult {
  final String label;
  final double confidence; // 0.0 - 1.0
  final Map<String, double> allScores; // All class predictions

  const DetectionResult({
    required this.label,
    required this.confidence,
    required this.allScores,
  });
}

/// Image detection service that uses the custom TFLite model and labels.txt
/// from the assets folder.
class ImageDetectionService {
  static const String _modelAsset = 'assets/model_unquant (1).tflite';
  static const String _labelsAsset = 'assets/labels.txt';

  Interpreter? _interpreter;
  List<String>? _labels;
  List<int>? _inputShape;
  bool _initializing = false;

  Future<void> _ensureInitialized() async {
    // TFLite doesn't work on web
    if (kIsWeb) {
      return;
    }
    
    if (_interpreter != null && _labels != null && _inputShape != null) {
      return;
    }
    if (_initializing) {
      // If another call is already initializing, wait a bit.
      while (_interpreter == null || _labels == null || _inputShape == null) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return;
    }

    _initializing = true;
    try {
      _interpreter = await Interpreter.fromAsset(_modelAsset);
      final inputTensor = _interpreter!.getInputTensor(0);
      _inputShape = inputTensor.shape; // e.g. [1, height, width, 3]

      final labelsString = await rootBundle.loadString(_labelsAsset);
      _labels = labelsString
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (e) {
      // If initialization fails (e.g., on web), just return
      _interpreter = null;
      _labels = null;
      _inputShape = null;
    } finally {
      _initializing = false;
    }
  }

  Future<DetectionResult?> detectImage(XFile imageFile) async {
    return detectImageFromFile(File(imageFile.path));
  }

  Future<DetectionResult?> detectImageFromFile(File imageFile) async {
    try {
      // TFLite doesn't work on web - return null
      if (kIsWeb) {
        return null;
      }
      
      await _ensureInitialized();
      if (_interpreter == null || _labels == null || _inputShape == null) {
        return null;
      }

      final imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        return null;
      }

      final height = _inputShape![1];
      final width = _inputShape![2];

      image = img.copyResize(
        image,
        height: height,
        width: width,
        interpolation: img.Interpolation.linear,
      );

      // Build input tensor: [1, height, width, 3]
      final input = List.generate(
        1,
        (_) => List.generate(
          height,
          (y) => List.generate(
            width,
            (x) {
              final pixel = image!.getPixel(x, y);
              final r = pixel.r / 255.0;
              final g = pixel.g / 255.0;
              final b = pixel.b / 255.0;
              return [r, g, b];
            },
          ),
        ),
      );

      // Output tensor: [1, numLabels]
      final numLabels = _labels!.length;
      final output = List.generate(
        1,
        (_) => List<double>.filled(numLabels, 0),
      );

      _interpreter!.run(input, output);

      final scores = output[0];
      
      // Normalize all scores to [0,1] range (apply softmax)
      bool needsNormalization = false;
      for (var i = 0; i < scores.length; i++) {
        if (scores[i] < 0 || scores[i] > 1) needsNormalization = true;
      }

      // Apply softmax normalization for all scores
      List<double> normalizedScores = List.filled(scores.length, 0.0);
      if (needsNormalization) {
        // Softmax normalization
        double sumExp = 0;
        for (var i = 0; i < scores.length; i++) {
          sumExp += exp(scores[i]);
        }
        for (var i = 0; i < scores.length; i++) {
          normalizedScores[i] = exp(scores[i]) / sumExp;
        }
      } else {
        // Scores are already normalized, but ensure they're in [0,1]
        for (var i = 0; i < scores.length; i++) {
          normalizedScores[i] = scores[i].clamp(0.0, 1.0);
          if (normalizedScores[i].isNaN || normalizedScores[i].isInfinite) {
            normalizedScores[i] = 0.0;
          }
        }
      }

      // Find the top prediction
      var maxIndex = 0;
      var maxScore = -double.infinity;
      for (var i = 0; i < normalizedScores.length; i++) {
        if (normalizedScores[i] > maxScore) {
          maxScore = normalizedScores[i];
          maxIndex = i;
        }
      }

      // Create map of all class scores
      Map<String, double> allScores = {};
      for (var i = 0; i < _labels!.length && i < normalizedScores.length; i++) {
        // Extract label name (remove index prefix if present)
        String labelName = _labels![i];
        if (labelName.contains(' ')) {
          // Remove index prefix (e.g., "0 Watches" -> "Watches")
          labelName = labelName.substring(labelName.indexOf(' ') + 1);
        }
        allScores[labelName] = normalizedScores[i];
      }

      final label = (maxIndex >= 0 && maxIndex < _labels!.length)
          ? _labels![maxIndex]
          : 'Unknown';
      
      // Remove index prefix from label for display
      String displayLabel = label;
      if (label.contains(' ')) {
        displayLabel = label.substring(label.indexOf(' ') + 1);
      }

      return DetectionResult(
        label: displayLabel, 
        confidence: maxScore,
        allScores: allScores,
      );
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
