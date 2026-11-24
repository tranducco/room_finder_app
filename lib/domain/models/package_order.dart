import 'package:cloud_firestore/cloud_firestore.dart';

/// Trạng thái của đơn mua gói
enum OrderStatus {
  pending, // Chờ thanh toán
  completed, // Đã thanh toán & kích hoạt thành công
  failed, // Thanh toán thất bại
  cancelled, // Người dùng hủy
  expired, // Hết hạn thanh toán (sau 15 phút)
}

/// Đơn hàng mua gói đăng tin của người dùng
class PackageOrder {
  final String orderId; // Mã đơn hàng (VD: TROTOT_1711234567_abc)
  final String userId; // ID người mua
  final String userEmail;
  final String userPhone;
  final String roomId; // Phòng áp dụng
  final String roomTitle;
  final String packageId; // 'bronze' | 'silver' | 'gold'
  final String packageName;
  final double amount; // Giá tiền thanh toán (VNĐ)
  final int durationDays;
  final int priority;
  final String status; // 'pending' | 'completed' | 'failed' | 'cancelled' | 'expired'
  final String paymentMethod; // 'momo'
  final String? transactionId; // Mã giao dịch MoMo transId
  final String? payUrl; // URL thanh toán Web MoMo
  final String? qrCodeUrl; // URL mã QR MoMo
  final String? deeplink; // Deeplink app MoMo
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? startAt;
  final DateTime? expiresAt;
  final DateTime? updatedAt;
  final String? note;

  PackageOrder({
    required this.orderId,
    required this.userId,
    this.userEmail = '',
    this.userPhone = '',
    required this.roomId,
    required this.roomTitle,
    required this.packageId,
    required this.packageName,
    required this.amount,
    required this.durationDays,
    required this.priority,
    required this.status,
    this.paymentMethod = 'momo',
    this.transactionId,
    this.payUrl,
    this.qrCodeUrl,
    this.deeplink,
    required this.createdAt,
    this.paidAt,
    this.startAt,
    this.expiresAt,
    this.updatedAt,
    this.note,
  });

  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';
  bool get isCancelled => status == 'cancelled';

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'orderId': orderId,
      'userId': userId,
      'userEmail': userEmail,
      'userPhone': userPhone,
      'roomId': roomId,
      'roomTitle': roomTitle,
      'packageId': packageId,
      'packageName': packageName,
      'amount': amount,
      'durationDays': durationDays,
      'priority': priority,
      'status': status,
      'paymentMethod': paymentMethod,
      'createdAt': Timestamp.fromDate(createdAt),
    };
    if (transactionId != null) map['transactionId'] = transactionId;
    if (payUrl != null) map['payUrl'] = payUrl;
    if (qrCodeUrl != null) map['qrCodeUrl'] = qrCodeUrl;
    if (deeplink != null) map['deeplink'] = deeplink;
    if (paidAt != null) map['paidAt'] = Timestamp.fromDate(paidAt!);
    if (startAt != null) map['startAt'] = Timestamp.fromDate(startAt!);
    if (expiresAt != null) map['expiresAt'] = Timestamp.fromDate(expiresAt!);
    if (updatedAt != null) map['updatedAt'] = Timestamp.fromDate(updatedAt!);
    if (note != null) map['note'] = note;
    return map;
  }

  factory PackageOrder.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      return fallback;
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return PackageOrder(
      orderId: docId.isNotEmpty ? docId : (map['orderId'] ?? ''),
      userId: map['userId'] ?? '',
      userEmail: map['userEmail'] ?? '',
      userPhone: map['userPhone'] ?? '',
      roomId: map['roomId'] ?? '',
      roomTitle: map['roomTitle'] ?? '',
      packageId: map['packageId'] ?? 'bronze',
      packageName: map['packageName'] ?? 'Gói Đăng Tin',
      amount: (map['amount'] ?? 0).toDouble(),
      durationDays: (map['durationDays'] ?? 7) as int,
      priority: (map['priority'] ?? 1) as int,
      status: map['status'] ?? 'pending',
      paymentMethod: map['paymentMethod'] ?? 'momo',
      transactionId: map['transactionId'] as String?,
      payUrl: map['payUrl'] as String?,
      qrCodeUrl: map['qrCodeUrl'] as String?,
      deeplink: map['deeplink'] as String?,
      createdAt: parseDate(map['createdAt'], DateTime.now()),
      paidAt: parseNullableDate(map['paidAt']),
      startAt: parseNullableDate(map['startAt']),
      expiresAt: parseNullableDate(map['expiresAt']),
      updatedAt: parseNullableDate(map['updatedAt']),
      note: map['note'] as String?,
    );
  }
}
