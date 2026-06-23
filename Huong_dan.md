from pathlib import Path

content = r"""# Hướng dẫn chạy dự án Smart Parking sau khi sửa

Tài liệu này dùng cho phiên bản hiện tại của dự án:

- Flutter Web nhận camera từ DroidCam.
- Flutter chụp ảnh biển số.
- Flutter gửi ảnh sang `ai_server`.
- `ai_server` gọi Plate Recognizer API để đọc biển số.
- Flutter nhận kết quả và hiển thị biển số.

---

## 1. Cấu trúc chính của dự án

```text
Smart-parking/
├── ai_server/
│   └── main.py
├── lib/
│   ├── main.dart
│   ├── firebase_options.dart
│   ├── screens/
│   │   └── plate_camera_screen.dart
│   └── services/
│       └── plate_recognition_service.dart
├── pubspec.yaml
└── web/

## Hướng dẫn chạy Flutter Web

Dự án hiện tại chạy giao diện bằng **Flutter Web**, mở trên trình duyệt Chrome. Flutter Web sẽ nhận camera từ DroidCam, sau đó gửi ảnh sang `ai_server` để đọc biển số.

### 1. Mở DroidCam trước khi chạy web

Trước khi chạy Flutter Web, cần mở DroidCam theo thứ tự:

```text
1. Mở DroidCam trên điện thoại
2. Mở DroidCam Client trên máy tính
3. Kết nối bằng USB hoặc Wi-Fi
4. Bấm Start
5. Đảm bảo DroidCam Client đã hiện hình thật từ điện thoại
```

Nếu DroidCam chưa hiện hình thì Flutter Web cũng sẽ không nhận được ảnh từ camera điện thoại.

---

### 2. Chạy Flutter Web

Mở terminal mới tại thư mục gốc dự án:

```powershell
cd D:\Smart-parking
```

Cài lại package nếu cần:

```powershell
flutter pub get
```

Chạy web trên Chrome với port cố định `5000`:

```powershell
flutter run -d chrome --web-port 5000
```

Sau khi chạy thành công, trình duyệt Chrome sẽ mở địa chỉ:

```text
http://localhost:5000
```

Nên dùng `localhost:5000` để tránh lỗi quyền camera trên trình duyệt.

---

### 3. Cấp quyền camera cho Chrome

Khi Chrome hỏi quyền sử dụng camera, chọn:

```text
Allow / Cho phép
```

Nếu lỡ bấm chặn hoặc web không thấy camera, vào:

```text
chrome://settings/content/camera
```

Sau đó chọn camera mặc định là:

```text
DroidCam Video
```

hoặc camera có tên chứa:

```text
DroidCam
```

Sau khi chọn xong, reload lại trang Flutter Web.

---

### 4. Chọn camera trong giao diện web

Trên màn hình Flutter Web, ở dropdown **Chọn camera**, chọn:

```text
DroidCam Video
```

Nếu không thấy DroidCam trong danh sách, thử:

```text
1. Tắt Chrome
2. Tắt DroidCam Client bằng File → Exit
3. Mở lại DroidCam Client
4. Bấm Start cho có hình thật
5. Mở lại Flutter Web
```

---

### 5. Test chụp ảnh và đọc biển số

Sau khi web đã hiển thị camera:

```text
1. Đưa biển số vào khung hình
2. Nếu ảnh bị ngược, bật/tắt switch "Lật ngang ảnh DroidCam"
3. Bấm nút "Chụp ảnh & đọc biển số"
4. Đợi hệ thống gửi ảnh sang ai_server
5. Kết quả biển số sẽ hiển thị trên màn hình
```

Kết quả hiển thị gồm:

```text
Biển số đã format: 29-B1 555.55
Dạng lưu database: 29B155555
Độ tin cậy nhận diện
Ảnh vừa chụp đã gửi AI
```

---

### 6. Lưu ý khi chạy web

Khi test đầy đủ chức năng đọc biển số, cần chạy đồng thời 3 phần:

```text
DroidCam
ai_server
Flutter Web
```

Thứ tự chạy chuẩn:

```text
1. Mở DroidCam và Start camera
2. Chạy ai_server ở port 8000
3. Chạy Flutter Web ở port 5000
4. Mở web tại http://localhost:5000
5. Chụp ảnh và đọc biển số
```

Nếu chỉ muốn test giao diện và camera thì có thể chưa cần `ai_server`.
Nếu muốn bấm **Chụp ảnh & đọc biển số** thì bắt buộc phải chạy `ai_server`.

---

### 7. Lệnh chạy nhanh Flutter Web

```powershell
cd D:\Smart-parking
flutter pub get
flutter run -d chrome --web-port 5000
```

Nếu gặp lỗi lạ sau khi sửa package, chạy:

```powershell
flutter clean
flutter pub get
flutter run -d chrome --web-port 5000
```
