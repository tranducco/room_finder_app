import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đánh giá phòng trọ.
/// Collection Firestore: `reviews`
/// Document ID: auto-generated bởi Firestore
class Review {
  final String reviewId;   // ID document (auto-generated)
  final String roomId;     // ID phòng được đánh giá
  final String userId;     // UID người đánh giá
  final String userName;   // Tên người đánh giá (để hiển thị nhanh trên UI)
  final String userAvatar; // Ảnh đại diện người đánh giá
  final String ownerId;    // UID chủ phòng
  final double rating;     // Điểm đánh giá: 1.0 – 5.0
  final String comment;    // Nội dung nhận xét
  final DateTime? createdAt;

  Review({
    required this.reviewId,
    required this.roomId,
    required this.userId,
    this.userName = 'Người dùng',
    this.userAvatar = '',
    required this.ownerId,
    required this.rating,
    required this.comment,
    this.createdAt,
  }) : assert(rating >= 1.0 && rating <= 5.0, 'rating phải nằm trong khoảng 1.0 – 5.0');

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'ownerId': ownerId,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory Review.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return Review(
      reviewId: documentId,
      roomId: map['roomId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? 'Người dùng',
      userAvatar: map['userAvatar'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      rating: (map['rating'] ?? 1).toDouble().clamp(1.0, 5.0),
      comment: map['comment'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
    );
  }

  Review copyWith({
    String? reviewId,
    String? roomId,
    String? userId,
    String? userName,
    String? userAvatar,
    String? ownerId,
    double? rating,
    String? comment,
    DateTime? createdAt,
  }) {
    return Review(
      reviewId: reviewId ?? this.reviewId,
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      ownerId: ownerId ?? this.ownerId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

