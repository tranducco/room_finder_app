import 'package:cloud_firestore/cloud_firestore.dart';

import 'room.dart';

class ChatMessage {
  final String id;
  final String sender; // 'user' | 'model'
  final String text;
  final List<String> suggestedRoomIds;
  final List<Room> suggestedRooms;
  final DateTime? createdAt;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    this.suggestedRoomIds = const [],
    this.suggestedRooms = const [],
    this.createdAt,
  });

  bool get isUser => sender == 'user';
  bool get isModel => sender == 'model';

  Map<String, dynamic> toMap() {
    return {
      'sender': sender,
      'text': text,
      'suggestedRoomIds': suggestedRoomIds,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }

  factory ChatMessage.fromMap(
    Map<String, dynamic> map,
    String docId, {
    List<Room> resolvedRooms = const [],
  }) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return ChatMessage(
      id: docId,
      sender: map['sender'] ?? 'user',
      text: map['text'] ?? '',
      suggestedRoomIds: List<String>.from(map['suggestedRoomIds'] ?? []),
      suggestedRooms: resolvedRooms,
      createdAt: parseDate(map['createdAt']),
    );
  }
}

