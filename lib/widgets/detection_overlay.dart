import '../models/classroom_catalog.dart';

import 'package:flutter/material.dart';

import '../models/detection_result.dart';

class DetectionOverlay extends StatelessWidget {
  final List<Recognition> recognitions;
  final Size previewSize;

  const DetectionOverlay({
    super.key,
    required this.recognitions,
    required this.previewSize,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _DetectionPainter(
        recognitions: recognitions,
        previewSize: previewSize,
      ),
    );
  }
}

class _DetectionPainter extends CustomPainter {
  final List<Recognition> recognitions;
  final Size previewSize;

  // Harmonious vivid color palette for bounding boxes
  static const List<Color> _palette = [
    Color(0xFF00E676), // Neon Green
    Color(0xFF00E5FF), // Bright Cyan
    Color(0xFFFF9100), // Vibrant Orange
    Color(0xFFFF4081), // Pink Accent
    Color(0xFFAA00FF), // Neon Purple
    Color(0xFFFFEA00), // Bright Yellow
    Color(0xFF00B0FF), // Sky Blue
    Color(0xFFFF3D00), // Deep Orange
    Color(0xFF76FF03), // Lime Green
    Color(0xFFE040FB), // Magenta
  ];

  _DetectionPainter({required this.recognitions, required this.previewSize});

  Color _getColorForClass(int classId) {
    return _palette[classId % _palette.length];
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (recognitions.isEmpty) return;

    final double scaleX = size.width;
    final double scaleY = size.height;

    final occupiedLabels = <Rect>[];
    for (var recognition in recognitions) {
      final Color color = _getColorForClass(recognition.classId);

      final Rect loc = recognition.location;
      final Rect boxRect = Rect.fromLTWH(
        loc.left * scaleX,
        loc.top * scaleY,
        loc.width * scaleX,
        loc.height * scaleY,
      );

      // 1. Draw Bounding Box Line
      final Paint boxPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawRRect(
        RRect.fromRectAndRadius(boxRect, const Radius.circular(8.0)),
        boxPaint,
      );

      // 2. Draw Translucent Fill Inner Rect
      final Paint fillPaint = Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(boxRect, const Radius.circular(8.0)),
        fillPaint,
      );

      // 3. Draw Label Badge Header
      final String labelText =
          '${displayLabel(recognition.label)} ${(recognition.score * 100).toStringAsFixed(1)}%';

      final TextSpan textSpan = TextSpan(
        text: labelText,
        style: TextStyle(
          color: ThemeData.estimateBrightnessForColor(color) == Brightness.light
              ? Colors.black
              : Colors.white,
          fontSize: 13.0,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      );

      final TextPainter textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      const double paddingH = 8.0;
      const double paddingV = 4.0;
      final double badgeWidth = textPainter.width + (paddingH * 2);
      final double badgeHeight = textPainter.height + (paddingV * 2);

      // Position badge right above top border or inside top border if near screen top
      double badgeTop = boxRect.top - badgeHeight - 2;
      if (badgeTop < 0) {
        badgeTop = boxRect.top + 2;
      }
      double badgeLeft = boxRect.left;
      if (badgeLeft + badgeWidth > size.width) {
        badgeLeft = size.width - badgeWidth - 4;
      }

      badgeLeft = badgeLeft.clamp(
        0.0,
        (size.width - badgeWidth).clamp(0.0, size.width),
      );
      final initialTop = badgeTop;
      for (var attempt = 0; attempt < 12; attempt++) {
        final candidate = Rect.fromLTWH(
          badgeLeft,
          badgeTop,
          badgeWidth,
          badgeHeight,
        );
        if (!occupiedLabels.any((r) => r.inflate(2).overlaps(candidate))) break;
        final offset = ((attempt ~/ 2) + 1) * (badgeHeight + 3);
        badgeTop = (initialTop + (attempt.isEven ? -offset : offset)).clamp(
          0.0,
          (size.height - badgeHeight).clamp(0.0, size.height),
        );
      }
      final Rect badgeRect = Rect.fromLTWH(
        badgeLeft,
        badgeTop,
        badgeWidth,
        badgeHeight,
      );

      occupiedLabels.add(badgeRect);

      final Paint badgeBackgroundPaint = Paint()
        ..color = color.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(badgeRect, const Radius.circular(6.0)),
        badgeBackgroundPaint,
      );

      textPainter.paint(
        canvas,
        Offset(badgeLeft + paddingH, badgeTop + paddingV),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionPainter oldDelegate) {
    return oldDelegate.recognitions != recognitions ||
        oldDelegate.previewSize != previewSize;
  }
}
