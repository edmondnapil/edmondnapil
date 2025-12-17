class ScanLog {
  final String id;
  final String userId;
  final String imagePath;
  final String? imageUrl;
  final String detectedLabel;
  final DateTime timestamp;
  final double confidence;

  ScanLog({
    required this.id,
    required this.userId,
    required this.imagePath,
    this.imageUrl,
    required this.detectedLabel,
    required this.timestamp,
    required this.confidence,
  });

  Map<String, dynamic> toJson() {
    // Save 4 fields: Accuracy_rate, ClassType, Time, imagePath (for logs screen)
    final timeString = _formatDateTime(timestamp);
    
    return {
      'Accuracy_rate': confidence * 100, // Convert to percentage (0-100)
      'ClassType': detectedLabel,
      'Time': timeString,
      'imagePath': imagePath, // Needed for logs screen to display images
    };
  }
  
  String _formatDateTime(DateTime dateTime) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;
    
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    // Get timezone offset
    final offset = dateTime.timeZoneOffset;
    final offsetHours = offset.inHours;
    final offsetMinutes = offset.inMinutes.remainder(60).abs();
    final offsetSign = offsetHours >= 0 ? '+' : '-';
    final timezone = 'UTC$offsetSign${offsetHours.abs().toString().padLeft(2, '0')}:${offsetMinutes.toString().padLeft(2, '0')}';
    
    return '$month $day, $year at $displayHour:$minute:$second $period $timezone';
  }

  factory ScanLog.fromJson(Map<String, dynamic> json) {
    // Support both new format (fashion-accessories) and old format (backward compatibility)
    String detectedLabel;
    double confidence;
    DateTime timestamp;
    String id;
    String userId;
    String imagePath;
    String? imageUrl;
    
    if (json.containsKey('ClassType')) {
      // New format (fashion-accessories collection) - 4 fields: Accuracy_rate, ClassType, Time, imagePath
      detectedLabel = json['ClassType'] as String;
      confidence = (json['Accuracy_rate'] as num).toDouble() / 100; // Convert from percentage to 0-1
      timestamp = _parseDateTime(json['Time'] as String);
      id = DateTime.now().millisecondsSinceEpoch.toString();
      userId = 'anonymous';
      imagePath = json['imagePath'] as String? ?? ''; // Get imagePath from Firestore
      imageUrl = null;
    } else {
      // Old format (backward compatibility for analytics/logs screens)
      detectedLabel = json['detectedLabel'] as String;
      confidence = (json['confidence'] as num).toDouble();
      timestamp = DateTime.parse(json['timestamp'] as String);
      id = json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
      userId = json['userId'] as String? ?? 'anonymous';
      imagePath = json['imagePath'] as String? ?? '';
      imageUrl = json['imageUrl'] as String?;
    }
    
    return ScanLog(
      id: id,
      userId: userId,
      imagePath: imagePath,
      imageUrl: imageUrl,
      detectedLabel: detectedLabel,
      timestamp: timestamp,
      confidence: confidence,
    );
  }
  
  static DateTime _parseDateTime(String timeString) {
    // Parse the formatted time string
    // Format: "December 3, 2025 at 11:10:44 PM UTC+8"
    try {
      final parts = timeString.split(' at ');
      if (parts.length == 2) {
        final datePart = parts[0]; // "December 3, 2025"
        final timePart = parts[1].split(' UTC')[0]; // "11:10:44 PM"
        
        // Parse date
        final dateMatch = RegExp(r'(\w+) (\d+), (\d+)').firstMatch(datePart);
        if (dateMatch != null) {
          final monthName = dateMatch.group(1)!;
          final day = int.parse(dateMatch.group(2)!);
          final year = int.parse(dateMatch.group(3)!);
          
          final months = {
            'January': 1, 'February': 2, 'March': 3, 'April': 4, 'May': 5, 'June': 6,
            'July': 7, 'August': 8, 'September': 9, 'October': 10, 'November': 11, 'December': 12
          };
          final month = months[monthName] ?? 1;
          
          // Parse time
          final timeMatch = RegExp(r'(\d+):(\d+):(\d+) (AM|PM)').firstMatch(timePart);
          if (timeMatch != null) {
            var hour = int.parse(timeMatch.group(1)!);
            final minute = int.parse(timeMatch.group(2)!);
            final second = int.parse(timeMatch.group(3)!);
            final period = timeMatch.group(4)!;
            
            if (period == 'PM' && hour != 12) hour += 12;
            if (period == 'AM' && hour == 12) hour = 0;
            
            return DateTime(year, month, day, hour, minute, second);
          }
        }
      }
    } catch (e) {
      // Fallback to current time if parsing fails
    }
    return DateTime.now();
  }
}

