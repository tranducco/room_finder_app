import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../domain/models/chat_message.dart';
import '../domain/models/chat_session.dart';
import 'admin_service.dart';
import 'ai_rate_limit_service.dart';
import 'rag_chat_service.dart';

class AiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();
  final AiRateLimitService _rateLimitService = AiRateLimitService();
  final RagChatService _ragChatService = RagChatService();

  static const String _envPaymentApiUrl = String.fromEnvironment('PAYMENT_API_URL');
  static const String _customPaymentServerUrl = 'https://room-finder-app-o3aq.onrender.com';

  String get _backendBaseUrl {
    if (_envPaymentApiUrl.isNotEmpty) return _envPaymentApiUrl;
    return _customPaymentServerUrl;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MODEL NORMALIZATION & SERVER PROXY
  // ─────────────────────────────────────────────────────────────────────────

  /// Chuẩn hóa tên model Gemini đồng bộ với [RagChatService.normalizeModelName]:
  /// - Mặc định sử dụng alias ổn định: "gemini-flash-latest".
  /// - Tự động chuyển các model cũ đã ngừng hoạt động (1.5 / 2.0) sang "gemini-flash-latest".
  static String normalizeModelName(String? rawModel) =>
      RagChatService.normalizeModelName(rawModel);

  /// Kiểm tra kết nối tới Gemini API thông qua Backend Proxy (không giữ key trên client).
  Future<String> testGeminiConnection({
    required String modelName,
    String? apiKey,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Vui lòng đăng nhập tài khoản Admin để kiểm tra kết nối AI.');
    }

    final idToken = await user.getIdToken();
    final normalizedModel = normalizeModelName(modelName);
    final payload = <String, dynamic>{
      'modelName': normalizedModel,
      if (apiKey != null && apiKey.trim().isNotEmpty) 'apiKey': apiKey.trim(),
    };

    final response = await http
        .post(
          Uri.parse('$_backendBaseUrl/testGeminiConnection'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));

    final rawBody = utf8.decode(response.bodyBytes);
    Map<String, dynamic> body;
    try {
      body = jsonDecode(rawBody) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Máy chủ AI Proxy đang khởi động hoặc bận (HTTP ${response.statusCode}).');
    }

    if (response.statusCode >= 200 && response.statusCode < 300 && body['success'] == true) {
      return body['message'] as String? ?? 'Kết nối thành công!';
    }
    throw Exception(body['message'] as String? ?? 'Không thể kết nối đến máy chủ Google Gemini.');
  }

  /// Kiểm tra trạng thái cấu hình GEMINI_API_KEY trên server (chỉ trả metadata, không trả raw key).
  Future<Map<String, dynamic>> getServerAiKeyStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {'configured': false, 'source': 'none'};
    }
    try {
      final idToken = await user.getIdToken();
      final response = await http
          .get(
            Uri.parse('$_backendBaseUrl/admin/aiKeyStatus'),
            headers: {'Authorization': 'Bearer $idToken'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {'configured': false, 'source': 'unknown'};
  }

  // 1. Lấy hoặc tạo phiên hội thoại mới
  Future<String> createSession(String userId, String firstMessage) async {
    final title = firstMessage.length > 40
        ? '${firstMessage.substring(0, 37)}...'
        : firstMessage;

    final docRef = await _firestore.collection('chat_histories').add({
      'userId': userId,
      'title': title,
      'lastMessage': firstMessage,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  // 2. Stream danh sách các phiên hội thoại của người dùng
  Stream<List<ChatSession>> getUserSessionsStream(String userId) {
    return _firestore
        .collection('chat_histories')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => ChatSession.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) {
        if (a.updatedAt == null) return 1;
        if (b.updatedAt == null) return -1;
        return b.updatedAt!.compareTo(a.updatedAt!);
      });
      return list;
    });
  }

  // 3. Xóa một phiên hội thoại
  Future<void> deleteSession(String sessionId) async {
    final msgs = await _firestore
        .collection('chat_histories')
        .doc(sessionId)
        .collection('messages')
        .get();
    final batch = _firestore.batch();
    for (var doc in msgs.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_firestore.collection('chat_histories').doc(sessionId));
    await batch.commit();
  }

  // 4. Stream tin nhắn của một phiên hội thoại
  Stream<List<ChatMessage>> getMessagesStream(String sessionId) {
    return _firestore
        .collection('chat_histories')
        .doc(sessionId)
        .collection('messages')
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => ChatMessage.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) {
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return a.createdAt!.compareTo(b.createdAt!);
      });
      return list;
    });
  }

  // 5. Gửi tin nhắn và nhận phản hồi từ Gemini AI (kèm Context Injection RAG)
  Future<void> sendMessage({
    required String sessionId,
    required String userId,
    required String userMessage,
  }) async {
    // ── RATE LIMITING: Kiểm tra quota trước khi làm bất cứ điều gì ──────────
    // Throw RateLimitExceededException nếu user đã vượt 50 request/ngày.
    await _rateLimitService.checkAndIncrement(userId);

    // 1. Lưu tin nhắn của người dùng vào Firestore
    final messagesRef = _firestore
        .collection('chat_histories')
        .doc(sessionId)
        .collection('messages');

    await messagesRef.add({
      'sender': 'user',
      'text': userMessage,
      'suggestedRoomIds': [],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('chat_histories').doc(sessionId).update({
      'lastMessage': userMessage,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Tải tri thức & cấu hình hệ thống từ Firestore (không đọc apiKey ở client)
    final knowledge = await _adminService.getAiKnowledge();
    final botName = knowledge['botName'] as String? ?? 'Trợ lý ảo TroTot AI';
    final rawModelName = knowledge['modelName'] as String? ?? 'gemini-flash-latest';
    final modelName = normalizeModelName(rawModelName);
    final temperature = (knowledge['temperature'] as num?)?.toDouble() ?? 0.5;
    final systemPrompt = knowledge['systemPrompt'] as String? ??
        'Bạn là chuyên gia tư vấn tìm phòng trọ thông minh tại Hà Nội.';
    final faqs = List<Map<String, dynamic>>.from(
      (knowledge['faqs'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );

    // 3. Lấy lịch sử hội thoại gần nhất (tối đa 6 tin) để giữ ngữ cảnh đa lượt
    final recentMsgsSnap = await messagesRef
        .orderBy('createdAt', descending: true)
        .limit(6)
        .get();

    final historyDocs = recentMsgsSnap.docs.reversed.toList();
    final List<Map<String, String>> chatHistory = historyDocs
        .take(historyDocs.isNotEmpty ? historyDocs.length - 1 : 0)
        .map((doc) {
          final d = doc.data();
          final isUser = d['sender'] == 'user';
          final txt = d['text'] as String? ?? '';
          return {'role': isUser ? 'user' : 'model', 'text': txt};
        })
        .toList();

    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();

    // 4. Thực thi quy trình RAG 3 bước qua Server Proxy
    final ragResult = await _ragChatService.executeRagChat(
      userMessage: userMessage,
      idToken: idToken,
      botName: botName,
      systemPrompt: systemPrompt,
      faqs: faqs,
      chatHistory: chatHistory,
      modelName: modelName,
      temperature: temperature,
    );

    final botResponseText = ragResult.botReply;
    final suggestedRoomIds = ragResult.suggestedRoomIds;

    // 5. Lưu phản hồi của bot vào Firestore
    await messagesRef.add({
      'sender': 'model',
      'text': botResponseText,
      'suggestedRoomIds': suggestedRoomIds,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('chat_histories').doc(sessionId).update({
      'lastMessage': botResponseText.length > 50
          ? '${botResponseText.substring(0, 47)}...'
          : botResponseText,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
