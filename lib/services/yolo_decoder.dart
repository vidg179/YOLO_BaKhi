import 'dart:math';
import 'dart:ui';

import '../models/detection_result.dart';

/// Decode raw YOLO xywh/class output; remove padding before drawing on preview.
class YoloDecoder {
  final int inputWidth, inputHeight, numBoxes;
  final List<String> labels;
  final bool normalizedCoordinates;
  int get numClasses => labels.length;
  const YoloDecoder({
    required this.inputWidth,
    required this.inputHeight,
    required this.numBoxes,
    required this.labels,
    required this.normalizedCoordinates,
  });

  /// Process YOLOv8 output matrix [84, 8400] and return list of Recognitions
  List<Recognition> decode(
    List<List<double>> output, {
    required double confidenceThreshold,
    required double iouThreshold,
    required int imageWidth,
    required int imageHeight,
    required int sensorOrientation,
    required bool mirror,
  }) {
    final List<Recognition> candidateRecognitions = [];

    // output is 84 x 8400
    for (int j = 0; j < numBoxes; j++) {
      // Find max class confidence score
      double maxScore = 0.0;
      int maxClassId = -1;

      for (int c = 0; c < numClasses; c++) {
        final double score = output[4 + c][j];
        if (score > maxScore) {
          maxScore = score;
          maxClassId = c;
        }
      }

      if (maxScore >= confidenceThreshold) {
        final double cx = output[0][j];
        final double cy = output[1][j];
        final double w = output[2][j];
        final double h = output[3][j];

        if (![cx, cy, w, h, maxScore].every((v) => v.isFinite) ||
            w <= 0 ||
            h <= 0) {
          continue;
        }
        // Coordinate convention is explicit in config.json, independent of layout.
        final coordX = normalizedCoordinates ? inputWidth.toDouble() : 1.0;
        final coordY = normalizedCoordinates ? inputHeight.toDouble() : 1.0;
        final rotated = sensorOrientation == 90 || sensorOrientation == 270;
        final sourceWidth = rotated ? imageHeight : imageWidth;
        final sourceHeight = rotated ? imageWidth : imageHeight;
        final scale = min(inputWidth / sourceWidth, inputHeight / sourceHeight);
        final padX = (inputWidth - sourceWidth * scale) / 2;
        final padY = (inputHeight - sourceHeight * scale) / 2;
        var left = (((cx - w / 2) * coordX - padX) / scale / sourceWidth).clamp(
          0.0,
          1.0,
        );
        final top = (((cy - h / 2) * coordY - padY) / scale / sourceHeight)
            .clamp(0.0, 1.0);
        final right = (((cx + w / 2) * coordX - padX) / scale / sourceWidth)
            .clamp(0.0, 1.0);
        final bottom = (((cy + h / 2) * coordY - padY) / scale / sourceHeight)
            .clamp(0.0, 1.0);
        final width = right - left;
        final height = bottom - top;
        if (width <= 0 || height <= 0) continue;
        if (mirror) left = 1 - right;

        final String label = maxClassId >= 0 && maxClassId < labels.length
            ? labels[maxClassId]
            : 'Unknown';

        candidateRecognitions.add(
          Recognition(
            classId: maxClassId,
            label: label,
            score: maxScore,
            location: Rect.fromLTWH(left, top, width, height),
          ),
        );
      }
    }

    // Apply Non-Maximum Suppression (NMS)
    return _applyNMS(candidateRecognitions, iouThreshold);
  }

  /// Perform Non-Maximum Suppression (NMS) to eliminate overlapping boxes
  List<Recognition> _applyNMS(List<Recognition> boxes, double iouThreshold) {
    if (boxes.isEmpty) return [];

    // Sort by confidence score descending
    boxes.sort((a, b) => b.score.compareTo(a.score));

    final List<Recognition> selected = [];
    final List<bool> active = List.filled(boxes.length, true);

    for (int i = 0; i < boxes.length; i++) {
      if (!active[i]) continue;

      final Recognition boxA = boxes[i];
      selected.add(boxA);

      for (int j = i + 1; j < boxes.length; j++) {
        if (!active[j]) continue;

        final Recognition boxB = boxes[j];

        // If same class (or all classes) and IoU > threshold, suppress
        if (boxA.classId == boxB.classId) {
          final double iou = _calculateIoU(boxA.location, boxB.location);
          if (iou > iouThreshold) {
            active[j] = false;
          }
        }
      }

      if (selected.length >= 30) break; // Limit max boxes returned
    }

    return selected;
  }

  /// Calculate Intersection over Union (IoU) between two Rects
  double _calculateIoU(Rect a, Rect b) {
    final double areaA = a.width * a.height;
    final double areaB = b.width * b.height;

    if (areaA <= 0 || areaB <= 0) return 0.0;

    final double intersectionLeft = max(a.left, b.left);
    final double intersectionTop = max(a.top, b.top);
    final double intersectionRight = min(a.right, b.right);
    final double intersectionBottom = min(a.bottom, b.bottom);

    final double intersectionWidth = max(
      0.0,
      intersectionRight - intersectionLeft,
    );
    final double intersectionHeight = max(
      0.0,
      intersectionBottom - intersectionTop,
    );

    final double intersectionArea = intersectionWidth * intersectionHeight;
    final double unionArea = areaA + areaB - intersectionArea;

    return unionArea > 0 ? intersectionArea / unionArea : 0.0;
  }
}
