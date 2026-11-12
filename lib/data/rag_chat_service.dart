import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../domain/models/room.dart';
import '../domain/models/search_intent.dart';

/// Kết quả trả về sau quy trình RAG 3 bước.
class RagChatResult {
  final String botReply;
  final List<String> suggestedRoomIds;
  final List<Room> topRooms;
  final UserSearchIntent intent;

  const RagChatResult({
    required this.botReply,
    required this.suggestedRoomIds,
    required this.topRooms,
    required this.intent,
  });
}

/// Dịch vụ RAG (Retrieval-Augmented Generation) chuẩn cho Chatbot AI TroTot.
///
/// Kiến trúc 3 bước tối ưu Context Window:
/// - Bước 1: Trích xuất ý định (Intent Extraction) từ câu hỏi thành JSON có cấu trúc.
/// - Bước 2: Truy vấn Firestore collection `rooms` và xếp hạng để chỉ lấy TOP 5 phòng tốt nhất.
/// - Bước 3: Inject gọn 5 phòng này vào System Prompt để sinh câu trả lời tự nhiên, thân thiện.
class RagChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ===========================================================================
  // BƯỚC 1: TRÍCH XUẤT Ý ĐỊNH NGƯỜI DÙNG (STRUCTURED INTENT EXTRACTION)
  // ===========================================================================

  /// Gửi câu hỏi của người dùng tới Gemini để trích xuất các tiêu chí tìm phòng dưới dạng JSON.
  /// Sử dụng JSON Schema (Structured Outputs) để đảm bảo đầu ra luôn chuẩn xác.
  Future<UserSearchIntent> extractIntent({
    required String userMessage,
    required String apiKey,
    String modelName = 'gemini-1.5-flash',
  }) async {
    // Nếu chưa có API Key, dùng bộ trích xuất dự phòng Offline bằng Regex
    if (apiKey.trim().isEmpty) {
      return _extractIntentFallback(userMessage);
    }

    try {
      final intentModel = GenerativeModel(
        model: modelName,
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: Schema.object(
            properties: {
              'isRoomSearchQuery': Schema.boolean(
                description:
                    'true nếu người dùng đang tìm kiếm, hỏi thuê phòng trọ; '
                    'false nếu chỉ chào hỏi hoặc hỏi thủ tục, quy định chung.',
              ),
              'maxPrice': Schema.number(
                description:
                    'Ngân sách tối đa tính bằng VNĐ (Ví dụ: "3 triệu", "3tr", "3000k" -> 3000000; "2.5tr" -> 2500000). Null nếu không nhắc đến giá.',
                nullable: true,
              ),
              'district': Schema.string(
                description:
                    'Tên quận tại Hà Nội chuẩn hóa tiếng Việt (Ví dụ: "Cầu Giấy", "Đống Đa", "Thanh Xuân", "Ba Đình", "Hai Bà Trưng", "Nam Từ Liêm", "Bắc Từ Liêm", "Hoàng Mai", "Hà Đông", "Tây Hồ"). Null nếu không nhắc đến khu vực.',
                nullable: true,
              ),
              'roomType': Schema.string(
                description:
                    'Loại hình phòng (Ví dụ: "Phòng khép kín", "Chung cư mini", "Căn hộ", "Ký túc xá"). Null nếu không nhắc.',
                nullable: true,
              ),
              'amenities': Schema.array(
                items: Schema.string(),
                description:
                    'Danh sách tiện nghi mong muốn (Ví dụ: "Điều hòa", "Nóng lạnh", "Ban công", "Máy giặt", "Thang máy", "Tủ lạnh").',
              ),
            },
            requiredProperties: ['isRoomSearchQuery', 'amenities'],
          ),
          temperature: 0.1, // Nhiệt độ thấp để phân tích chính xác, không sáng tạo
        ),
        systemInstruction: Content.system(
          'Bạn là bộ phân tích ý định (Intent Extractor) cho ứng dụng tìm phòng trọ TroTot tại Hà Nội. '
          'Nhiệm vụ của bạn là bóc tách các tiêu chí người dùng yêu cầu ra JSON đúng schema. '
          'Chỉ trả về JSON thuần túy, không có text dẫn dụ.',
        ),
      );

      final response = await intentModel.generateContent([
        Content.text('Phân tích câu nói sau của người dùng: "$userMessage"'),
      ]);

      final rawText = response.text?.trim() ?? '';
      if (rawText.isEmpty) {
        return _extractIntentFallback(userMessage);
      }

      // Loại bỏ markdown code block nếu có
      String cleanedJson = rawText;
      if (cleanedJson.startsWith('```json')) {
        cleanedJson = cleanedJson.replaceFirst('```json', '');
      } else if (cleanedJson.startsWith('```')) {
        cleanedJson = cleanedJson.replaceFirst('```', '');
      }
      if (cleanedJson.endsWith('```')) {
        cleanedJson = cleanedJson.substring(0, cleanedJson.length - 3);
      }
      cleanedJson = cleanedJson.trim();

      final Map<String, dynamic> decoded = jsonDecode(cleanedJson);
      return UserSearchIntent.fromJson(decoded);
    } catch (_) {
      // Khi API lỗi hoặc parse fail, fallback phân tích regex cục bộ để không gián đoạn
      return _extractIntentFallback(userMessage);
    }
  }

  /// Bộ trích xuất Regex dự phòng khi mất kết nối API hoặc xử lý offline.
  UserSearchIntent _extractIntentFallback(String message) {
    final lower = message.toLowerCase();

    // 1. Nhận diện quận tại Hà Nội
    final districts = [
      'cầu giấy', 'đống đa', 'thanh xuân', 'ba đình', 'hai bà trưng',
      'hoàn kiếm', 'nam từ liêm', 'bắc từ liêm', 'hoàng mai', 'hà đông',
      'tây hồ', 'long biên',
    ];
    String? matchedDistrict;
    for (final d in districts) {
      if (lower.contains(d)) {
        // Viết hoa chữ cái đầu cho chuẩn
        matchedDistrict = d
            .split(' ')
            .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
            .join(' ');
        break;
      }
    }

    // 2. Nhận diện ngân sách (Ví dụ: "3 triệu", "3tr", "3.5tr", "3000k")
    double? maxPrice;
    final priceRegex = RegExp(r'(\d+([.,]\d+)?)\s*(triệu|tr|k|nghìn)', caseSensitive: false);
    final match = priceRegex.firstMatch(lower);
    if (match != null) {
      final numStr = match.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(numStr);
      final unit = match.group(3)!.toLowerCase();
      if (val != null) {
        if (unit == 'triệu' || unit == 'tr') {
          maxPrice = val * 1000000;
        } else if (unit == 'k' || unit == 'nghìn') {
          maxPrice = val * 1000;
        }
      }
    }

    // 3. Nhận diện tiện ích
    final List<String> amenities = [];
    if (lower.contains('điều hòa') || lower.contains('máy lạnh')) amenities.add('Điều hòa');
    if (lower.contains('nóng lạnh') || lower.contains('bình nóng lạnh')) amenities.add('Nóng lạnh');
    if (lower.contains('ban công')) amenities.add('Ban công');
    if (lower.contains('máy giặt')) amenities.add('Máy giặt');
    if (lower.contains('thang máy')) amenities.add('Thang máy');
    if (lower.contains('gác lửng') || lower.contains('gác xép')) amenities.add('Gác lửng');
    if (lower.contains('khép kín')) amenities.add('Khép kín');

    final isSearch = matchedDistrict != null ||
        maxPrice != null ||
        amenities.isNotEmpty ||
        lower.contains('tìm phòng') ||
        lower.contains('thuê phòng') ||
        lower.contains('có phòng');

    return UserSearchIntent(
      maxPrice: maxPrice,
      district: matchedDistrict,
      amenities: amenities,
      isRoomSearchQuery: isSearch,
    );
  }

  // ===========================================================================
  // BƯỚC 2: TRUY VẤN CSDL VÀ LỌC TOP 5 PHÒNG KHỚP NHẤT (DATABASE RETRIEVAL)
  // ===========================================================================

  /// Truy vấn Firestore collection `rooms` (`status == 'available'`).
  /// Áp dụng thuật toán tính điểm tương đồng (Relevance Scoring) để chọn ra TOP 5 phòng tối ưu nhất.
  Future<List<Room>> retrieveTopRooms(UserSearchIntent intent) async {
    // Nếu không phải câu hỏi tìm kiếm phòng trọ (hỏi chào hỏi, FAQ thủ tục),
    // không cần lấy phòng nào -> Tiết kiệm 100% token inject!
    if (!intent.isRoomSearchQuery) {
      return [];
    }

    try {
      // 1. Lấy danh sách các phòng đang khả dụng trên sàn
      final snapshot = await _firestore
          .collection('rooms')
          .where('status', isEqualTo: 'available')
          .limit(40) // Lấy pool ứng viên vừa phải để chấm điểm
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      final List<Room> allAvailableRooms = snapshot.docs
          .map((doc) => Room.fromMap(doc.data(), doc.id))
          .toList();

      // 2. Chấm điểm tương đồng cho từng phòng dựa trên các tiêu chí trích xuất
      final scoredRooms = <_ScoredRoom>[];

      for (final room in allAvailableRooms) {
        double score = 0.0;

        // Chuẩn hóa giá của phòng về đơn vị VNĐ để so sánh
        final roomPriceVnd = room.price < 1000 ? room.price * 1000000 : room.price;

        // Tiêu chí 1: Khớp quận / khu vực (Trọng số cao nhất: 40 điểm)
        if (intent.district != null && intent.district!.isNotEmpty) {
          final targetDist = intent.district!.toLowerCase();
          final roomDist = room.district.toLowerCase();
          final roomAddr = room.address.toLowerCase();

          if (roomDist.contains(targetDist) || targetDist.contains(roomDist)) {
            score += 40.0;
          } else if (roomAddr.contains(targetDist)) {
            score += 30.0;
          }
        } else {
          // Người dùng không nêu quận cụ thể -> chia đều cơ hội
          score += 15.0;
        }

        // Tiêu chí 2: Khớp ngân sách tối đa (Trọng số 30 điểm)
        if (intent.maxPrice != null && intent.maxPrice! > 0) {
          if (roomPriceVnd <= intent.maxPrice!) {
            score += 30.0; // Hoàn toàn dưới ngân sách
          } else if (roomPriceVnd <= intent.maxPrice! * 1.15) {
            score += 15.0; // Vượt nhẹ không quá 15% (đề xuất tham khảo)
          }
        } else {
          score += 10.0;
        }

        // Tiêu chí 3: Khớp tiện nghi (Trọng số 20 điểm)
        if (intent.amenities.isNotEmpty) {
          int matchAmenityCount = 0;
          for (final am in intent.amenities) {
            final target = am.toLowerCase();
            final hasMatch = room.amenities.any(
              (a) => a.toLowerCase().contains(target) || target.contains(a.toLowerCase()),
            );
            if (hasMatch) matchAmenityCount++;
          }
          final matchRatio = matchAmenityCount / intent.amenities.length;
          score += matchRatio * 20.0;
        } else {
          score += 10.0;
        }

        // Tiêu chí 4: Khớp loại hình phòng (Trọng số 10 điểm)
        if (intent.roomType != null && intent.roomType!.isNotEmpty) {
          final targetType = intent.roomType!.toLowerCase();
          final rType = room.roomType.toLowerCase();
          if (rType.contains(targetType) || targetType.contains(rType)) {
            score += 10.0;
          }
        }

        // Thưởng nhẹ cho phòng có đánh giá sao cao (0 - 5 điểm)
        score += (room.averageRating / 5.0) * 5.0;

        scoredRooms.add(_ScoredRoom(room: room, score: score));
      }

      // 3. Sắp xếp điểm giảm dần và chỉ lấy TOP 5 phòng cao nhất
      scoredRooms.sort((a, b) => b.score.compareTo(a.score));

      // Lọc các phòng có điểm phù hợp > 0 (nếu có tiêu chí lọc)
      final topList = scoredRooms
          .where((sr) => sr.score > 20.0)
          .take(5)
          .map((sr) => sr.room)
          .toList();

      // Nếu không có phòng nào đạt ngưỡng điểm (do người dùng tìm quá ngặt nghèo),
      // Fallback: trả về 3 phòng gần mức giá nhất hoặc để trống để Gemini tư vấn
      if (topList.isEmpty && allAvailableRooms.isNotEmpty) {
        if (intent.district != null) {
          // Thử lấy phòng cùng quận bất kể giá
          final sameDistrict = allAvailableRooms
              .where((r) => r.district.toLowerCase().contains(intent.district!.toLowerCase()))
              .take(3)
              .toList();
          if (sameDistrict.isNotEmpty) return sameDistrict;
        }
      }

      return topList;
    } catch (_) {
      return [];
    }
  }

  // ===========================================================================
  // BƯỚC 3: INJECT VÀO PROMPT VÀ SINH CÂU TRẢ LỜI (GENERATION)
  // ===========================================================================

  /// Định dạng ngắn gọn danh sách 5 phòng trọ thành đoạn text ngữ cảnh để inject vào System Prompt.
  /// Giúp giảm tới 90% số lượng token so với việc inject toàn bộ CSDL.
  String formatRoomsContext(List<Room> rooms) {
    if (rooms.isEmpty) {
      return 'KẾT QUẢ TÌM KIẾM TRONG HỆ THỐNG: Hiện tại KHÔNG TÌM THẤY phòng nào phù hợp 100% với các tiêu chí người dùng đưa ra.';
    }

    final buf = StringBuffer();
    buf.writeln('DANH SÁCH ${rooms.length} PHÒNG PHÙ HỢP NHẤT TÌM THẤY TỪ HỆ THỐNG TROTOT:');
    for (int i = 0; i < rooms.length; i++) {
      final r = rooms[i];
      final priceDisplay = r.price >= 1000000
          ? '${(r.price / 1000000).toStringAsFixed(1)} triệu'
          : '${r.price} triệu';

      buf.writeln('${i + 1}. [MÃ: ${r.roomId}] "${r.title}"');
      buf.writeln('   - Giá: $priceDisplay/tháng | Diện tích: ${r.area}m²');
      buf.writeln('   - Địa chỉ: ${r.address} (Quận: ${r.district})');
      buf.writeln('   - Loại phòng: ${r.roomType.isNotEmpty ? r.roomType : "Phòng trọ"}');
      if (r.amenities.isNotEmpty) {
        buf.writeln('   - Tiện nghi: ${r.amenities.join(", ")}');
      }
      if (r.averageRating > 0) {
        buf.writeln('   - Đánh giá: ${r.averageRating}/5⭐ (${r.totalReviews} lượt)');
      }
    }
    return buf.toString();
  }

  /// Thực hiện quy trình RAG hoàn chỉnh:
  /// Bước 1 (Intent) -> Bước 2 (Retrieval Top 5) -> Bước 3 (Sinh câu trả lời với Gemini)
  Future<RagChatResult> executeRagChat({
    required String userMessage,
    required String apiKey,
    required String botName,
    required String systemPrompt,
    required List<Map<String, dynamic>> faqs,
    required List<Content> chatHistory,
    String modelName = 'gemini-1.5-flash',
    double temperature = 0.5,
  }) async {
    // ── BƯỚC 1: Trích xuất tiêu chí (Structured Extraction) ──────────────────
    final intent = await extractIntent(
      userMessage: userMessage,
      apiKey: apiKey,
      modelName: modelName,
    );

    // ── BƯỚC 2: Truy vấn CSDL để lấy TOP 5 phòng phù hợp ───────────────────
    final topRooms = await retrieveTopRooms(intent);

    // ── BƯỚC 3: Xây dựng System Prompt với Context tối ưu ───────────────────
    final roomsContext = formatRoomsContext(topRooms);

    final StringBuffer faqsContext = StringBuffer();
    if (faqs.isNotEmpty) {
      faqsContext.writeln('CÂU HỎI THƯỜNG GẶP (FAQ) & GIẢI ĐÁP:');
      for (var f in faqs) {
        faqsContext.writeln('- Q: ${f['question']}');
        faqsContext.writeln('  A: ${f['answer']}');
      }
    }

    final fullInstruction = '''
$systemPrompt

Tên của bạn: $botName.
Bạn là trợ lý ảo bất động sản chuyên nghiệp của nền tảng Trọ Tốt (TroTot).
Hãy trả lời lịch sự, thân thiện, súc tích bằng tiếng Việt tự nhiên.

$faqsContext

$roomsContext

QUY TẮC PHẢN HỒI QUAN TRỌNG:
1. Khi người dùng muốn tìm phòng:
   - Dựa vào DANH SÁCH PHÒNG PHÙ HỢP ở trên để tư vấn các căn tốt nhất.
   - BẮT BUỘC: Khi nhắc tới hoặc gợi ý bất kỳ phòng nào, PHẢI đính kèm mã phòng theo đúng cú pháp: [ROOM_ID: <Mã_phòng>]. Ví dụ: "Căn phòng này rất thoáng: [ROOM_ID: ${topRooms.isNotEmpty ? topRooms.first.roomId : 'room_01'}]".
2. Trường hợp KHÔNG CÓ PHÒNG PHÙ HỢP:
   - Hãy giải thích lịch sự, nhẹ nhàng rằng hiện chưa có phòng trùng khớp hoàn toàn các tiêu chí trên hệ thống.
   - Gợi ý người dùng mở rộng khu vực tìm kiếm sang quận lân cận hoặc nâng ngân sách một chút để có thêm lựa chọn.
3. Nếu người dùng chỉ chào hỏi hoặc hỏi thủ tục (đặt cọc, hợp đồng, giấy tờ):
   - Trả lời dựa trên thông tin FAQ hoặc kinh nghiệm thuê trọ chuẩn xác, không tự ý bịa đặt.
''';

    String botResponseText = '';
    final List<String> suggestedRoomIds = [];

    // Gọi Gemini API sinh phản hồi
    if (apiKey.isNotEmpty) {
      try {
        final chatModel = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          generationConfig: GenerationConfig(temperature: temperature),
          systemInstruction: Content.system(fullInstruction),
        );

        final chat = chatModel.startChat(history: chatHistory);
        final response = await chat.sendMessage(Content.text(userMessage));
        botResponseText = response.text ?? 'Xin lỗi, tôi chưa hiểu rõ yêu cầu của bạn.';
      } catch (_) {
        // Fallback tạo câu trả lời offline thông minh
        botResponseText = _generateSmartOfflineResponse(
          userMessage: userMessage,
          botName: botName,
          topRooms: topRooms,
          faqs: faqs,
          intent: intent,
        );
      }
    } else {
      // Khi chưa cấu hình API Key: Chạy bộ suy luận offline
      botResponseText = _generateSmartOfflineResponse(
        userMessage: userMessage,
        botName: botName,
        topRooms: topRooms,
        faqs: faqs,
        intent: intent,
      );
    }

    // Trích xuất mã [ROOM_ID: ...] từ câu trả lời của bot
    final regExp = RegExp(r'\[ROOM_ID:\s*([a-zA-Z0-9_\-]+)\]');
    final matches = regExp.allMatches(botResponseText);
    for (var m in matches) {
      final rId = m.group(1);
      if (rId != null && !suggestedRoomIds.contains(rId)) {
        suggestedRoomIds.add(rId);
      }
    }

    // Nếu bot quên gắn mã ROOM_ID nhưng topRooms có sẵn, tự động bổ sung danh sách ID gợi ý
    if (suggestedRoomIds.isEmpty && topRooms.isNotEmpty && intent.isRoomSearchQuery) {
      suggestedRoomIds.addAll(topRooms.take(2).map((r) => r.roomId));
    }

    return RagChatResult(
      botReply: botResponseText,
      suggestedRoomIds: suggestedRoomIds,
      topRooms: topRooms,
      intent: intent,
    );
  }

  /// Bộ sinh phản hồi Offline dự phòng thông minh (Đảm bảo demo đồ án không bao giờ lỗi)
  String _generateSmartOfflineResponse({
    required String userMessage,
    required String botName,
    required List<Room> topRooms,
    required List<Map<String, dynamic>> faqs,
    required UserSearchIntent intent,
  }) {
    final lower = userMessage.toLowerCase();

    // 1. Khớp FAQ
    for (var f in faqs) {
      final q = (f['question'] as String? ?? '').toLowerCase();
      if (lower.contains(q) || q.contains(lower)) {
        return '🤖 **$botName:** ${f['answer']}';
      }
    }

    // 2. Nếu tìm được phòng từ topRooms
    if (topRooms.isNotEmpty) {
      final buf = StringBuffer();
      buf.writeln('Chào bạn! Dựa trên yêu cầu của bạn, $botName đã tìm thấy các căn phòng phù hợp nhất dưới đây:\n');
      for (var r in topRooms.take(3)) {
        final priceDisplay = r.price >= 1000000
            ? '${(r.price / 1000000).toStringAsFixed(1)} triệu'
            : '${r.price} triệu';
        buf.writeln('🏠 **${r.title}**');
        buf.writeln('- Khu vực: **${r.district}** (${r.address})');
        buf.writeln('- Giá thuê: **$priceDisplay/tháng** | Diện tích: ${r.area}m²');
        if (r.amenities.isNotEmpty) {
          buf.writeln('- Tiện nghi: ${r.amenities.join(", ")}');
        }
        buf.writeln('👉 Xem chi tiết ngay: [ROOM_ID: ${r.roomId}]\n');
      }
      buf.writeln('Bạn có thể bấm vào thẻ phòng bên dưới để xem hình ảnh và đặt lịch hẹn xem phòng trực tiếp nhé!');
      return buf.toString();
    }

    // 3. Nếu không có phòng nào khớp
    if (intent.isRoomSearchQuery) {
      final districtStr = intent.district != null ? ' tại khu vực ${intent.district}' : '';
      return 'Chào bạn! Hiện tại Trọ Tốt chưa tìm thấy phòng trọ nào khớp chính xác với tiêu chí của bạn$districtStr. '
          'Bạn thử nới rộng ngân sách một chút hoặc tìm kiếm thêm ở các quận lân cận để xem thêm các phòng đẹp nhé!';
    }

    return 'Chào bạn! Tôi là $botName. Bạn đang muốn tìm phòng trọ tại khu vực nào ở Hà Nội, khoảng giá bao nhiêu để tôi hỗ trợ tìm kiếm tốt nhất cho bạn nhé!';
  }
}

/// Helper class hỗ trợ chấm điểm tương quan của phòng
class _ScoredRoom {
  final Room room;
  final double score;

  const _ScoredRoom({required this.room, required this.score});
}

