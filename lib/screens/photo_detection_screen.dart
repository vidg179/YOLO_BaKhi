import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/classroom_catalog.dart';
import '../models/detection_result.dart';
import '../services/yolo_service.dart';
import '../services/history_service.dart';
import '../widgets/detection_overlay.dart';

class PhotoDetectionScreen extends StatefulWidget {
  const PhotoDetectionScreen({super.key, this.demo = false});
  final bool demo;
  @override
  State<PhotoDetectionScreen> createState() => _PhotoDetectionScreenState();
}

class _PhotoDetectionScreenState extends State<PhotoDetectionScreen> {
  final _yolo = YoloService();
  Uint8List? _bytes;
  List<Recognition> _results = [];
  bool _busy = true;
  String? _error;
  double _ratio = 1, _threshold = .35;
  int _elapsed = 0;
  String _source = 'Ảnh của bạn';
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _yolo.loadModel();
      if (!mounted) return;
      if (widget.demo) {
        await _sample();
      } else {
        setState(() => _busy = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Không nạp được mô hình: $e';
          _busy = false;
        });
      }
    }
  }

  Future<void> _sample() async {
    try {
      final data = await rootBundle.load('assets/demo/room.jpg');
      if (mounted) {
        await _setImage(data.buffer.asUint8List(), 'Ảnh mẫu • TV, bàn và ghế');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  Future<void> _choose() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (file != null && mounted) {
        await _setImage(await file.readAsBytes(), 'Ảnh từ thư viện');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Không mở được ảnh: $e');
    }
  }

  Future<void> _setImage(Uint8List data, String source) async {
    setState(() {
      _busy = true;
      _error = null;
      _results = [];
    });
    try {
      final normalized = await compute(_normalizePhoto, data);
      if (!mounted) return;
      _bytes = normalized['bytes'] as Uint8List;
      _ratio = normalized['ratio'] as double;
      _source = source;
      await _detect();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  Future<void> _detect() async {
    if (_bytes == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final watch = Stopwatch()..start();
    try {
      final results = await _yolo.detectImage(
        _bytes!,
        confidenceThreshold: _threshold,
      );
      if (mounted) {
        setState(() {
          _results = results;
          _elapsed = watch.elapsedMilliseconds;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Nhận diện thất bại: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    File? temporary;
    try {
      final dir = await getTemporaryDirectory();
      temporary = File(
        '${dir.path}/photo_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await temporary.writeAsBytes(_bytes!);
      final item = await HistoryService().saveDetection(
        photoFile: XFile(temporary.path),
        detections: List.of(_results),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              item == null
                  ? 'Không lưu được kết quả.'
                  : 'Đã lưu ảnh và kết quả nhận diện.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Không lưu được ảnh: $e');
    } finally {
      if (temporary != null && await temporary.exists()) {
        await temporary.delete();
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _yolo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nhận diện từ ảnh')),
    body: ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _choose,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Chọn ảnh'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : _sample,
                child: const Text('Dùng ảnh mẫu'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          ),
        if (_bytes != null) ...[
          const SizedBox(height: 12),
          Text(_source, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: _ratio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    _bytes!,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  ),
                  DetectionOverlay(
                    recognitions: _results,
                    previewSize: Size(_ratio, 1),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _busy
                ? 'YOLO đang phân tích ảnh…'
                : '${_results.length} vật thể • $_elapsed ms',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Row(
            children: [
              const Text('Ngưỡng tin cậy'),
              Expanded(
                child: Slider(
                  value: _threshold,
                  min: .15,
                  max: .85,
                  divisions: 14,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _threshold = v),
                  onChangeEnd: (_) => _detect(),
                ),
              ),
              Text('${(_threshold * 100).round()}%'),
            ],
          ),
          if (!_busy && _results.isEmpty && _error == null)
            const Text(
              'Chưa tìm thấy vật thể ở ngưỡng này. Thử ảnh rõ hơn hoặc giảm ngưỡng.',
            ),
          for (final r in _results)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.check_circle_outline,
                color: Colors.cyanAccent,
              ),
              title: Text(displayLabel(r.label)),
              trailing: Text(r.scorePercentage),
            ),
          OutlinedButton.icon(
            onPressed: _busy || _error != null ? null : _save,
            icon: const Icon(Icons.save_alt),
            label: const Text('Lưu kết quả'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Khung và điểm tin cậy được tính từ mô hình trên thiết bị mỗi lần phân tích.',
            style: TextStyle(color: Colors.white60),
          ),
        ] else if (!_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: Column(
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 72,
                  color: Colors.cyan,
                ),
                SizedBox(height: 16),
                Text(
                  'Chọn ảnh đồ vật hoặc dùng ảnh mẫu để bắt đầu.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

Map<String, dynamic> _normalizePhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Ảnh không hỗ trợ. Hãy chọn JPG/PNG.');
  }
  var photo = img.bakeOrientation(decoded);
  if (photo.width > 1920 || photo.height > 1920) {
    photo = img.copyResize(
      photo,
      width: photo.width >= photo.height ? 1920 : null,
      height: photo.height > photo.width ? 1920 : null,
    );
  }
  return {
    'bytes': Uint8List.fromList(img.encodeJpg(photo, quality: 92)),
    'ratio': photo.width / photo.height,
  };
}
