import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide ChatSession;

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

  // ─────────────────────────────────────────────────────────────────────────
  // MODEL NORMALIZATION & FALLBACK
  // ─────────────────────────────────────────────────────────────────────────

  /// Chuẩn hóa tên model Gemini:
  /// - Nếu người dùng nhập "3.8", "3.8 flash", "gemini-3.8-flash" (tên hiển thị trong IDE)
  ///   -> Tự động ánh xạ về model Flash mới nhất miễn phí của Google: "gemini-2.0-flash".
  /// - Model mặc định miễn phí: "gemini-2.0-flash".
  static String normalizeModelName(String? rawModel) =>
      RagChatService.normalizeModelName(rawModel);

  /// Kiểm tra kết nối tới Gemini API với apiKey và modelName cụ thể (Dùng cho Admin Test Ping)
  Future<String> testGeminiConnection({
    required String apiKey,
    required String modelName,
  }) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      throw Exception('API Key không được để trống! Vui lòng nhập Gemini API Key.');
    }
    final normalizedModel = normalizeModelName(modelName);
    final candidateModels = <String>[
      if (normalizedModel.contains('lite')) normalizedModel,
      'gemini-flash-lite-latest',
      'gemini-3.5-flash-lite',
      if (!normalizedModel.contains('lite')) normalizedModel,
      'gemini-flash-latest',
      'gemini-3.8-flash',
    ];

    String? lastError;
    for (final candidate in candidateModels) {
      try {
        final testModel = GenerativeModel(
          model: candidate,
          apiKey: cleanKey,
          generationConfig: GenerationConfig(temperature: 0.2),
        );

        final response = await testModel.generateContent([
          Content.text('Phản hồi lại đúng 1 từ "OK" để kiểm tra kết nối.'),
        ]).timeout(const Duration(milliseconds: 3500));

        final reply = response.text?.trim() ?? '';
        if (reply.isNotEmpty) {
          if (candidate != normalizedModel) {
            return 'Kết nối thành công! Đã tự động tối ưu hóa sang $candidate (phản hồi siêu nhanh < 1s): $reply';
          }
          return 'Kết nối thành công ($candidate): $reply';
        }
      } catch (e) {
        lastError = e.toString().replaceAll('Exception: ', '');
        continue;
      }
    }

    throw Exception(lastError ?? 'Không thể kết nối đến máy chủ Google Gemini.');
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

    // 2. Tải tri thức & cấu hình hệ thống từ Firestore
    final knowledge = await _adminService.getAiKnowledge();
    final botName = knowledge['botName'] as String? ?? 'Trợ lý ảo TroTot AI';
    final rawModelName = knowledge['modelName'] as String? ?? 'gemini-2.0-flash';
    final modelName = normalizeModelName(rawModelName);
    final temperature = (knowledge['temperature'] as num?)?.toDouble() ?? 0.5;
    final systemPrompt = knowledge['systemPrompt'] as String? ??
        'Bạn là chuyên gia tư vấn tìm phòng trọ thông minh tại Hà Nội.';
    final faqs = List<Map<String, dynamic>>.from(
      (knowledge['faqs'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final configuredApiKey = (knowledge['apiKey'] as String? ?? '').trim();

    // Lấy API Key từ config Firestore hoặc --dart-define
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    final effectiveApiKey = configuredApiKey.isNotEmpty ? configuredApiKey : envKey;

    // 3. Lấy lịch sử hội thoại gần nhất (tối đa 6 tin) để giữ ngữ cảnh đa lượt
    final recentMsgsSnap = await messagesRef
        .orderBy('createdAt', descending: true)
        .limit(6)
        .get();

    final historyDocs = recentMsgsSnap.docs.reversed.toList();
    final List<Content> chatHistory = historyDocs
        .take(historyDocs.length - 1)
        .map((doc) {
          final d = doc.data();
          final isUser = d['sender'] == 'user';
          final txt = d['text'] as String? ?? '';
          return isUser ? Content.text(txt) : Content.model([TextPart(txt)]);
        })
        .toList();

    // 4. Thực thi quy trình RAG 3 bước chuẩn:
    //    Bước 1: Trích xuất Intent -> JSON (có auto-fallback)
    //    Bước 2: Truy vấn CSDL Firestore -> Lọc TOP 5 phòng khớp nhất
    //    Bước 3: Inject gọn 5 phòng vào System Prompt và sinh câu trả lời với cascade model
    final ragResult = await _ragChatService.executeRagChat(
      userMessage: userMessage,
      apiKey: effectiveApiKey,
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
