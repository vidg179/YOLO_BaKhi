import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/classroom_catalog.dart';
import '../models/detection_result.dart';
import '../services/camera_service.dart';
import '../services/history_service.dart';
import '../services/yolo_service.dart';
import '../widgets/detection_overlay.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});
  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen>
    with WidgetsBindingObserver {
  final _camera = CameraService();
  final _yolo = YoloService();
  final _history = HistoryService();
  bool _loading = true, _running = true, _busy = false;
  bool _classroomOnly = false, _closed = false;
  double _threshold = .35;
  int _latency = 0;
  String? _error;
  List<Recognition> _results = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  Future<void> _setup() async {
    if (_closed) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_yolo.isInitialized) await _yolo.loadModel();
      if (_closed) return;
      await _camera.initialize(resolution: ResolutionPreset.medium);
      if (_closed) {
        await _camera.dispose();
        return;
      }
      if (_running) await _stream();
    } catch (e) {
      if (mounted) {
        _error =
            'Không thể mở camera hoặc mô hình. Kiểm tra quyền camera và thử lại.\n$e';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _stream() async {
    await _camera.startImageStream((image, rotation) async {
      if (!_running || _closed || _busy) return;
      final watch = Stopwatch()..start();
      try {
        final result = await _yolo.detectFrame(
          image,
          confidenceThreshold: _threshold,
          sensorOrientation: rotation,
          mirror:
              _camera.currentCamera?.lensDirection == CameraLensDirection.front,
        );
        if (mounted && _running && !_busy) {
          setState(() {
            _results = result
                .where(
                  (r) =>
                      !_classroomOnly || classroomLabels.containsKey(r.label),
                )
                .toList();
            _latency = watch.elapsedMilliseconds;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = 'Nhận diện gặp lỗi: $e';
            _running = false;
          });
        }
      }
    });
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _running = !_running;
    });
    try {
      if (_running) {
        await _camera.controller?.resumePreview();
        await _stream();
      } else {
        await _camera.stopImageStream();
        await _camera.controller?.pausePreview();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Không thể đổi trạng thái camera: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switch() async {
    if (_busy) return;
    if (_camera.cameraCount < 2) {
      _message('Thiết bị chỉ có một camera.');
      return;
    }
    setState(() {
      _busy = true;
      _results = [];
    });
    try {
      await _camera.switchCamera();
      if (_running && !_closed) await _stream();
    } catch (e) {
      if (mounted) setState(() => _error = 'Không thể đổi camera: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _capture() async {
    if (_busy || !_running) return;
    setState(() => _busy = true);
    // Metadata belongs to the last processed preview frame, not a second inference.
    final snapshot = List<Recognition>.of(_results);
    try {
      final photo = await _camera.takePicture();
      if (photo == null) throw StateError('Camera chưa sẵn sàng.');
      final saved = await _history.saveDetection(
        photoFile: photo,
        detections: snapshot,
      );
      _message(
        saved == null
            ? 'Không lưu được ảnh. Vui lòng thử lại.'
            : 'Đã lưu ảnh và ${snapshot.length} kết quả từ khung hình gần nhất.',
      );
    } catch (e) {
      _message('Chụp ảnh thất bại: $e');
    } finally {
      try {
        if (_running && !_closed) await _stream();
      } catch (e) {
        if (mounted) setState(() => _error = 'Không thể tiếp tục camera: $e');
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive && !_loading) {
      _running = false;
      _camera.stopImageStream();
      if (mounted) setState(() => _results = []);
    } else if (state == AppLifecycleState.resumed && !_loading && !_busy) {
      _setup();
    }
  }

  @override
  void dispose() {
    _closed = true;
    WidgetsBinding.instance.removeObserver(this);
    _camera.dispose();
    _yolo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final r in _results) {
      counts.update(displayLabel(r.label), (n) => n + 1, ifAbsent: () => 1);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Camera trực tiếp')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () {
                                  _running = true;
                                  _setup();
                                },
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : _camera.isInitialized
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: 1 / _camera.controller!.value.aspectRatio,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(_camera.controller!),
                            DetectionOverlay(
                              recognitions: _results,
                              previewSize:
                                  _camera.controller!.value.previewSize ??
                                  const Size(640, 480),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                color: Colors.black.withValues(alpha: .7),
                                child: Text(
                                  _running
                                      ? '${_results.length} vật thể • $_latency ms/khung'
                                      : 'Tạm dừng • kết quả khung hình trước',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const Center(child: Text('Camera chưa sẵn sàng.')),
            ),
            if (!_loading && _error == null) ...[
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    if (counts.isEmpty)
                      const Center(
                        child: Text(
                          'Đưa vật thể vào khung hình, giữ máy ổn định.',
                        ),
                      ),
                    for (final entry in counts.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text('${entry.key}: ${entry.value}'),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  const SizedBox(width: 16),
                  const Text('Chỉ đồ dùng lớp học'),
                  Switch(
                    value: _classroomOnly,
                    onChanged: (v) => setState(() {
                      _classroomOnly = v;
                      _results = [];
                    }),
                  ),
                  const Spacer(),
                  Text('${(_threshold * 100).round()}%'),
                  const SizedBox(width: 16),
                ],
              ),
              Semantics(
                label: 'Ngưỡng tin cậy',
                child: Slider(
                  value: _threshold,
                  min: .15,
                  max: .85,
                  divisions: 14,
                  label: 'Ngưỡng tin cậy ${(_threshold * 100).round()}%',
                  onChanged: (v) => setState(() {
                    _threshold = v;
                    _results = [];
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: _busy ? null : _toggle,
                      icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                      tooltip: _running
                          ? 'Tạm dừng để thuyết trình'
                          : 'Tiếp tục',
                    ),
                    FilledButton.icon(
                      onPressed: _busy || !_running ? null : _capture,
                      icon: const Icon(Icons.camera_alt),
                      label: Text(_busy ? 'Đang xử lý…' : 'Lưu kết quả'),
                    ),
                    IconButton(
                      onPressed: _busy ? null : _switch,
                      icon: const Icon(Icons.cameraswitch),
                      tooltip: 'Đổi camera',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
