import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/app_notification.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Gửi thông báo toàn sàn (Broadcast)
  Future<void> sendBroadcastNotification({
    required String title,
    required String body,
    String type = 'system',
  }) async {
    await _firestore.collection('notifications').add({
      'recipientId': 'all',
      'title': title,
      'body': body,
      'type': type,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 2. Gửi thông báo đến 1 người dùng cụ thể (hỗ trợ cả UID và Email)
  Future<void> sendUserNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'system',
  }) async {
    String targetUid = userId.trim();

    // Nếu quản trị viên nhập email, tự động tìm UID tương ứng trong Firestore
    if (targetUid.contains('@')) {
      try {
        final queryEmail = await _firestore
            .collection('users')
            .where('email', isEqualTo: targetUid)
            .limit(1)
            .get();
        if (queryEmail.docs.isNotEmpty) {
          targetUid = queryEmail.docs.first.id;
        }
      } catch (_) {}
    }

    await _firestore.collection('notifications').add({
      'recipientId': targetUid,
      'title': title,
      'body': body,
      'type': type,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 3. Lấy toàn bộ thông báo cho Admin
  Future<List<AppNotification>> getAllNotificationsAdmin() async {
    final snap = await _firestore.collection('notifications').get();
    final list = snap.docs
        .map((d) => AppNotification.fromMap(d.data(), d.id))
        .toList();
    list.sort((a, b) {
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      return b.createdAt!.compareTo(a.createdAt!);
    });
    return list;
  }

  // 4. Lấy danh sách thông báo cho người dùng hiện tại (hỗ trợ cả UID và email)
  Stream<List<AppNotification>> getUserNotificationsStream(String userId, [String? userEmail]) {
    final List<String> targets = [userId, 'all'];
    if (userEmail != null && userEmail.trim().isNotEmpty && !targets.contains(userEmail.trim())) {
      targets.add(userEmail.trim());
    }

    return _firestore
        .collection('notifications')
        .where('recipientId', whereIn: targets)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => AppNotification.fromMap(d.data(), d.id))
              .toList();
          list.sort((a, b) {
            if (a.createdAt == null) return 1;
            if (b.createdAt == null) return -1;
            return b.createdAt!.compareTo(a.createdAt!);
          });
          return list;
        });
  }

  // 5. Đánh dấu đã đọc
  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }

  // 6. Xóa thông báo (Admin)
  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }

  // 7. Khởi tạo dữ liệu thông báo mẫu nếu hệ thống chưa có
  Future<void> ensureInitialData() async {
    try {
      final snap = await _firestore.collection('notifications').limit(1).get();
      if (snap.docs.isEmpty) {
        await sendBroadcastNotification(
          title: 'Chào mừng bạn đến với Trọ Tốt! 🎉',
          body: 'Ứng dụng tìm kiếm và cho thuê phòng trọ thông minh tại Hà Nội. Chúc bạn tìm được căn phòng ưng ý!',
          type: 'system',
        );
        await sendBroadcastNotification(
          title: 'Khuyến cáo an toàn khi thuê phòng 🛡️',
          body: 'Tuyệt đối không chuyển tiền cọc khi chưa đến xem phòng trực tiếp và chưa ký hợp đồng thuê trọ.',
          type: 'system',
        );
      }
    } catch (_) {}
  }
}

