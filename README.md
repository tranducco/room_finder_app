
# 🏠 TroTot – Ứng dụng tìm kiếm và cho thuê phòng trọ tích hợp Chatbot AI

<p align="center">
  <strong>Ứng dụng cho thuê phòng trọ đa nền tảng bằng Flutter tích hợp Chatbot AI tư vấn người dùng</strong>
</p>

---

## 📖 1. Giới thiệu dự án

**TroTot** là ứng dụng hỗ trợ tìm kiếm và cho thuê phòng trọ, được phát triển bằng Flutter nhằm cung cấp trải nghiệm sử dụng trên cả nền tảng Web và thiết bị di động Android.

Dự án hướng tới việc giải quyết những khó khăn thường gặp trong quá trình tìm kiếm phòng trọ như thông tin phân tán, khó lựa chọn phòng phù hợp, thiếu công cụ tư vấn và khó quản lý hoạt động đăng tin.

Điểm nổi bật của TroTot là tích hợp **Chatbot AI sử dụng Google Gemini API kết hợp kỹ thuật RAG**, cho phép người dùng tìm kiếm phòng trọ bằng ngôn ngữ tự nhiên. Hệ thống phân tích các tiêu chí như khu vực, giá thuê và tiện ích, sau đó truy xuất dữ liệu phòng từ Cloud Firestore để đưa ra gợi ý phù hợp.

Ngoài ra, hệ thống cung cấp chức năng đăng tin, đặt lịch xem phòng, đánh giá, quản lý tin đăng, các gói quảng bá VIP và tích hợp thanh toán MoMo Sandbox.

## 🎯 2. Mục tiêu dự án

- Xây dựng ứng dụng tìm kiếm và cho thuê phòng trọ đa nền tảng bằng Flutter.
- Hỗ trợ tìm kiếm và lọc phòng trọ theo nhiều tiêu chí.
- Tích hợp Chatbot AI tư vấn người dùng bằng ngôn ngữ tự nhiên.
- Áp dụng kỹ thuật RAG để kết hợp mô hình ngôn ngữ với dữ liệu phòng trọ.
- Xây dựng hệ thống đăng tin, quản lý phòng và đặt lịch xem phòng.
- Tích hợp các gói đăng tin VIP và cổng thanh toán MoMo.
- Xây dựng Admin Dashboard phục vụ quản trị và giám sát hệ thống.

## ✨ 3. Các chức năng chính

### 3.1. Chức năng dành cho người dùng (User)

| Chức năng | Mô tả |
|---|---|
| Đăng ký / Đăng nhập | Xác thực tài khoản bằng Firebase Authentication |
| Quản lý hồ sơ | Cập nhật thông tin cá nhân và ảnh đại diện |
| Tìm kiếm phòng | Tìm kiếm theo từ khóa, khu vực và tên đường |
| Lọc nâng cao | Lọc theo giá, diện tích, loại phòng, quận huyện và tiện ích |
| Xem chi tiết phòng | Xem hình ảnh, giá thuê, tiền cọc, địa chỉ và tiện ích |
| Yêu thích | Lưu và quản lý danh sách phòng quan tâm |
| Đặt lịch xem phòng | Tạo lịch hẹn và theo dõi trạng thái |
| Đánh giá | Đánh giá phòng bằng số sao và nhận xét |
| Chatbot AI | Tư vấn và gợi ý phòng trọ bằng ngôn ngữ tự nhiên |
| Đăng tin | Đăng phòng trọ kèm thông tin và hình ảnh |
| Quản lý tin đăng | Chỉnh sửa, xóa và thay đổi trạng thái phòng |
| Gói VIP | Mua và quản lý các gói quảng bá phòng trọ |

### 3.2. Chức năng dành cho quản trị viên (Admin)

Admin Dashboard được xây dựng với 7 phân hệ:

1. **Tổng quan hệ thống:** Thống kê người dùng, phòng trọ, tin chờ duyệt và các chỉ số hoạt động.
2. **Quản lý tin đăng:** Duyệt, từ chối, khóa và mở khóa tin đăng.
3. **Quản lý người dùng:** Xem thông tin, phân quyền và quản lý trạng thái tài khoản.
4. **Báo cáo vi phạm:** Tiếp nhận và xử lý các báo cáo từ người dùng.
5. **Gửi thông báo:** Gửi thông báo tới người dùng cá nhân hoặc toàn hệ thống.
6. **Trợ lý AI & Tri thức:** Theo dõi hoạt động Chatbot và quản lý cơ sở tri thức tư vấn.
7. **Gói VIP & Doanh thu:** Quản lý đơn hàng, gói VIP và thống kê doanh thu.

## 🤖 4. Chatbot AI và kỹ thuật RAG

TroTot tích hợp Google Gemini API để xây dựng trợ lý ảo chuyên tư vấn phòng trọ.

Hệ thống áp dụng quy trình Retrieval-Augmented Generation (RAG), kết hợp khả năng xử lý ngôn ngữ tự nhiên của mô hình AI với dữ liệu phòng trọ trong Cloud Firestore.

### Quy trình xử lý

1. Người dùng nhập câu hỏi bằng ngôn ngữ tự nhiên.
2. Hệ thống phân tích câu hỏi và trích xuất tiêu chí tìm kiếm thành đối tượng `UserSearchIntent`.
3. Truy vấn Cloud Firestore để tìm các phòng có trạng thái phù hợp.
4. Lọc và sắp xếp kết quả theo tiêu chí, ưu tiên các tin đăng VIP.
5. Đưa dữ liệu phòng tìm được vào ngữ cảnh gửi tới Gemini API.
6. Gemini tạo câu trả lời dựa trên ngữ cảnh được cung cấp.
7. Ứng dụng hiển thị câu trả lời kèm các thẻ phòng `SuggestedRoomCard`.
8. Người dùng có thể nhấn vào thẻ phòng để xem chi tiết và đặt lịch.

### Các kỹ thuật hỗ trợ

- System Prompt định hướng vai trò tư vấn của Chatbot.
- Natural Language Intent Extraction.
- Context Retrieval từ Firestore.
- Context Injection.
- `ROOM_ID` liên kết nội dung tư vấn với phòng tương ứng.
- Offline Fallback khi API hoặc kết nối gặp sự cố.
- Lưu lịch sử hội thoại trong Firestore.

## 💳 5. Hệ thống gói VIP và thanh toán MoMo

TroTot xây dựng ba gói quảng bá tin đăng:

| Gói | Giá | Thời hạn | Priority |
|---|---:|---:|---:|
| Đồng | 15.000 VNĐ | 7 ngày | 1 |
| Bạc | 39.000 VNĐ | 15 ngày | 2 |
| Vàng | 69.000 VNĐ | 30 ngày | 3 |

Thứ tự ưu tiên hiển thị:

**Gói Vàng → Gói Bạc → Gói Đồng → Tin thường**

### Tích hợp MoMo

Hệ thống sử dụng MoMo v2 AIO Gateway trong môi trường Sandbox để thử nghiệm quy trình thanh toán.

Các Cloud Functions chính:

- `createMoMoPayment`: Tạo yêu cầu thanh toán và chữ ký HMAC-SHA256.
- `momoIpnWebhook`: Tiếp nhận và xác minh thông báo thanh toán IPN.
- `checkPaymentStatus`: Kiểm tra trạng thái giao dịch.
- `checkExpiredPromotions`: Kiểm tra các gói VIP đã hết hạn.

### Cơ chế bảo mật

- Xác thực người dùng trước khi tạo giao dịch.
- Tạo và xác minh chữ ký HMAC-SHA256 ở phía máy chủ.
- Kiểm tra idempotency nhằm hạn chế xử lý trùng giao dịch.
- Không lưu Secret Key và Access Key trực tiếp trong ứng dụng Flutter.
- Client không được tự ý kích hoạt gói VIP.

> **Lưu ý:** Tích hợp MoMo trong dự án sử dụng môi trường Sandbox phục vụ mục đích học tập và trình diễn, không đồng nghĩa với việc đã triển khai thanh toán thương mại chính thức.

## 🛠️ 6. Công nghệ sử dụng

| Thành phần | Công nghệ |
|---|---|
| Frontend | Flutter, Dart |
| Backend | Firebase Cloud Functions |
| Ngôn ngữ Backend | Node.js, TypeScript |
| Authentication | Firebase Authentication |
| Database | Cloud Firestore |
| Security | Firestore Security Rules |
| AI / LLM | Google Gemini API |
| AI Architecture | RAG |
| Payment | MoMo v2 AIO Gateway |
| Version Control | Git, GitHub |
| CI/CD | GitHub Actions |
| Testing | Flutter Test, Flutter Analyze |

## 🏗️ 7. Kiến trúc hệ thống

```text
                         USER / ADMIN
                              |
                              v
                    FLUTTER APPLICATION
                       /           \
                      /             \
                 MOBILE              WEB
                      \             /
                       \           /
                              |
                              v
                     FIREBASE BACKEND
                              |
              +---------------+----------------+
              |               |                |
              v               v                v
         Firebase Auth    Cloud Firestore   Cloud Functions
                              |                |
                              |         +------+------+
                              |         |             |
                              v         v             v
                         Room Data   Gemini API    MoMo API
                                     (RAG Chatbot)  (Payment)
                              |
                              v
                       Application Data

                    DEVELOPMENT & DEVOPS
                              |
                       GitHub Repository
                              |
                       GitHub Actions
                              |
                    Analyze / Test / Build
                              |
                       Android APK
```

## 🗄️ 8. Thiết kế cơ sở dữ liệu

Hệ thống sử dụng Cloud Firestore theo mô hình NoSQL.

Các collection chính:

| Collection | Chức năng |
|---|---|
| `users` | Lưu thông tin và vai trò người dùng |
| `rooms` | Lưu thông tin phòng trọ |
| `favorites` | Quản lý danh sách phòng yêu thích |
| `bookings` | Lưu thông tin lịch hẹn xem phòng |
| `reviews` | Lưu đánh giá và nhận xét |
| `reports` | Lưu báo cáo vi phạm |
| `notifications` | Quản lý thông báo |
| `chat_sessions` | Lưu phiên hội thoại |
| `chat_messages` | Lưu nội dung tin nhắn |

Các dữ liệu liên quan đến đơn hàng và gói VIP được sử dụng trong nghiệp vụ thanh toán, quản lý quảng bá và thống kê doanh thu.

## 📂 9. Cấu trúc dự án

```text
room_finder_app/
│
├── android/                  # Cấu hình ứng dụng Android
├── web/                      # Cấu hình Flutter Web
├── functions/                # Firebase Cloud Functions
│   ├── src/
│   ├── package.json
│   └── tsconfig.json
│
├── lib/
│   ├── core/                 # Thành phần dùng chung
│   ├── data/                 # Truy cập và xử lý dữ liệu
│   ├── domain/
│   │   └── models/           # Các mô hình dữ liệu
│   ├── presentation/         # Giao diện và màn hình
│   ├── firebase_options.dart
│   └── main.dart
│
├── test/                     # Các bộ kiểm thử
├── firestore.rules           # Quy tắc bảo mật Firestore
├── pubspec.yaml              # Dependencies Flutter
├── .github/
│   └── workflows/
│       └── ci_cd.yml         # GitHub Actions
│
└── README.md
```

*Cấu trúc trên là cấu trúc tổng quan theo các thành phần chính của dự án. Tên thư mục hoặc tệp có thể thay đổi tùy theo phiên bản mã nguồn thực tế.*

## 🚀 10. Hướng dẫn cài đặt và chạy dự án

### 10.1. Yêu cầu môi trường

Cần chuẩn bị:

- Flutter SDK 3.7 trở lên.
- Dart SDK 3.7 trở lên.
- Visual Studio Code hoặc Android Studio.
- Git.
- Node.js và npm để phát triển Firebase Cloud Functions.
- Tài khoản Firebase.
- Trình duyệt Chrome để chạy Flutter Web.

Kiểm tra môi trường:

```bash
flutter doctor
```

### 10.2. Clone repository

```bash
git clone <YOUR_GITHUB_REPOSITORY_URL>
```

Di chuyển vào thư mục dự án:

```bash
cd room_finder_app
```

### 10.3. Cài đặt dependencies

```bash
flutter pub get
```

### 10.4. Cấu hình Firebase

Dự án sử dụng Firebase Authentication và Cloud Firestore.

Cần cấu hình Firebase cho các nền tảng tương ứng và tạo tệp `firebase_options.dart` bằng FlutterFire CLI nếu chưa có.

Cài đặt FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
```

Cấu hình Firebase:

```bash
flutterfire configure
```

Sau đó kiểm tra lại cấu hình Firebase trong dự án trước khi chạy ứng dụng.

### 10.5. Chạy ứng dụng Web

```bash
flutter run -d chrome
```

Build phiên bản Web:

```bash
flutter build web --release
```

### 10.6. Chạy ứng dụng Android

Kiểm tra thiết bị:

```bash
flutter devices
```

Chạy ứng dụng:

```bash
flutter run
```

Build APK Release:

```bash
flutter build apk --release
```

File APK sau khi build nằm tại:

```text
build/app/outputs/flutter-apk/app-release.apk
```

### 10.7. Cài đặt và chạy Cloud Functions

Di chuyển vào thư mục:

```bash
cd functions
```

Cài đặt dependencies:

```bash
npm install
```

Build TypeScript:

```bash
npm run build
```

Việc triển khai Cloud Functions yêu cầu cấu hình Firebase CLI, quyền truy cập dự án Firebase và các biến môi trường hoặc secrets cần thiết.

> Không đưa Gemini API Key, MoMo Secret Key, Access Key hoặc thông tin xác thực nhạy cảm lên GitHub.

## 🧪 11. Kiểm thử và CI/CD

Dự án xây dựng bộ kiểm thử tự động gồm **41 test cases** (đạt 100%, 0 fail, 0 skip):

| Bộ kiểm thử | Số lượng |
|---|---:|
| `package_system_test.dart` | 9 |
| `admin_models_test.dart` | 11 |
| `ai_service_test.dart` | 6 |
| `e2e_user_journey_test.dart` | 6 |
| `chatbot_evaluation_test.dart` | 6 |
| `home_banner_carousel_test.dart` | 2 |
| `widget_test.dart` | 1 |
| **Tổng cộng** | **41** |

Chạy kiểm thử:

```bash
flutter test
```

Kiểm tra chất lượng mã nguồn (0 errors, 0 warnings, 0 infos):

```bash
flutter analyze
```

Build Backend TypeScript (`functions` và `payment-server`):

```bash
cd functions && npm run build
cd ../payment-server && npm run build
```

### GitHub Actions CI/CD

Dự án sử dụng GitHub Actions với workflow:

```text
.github/workflows/ci_cd.yml
```

Các bước tự động hóa chính:

1. Kiểm tra mã nguồn Flutter (`flutter analyze`) và chạy **41/41** test cases (`flutter test`).
2. Build TypeScript cho cả `functions/` và `payment-server/`.
3. Build Android APK Release và Flutter Web Release.
4. Lưu trữ APK và bản build Web dưới dạng GitHub Actions Artifacts.

## 🔐 12. Bảo mật

Một số nguyên tắc bảo mật được áp dụng:

- Sử dụng Firebase Authentication để xác thực người dùng.
- Phân quyền User và Admin.
- Sử dụng Firestore Security Rules để kiểm soát quyền đọc và ghi dữ liệu.
- Người dùng chỉ được chỉnh sửa thông tin và tin đăng thuộc quyền sở hữu của mình.
- Người dùng thông thường không được tự ý thay đổi các trường nhạy cảm như `priority` và `packageExpiresAt`.
- Các thao tác thanh toán được xử lý thông qua Cloud Functions.
- Secret Key và Access Key không được lưu trực tiếp trong mã nguồn phía Client.

## 📸 13. Giao diện ứng dụng

Các ảnh minh họa nên được lưu trong thư mục `screenshots/` của repository.

Ví dụ:

```markdown
![TroTot Home](screenshots/home.png)
![TroTot Room List](screenshots/room_list.png)
![TroTot Chatbot](screenshots/chatbot.png)
![TroTot Admin Dashboard](screenshots/admin_dashboard.png)
![TroTot VIP Packages](screenshots/vip_packages.png)
![TroTot Payment](screenshots/payment.png)
```

## 📌 14. Trạng thái phát triển

Các hạng mục đã được ghi nhận hoàn thành trong checklist:

- [x] Phân tích yêu cầu và thiết kế hệ thống.
- [x] Xây dựng ứng dụng Flutter đa nền tảng.
- [x] Tích hợp Firebase Authentication.
- [x] Thiết kế dữ liệu Cloud Firestore.
- [x] Xây dựng giao diện trang chủ Responsive.
- [x] Tìm kiếm và lọc phòng trọ.
- [x] Quản lý yêu thích, đặt lịch và đánh giá.
- [x] Đăng tin và quản lý phòng trọ.
- [x] Xây dựng Admin Dashboard 7 phân hệ.
- [x] Tích hợp Gemini API qua Backend Proxy và Chatbot RAG.
- [x] Xây dựng hệ thống gói VIP & Chế độ Khách (Guest Mode + `AuthGuard`).
- [x] Tích hợp MoMo Sandbox (Render + Cloud Functions).
- [x] Xây dựng **41 test cases** (Unit, Widget, E2E luồng chính & Đánh giá chống ảo giác Chatbot).
- [x] Cấu hình GitHub Actions CI/CD (`flutter analyze`, `flutter test`, `functions`, `payment-server`, Web & APK).
- [x] Triển khai phiên bản thử nghiệm Web (Firebase Hosting) & Payment/AI Proxy Server (Render).
- [ ] Hoàn thiện khảo sát UAT sau nghiệm thu.

## 🔮 15. Hướng phát triển

Trong tương lai, hệ thống có thể được mở rộng theo các hướng:

- Tích hợp bản đồ GPS để tìm phòng trọ theo vị trí và bán kính.
- Phát triển Chatbot AI hỗ trợ hội thoại bằng giọng nói.
- Tích hợp ký hợp đồng thuê phòng điện tử.
- Mở rộng các phương thức thanh toán trực tuyến.
- Cải thiện thuật toán gợi ý phòng theo hành vi và nhu cầu người dùng.
- Tối ưu hiệu năng và khả năng mở rộng dữ liệu.

## 👨‍🎓 16. Thông tin dự án

| Nội dung | Thông tin |
|---|---|
| Tên dự án | TroTot |
| Tên đề tài | Xây dựng ứng dụng cho thuê phòng trọ đa nền tảng bằng Flutter tích hợp Chatbot AI tư vấn người dùng |
| Sinh viên thực hiện | Trần Đức Cơ |
| Mã sinh viên | 2251161959 |
| Lớp | 64HTTT2 |
| Ngành | Hệ thống thông tin |
| Khoa | Công nghệ Thông tin |
| Trường | Đại học Thủy lợi |
| Giảng viên hướng dẫn | TS. Đỗ Oanh Cường |

## 📄 17. License

Dự án được xây dựng phục vụ mục đích học tập và thực hiện đồ án tốt nghiệp.

Thông tin về giấy phép sử dụng và phân phối mã nguồn sẽ được bổ sung khi tác giả lựa chọn License phù hợp.

---

<p align="center">
  <strong>TroTot – Tìm phòng trọ dễ dàng, tư vấn thông minh cùng AI.</strong>
</p>

<p align="center">
  Made with ❤️ using Flutter & Firebase
</p>
