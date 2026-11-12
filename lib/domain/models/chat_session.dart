import 'package:cloud_firestore/cloud_firestore.dart';

class ChatSession {
  final String id;
  final String userId;
  final String title;
  final String lastMessage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ChatSession({
    required this.id,
    required this.userId,
    required this.title,
    this.lastMessage = '',
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'lastMessage': lastMessage,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  factory ChatSession.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return ChatSession(
      id: docId,
      userId: map['userId'] ?? '',
      title: map['title'] ?? 'Đoạn hội thoại mới',
      lastMessage: map['lastMessage'] ?? '',
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}

