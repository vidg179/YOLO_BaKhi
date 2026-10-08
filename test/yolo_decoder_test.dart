import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nhan_dien_vat_the/services/yolo_decoder.dart';

void main() {
  final output = <List<double>>[
    [200, 200, 200, 500],
    [320, 320, 320, 320],
    [80, 80, 80, 40],
    [160, 160, 160, 40],
    [.9, .8, .1, .1],
    [.1, .1, .85, .1],
  ];
  const decoder = YoloDecoder(
    inputWidth: 640,
    inputHeight: 640,
    numBoxes: 4,
    labels: ['cell phone', 'laptop'],
    normalizedCoordinates: false,
  );
  test(
    'Remove letterbox padding and suppress only duplicate same-class boxes',
    () {
      final result = decoder.decode(
        output,
        confidenceThreshold: .35,
        iouThreshold: .45,
        imageWidth: 640,
        imageHeight: 480,
        sensorOrientation: 90,
        mirror: false,
      );
      expect(result.length, 2);
      expect(result.first.label, 'cell phone');
      expect(
        result.first.location,
        const Rect.fromLTWH(1 / 6, .375, 1 / 6, .25),
      );
    },
  );
  test('Front preview mirrors horizontal bounds', () {
    final result = decoder.decode(
      output,
      confidenceThreshold: .35,
      iouThreshold: .45,
      imageWidth: 640,
      imageHeight: 480,
      sensorOrientation: 90,
      mirror: true,
    );
    expect(result.first.location.left, closeTo(2 / 3, 1e-9));
  });
  test('Normalized export produces same coordinates as pixel export', () {
    final normalized = [
      for (var i = 0; i < output.length; i++)
        [for (final v in output[i]) i < 4 ? v / 640 : v],
    ];
    const normalizedDecoder = YoloDecoder(
      inputWidth: 640,
      inputHeight: 640,
      numBoxes: 4,
      labels: ['cell phone', 'laptop'],
      normalizedCoordinates: true,
    );
    final result = normalizedDecoder.decode(
      normalized,
      confidenceThreshold: .35,
      iouThreshold: .45,
      imageWidth: 640,
      imageHeight: 480,
      sensorOrientation: 90,
      mirror: false,
    );
    expect(result.length, 2);
    expect(result.first.location.left, closeTo(1 / 6, 1e-9));
  });
  test('Reject invalid coordinates and low confidence', () {
    final bad = output.map((row) => List<double>.of(row)).toList();
    bad[0][0] = double.nan;
    bad[2][1] = -1;
    bad[3][2] = 0;
    expect(
      decoder.decode(
        bad,
        confidenceThreshold: .35,
        iouThreshold: .45,
        imageWidth: 640,
        imageHeight: 480,
        sensorOrientation: 90,
        mirror: false,
      ),
      isEmpty,
    );
  });
}
