import 'package:cloud_firestore/cloud_firestore.dart';

/// Bản ghi gói xúc tiến / đẩy tin đang hoạt động của phòng trọ
class RoomPromotion {
  final String roomId; // Khóa chính: mỗi phòng có 1 promotion record
  final String ownerId; // Chủ phòng
  final String packageId; // 'bronze' | 'silver' | 'gold'
  final String packageName;
  final int priority; // 1, 2, 3
  final String status; // 'active' | 'expired' | 'cancelled'
  final DateTime startAt;
  final DateTime expiresAt;
  final String lastOrderId;
  final DateTime updatedAt;

  RoomPromotion({
    required this.roomId,
    required this.ownerId,
    required this.packageId,
    required this.packageName,
    required this.priority,
    required this.status,
    required this.startAt,
    required this.expiresAt,
    required this.lastOrderId,
    required this.updatedAt,
  });

  bool get isActive =>
      status == 'active' && expiresAt.isAfter(DateTime.now());

  int get remainingDays {
    if (!isActive) return 0;
    final diff = expiresAt.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff + 1;
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'ownerId': ownerId,
      'packageId': packageId,
      'packageName': packageName,
      'priority': priority,
      'status': status,
      'startAt': Timestamp.fromDate(startAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'lastOrderId': lastOrderId,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory RoomPromotion.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      return fallback;
    }

    return RoomPromotion(
      roomId: docId.isNotEmpty ? docId : (map['roomId'] ?? ''),
      ownerId: map['ownerId'] ?? '',
      packageId: map['packageId'] ?? 'bronze',
      packageName: map['packageName'] ?? 'Gói Đăng Tin',
      priority: (map['priority'] ?? 1) as int,
      status: map['status'] ?? 'active',
      startAt: parseDate(map['startAt'], DateTime.now()),
      expiresAt: parseDate(map['expiresAt'], DateTime.now().add(const Duration(days: 7))),
      lastOrderId: map['lastOrderId'] ?? '',
      updatedAt: parseDate(map['updatedAt'], DateTime.now()),
    );
  }
}
