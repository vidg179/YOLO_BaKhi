import 'dart:math';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/detection_result.dart';
import 'yolo_decoder.dart';

class YoloService {
  static const String modelPath = 'assets/models/best.tflite';
  static const String labelPath = 'assets/models/labels.txt';

  int inputWidth = 640;
  int inputHeight = 640;
  int numClasses = 80;
  int numBoxes = 8400; // 8400 candidates for 640x640 YOLOv8

  bool _channelsFirst = true;
  bool _normalizedCoordinates = false;
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;
  bool _disposed = false;
  Future<List<Recognition>>? _pending;
  YoloService();

  YoloService._worker(Map<String, dynamic> config) {
    _interpreter = Interpreter.fromAddress(config['address'] as int);
    inputWidth = config['width'] as int;
    inputHeight = config['height'] as int;
    numClasses = config['classes'] as int;
    numBoxes = config['boxes'] as int;
    _channelsFirst = config['channelsFirst'] as bool;
    _normalizedCoordinates = config['normalized'] as bool;
    _labels = config['labels'] as List<String>;
    _isInitialized = true;
  }

  Map<String, dynamic> get _config => {
    'address': _interpreter!.address,
    'width': inputWidth,
    'height': inputHeight,
    'classes': numClasses,
    'boxes': numBoxes,
    'channelsFirst': _channelsFirst,
    'normalized': _normalizedCoordinates,
    'labels': _labels,
  };

  Future<List<Recognition>> _dispatch(Map<String, dynamic> request) async {
    if (_disposed || !_isInitialized) {
      throw StateError('Mô hình chưa sẵn sàng.');
    }
    if (_pending != null) throw StateError('Mô hình đang xử lý ảnh.');
    final task = compute(_detectInWorker, {..._config, ...request});
    _pending = task;
    try {
      return await task;
    } finally {
      _pending = null;
    }
  }

  Future<List<Recognition>> detectImage(
    Uint8List bytes, {
    double confidenceThreshold = .35,
  }) => _dispatch({'bytes': bytes, 'threshold': confidenceThreshold});

  bool get isInitialized => _isInitialized;
  List<String> get labels => List.unmodifiable(_labels);

  /// Load TFLite model and labels list
  Future<void> loadModel() async {
    try {
      final config = jsonDecode(
        await rootBundle.loadString('assets/models/config.json'),
      ) as Map<String, dynamic>;
      final coordinateSpace = config['coordinate_space'];
      if (coordinateSpace != 'pixels' && coordinateSpace != 'normalized') {
        throw StateError('coordinate_space phải là pixels hoặc normalized.');
      }
      _normalizedCoordinates = coordinateSpace == 'normalized';
      // 1. Load labels
      final labelData = await rootBundle.loadString(labelPath);
      _labels = labelData
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      // 2. Load interpreter options & model
      _interpreter?.close();
      _interpreter = null;
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(modelPath, options: options);

      if (_disposed) {
        _interpreter?.close();
        _interpreter = null;
        return;
      }
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();

      final input = inputTensors.single;
      final output = outputTensors.single;
      if (input.type != TensorType.float32 ||
          output.type != TensorType.float32 ||
          input.shape.length != 4 ||
          input.shape[0] != 1 ||
          output.shape.length != 3 ||
          output.shape[0] != 1) {
        throw StateError(
          'Cần mô hình YOLO detection Float32, batch=1, không NMS.',
        );
      }
      _channelsFirst = input.shape[1] == 3;
      if (!_channelsFirst && input.shape[3] != 3) {
        throw StateError('Input phải là RGB NCHW hoặc NHWC.');
      }
      inputHeight = input.shape[_channelsFirst ? 2 : 1];
      inputWidth = input.shape[_channelsFirst ? 3 : 2];
      numClasses = _labels.length;
      if (output.shape[1] != 4 + numClasses) {
        throw StateError(
          'Số nhãn không khớp output mô hình: ${output.shape}. '
          'Hãy thay model và labels cùng nhau.',
        );
      }
      numBoxes = output.shape[2];
      _isInitialized = true;
    } catch (e, stack) {
      _isInitialized = false;
      _interpreter?.close();
      _interpreter = null;
      debugPrint('Error loading TFLite model: $e');
      debugPrint('$stack');
      rethrow;
    }
  }

  /// Run real-time detection on a CameraImage frame
  Future<List<Recognition>> detectFrame(
    CameraImage image, {
    double confidenceThreshold = 0.25,
    double iouThreshold = 0.45,
    int sensorOrientation = 90,
    bool mirror = false,
  }) async {
    return _dispatch({
      'frame': image,
      'rotation': sensorOrientation,
      'mirror': mirror,
      'threshold': confidenceThreshold,
      'iou': iouThreshold,
    });
  }

  List<Recognition> _infer(
    Float32List inputBytes,
    int width,
    int height, {
    required double threshold,
    int rotation = 0,
    bool mirror = false,
    double iou = .45,
  }) {
    // ByteBuffer avoids materializing >1 million boxed numbers on every frame.
    _interpreter!.runInference([inputBytes.buffer]);
    final bytes = _interpreter!.getOutputTensor(0).data;
    final values = Float32List.view(
      bytes.buffer,
      bytes.offsetInBytes,
      bytes.lengthInBytes ~/ 4,
    );
    final output = List<List<double>>.generate(
      4 + numClasses,
      (c) => values.sublist(c * numBoxes, (c + 1) * numBoxes),
    );
    return YoloDecoder(
      inputWidth: inputWidth,
      inputHeight: inputHeight,
      numBoxes: numBoxes,
      labels: _labels,
      normalizedCoordinates: _normalizedCoordinates,
    ).decode(
      output,
      confidenceThreshold: threshold,
      iouThreshold: iou,
      imageWidth: width,
      imageHeight: height,
      sensorOrientation: rotation,
      mirror: mirror,
    );
  }

  Float32List _convertPhoto(img.Image photo) {
    final scale = min(inputWidth / photo.width, inputHeight / photo.height);
    final padX = (inputWidth - photo.width * scale) / 2;
    final padY = (inputHeight - photo.height * scale) / 2;
    final planeSize = inputWidth * inputHeight;
    final data = Float32List(planeSize * 3);
    for (var y = 0; y < inputHeight; y++) {
      for (var x = 0; x < inputWidth; x++) {
        final sx = ((x - padX) / scale).floor();
        final sy = ((y - padY) / scale).floor();
        final pixel =
            sx >= 0 && sx < photo.width && sy >= 0 && sy < photo.height
            ? photo.getPixel(sx, sy)
            : null;
        final i = y * inputWidth + x;
        data[_channelsFirst ? i : i * 3] = (pixel?.r ?? 114) / 255;
        data[_channelsFirst ? planeSize + i : i * 3 + 1] =
            (pixel?.g ?? 114) / 255;
        data[_channelsFirst ? planeSize * 2 + i : i * 3 + 2] =
            (pixel?.b ?? 114) / 255;
      }
    }
    return data;
  }

  /// Preprocess CameraImage (YUV420 or BGRA8888) into NCHW Float32 tensor [1, 3, 640, 640]
  Float32List _convertCameraImage(CameraImage image, int rotation) {
    if (image.format.group != ImageFormatGroup.yuv420 &&
        image.format.group != ImageFormatGroup.bgra8888) {
      throw StateError('Định dạng camera chưa hỗ trợ: ${image.format.group}');
    }
    final rotated = rotation == 90 || rotation == 270;
    final width = rotated ? image.height : image.width;
    final height = rotated ? image.width : image.height;
    final scale = min(inputWidth / width, inputHeight / height);
    final padX = (inputWidth - width * scale) / 2;
    final padY = (inputHeight - height * scale) / 2;
    final data = Float32List(3 * inputWidth * inputHeight);
    final planeSize = inputWidth * inputHeight;
    for (var y = 0; y < inputHeight; y++) {
      for (var x = 0; x < inputWidth; x++) {
        final rx = ((x - padX) / scale).floor();
        final ry = ((y - padY) / scale).floor();
        double r = 114, g = 114, b = 114;
        if (rx >= 0 && ry >= 0 && rx < width && ry < height) {
          final (sx, sy) = switch (rotation) {
            90 => (ry, image.height - 1 - rx),
            180 => (image.width - 1 - rx, image.height - 1 - ry),
            270 => (image.width - 1 - ry, rx),
            _ => (rx, ry),
          };
          if (image.format.group == ImageFormatGroup.bgra8888) {
            final plane = image.planes[0];
            final i = sy * plane.bytesPerRow + sx * 4;
            b = plane.bytes[i].toDouble();
            g = plane.bytes[i + 1].toDouble();
            r = plane.bytes[i + 2].toDouble();
          } else {
            final yp = image.planes[0];
            final up = image.planes[1];
            final vp = image.planes[2];
            final yy = image
                .planes[0]
                .bytes[sy * yp.bytesPerRow + sx * (yp.bytesPerPixel ?? 1)];
            final u =
                up.bytes[(sy ~/ 2) * up.bytesPerRow +
                    (sx ~/ 2) * (up.bytesPerPixel ?? 1)] -
                128;
            final v =
                vp.bytes[(sy ~/ 2) * vp.bytesPerRow +
                    (sx ~/ 2) * (vp.bytesPerPixel ?? 1)] -
                128;
            r = (yy + 1.402 * v).clamp(0, 255).toDouble();
            g = (yy - .344136 * u - .714136 * v).clamp(0, 255).toDouble();
            b = (yy + 1.772 * u).clamp(0, 255).toDouble();
          }
        }
        final i = y * inputWidth + x;
        data[_channelsFirst ? i : i * 3] = r / 255;
        data[_channelsFirst ? planeSize + i : i * 3 + 1] = g / 255;
        data[_channelsFirst ? planeSize * 2 + i : i * 3 + 2] = b / 255;
      }
    }
    return data;
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _pending;
    } catch (_) {
      /* Close even after a failed inference. */
    }
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}

// All preprocessing and native inference run outside the UI isolate.
// The main service waits for this task before releasing the native interpreter.
List<Recognition> _detectInWorker(Map<String, dynamic> request) {
  final worker = YoloService._worker(request);
  final threshold = request['threshold'] as double;
  if (request['bytes'] != null) {
    final decoded = img.decodeImage(request['bytes'] as Uint8List);
    if (decoded == null) {
      throw FormatException('Không đọc được ảnh. Hãy chọn JPG hoặc PNG.');
    }
    final photo = img.bakeOrientation(decoded);
    return worker._infer(
      worker._convertPhoto(photo),
      photo.width,
      photo.height,
      threshold: threshold,
    );
  }
  final frame = request['frame'] as CameraImage;
  final rotation = request['rotation'] as int;
  return worker._infer(
    worker._convertCameraImage(frame, rotation),
    frame.width,
    frame.height,
    threshold: threshold,
    rotation: rotation,
    mirror: request['mirror'] as bool,
    iou: request['iou'] as double,
  );
}
