# Nhận diện vật thể trong lớp học

Ứng dụng Flutter + YOLO + TensorFlow Lite, ưu tiên demo trên Android bằng camera sau, cầm dọc. Nhận diện chạy trên thiết bị, không gửi ảnh lên máy chủ.

## Bản demo hoàn chỉnh

Trang chủ có Camera trực tiếp, Nhận diện từ ảnh, Thử ngay với ảnh mẫu và Lịch sử nhận diện. Dùng ảnh mẫu để trình diễn trên Android ảo mà không phụ thuộc webcam: app chạy mô hình thật trên ảnh COCO có TV, bàn và ghế. Chọn ảnh từ thư viện để thử các vật thể khác. Kết quả có khung, nhãn tiếng Việt, độ tin cậy và thời gian xử lý; có thể điều chỉnh ngưỡng và lưu lịch sử.

Luồng ảnh lưu kết quả đúng ảnh đã phân tích. Luồng camera lưu ảnh chụp kèm kết quả khung preview gần nhất. Các ảnh mẫu được ghi nguồn trong `assets/demo/SOURCE.md`; chúng là dữ liệu demo/kiểm tra, không phải dữ liệu mới để huấn luyện.

## Chạy demo

```sh
flutter pub get
flutter run
# Đóng gói để cài Android
flutter build apk --debug
```

Chuẩn bị điện thoại thứ hai, laptop mở màn hình, chai nước, ghế, sách. Bật “Chỉ đồ dùng lớp học”, bắt đầu ở ngưỡng 35%. Đủ sáng, vật thể chiếm diện tích đáng kể, giữ máy ổn định. Tạm dừng để giải thích khung; tiếp tục trước khi lưu ảnh. Dùng nút thông tin ở trang chủ để giải thích YOLO và TensorFlow Lite.

Điểm tin cậy không phải độ chính xác của hệ thống. Thời gian hiển thị là tổng xử lý một khung, không phải FPS camera. Ảnh lịch sử lưu kết quả của khung preview gần nhất, có thể khác nhẹ thời điểm chụp; không phải lần nhận diện riêng trên ảnh chụp.

## Phạm vi thật của bản hiện tại

- Giữ nguyên mô hình COCO có sẵn: 80 lớp. Điện thoại, laptop, ghế, chai, TV, sách, ba lô, chuột và bàn phím có trong danh sách nhãn.
- Bàn hiện là `dining table`: không đảm bảo nhận đúng bàn học.
- **Chưa nhận diện riêng bảng hoặc máy chiếu. Chưa có ảnh lớp học mới và chưa huấn luyện model custom.**
- Không thêm nhãn vào `assets/models/labels.txt` khi chưa đổi mô hình tương ứng.
- Android là mục tiêu đóng gói. Camera/TFLite hiện không phải luồng chạy web; iOS cần build và kiểm tra trên Mac/thiết bị thật.

## Bổ sung dữ liệu lớp học

Đã chuẩn bị `training/classroom.yaml`, các thư mục dữ liệu rỗng và `training/train_classroom.py`. Đây là bộ khung, **không phải dataset đã thu thập**.

13 lớp: điện thoại, laptop, bàn học, ghế, chai, bảng trắng, bảng đen, máy chiếu, TV, sách, ba lô, chuột, bàn phím. ID và thứ tự nằm trong YAML. Đây là mô hình 13 lớp mới, không giữ toàn bộ 80 lớp COCO.

1. Chụp ảnh thực tế hoặc dùng ảnh được phép sử dụng. Điểm bắt đầu gợi ý: 100–300 ảnh đa dạng mỗi lớp, không phải bảo đảm chất lượng. Có nhiều góc, khoảng cách, ánh sáng, ảnh có nhiều đồ vật và ảnh nền không có vật thể. Tránh đưa thông tin cá nhân lên tập dữ liệu.
2. Gán hộp bằng công cụ hỗ trợ xuất YOLO detection. Máy chiếu là thân thiết bị; màn chiếu không phải máy chiếu. Bảng trắng/đen tách riêng, TV không gộp với bảng.
3. Chia khoảng 70/20/10 theo buổi chụp/phòng/thiết bị, tránh chia ngẫu nhiên những khung liền nhau của một video. File nhãn cùng tên ảnh, mỗi dòng `class_id x_center y_center width height`, tọa độ chuẩn hóa 0–1. Ảnh nền dùng file nhãn rỗng.
4. Đặt ảnh vào `training/datasets/classroom/images/{train,val,test}` và nhãn vào `labels/{train,val,test}`. Mỗi tập phải có đủ lớp.
5. Dùng môi trường Python 3.11/3.12 riêng (hoặc Colab có GPU), cài `ultralytics`. Chạy từ thư mục dự án:

```sh
python training/train_classroom.py --check-only
python training/train_classroom.py --epochs 80 --device 0
# Máy không có GPU NVIDIA: --device cpu (chậm hơn)
```

Script kiểm tra thiếu ảnh/nhãn, giới hạn hộp, ảnh trùng giữa các tập và độ phủ lớp trước khi train. Kiểm tra thêm thủ công ảnh gần trùng và chất lượng nhãn. Xem precision/recall, mAP và nhầm lẫn từng lớp trên test; không chỉ nhìn loss. Export TFLite có thể yêu cầu các dependency TensorFlow theo môi trường Ultralytics; ưu tiên Colab/Linux nếu Windows export lỗi.

6. Sau khi đánh giá, sao lưu 3 file trong `assets/models`. Thay `best.tflite` bằng bản **float32** được export, `labels.txt` và `config.json` bằng cặp tương ứng trong `training/export`. Chạy lại kiểm tra và thử trên điện thoại. Cập nhật nội dung phạm vi mô hình trong hộp thông tin khi thực sự nghiệm thu model mới.

## Hợp đồng mô hình và kiểm tra

Mô hình kèm dự án có input Float32 `[1,3,640,640]`, output `[1,84,8400]`. App hỗ trợ input RGB NCHW/NHWC Float32, batch 1; output `[1,4+C,N]`, không NMS tích hợp. Số lớp phải khớp file nhãn. `config.json` chỉ rõ tọa độ pixel hay normalized, không suy đoán từ layout tensor. Mô hình kèm app trả xywh normalized (đã kiểm tra đầu ra trên Android); bản mã ban đầu nhầm thành pixel, làm hộp gần như bằng không. Cấu hình đã sửa thành normalized.

Pipeline: xoay ảnh về hướng dọc → resize giữ tỷ lệ và đệm 114 → RGB/255 → suy luận → lọc tin cậy → bỏ padding → NMS theo lớp → vẽ trên đúng vùng preview. Camera trước được phản chiếu khi vẽ. Tiền xử lý và suy luận chạy trong isolate riêng để không chặn giao diện. Camera chỉ xử lý một khung tại một thời điểm; tốc độ phụ thuộc thiết bị.

```sh
flutter analyze
flutter test
```

Checklist nghiệm thu trên điện thoại: quyền camera (cho phép/từ chối), khung bám đúng bốn cạnh đồ vật, camera trước/sau, tạm dừng/tiếp tục, chuyển app rồi quay lại, chụp/lịch sử, nhiều đồ vật, ánh sáng kém. Chưa được xem kiểm tra tự động là bằng chứng chất lượng nhận diện ngoài đời.

Tài liệu: [COCO](https://docs.ultralytics.com/datasets/detect/coco/), [YOLO dataset](https://docs.ultralytics.com/datasets/detect/), [export TFLite](https://docs.ultralytics.com/modes/export/).


## Kiểm tra mô hình thật trên Android

```sh
flutter test integration_test/model_test.dart -d emulator-5554
```

Bài kiểm tra nạp đúng `best.tflite` của app, chạy suy luận từ pixel của ảnh đường phố/nội thất và yêu cầu tìm thấy người, xe buýt, TV, ghế với khung hợp lệ. Đây là kiểm tra chức năng trên ảnh mẫu, không thay cho đánh giá độ chính xác trên tập test độc lập. Sau bài kiểm tra tích hợp, chạy `flutter run -d emulator-5554` để trở lại bản app thông thường.


### Kết quả kiểm tra ngày 07/10/2026

- `flutter analyze`: không có vấn đề.
- `flutter test`: 5 bài kiểm tra đạt.
- Kiểm tra tích hợp trên Pixel 10 Pro Android ảo: đạt; ảnh đường phố có người 88,3% và xe buýt 85,5%; ảnh nội thất có TV 92,3% và ghế 85,2% (điểm của lần chạy trên ảnh gốc, không phải accuracy tổng quát).
- Đã sửa lỗi quan trọng: tọa độ đầu ra model là normalized, không phải pixel, dù input có layout NCHW.

Máy ảo Pixel đang dùng Android với trang bộ nhớ 16 KB. Thư viện TFLite kèm bản demo chạy qua chế độ tương thích của Android; nếu hiện thông báo tương thích lần đầu, bấm OK. Chưa xác nhận khả năng phát hành Play Store/16 KB native. Tham khảo https://developer.android.com/guide/practices/page-sizes.

### Kết quả kiểm tra ngày 08/10/2026

- Môi trường: Flutter 3.47.4, Dart 3.13.3, Windows; Android toolchain được `flutter doctor -v` xác nhận sẵn sàng.
- `flutter analyze`: không có vấn đề.
- `flutter test`: 5 bài kiểm tra đạt.
- `flutter build apk --debug`: thành công, tạo `build/app/outputs/flutter-apk/app-debug.apk`.
- Không chạy lại kiểm tra tích hợp/camera trong lần này vì chưa có thiết bị Android kết nối.
- Build có cảnh báo plugin camera còn dùng Kotlin Gradle Plugin; cần rà soát tương thích khi nâng Flutter trong tương lai.
