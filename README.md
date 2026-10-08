# Yolo/tensorflow detect object

Ứng dụng di động sử dụng **Flutter, YOLO và TensorFlow Lite** để nhận diện vật thể qua camera hoặc ảnh có sẵn. Kết quả gồm khung bao, tên vật thể bằng tiếng Việt và điểm tin cậy. Mô hình chạy trực tiếp trên thiết bị, không cần máy chủ nhận diện.

> Nền tảng hướng dẫn và đóng gói: **Android 7.0 (API 24) trở lên**. Mô hình và ảnh mẫu đã có trong kho mã nguồn; không cần huấn luyện lại để chạy ứng dụng.

## Mục lục

- [1. Chức năng](#1-chức-năng)
- [2. Chuẩn bị môi trường](#2-chuẩn-bị-môi-trường)
- [3. Cài đặt và chạy từ mã nguồn](#3-cài-đặt-và-chạy-từ-mã-nguồn)
- [4. Tạo và cài file APK](#4-tạo-và-cài-file-apk)
- [5. Hướng dẫn sử dụng](#5-hướng-dẫn-sử-dụng)
- [6. Kịch bản trình diễn](#6-kịch-bản-trình-diễn)
- [7. Xử lý lỗi thường gặp](#7-xử-lý-lỗi-thường-gặp)
- [8. Cấu trúc dự án](#8-cấu-trúc-dự-án)
- [9. Kiểm tra và giới hạn](#9-kiểm-tra-và-giới-hạn)

## 1. Chức năng

| Chức năng | Mô tả |
| --- | --- |
| Camera trực tiếp | Phân tích các khung hình, hiển thị khung và nhãn; hỗ trợ đổi camera, tạm dừng và tiếp tục. |
| Nhận diện từ ảnh | Chọn ảnh trong thư viện và chạy nhận diện trên ảnh đó. |
| Ảnh mẫu | Chạy mô hình thật trên ảnh nội thất có sẵn, thuận tiện khi dùng máy ảo. |
| Điều chỉnh ngưỡng | Chọn ngưỡng tin cậy từ 15% đến 85%; mặc định 35%. |
| Lọc đồ dùng lớp học | Bộ lọc trên màn hình camera để tập trung vào các nhãn đồ dùng. |
| Lịch sử | Lưu ảnh và kết quả, xem lại hoặc xóa dữ liệu đã lưu. |

Mô hình hiện tại nhận diện **80 lớp COCO**, trong đó có điện thoại, laptop, ghế, chai, TV, sách, ba lô, chuột và bàn phím. Lớp bàn hiện là `dining table` (bàn ăn), chưa phải mô hình chuyên biệt cho bàn học. **Chưa nhận diện riêng bảng trắng, bảng đen hoặc máy chiếu.**

## 2. Chuẩn bị môi trường

Phần này dành cho người chạy hoặc đóng gói từ mã nguồn. Người chỉ cài APK có thể đọc mục 4 và 5.

| Thành phần | Yêu cầu / cấu hình đã dùng |
| --- | --- |
| Flutter SDK | Môi trường kiểm tra: Flutter **3.47.4**, kèm Dart **3.13.3**. `pubspec.yaml` yêu cầu Dart `^3.13.3`. |
| Android Studio | Cài Android SDK (gồm Platform 36 cho các thư viện Android), SDK Platform-Tools, Command-line Tools và Android Emulator nếu dùng máy ảo. SDK của ứng dụng chính theo bản Flutter đang dùng. |
| Java | Dùng JDK đi kèm Android Studio và kiểm tra bằng `flutter doctor -v`. Môi trường hiện tại dùng JDK 25; mã Android đặt mức tương thích Java 17. |
| Git | Dùng để tải mã nguồn. Có thể thay bằng **Code → Download ZIP** trên GitHub. |
| Thiết bị | Điện thoại Android API 24 trở lên hoặc máy ảo Android; điện thoại thật phù hợp hơn để thử camera. |
| Internet | Cần khi tải công cụ, thư viện và build lần đầu; nhận diện bằng mô hình đã đóng gói hoạt động trên thiết bị. |

Sau khi cài Flutter và thêm thư mục `flutter/bin` vào PATH, mở terminal mới và chạy:

```sh
flutter --version
flutter doctor -v
flutter doctor --android-licenses
```

Chấp nhận các giấy phép Android khi được hỏi. Khắc phục các lỗi ở mục **Android toolchain** trước khi tiếp tục. Không cần cài Python, CUDA hay máy chủ để sử dụng ứng dụng hiện tại.

## 3. Cài đặt và chạy từ mã nguồn

### Bước 1 — Tải dự án

```sh
git clone https://github.com/vidg179/YOLO_BaKhi.git
cd YOLO_BaKhi
flutter pub get
```

Nếu tải ZIP, giải nén rồi mở terminal tại thư mục có `pubspec.yaml`.

Các tài nguyên cần có đã được đưa vào repository:

```text
assets/models/best.tflite
assets/models/labels.txt
assets/models/config.json
assets/demo/room.jpg
assets/demo/street.jpg
```

### Bước 2 — Kết nối thiết bị Android

**Điện thoại thật:** bật Tùy chọn nhà phát triển → Gỡ lỗi USB (USB debugging), kết nối bằng cáp truyền dữ liệu và chấp nhận thông báo cho phép gỡ lỗi trên điện thoại.

**Máy ảo:** mở Android Studio → Device Manager, tạo thiết bị Android có API từ 24 trở lên và khởi động thiết bị. Dùng chức năng ảnh mẫu nếu camera máy ảo không phù hợp.

Liệt kê thiết bị:

```sh
flutter devices
```

### Bước 3 — Chạy ứng dụng

Nếu chỉ có một thiết bị Android phù hợp:

```sh
flutter run
```

Nếu có nhiều thiết bị, thay `ANDROID_DEVICE_ID` bằng ID Android từ lệnh trên:

```sh
flutter run -d ANDROID_DEVICE_ID
```

Chọn thiết bị **Android**. Dự án chưa cung cấp luồng nhận diện chạy trên Chrome hoặc Windows desktop. Lần build đầu có thể lâu vì phải tải thư viện. Khi mở camera lần đầu, chọn **Cho phép** quyền camera.

## 4. Tạo và cài file APK

### Tạo bản APK để trình diễn

Tại thư mục dự án, chạy:

```sh
flutter build apk --debug
```

APK được tạo tại:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Đây là bản phục vụ chạy thử/nộp demo. Thư mục `build/` được bỏ qua khi đưa mã nguồn lên Git; **APK không được đính kèm sẵn trong repository**.

### Cài lên điện thoại

1. Chép `app-debug.apk` vào điện thoại qua USB hoặc phương thức chuyển file của bạn.
2. Mở APK trong ứng dụng quản lý tệp.
3. Nếu Android yêu cầu, cho phép ứng dụng quản lý tệp đó **cài ứng dụng không rõ nguồn gốc**, rồi quay lại chọn **Cài đặt**.
4. Mở ứng dụng **Nhận diện lớp học** và thử chức năng ảnh mẫu.

Nếu máy tính đã có `adb` trong PATH và điện thoại đã bật gỡ lỗi USB, có thể cài bằng:

```sh
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Cấu hình `release` hiện cũng dùng khóa ký debug; cần cấu hình ký phát hành riêng nếu sau này phân phối chính thức.

## 5. Hướng dẫn sử dụng

### 5.1. Thử nhanh bằng ảnh mẫu

1. Mở ứng dụng, chọn **Thử ngay với ảnh mẫu** ở trang chủ.
2. Chờ mô hình phân tích ảnh nội thất có sẵn.
3. Quan sát khung nhận diện, tên vật thể, điểm tin cậy, số vật thể và thời gian xử lý.
4. Kéo **Ngưỡng tin cậy** để lọc kết quả; ứng dụng phân tích lại khi thả thanh trượt.
5. Chọn **Lưu kết quả** và đợi thông báo lưu thành công.
6. Quay lại trang chủ → **Lịch sử nhận diện** để xem mục vừa lưu.

### 5.2. Nhận diện qua camera

1. Chọn **Camera trực tiếp** và cho phép truy cập camera.
2. Cầm điện thoại dọc, hướng camera vào vật thể đủ sáng, giữ máy ổn định.
3. Bắt đầu với ngưỡng **35%**. Giảm ngưỡng nếu bỏ sót vật thể; tăng ngưỡng nếu xuất hiện nhiều nhận diện sai.
4. Bật **Chỉ đồ dùng lớp học** để lọc các nhãn phù hợp; tắt để xem các lớp khác mà mô hình hỗ trợ.
5. Dùng nút tạm dừng để giữ kết quả khi giải thích, rồi nhấn tiếp tục để nhận diện trở lại.
6. Dùng nút **Đổi camera** nếu thiết bị có nhiều camera.
7. Khi nhận diện đang chạy, chọn **Lưu kết quả** để lưu ảnh chụp và kết quả vào lịch sử.

**Lưu ý:** kết quả lưu từ camera là kết quả của khung xem trước gần nhất, có thể lệch nhẹ so với thời điểm chụp. Để phân tích đúng một ảnh tĩnh, dùng chức năng **Nhận diện từ ảnh**.

### 5.3. Nhận diện ảnh trong thư viện

1. Chọn **Nhận diện từ ảnh** → **Chọn ảnh**.
2. Chọn ảnh JPG/PNG rõ nét trong thư viện.
3. Đợi phân tích, xem danh sách vật thể và khung trên ảnh.
4. Điều chỉnh **Ngưỡng tin cậy** nếu cần.
5. Chọn **Lưu kết quả** để lưu ảnh đã phân tích cùng kết quả.

Nút **Dùng ảnh mẫu** trong màn hình này cho phép chuyển sang ảnh có sẵn.

### 5.4. Xem và xóa lịch sử

- Tại trang chủ, chọn **Lịch sử nhận diện**. Các mục mới nhất nằm trước.
- Chạm một mục để xem ảnh, thời điểm lưu và danh sách vật thể cùng điểm tin cậy.
- Dùng nút xóa của từng mục để xóa mục đó.
- Dùng nút **Xóa tất cả**, rồi xác nhận trong hộp thoại để xóa toàn bộ lịch sử và ảnh đã lưu.

Ảnh và lịch sử được lưu trong vùng dữ liệu của ứng dụng trên thiết bị, không tự xuất ra thư viện ảnh. Xóa dữ liệu ứng dụng hoặc gỡ ứng dụng sẽ làm mất lịch sử cục bộ.

### 5.5. Đọc kết quả đúng cách

- **Khung bao:** vị trí vật thể do mô hình dự đoán.
- **Tên và phần trăm:** nhãn vật thể và điểm tin cậy của lần dự đoán, không phải độ chính xác tổng thể của phần mềm.
- **ms / ms mỗi khung:** thời gian xử lý, không phải tốc độ khung hình camera.
- **Không thấy vật thể:** thử tăng ánh sáng, đưa vật thể gần hơn, dùng ảnh rõ hơn hoặc giảm ngưỡng. Vật thể ngoài 80 lớp có thể không được nhận diện.

Nút thông tin ở góc trên trang chủ giải thích ngắn gọn YOLO, TensorFlow Lite và phạm vi mô hình.

## 6. Kịch bản trình diễn

1. Giới thiệu: Flutter cung cấp giao diện; YOLO phát hiện vật thể; TensorFlow Lite chạy mô hình trên thiết bị.
2. Chạy **Thử ngay với ảnh mẫu**, giải thích khung bao và điểm tin cậy.
3. Thay đổi ngưỡng để minh họa tác động đến số kết quả.
4. Lưu kết quả rồi mở lịch sử để kiểm tra.
5. Mở camera, thử lần lượt chai nước, điện thoại thứ hai, laptop, ghế hoặc sách.
6. Trình bày giới hạn: mô hình COCO có sẵn, chưa huấn luyện riêng cho bảng hoặc máy chiếu.

## 7. Xử lý lỗi thường gặp

| Hiện tượng | Cách xử lý |
| --- | --- |
| Không nhận lệnh `flutter` | Kiểm tra PATH có `flutter/bin`, mở terminal mới và chạy `flutter --version`. |
| Báo Dart SDK không phù hợp | Dùng Flutter có Dart đáp ứng `^3.13.3`; đối chiếu bản đã dùng trong mục 2. |
| Thiếu Android SDK / giấy phép | Kiểm tra SDK Manager trong Android Studio, chạy `flutter doctor -v` và `flutter doctor --android-licenses`. |
| Không thấy điện thoại | Kiểm tra cáp dữ liệu, gỡ lỗi USB, thông báo cấp quyền và driver USB trên Windows; chạy lại `flutter devices`. |
| Lỗi tải thư viện / Gradle | Kiểm tra kết nối mạng và lỗi cụ thể trong terminal. Sau khi sửa môi trường, chạy `flutter clean`, `flutter pub get` rồi build lại. |
| Camera không mở | Vào Cài đặt Android → Ứng dụng → Nhận diện lớp học → Quyền → cho phép Camera, sau đó mở lại màn hình camera. |
| Camera máy ảo không có ảnh hữu ích | Dùng **Thử ngay với ảnh mẫu** hoặc chuyển sang điện thoại thật. |
| Không nạp được mô hình | Kiểm tra đủ ba file trong `assets/models/` và khai báo assets trong `pubspec.yaml`; chạy `flutter pub get` và build lại. |
| Ảnh không hỗ trợ | Chọn ảnh JPG hoặc PNG. |
| Không thấy kết quả / nhận sai | Kiểm tra vật thể thuộc lớp được hỗ trợ, ánh sáng, góc chụp, ngưỡng và công tắc lọc đồ dùng. |
| Không cài được APK do chữ ký khác | Dùng APK có cùng khóa ký với bản đang cài; nếu phải gỡ bản cũ trước, lưu ý lịch sử cục bộ sẽ mất. |
| Thiết bị báo tương thích trang bộ nhớ 16 KB | Thư viện TFLite của bản demo có thể cần chế độ tương thích; bản hiện tại chưa được xác nhận đáp ứng phát hành native 16 KB. |

## 8. Cấu trúc dự án

```text
lib/
  main.dart                       Điểm khởi động ứng dụng
  screens/                        Trang chủ, camera, ảnh và lịch sử
  services/                       Camera, suy luận YOLO, giải mã và lưu lịch sử
  models/                         Kết quả nhận diện và tên đồ dùng
  widgets/                        Vẽ khung và nhãn trên ảnh
assets/
  models/                         Mô hình TFLite, 80 nhãn và cấu hình tọa độ
  demo/                           Ảnh mẫu và thông tin nguồn
android/                          Cấu hình ứng dụng Android
  app/src/main/                   Quyền camera và mã khởi động Android
ios/                              Khung dự án iOS, cần kiểm tra riêng trên Mac
test/                             Kiểm tra giao diện và giải mã YOLO
integration_test/                 Kiểm tra mô hình thật trên Android
training/                         Bộ khung chuẩn bị huấn luyện 13 lớp lớp học
docs/TECHNICAL.md                  Ghi chú kỹ thuật và quy trình huấn luyện
pubspec.yaml                      Thư viện, yêu cầu Dart và tài nguyên
pubspec.lock                      Phiên bản thư viện đã khóa
```

## 9. Kiểm tra và giới hạn

Kiểm tra mã nguồn và các bài kiểm tra tự động:

```sh
flutter analyze
flutter test
```

Khi đã kết nối Android, thay `ANDROID_DEVICE_ID` bằng ID thật để kiểm tra mô hình:

```sh
flutter test integration_test/model_test.dart -d ANDROID_DEVICE_ID
flutter run -d ANDROID_DEVICE_ID
```

Lệnh cuối mở lại ứng dụng thông thường sau bài kiểm tra tích hợp. Kiểm tra trên ảnh mẫu không thay thế đánh giá chất lượng bằng tập dữ liệu độc lập.

- Android là mục tiêu chính. Mã iOS cần build và kiểm tra trên macOS/thiết bị thật; chưa xác nhận hoạt động tương đương Android.
- Mô hình hiện tại là mô hình COCO đi kèm dự án. Không có số liệu đánh giá riêng trên tập ảnh lớp học thực tế.
- `training/` chỉ có bộ khung cho 13 lớp mới; các thư mục dữ liệu chưa có ảnh huấn luyện. Không cần chạy phần này để cài hoặc dùng ứng dụng.
- Không tự thêm nhãn vào `labels.txt` nếu chưa thay mô hình tương ứng.
- Tốc độ và kết quả phụ thuộc thiết bị, ánh sáng, kích thước vật thể và góc chụp.

Xem [ghi chú kỹ thuật và hướng dẫn chuẩn bị dữ liệu](docs/TECHNICAL.md), [danh sách nhãn](assets/models/labels.txt) và [nguồn ảnh mẫu](assets/demo/SOURCE.md).
