import 'package:cloud_firestore/cloud_firestore.dart';

/// Model lịch hẹn xem phòng trọ (Booking).
/// Collection: `bookings`
class Booking {
  final String id;
  final String roomId;
  final String roomTitle;
  final String roomAddress;
  final double roomPrice;
  final String roomImage;
  final String userId;
  final String userName;
  final String userPhone;
  final String userEmail;
  final String ownerId;
  final DateTime appointmentDate;
  final String phone;
  final String note;
  final String status; // 'pending' | 'confirmed' | 'cancelled' | 'completed'
  final DateTime? createdAt;

  Booking({
    required this.id,
    required this.roomId,
    this.roomTitle = '',
    this.roomAddress = '',
    this.roomPrice = 0.0,
    this.roomImage = '',
    required this.userId,
    this.userName = '',
    this.userPhone = '',
    this.userEmail = '',
    required this.ownerId,
    required this.appointmentDate,
    required this.phone,
    this.note = '',
    this.status = 'pending',
    this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'roomTitle': roomTitle,
      'roomAddress': roomAddress,
      'roomPrice': roomPrice,
      'roomImage': roomImage,
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'userEmail': userEmail,
      'ownerId': ownerId,
      'appointmentDate': Timestamp.fromDate(appointmentDate),
      'phone': phone,
      'note': note,
      'status': status,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory Booking.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return Booking(
      id: docId,
      roomId: map['roomId'] as String? ?? '',
      roomTitle: map['roomTitle'] as String? ?? '',
      roomAddress: map['roomAddress'] as String? ?? '',
      roomPrice: (map['roomPrice'] ?? 0).toDouble(),
      roomImage: map['roomImage'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      userPhone: map['userPhone'] as String? ?? '',
      userEmail: map['userEmail'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      appointmentDate: parseDate(map['appointmentDate']),
      phone: map['phone'] as String? ?? '',
      note: map['note'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}

