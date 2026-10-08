import 'package:flutter/material.dart';

import 'detection_screen.dart';
import 'history_screen.dart';
import 'photo_detection_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  void _open(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Nhận diện vật thể'),
      actions: [
        IconButton(
          tooltip: 'Thông tin đề tài',
          onPressed: () => showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('YOLO × TensorFlow Lite'),
              content: const SingleChildScrollView(
                child: Text(
                  'YOLO phát hiện vị trí và loại vật thể. TensorFlow Lite chạy mô hình ngay trên thiết bị.\n\nPipeline: ảnh → chuẩn hóa → YOLO → lọc độ tin cậy và khung trùng → hiển thị kết quả.\n\nMô hình hiện tại có 80 lớp COCO, gồm người, điện thoại, laptop, ghế, chai, TV, sách… Bàn là lớp bàn ăn; chưa hỗ trợ riêng bảng và máy chiếu.\n\nĐiểm tin cậy là điểm dự đoán, không phải độ chính xác đã đo. Ảnh mẫu nội thất từ COCO val2017 (000000000139.jpg).',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          ),
          icon: const Icon(Icons.info_outline),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 12),
        const Icon(
          Icons.center_focus_strong,
          size: 72,
          color: Colors.cyanAccent,
        ),
        const SizedBox(height: 24),
        Text(
          'Đưa đồ vật vào khung.\nXem AI nhận diện.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'YOLO • TensorFlow Lite • 80 loại vật thể',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 32),
        _action(
          context,
          Icons.videocam_outlined,
          'Camera trực tiếp',
          'Nhận diện đồ vật qua camera',
          () => _open(context, const DetectionScreen()),
          primary: true,
        ),
        _action(
          context,
          Icons.photo_library_outlined,
          'Nhận diện từ ảnh',
          'Chọn ảnh có sẵn trong thư viện',
          () => _open(context, const PhotoDetectionScreen()),
        ),
        _action(
          context,
          Icons.play_circle_outline,
          'Thử ngay với ảnh mẫu',
          'Chạy mô hình thật • không cần camera',
          () => _open(context, const PhotoDetectionScreen(demo: true)),
        ),
        _action(
          context,
          Icons.history,
          'Lịch sử nhận diện',
          'Xem lại ảnh và kết quả đã lưu',
          () => _open(context, const HistoryScreen()),
        ),
        const SizedBox(height: 20),
        const Text(
          'Dễ thử với: điện thoại, laptop, chai nước, ghế, sách, chuột và bàn phím.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, height: 1.5),
        ),
      ],
    ),
  );
  Widget _action(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback action, {
    bool primary = false,
  }) => Card(
    color: primary ? Colors.cyan.withValues(alpha: .16) : null,
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: Icon(icon, color: Colors.cyanAccent, size: 30),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: action,
    ),
  );
}
