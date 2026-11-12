import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String recipientId; // 'all' or specific userId
  final String title;
  final String body;
  final String type; // 'system' | 'room_approved' | 'room_rejected' | 'booking'
  final bool isRead;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    required this.recipientId,
    required this.title,
    required this.body,
    this.type = 'system',
    this.isRead = false,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'recipientId': recipientId,
      'title': title,
      'body': body,
      'type': type,
      'isRead': isRead,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return AppNotification(
      id: docId,
      recipientId: map['recipientId'] ?? 'all',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'system',
      isRead: map['isRead'] ?? false,
      createdAt: parseDate(map['createdAt']),
    );
  }
}

