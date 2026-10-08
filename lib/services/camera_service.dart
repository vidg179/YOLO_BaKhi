import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isProcessingFrame = false;
  DateTime _lastFrameTime = DateTime.now();

  // Target frame throttle interval (e.g. 120ms = ~8 FPS)
  static const int minFrameIntervalMs = 120;

  CameraController? get controller => _controller;
  bool get isInitialized =>
      _controller != null && _controller!.value.isInitialized;
  int get cameraCount => _cameras.length;
  CameraDescription? get currentCamera =>
      _cameras.isNotEmpty ? _cameras[_selectedCameraIndex] : null;

  /// Fetch cameras and initialize primary camera
  Future<void> initialize({
    ResolutionPreset resolution = ResolutionPreset.medium,
  }) async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        throw CameraException(
          'NoCamerasAvailable',
          'No camera detected on this device.',
        );
      }

      // Default to rear back camera if available
      _selectedCameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_selectedCameraIndex < 0) _selectedCameraIndex = 0;

      await _initController(_cameras[_selectedCameraIndex], resolution);
    } catch (e) {
      debugPrint('Error initializing camera service: $e');
      rethrow;
    }
  }

  /// Initialize controller for a specific camera description
  Future<void> _initController(
    CameraDescription camera,
    ResolutionPreset resolution,
  ) async {
    await _controller?.dispose();

    _controller = CameraController(
      camera,
      resolution,
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
    await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
  }

  /// Toggle between front and back cameras if available
  Future<bool> switchCamera() async {
    if (_cameras.length < 2 || _controller == null) return false;

    // Stop current stream if running
    if (_controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initController(
      _cameras[_selectedCameraIndex],
      _controller!.resolutionPreset,
    );

    return true;
  }

  /// Start camera frame stream with frame rate throttling
  Future<void> startImageStream(
    Function(CameraImage image, int sensorOrientation) onFrameAvailable,
  ) async {
    if (!isInitialized || _controller == null) return;
    if (_controller!.value.isStreamingImages) return;

    final sensorOrientation = currentCamera?.sensorOrientation ?? 90;

    await _controller!.startImageStream((CameraImage image) async {
      final now = DateTime.now();
      if (_isProcessingFrame) return;

      if (now.difference(_lastFrameTime).inMilliseconds < minFrameIntervalMs) {
        return; // Skip frame to maintain throttled target FPS
      }

      _isProcessingFrame = true;
      _lastFrameTime = now;

      try {
        await onFrameAvailable(image, sensorOrientation);
      } catch (e) {
        debugPrint('Error handling streamed frame: $e');
      } finally {
        _isProcessingFrame = false;
      }
    });
  }

  /// Stop image stream
  Future<void> stopImageStream() async {
    if (isInitialized && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
  }

  /// Take a picture snapshot and return the XFile
  Future<XFile?> takePicture() async {
    if (!isInitialized || _controller == null) return null;
    try {
      if (_controller!.value.isStreamingImages) {
        await stopImageStream();
      }
      final file = await _controller!.takePicture();
      return file;
    } catch (e) {
      debugPrint('Error taking picture: $e');
      rethrow;
    }
  }

  /// Dispose camera controller
  Future<void> dispose() async {
    await stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }
}
