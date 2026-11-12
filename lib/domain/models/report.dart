import 'package:cloud_firestore/cloud_firestore.dart';

class Report {
  final String id;
  final String roomId;
  final String roomTitle;
  final String reporterId;
  final String reporterEmail;
  final String reason;
  final String description;
  final String status; // 'pending' | 'resolved' | 'dismissed'
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? adminNote;

  Report({
    required this.id,
    required this.roomId,
    required this.roomTitle,
    required this.reporterId,
    required this.reporterEmail,
    required this.reason,
    required this.description,
    this.status = 'pending',
    this.createdAt,
    this.resolvedAt,
    this.adminNote,
  });

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'roomTitle': roomTitle,
      'reporterId': reporterId,
      'reporterEmail': reporterEmail,
      'reason': reason,
      'description': description,
      'status': status,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
      if (adminNote != null) 'adminNote': adminNote,
    };
  }

  factory Report.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return Report(
      id: docId,
      roomId: map['roomId'] ?? '',
      roomTitle: map['roomTitle'] ?? '',
      reporterId: map['reporterId'] ?? '',
      reporterEmail: map['reporterEmail'] ?? '',
      reason: map['reason'] ?? '',
      description: map['description'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: parseDate(map['createdAt']),
      resolvedAt: parseDate(map['resolvedAt']),
      adminNote: map['adminNote'] as String?,
    );
  }
}

