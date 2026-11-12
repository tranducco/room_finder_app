import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String fullName;
  final String phoneNumber;
  final String avatarUrl;
  final String role; // 'user' | 'admin'
  final String status; // 'active' | 'blocked'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.avatarUrl,
    required this.role,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  bool get isAdmin => role == 'admin';
  bool get isBlocked => status == 'blocked';

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'avatarUrl': avatarUrl,
      'role': role,
      'status': status,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      if (val is int) {
        if (val > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(val);
        if (val > 1000000000) return DateTime.fromMillisecondsSinceEpoch(val * 1000);
      }
      return null;
    }

    DateTime? resolveDate(List<String> keys) {
      for (final k in keys) {
        if (map[k] != null) {
          final d = parseDate(map[k]);
          if (d != null) return d;
        }
      }
      return null;
    }

    String resolveString(List<String> keys) {
      for (final k in keys) {
        if (map[k] != null && map[k].toString().trim().isNotEmpty) {
          return map[k].toString().trim();
        }
      }
      return '';
    }

    final email = resolveString(['email', 'userEmail', 'user_email', 'mail', 'emailAddress']);
    final createdAt = resolveDate([
      'createdAt',
      'created_at',
      'timestamp',
      'dateCreated',
      'date_created',
      'createdTime',
      'registeredAt',
      'registered_at',
      'updatedAt',
      'updated_at',
    ]);
    final updatedAt = resolveDate(['updatedAt', 'updated_at', 'modifiedAt', 'modified_at']);

    return AppUser(
      uid: docId,
      email: email,
      fullName: resolveString(['fullName', 'name', 'displayName', 'full_name']),
      phoneNumber: resolveString(['phoneNumber', 'phone', 'phone_number', 'mobile']),
      avatarUrl: resolveString(['avatarUrl', 'photoURL', 'photoUrl', 'avatar_url', 'avatar']),
      role: map['role'] ?? 'user',
      status: map['status'] ?? 'active',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

