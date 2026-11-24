import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/app_user.dart';
import '../domain/models/report.dart';
import '../domain/models/room.dart';
import 'rag_chat_service.dart';

class AdminDashboardStats {
  final int totalRooms;
  final int availableRooms;
  final int pendingRooms;
  final int rentedRooms;
  final int hiddenRooms;
  final int rejectedRooms;
  final int totalUsers;
  final int blockedUsers;
  final int totalBookings;
  final int totalReports;
  final int pendingReports;
  final int totalAiSessions;

  AdminDashboardStats({
    required this.totalRooms,
    required this.availableRooms,
    required this.pendingRooms,
    required this.rentedRooms,
    required this.hiddenRooms,
    required this.rejectedRooms,
    required this.totalUsers,
    required this.blockedUsers,
    required this.totalBookings,
    required this.totalReports,
    required this.pendingReports,
    this.totalAiSessions = 0,
  });
}

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Thống kê toàn hệ thống
  Future<AdminDashboardStats> getDashboardStats() async {
    // Rooms
    final roomsSnap = await _firestore.collection('rooms').get();
    int available = 0;
    int pending = 0;
    int rented = 0;
    int hidden = 0;
    int rejected = 0;

    for (var doc in roomsSnap.docs) {
      final status = doc.data()['status'] as String? ?? 'available';
      switch (status) {
        case 'available':
          available++;
          break;
        case 'pending_approval':
          pending++;
          break;
        case 'rented':
          rented++;
          break;
        case 'hidden':
          hidden++;
          break;
        case 'rejected':
          rejected++;
          break;
        default:
          available++;
      }
    }

    // Users
    final usersSnap = await _firestore.collection('users').get();
    int blockedUsers = 0;
    for (var doc in usersSnap.docs) {
      if (doc.data()['status'] == 'blocked') {
        blockedUsers++;
      }
    }

    // Bookings
    final bookingsSnap = await _firestore.collection('bookings').get();

    // Reports
    final reportsSnap = await _firestore.collection('reports').get();
    int pendingReports = 0;
    for (var doc in reportsSnap.docs) {
      if (doc.data()['status'] == 'pending') {
        pendingReports++;
      }
    }

    // AI Chat sessions
    int totalAiSessions = 0;
    try {
      final aiSnap = await _firestore.collection('chat_histories').get();
      totalAiSessions = aiSnap.docs.length;
    } catch (_) {}

    return AdminDashboardStats(
      totalRooms: roomsSnap.docs.length,
      availableRooms: available,
      pendingRooms: pending,
      rentedRooms: rented,
      hiddenRooms: hidden,
      rejectedRooms: rejected,
      totalUsers: usersSnap.docs.length,
      blockedUsers: blockedUsers,
      totalBookings: bookingsSnap.docs.length,
      totalReports: reportsSnap.docs.length,
      pendingReports: pendingReports,
      totalAiSessions: totalAiSessions,
    );
  }

  // 2. Quản lý người dùng
  Future<List<AppUser>> getAllUsers() async {
    final snap = await _firestore.collection('users').get();
    return snap.docs.map((d) => AppUser.fromMap(d.data(), d.id)).toList();
  }

  Future<void> toggleUserBlock(String uid, bool isBlocked) async {
    await _firestore.collection('users').doc(uid).update({
      'status': isBlocked ? 'blocked' : 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> changeUserRole(String uid, String newRole) async {
    await _firestore.collection('users').doc(uid).update({
      'role': newRole,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Room>> getUserRooms(String userId) async {
    final snap = await _firestore
        .collection('rooms')
        .where('ownerId', isEqualTo: userId)
        .get();
    return snap.docs.map((d) => Room.fromMap(d.data(), d.id)).toList();
  }

  // 3. Quản lý báo cáo vi phạm
  Future<List<Report>> getAllReports() async {
    final snap = await _firestore.collection('reports').get();
    final list = snap.docs.map((d) => Report.fromMap(d.data(), d.id)).toList();
    list.sort((a, b) {
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      return b.createdAt!.compareTo(a.createdAt!);
    });
    return list;
  }

  Future<void> createReport(Report report) async {
    await _firestore.collection('reports').add(report.toMap());
  }

  Future<void> resolveReport({
    required String reportId,
    required String roomId,
    required bool hideRoom,
    required String adminNote,
  }) async {
    final batch = _firestore.batch();

    final reportRef = _firestore.collection('reports').doc(reportId);
    batch.update(reportRef, {
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
      'adminNote': adminNote,
    });

    if (hideRoom && roomId.isNotEmpty) {
      final roomRef = _firestore.collection('rooms').doc(roomId);
      batch.update(roomRef, {
        'status': 'hidden',
      });
    }

    await batch.commit();
  }

  Future<void> dismissReport({
    required String reportId,
    required String adminNote,
  }) async {
    await _firestore.collection('reports').doc(reportId).update({
      'status': 'dismissed',
      'resolvedAt': FieldValue.serverTimestamp(),
      'adminNote': adminNote,
    });
  }

  // 4. Quản lý AI Knowledge & System Settings
  static Map<String, dynamic>? _cachedAiKnowledge;
  static DateTime? _lastAiKnowledgeFetch;

  Future<Map<String, dynamic>> getAiKnowledge() async {
    final now = DateTime.now();
    if (_cachedAiKnowledge != null &&
        _lastAiKnowledgeFetch != null &&
        now.difference(_lastAiKnowledgeFetch!) < const Duration(minutes: 2)) {
      return Map<String, dynamic>.from(_cachedAiKnowledge!);
    }

    try {
      final doc = await _firestore
          .collection('system_settings')
          .doc('ai_knowledge')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = Map<String, dynamic>.from(doc.data()!);
        data['modelName'] = RagChatService.normalizeModelName(data['modelName'] as String?);
        _cachedAiKnowledge = data;
        _lastAiKnowledgeFetch = now;
        return Map<String, dynamic>.from(data);
      }
    } catch (_) {}

    // Giá trị cấu hình mặc định chuẩn đồ án (Gemini Flash-Lite siêu tốc & Gemini 3.8 Flash)
    final defaultKnowledge = {
      'botName': 'Trợ lý ảo TroTot AI',
      'modelName': 'gemini-flash-lite-latest',
      'temperature': 0.5,
      'systemPrompt':
          'Bạn là Trợ lý ảo AI thông minh của ứng dụng Trọ Tốt, chuyên tư vấn tìm kiếm và thuê phòng trọ tại Việt Nam. '
          'Hãy trả lời lịch sự, thân thiện, súc tích. Chỉ tư vấn nội dung xoay quanh: tìm phòng, giá thuê trung bình, hợp đồng, cọc trọ. '
          'Từ chối các chủ đề ngoài lề một cách nhã nhặn.',
      'faqs': [
        {
          'question': 'Giá phòng trọ trung bình ở Cầu Giấy là bao nhiêu?',
          'answer': 'Khu vực Cầu Giấy phòng khép kín dao động từ 2.5 - 4.5 triệu/tháng tùy diện tích và tiện ích.'
        },
        {
          'question': 'Khi ký hợp đồng thuê trọ cần chú ý những gì?',
          'answer': 'Cần lưu ý: Tiền cọc (thường 1 tháng), giá điện nước theo giá nhà nước hay giá riêng, ngày thanh toán, chu kỳ báo trước khi trả phòng.'
        },
        {
          'question': 'Làm thế nào để đặt lịch xem phòng trên app?',
          'answer': 'Bấm vào chi tiết phòng bạn thích, nhấn nút "Đặt lịch xem phòng", chọn ngày giờ và gửi số điện thoại.'
        }
      ],
      'updatedAt': null,
    };
    _cachedAiKnowledge = defaultKnowledge;
    _lastAiKnowledgeFetch = now;
    return Map<String, dynamic>.from(defaultKnowledge);
  }

  Future<void> saveAiKnowledge(Map<String, dynamic> data) async {
    _cachedAiKnowledge = null; // Invalidate cache để cập nhật ngay
    final sanitized = Map<String, dynamic>.from(data);
    if (sanitized.containsKey('modelName')) {
      sanitized['modelName'] =
          RagChatService.normalizeModelName(sanitized['modelName'] as String?);
    }
    sanitized['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('system_settings').doc('ai_knowledge').set(
          sanitized,
          SetOptions(merge: true),
        );
  }
}

