import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../domain/models/review.dart';
import 'notification_service.dart';

/// Service xử lý đánh giá phòng trọ.
/// Mọi thao tác ghi đều dùng Firestore và cập nhật thống kê phòng qua Backend API
/// để đảm bảo quy tắc bảo mật trên Firestore Security Rules.
class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _envPaymentApiUrl = String.fromEnvironment('PAYMENT_API_URL');
  static const String _customPaymentServerUrl = 'https://room-finder-app-o3aq.onrender.com';

  String get _backendBaseUrl {
    if (_envPaymentApiUrl.isNotEmpty) return _envPaymentApiUrl;
    return _customPaymentServerUrl;
  }

  // ─────────────────────────── Thêm đánh giá ───────────────────────────────

  /// Thêm một đánh giá mới.
  ///
  /// Quy trình (atomic transaction):
  /// 1. Kiểm tra chủ phòng không được tự review phòng của mình.
  /// 2. Kiểm tra user đã có đánh giá cho phòng này chưa (mỗi user chỉ được đánh giá 1 lần).
  /// 3. Kiểm tra user có lịch hẹn trạng thái 'completed' (hoặc admin/verified).
  /// 4. Đọc document phòng để lấy [averageRating] và [totalReviews] hiện tại.
  /// 5. Tính toán [averageRating] mới và tăng [totalReviews] lên 1.
  /// 6. Ghi review mới vào collection `reviews`.
  /// 7. Cập nhật `averageRating` + `totalReviews` trong document `rooms`.
  /// 8. Gửi thông báo cho chủ phòng biết có đánh giá mới.
  Future<void> addReview(Review review) async {
    final reviewsCol = _firestore.collection('reviews');

    // 1. Chủ phòng không được tự đánh giá phòng của mình
    if (review.userId.isNotEmpty && review.userId == review.ownerId) {
      throw Exception('Chủ phòng không thể tự đánh giá phòng của chính mình.');
    }

    // 2. Kiểm tra đã đánh giá chưa (mỗi người 1 đánh giá cho 1 phòng)
    final existing = await reviewsCol
        .where('userId', isEqualTo: review.userId)
        .where('roomId', isEqualTo: review.roomId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('Bạn đã đánh giá phòng này rồi.');
    }

    // 3. Kiểm tra thông tin người thuê đã xác thực (nếu có lịch hẹn completed)
    bool isVerifiedRenter = false;
    try {
      final completedBooking = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: review.userId)
          .where('roomId', isEqualTo: review.roomId)
          .where('status', isEqualTo: 'completed')
          .limit(1)
          .get();
      isVerifiedRenter = completedBooking.docs.isNotEmpty;
    } catch (_) {}

    // 4. Lấy thông tin họ tên & avatar người đánh giá nếu chưa có
    String reviewerName = review.userName;
    String reviewerAvatar = review.userAvatar;
    if (reviewerName.isEmpty || reviewerName == 'Người dùng') {
      try {
        final uDoc = await _firestore.collection('users').doc(review.userId).get();
        if (uDoc.exists && uDoc.data() != null) {
          final uData = uDoc.data()!;
          reviewerName = uData['fullName'] as String? ??
              uData['name'] as String? ??
              reviewerName;
          reviewerAvatar = uData['avatarUrl'] as String? ??
              uData['photoURL'] as String? ??
              reviewerAvatar;
        }
      } catch (_) {}
    }

    final enrichedReview = review.copyWith(
      userName: reviewerName,
      userAvatar: reviewerAvatar,
    );

    // 5. Thêm review mới vào collection `reviews`
    final newReviewRef = reviewsCol.doc();
    await newReviewRef.set({
      ...enrichedReview.toMap(),
      'isVerifiedRenter': isVerifiedRenter,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 6. Gọi Backend API tính lại averageRating & totalReviews (an toàn, không ghi thẳng vào rooms)
    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken != null && idToken.isNotEmpty) {
        await http
            .post(
              Uri.parse('$_backendBaseUrl/recalculateRoomRating'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $idToken',
              },
              body: jsonEncode({'roomId': review.roomId}),
            )
            .timeout(const Duration(seconds: 10));
      }
    } catch (_) {
      // Server trigger / lần tính kế tiếp sẽ đồng bộ lại thống kê
    }

    // 7. Gửi thông báo cho chủ phòng (kèm senderId & reviewId hợp lệ theo Firestore Rules)
    if (review.ownerId.isNotEmpty && review.ownerId != review.userId) {
      try {
        await NotificationService().sendUserNotification(
          userId: review.ownerId,
          title: 'Phòng của bạn vừa nhận đánh giá mới! ⭐',
          body: '$reviewerName đã đánh giá ${review.rating.toStringAsFixed(1)} sao kèm nhận xét: "${review.comment}".',
          type: 'review',
          senderId: review.userId,
          reviewId: newReviewRef.id,
        );
      } catch (_) {}
    }
  }

  // ─────────────────────── Lấy danh sách đánh giá ──────────────────────────

  /// Lấy tất cả đánh giá của một phòng, sắp xếp mới nhất trước.
  Future<List<Review>> getReviewsByRoom(String roomId) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('roomId', isEqualTo: roomId)
        .get();

    final list = snapshot.docs
        .map((doc) => Review.fromMap(doc.data(), doc.id))
        .toList();
    list.sort((a, b) {
      final tA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tB.compareTo(tA);
    });
    return list;
  }

  /// Stream real-time đánh giá của một phòng (dùng cho UI reactive).
  Stream<List<Review>> reviewsStream(String roomId) {
    return _firestore
        .collection('reviews')
        .where('roomId', isEqualTo: roomId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => Review.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) {
        final tA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tB.compareTo(tA);
      });
      return list;
    });
  }

  /// Lấy tất cả đánh giá do một user viết.
  Future<List<Review>> getReviewsByUser(String userId) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('userId', isEqualTo: userId)
        .get();

    final list = snapshot.docs
        .map((doc) => Review.fromMap(doc.data(), doc.id))
        .toList();
    list.sort((a, b) {
      final tA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tB.compareTo(tA);
    });
    return list;
  }

  /// Kiểm tra user đã đánh giá phòng này chưa.
  Future<bool> hasUserReviewed(String userId, String roomId) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('userId', isEqualTo: userId)
        .where('roomId', isEqualTo: roomId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // ─────────────────────── Xóa đánh giá (Admin) ────────────────────────────

  /// Xóa đánh giá và cập nhật lại thống kê phòng (chỉ Admin).
  Future<void> deleteReview(String reviewId) async {
    final reviewRef = _firestore.collection('reviews').doc(reviewId);

    await _firestore.runTransaction((transaction) async {
      final reviewSnap = await transaction.get(reviewRef);
      if (!reviewSnap.exists) return;

      final reviewData = reviewSnap.data()!;
      final roomId = reviewData['roomId'] as String? ?? '';
      final deletedRating = (reviewData['rating'] ?? 0).toDouble();

      if (roomId.isNotEmpty) {
        final roomRef = _firestore.collection('rooms').doc(roomId);
        final roomSnap = await transaction.get(roomRef);

        if (roomSnap.exists) {
          final roomData = roomSnap.data()!;
          final oldTotal = (roomData['totalReviews'] ?? 0) as int;
          final oldAvg = (roomData['averageRating'] ?? 0).toDouble();

          final newTotal = oldTotal > 1 ? oldTotal - 1 : 0;
          final newAvg = newTotal > 0
              ? ((oldAvg * oldTotal) - deletedRating) / newTotal
              : 0.0;

          transaction.update(roomRef, {
            'averageRating': double.parse(newAvg.toStringAsFixed(1)),
            'totalReviews': newTotal,
          });
        }
      }

      transaction.delete(reviewRef);
    });
  }
}

