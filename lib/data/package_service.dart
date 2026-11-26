import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../domain/models/package_order.dart';
import '../domain/models/package_plan.dart';
import '../domain/models/room_promotion.dart';

/// Dịch vụ quản lý Gói Đăng Tin và Tích hợp Thanh toán MoMo
class PackageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Có thể truyền qua --dart-define=PAYMENT_API_URL=https://trotot-payment-server.onrender.com
  // hoặc sửa trực tiếp _customPaymentServerUrl bên dưới sau khi deploy miễn phí lên Render.
  static const String _envPaymentApiUrl = String.fromEnvironment('PAYMENT_API_URL');
  static const String _customPaymentServerUrl = 'https://room-finder-app-o3aq.onrender.com';
  static const String _defaultFunctionsRegion = 'asia-southeast1';
  static const String _firebaseProjectId = 'phongtro-ai';

  String get _functionsBaseUrl {
    if (_envPaymentApiUrl.isNotEmpty) return _envPaymentApiUrl;
    if (_customPaymentServerUrl.isNotEmpty) return _customPaymentServerUrl;
    return 'https://$_defaultFunctionsRegion-$_firebaseProjectId.cloudfunctions.net';
  }

  // =========================================================================
  // 1. LẤY DANH SÁCH BẢNG GIÁ GÓI ĐĂNG TIN
  // =========================================================================

  /// Lấy danh sách 3 gói (Đồng, Bạc, Vàng) từ Firestore (hoặc fallback mặc định)
  Future<List<PackagePlan>> getPackagePlans() async {
    try {
      final snap = await _firestore.collection('package_plans').get();
      if (snap.docs.isNotEmpty) {
        final list = snap.docs
            .map((doc) => PackagePlan.fromMap(doc.data(), doc.id))
            .toList();
        list.sort((a, b) => a.priority.compareTo(b.priority));
        return list;
      }
    } catch (_) {}
    return PackagePlan.defaultPlans;
  }

  /// Nạp danh sách 3 gói mặc định lên Firestore nếu chưa có
  Future<void> seedDefaultPlans() async {
    final batch = _firestore.batch();
    for (final plan in PackagePlan.defaultPlans) {
      final docRef = _firestore.collection('package_plans').doc(plan.id);
      batch.set(docRef, plan.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  // =========================================================================
  // 2. KHỞI TẠO ĐƠN HÀNG VÀ YÊU CẦU THANH TOÁN MOMO PHÍA SERVER
  // =========================================================================

  /// Tạo đơn hàng và lấy link thanh toán MoMo an toàn từ Backend (Cloud Function)
  /// TUYỆT ĐỐI không để Secret Key MoMo ở client Flutter.
  Future<Map<String, dynamic>> createMoMoPayment({
    required String roomId,
    required String packageId,
    String? returnUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Vui lòng đăng nhập để thực hiện thanh toán.');
    }

    final idToken = await user.getIdToken();
    final url = Uri.parse('$_functionsBaseUrl/createMoMoPayment');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'roomId': roomId,
          'packageId': packageId,
          'returnUrl': returnUrl ??
              (kIsWeb ? '${Uri.base.origin}/#/payment-result' : 'trotot://payment-result'),
        }),
      );

      final rawBody = utf8.decode(response.bodyBytes);
      Map<String, dynamic> body;
      try {
        body = jsonDecode(rawBody) as Map<String, dynamic>;
      } catch (_) {
        throw Exception(
          'Máy chủ thanh toán đang khởi động hoặc bận (HTTP ${response.statusCode}). Vui lòng thử lại sau vài giây.',
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300 && body['success'] == true) {
        return body;
      } else {
        final errorMsg = body['message'] ?? 'Không thể khởi tạo giao dịch MoMo (${response.statusCode})';
        throw Exception(errorMsg);
      }
    } catch (e) {
      // Nếu Cloud Functions chưa deploy hoặc mất mạng, ta trả về thông tin lỗi chi tiết
      rethrow;
    }
  }

  /// Kiểm tra trạng thái giao dịch từ server (hỗ trợ khi người dùng vừa thanh toán xong)
  Future<Map<String, dynamic>> checkPaymentStatus(String orderId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Chưa đăng nhập');

    final idToken = await user.getIdToken();
    final url = Uri.parse('$_functionsBaseUrl/checkPaymentStatus');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'orderId': orderId}),
      );

      final rawBody = utf8.decode(response.bodyBytes);
      Map<String, dynamic> body;
      try {
        body = jsonDecode(rawBody) as Map<String, dynamic>;
      } catch (_) {
        throw Exception(
          'Máy chủ thanh toán đang khởi động hoặc bận (HTTP ${response.statusCode}). Vui lòng thử lại sau vài giây.',
        );
      }
      return body;
    } catch (_) {
      // Fallback kiểm tra trực tiếp Firestore doc
      final doc = await _firestore.collection('package_orders').doc(orderId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return {
          'success': true,
          'status': data['status'],
          'isCompleted': data['status'] == 'completed',
        };
      }
      return {'success': false, 'status': 'unknown'};
    }
  }

  // =========================================================================
  // 3. THEO DÕI ĐƠN HÀNG VÀ GÓI ĐĂNG TIN THEO THỜI GIAN THỰC (REALTIME)
  // =========================================================================

  /// Lắng nghe stream 1 đơn hàng cụ thể (để tự động chuyển màn hình khi MoMo IPN gửi về)
  Stream<PackageOrder?> streamOrder(String orderId) {
    return _firestore.collection('package_orders').doc(orderId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return PackageOrder.fromMap(doc.data()!, doc.id);
    });
  }

  /// Lấy danh sách lịch sử mua gói của User hiện tại
  Stream<List<PackageOrder>> getMyOrders(String userId) {
    return _firestore
        .collection('package_orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => PackageOrder.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Lấy danh sách gói đang kích hoạt của các phòng do User sở hữu
  Stream<List<RoomPromotion>> getMyPromotions(String userId) {
    return _firestore
        .collection('room_promotions')
        .where('ownerId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => RoomPromotion.fromMap(doc.data(), doc.id))
            .where((p) => p.isActive)
            .toList());
  }

  /// Lấy thông tin gói đang kích hoạt của 1 phòng
  Future<RoomPromotion?> getRoomPromotion(String roomId) async {
    try {
      final doc = await _firestore.collection('room_promotions').doc(roomId).get();
      if (doc.exists && doc.data() != null) {
        final promo = RoomPromotion.fromMap(doc.data()!, doc.id);
        if (promo.isActive) return promo;
      }
    } catch (_) {}
    return null;
  }

  // =========================================================================
  // 4. QUẢN TRỊ VIÊN (ADMIN DASHBOARD)
  // =========================================================================

  /// Lấy toàn bộ đơn hàng (Admin)
  Stream<List<PackageOrder>> getAllOrders({String? statusFilter}) {
    Query query = _firestore.collection('package_orders').orderBy('createdAt', descending: true);
    if (statusFilter != null && statusFilter != 'all') {
      query = query.where('status', isEqualTo: statusFilter);
    }
    return query.snapshots().map((snap) => snap.docs
        .map((doc) => PackageOrder.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }

  /// Lấy toàn bộ danh sách gói xúc tiến đang active (Admin)
  Stream<List<RoomPromotion>> getAllPromotions() {
    return _firestore
        .collection('room_promotions')
        .orderBy('expiresAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => RoomPromotion.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Thống kê doanh thu thực tế dựa trên giao dịch đã hoàn thành
  Future<Map<String, dynamic>> getRevenueStats() async {
    try {
      final snap = await _firestore
          .collection('package_orders')
          .where('status', isEqualTo: 'completed')
          .get();

      double totalRevenue = 0;
      int bronzeCount = 0;
      int silverCount = 0;
      int goldCount = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0).toDouble();
        totalRevenue += amount;

        final pkg = data['packageId'] as String? ?? '';
        if (pkg == 'gold') {
          goldCount++;
        } else if (pkg == 'silver') {
          silverCount++;
        } else if (pkg == 'bronze') {
          bronzeCount++;
        }
      }

      return {
        'totalRevenue': totalRevenue,
        'completedOrders': snap.docs.length,
        'goldCount': goldCount,
        'silverCount': silverCount,
        'bronzeCount': bronzeCount,
      };
    } catch (e) {
      return {
        'totalRevenue': 0.0,
        'completedOrders': 0,
        'goldCount': 0,
        'silverCount': 0,
        'bronzeCount': 0,
      };
    }
  }
}
