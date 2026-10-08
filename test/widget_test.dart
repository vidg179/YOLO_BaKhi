import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhan_dien_vat_the/main.dart';

void main() {
  testWidgets('Demo actions remain accessible on small phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ObjectDetectionApp());
    expect(find.text('Nhận diện vật thể'), findsOneWidget);
    expect(find.text('Camera trực tiếp'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Thử ngay với ảnh mẫu'), 180);
    expect(find.text('Thử ngay với ảnh mẫu'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Thông tin đề tài'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('chưa hỗ trợ riêng bảng và máy chiếu'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
