import 'package:cloud_firestore/cloud_firestore.dart';

/// Custom exception để phân biệt lỗi Rate Limit với các lỗi thông thường.
/// UI có thể catch riêng exception này để hiển thị dialog thân thiện.
class RateLimitExceededException implements Exception {
  final String message;
  final DateTime? resetAt; // Thời điểm quota được reset, dùng để hiển thị countdown

  const RateLimitExceededException({
    required this.message,
    this.resetAt,
  });

  @override
  String toString() => message;
}

/// Service quản lý giới hạn số lần gọi AI mỗi ngày (Rate Limiting).
///
/// Lưu trữ: collection `api_limits`, document ID là `userId`.
/// Schema document:
/// ```json
/// {
///   "userId":        "uid_abc123",
///   "requestCount":  12,           // số lần đã gọi hôm nay
///   "resetAt":       Timestamp,    // thời điểm reset về 0 (23:59:59 cùng ngày)
///   "updatedAt":     Timestamp     // lần cuối cập nhật
/// }
/// ```
///
/// Giới hạn mặc định: [dailyLimit] = 50 request/ngày.
/// Có thể truyền giá trị tùy chỉnh nếu muốn thay đổi theo plan của user.
class AiRateLimitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Số request AI tối đa mỗi ngày trên mỗi user.
  static const int dailyLimit = 50;

  /// Kiểm tra quota và tăng counter trong một Firestore Transaction (atomic).
  ///
  /// Quy trình:
  /// 1. Đọc document `api_limits/{userId}`.
  /// 2. Nếu chưa có document → tạo mới với requestCount = 1.
  /// 3. Nếu đã vượt quá resetAt (hết ngày) → reset counter về 1.
  /// 4. Nếu requestCount >= [dailyLimit] và chưa hết ngày → ném [RateLimitExceededException].
  /// 5. Trường hợp hợp lệ → tăng requestCount += 1 và cập nhật Firestore.
  ///
  /// Throw [RateLimitExceededException] nếu quota đã cạn.
  Future<void> checkAndIncrement(String userId) async {
    final docRef = _firestore.collection('api_limits').doc(userId);

    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      final now = DateTime.now();

      // ── Trường hợp 1: User chưa có document quota → Tạo mới ──────────────
      if (!snap.exists) {
        transaction.set(docRef, {
          'userId': userId,
          'requestCount': 1,
          'resetAt': Timestamp.fromDate(_endOfDay(now)),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return; // Hợp lệ, tiến hành gọi API
      }

      final data = snap.data()!;
      final requestCount = (data['requestCount'] ?? 0) as int;
      final resetAtTimestamp = data['resetAt'];

      // Parse thời điểm reset từ Firestore Timestamp
      DateTime? resetAt;
      if (resetAtTimestamp is Timestamp) {
        resetAt = resetAtTimestamp.toDate();
      }

      // ── Trường hợp 2: Đã qua ngày mới (thời gian hiện tại > resetAt) → Reset ──
      if (resetAt == null || now.isAfter(resetAt)) {
        transaction.update(docRef, {
          'requestCount': 1,
          'resetAt': Timestamp.fromDate(_endOfDay(now)),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return; // Quota mới, tiến hành gọi API
      }

      // ── Trường hợp 3: Đã đạt giới hạn, chưa qua ngày mới → Từ chối ──────
      if (requestCount >= dailyLimit) {
        // Tính thời gian còn lại đến khi reset (dùng cho UI countdown nếu cần)
        throw RateLimitExceededException(
          message:
              'Bạn đã đạt giới hạn $dailyLimit câu hỏi AI hôm nay. '
              'Vui lòng quay lại vào ngày mai!',
          resetAt: resetAt,
        );
      }

      // ── Trường hợp 4: Hợp lệ → Tăng counter ─────────────────────────────
      transaction.update(docRef, {
        'requestCount': requestCount + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Lấy thông tin quota hiện tại của user (dùng cho UI hiển thị "X/50 câu hôm nay").
  Future<AiQuotaInfo> getQuotaInfo(String userId) async {
    final doc = await _firestore.collection('api_limits').doc(userId).get();

    if (!doc.exists) {
      return AiQuotaInfo(
        used: 0,
        limit: dailyLimit,
        resetAt: _endOfDay(DateTime.now()),
      );
    }

    final data = doc.data()!;
    final now = DateTime.now();
    final resetAtTs = data['resetAt'];
    DateTime? resetAt;
    if (resetAtTs is Timestamp) resetAt = resetAtTs.toDate();

    // Nếu đã qua ngày, quota thực tế = 0
    final effectiveCount = (resetAt == null || now.isAfter(resetAt))
        ? 0
        : (data['requestCount'] ?? 0) as int;

    return AiQuotaInfo(
      used: effectiveCount,
      limit: dailyLimit,
      resetAt: resetAt ?? _endOfDay(now),
    );
  }

  /// Tính thời điểm 23:59:59.999 của ngày hiện tại (UTC+7).
  DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }
}

/// Data class chứa thông tin quota của user, dùng để hiển thị trên UI.
class AiQuotaInfo {
  final int used;    // Số request đã dùng hôm nay
  final int limit;   // Giới hạn tối đa mỗi ngày
  final DateTime resetAt; // Thời điểm quota được reset

  const AiQuotaInfo({
    required this.used,
    required this.limit,
    required this.resetAt,
  });

  /// Số request còn lại
  int get remaining => (limit - used).clamp(0, limit);

  /// Phần trăm đã dùng (0.0 – 1.0), dùng cho LinearProgressIndicator
  double get usagePercent => used / limit;

  /// True nếu đã cạn quota
  bool get isExhausted => used >= limit;

  @override
  String toString() => 'AiQuotaInfo(used: $used/$limit, resetAt: $resetAt)';
}

