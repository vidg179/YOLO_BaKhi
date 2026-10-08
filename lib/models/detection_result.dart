import 'dart:ui';

/// Represents a single bounding box object detection result.
class Recognition {
  final int classId;
  final String label;
  final double score;
  final Rect location;

  Recognition({
    required this.classId,
    required this.label,
    required this.score,
    required this.location,
  });

  /// Get score as a formatted percentage string (e.g., "85.4%")
  String get scorePercentage => '${(score * 100).toStringAsFixed(1)}%';

  Map<String, dynamic> toJson() {
    return {
      'classId': classId,
      'label': label,
      'score': score,
      'left': location.left,
      'top': location.top,
      'width': location.width,
      'height': location.height,
    };
  }

  factory Recognition.fromJson(Map<String, dynamic> json) {
    return Recognition(
      classId: json['classId'] as int,
      label: json['label'] as String,
      score: (json['score'] as num).toDouble(),
      location: Rect.fromLTWH(
        (json['left'] as num).toDouble(),
        (json['top'] as num).toDouble(),
        (json['width'] as num).toDouble(),
        (json['height'] as num).toDouble(),
      ),
    );
  }
}

/// Represents a saved detection history item.
class HistoryItem {
  final String id;
  final String imagePath;
  final DateTime timestamp;
  final List<Recognition> detections;

  HistoryItem({
    required this.id,
    required this.imagePath,
    required this.timestamp,
    required this.detections,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagePath': imagePath,
      'timestamp': timestamp.toIso8601String(),
      'detections': detections.map((d) => d.toJson()).toList(),
    };
  }

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] as String,
      imagePath: json['imagePath'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      detections: (json['detections'] as List)
          .map((item) => Recognition.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
