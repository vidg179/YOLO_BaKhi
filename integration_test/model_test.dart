import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nhan_dien_vat_the/services/yolo_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Bundled model really detects people and bus from sample pixels', (
    tester,
  ) async {
    final yolo = YoloService();
    await yolo.loadModel();
    final sample = await rootBundle.load('assets/demo/street.jpg');
    final results = await yolo.detectImage(sample.buffer.asUint8List());
    // ignore: avoid_print
    print(
      'REAL_MODEL_RESULTS: ${results.map((r) => '${r.label} ${r.scorePercentage} ${r.location}').join('; ')}',
    );
    expect(results.any((r) => r.label == 'person'), isTrue);
    expect(results.any((r) => r.label == 'bus'), isTrue);
    expect(
      results.every((r) => r.location.width > .02 && r.location.height > .02),
      isTrue,
    );
    final room = await rootBundle.load('assets/demo/room.jpg');
    final roomResults = await yolo.detectImage(room.buffer.asUint8List());
    // ignore: avoid_print
    print(
      'ROOM_RESULTS: ${roomResults.map((r) => '${r.label} ${r.scorePercentage} ${r.location}').join('; ')}',
    );
    expect(roomResults.any((r) => r.label == 'tv'), isTrue);
    expect(roomResults.any((r) => r.label == 'chair'), isTrue);
    await yolo.dispose();
  });
}
