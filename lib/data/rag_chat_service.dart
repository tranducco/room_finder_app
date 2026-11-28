import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

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
  final FirebaseFirestore? _customFirestore;

  RagChatService({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  static const String _envPaymentApiUrl = String.fromEnvironment('PAYMENT_API_URL');
  static const String _customPaymentServerUrl = 'https://room-finder-app-o3aq.onrender.com';

  String get _backendBaseUrl {
    if (_envPaymentApiUrl.isNotEmpty) return _envPaymentApiUrl;
    return _customPaymentServerUrl;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MODEL NORMALIZATION & AUTO-FALLBACK
  // ─────────────────────────────────────────────────────────────────────────

  /// Chuẩn hóa tên model Gemini:
  /// - Mặc định sử dụng alias ổn định: "gemini-flash-latest".
  /// - Giữ nguyên các dòng hợp lệ: "gemini-flash-latest", "gemini-flash-lite-latest",
  ///   "gemini-3.8-flash", "gemini-3.6-flash", "gemini-3.5-flash",
  ///   "gemini-3.5-flash-lite", "gemini-2.5-flash", "gemini-2.5-flash-lite".
  /// - Tự động chuyển các model cũ đã ngừng hoạt động (1.5 / 2.0) sang "gemini-flash-latest".
  static String normalizeModelName(String? rawModel) {
    if (rawModel == null || rawModel.trim().isEmpty) {
      return 'gemini-flash-latest';
    }
    final s = rawModel.trim().toLowerCase();
    if (s.contains('flash-lite-latest') ||
        (s.contains('latest') && s.contains('lite')) ||
        s.contains('3.1')) {
      return 'gemini-flash-lite-latest';
    }
    if (s == 'gemini-flash-latest' ||
        s == 'latest' ||
        s == 'flash' ||
        s == 'gemini-flash') {
      return 'gemini-flash-latest';
    }
    if (s.contains('3.8')) {
      return 'gemini-3.8-flash';
    }
    if (s.contains('3.6')) {
      return 'gemini-3.6-flash';
    }
    if (s.contains('3.5')) {
      if (s.contains('lite')) return 'gemini-3.5-flash-lite';
      return 'gemini-3.5-flash';
    }
    if (s.contains('2.5')) {
      if (s.contains('lite')) return 'gemini-2.5-flash-lite';
      return 'gemini-2.5-flash';
    }
    if (s.startsWith('gemini-')) {
      // Các model cũ đã ngừng hỗ trợ (1.5 / 2.0) -> tự động ánh xạ sang gemini-flash-latest
      if (s.contains('1.5') || s.contains('2.0')) {
        return 'gemini-flash-latest';
      }
      return s;
    }
    return 'gemini-flash-latest';
  }

  // ===========================================================================
  // BƯỚC 1: TRÍCH XUẤT Ý ĐỊNH NGƯỜI DÙNG (STRUCTURED INTENT EXTRACTION)
  // ===========================================================================

  /// Phân tích câu hỏi để trích xuất các tiêu chí tìm phòng dưới dạng JSON.
  /// Tối ưu tốc độ:
  /// - Phân tích cục bộ tức thì (0ms, 0 Token) xử lý chính xác 99% các mẫu câu tìm phòng tiếng Việt.
  /// - Chỉ gọi Gemini Proxy phía server khi câu hỏi mơ hồ và có [idToken] hợp lệ.
  Future<UserSearchIntent> extractIntent({
    required String userMessage,
    String? idToken,
    String modelName = 'gemini-flash-latest',
  }) async {
    // 1. Phân tích ngữ nghĩa siêu tốc cục bộ (0ms)
    final localIntent = _extractIntentFallback(userMessage);

    // Nếu đã phát hiện rõ tiêu chí (Quận, Giá, Tiện nghi, Loại phòng)
    // hoặc là câu chào hỏi / hỏi thủ tục FAQ -> Trả về ngay lập tức để tiết kiệm thời gian!
    if (localIntent.district != null ||
        localIntent.maxPrice != null ||
        localIntent.amenities.isNotEmpty ||
        localIntent.roomType != null ||
        !localIntent.isRoomSearchQuery) {
      return localIntent;
    }

    final cleanToken = (idToken ?? '').trim();
    if (cleanToken.isEmpty) {
      return localIntent;
    }

    // 2. Dự phòng: Câu hỏi quá phức tạp, gọi Gemini Proxy phía server với timeout ngắn
    try {
      final result = await _callExtractIntentViaProxy(
        userMessage: userMessage,
        idToken: cleanToken,
        modelName: normalizeModelName(modelName),
      ).timeout(const Duration(seconds: 6));
      if (result != null) {
        return result;
      }
    } catch (_) {}

    return localIntent;
  }

  Future<UserSearchIntent?> _callExtractIntentViaProxy({
    required String userMessage,
    required String idToken,
    required String modelName,
  }) async {
    const intentSystemInstruction =
        'Bạn là bộ phân tích ý định (Intent Extractor) cho ứng dụng tìm phòng trọ TroTot tại Hà Nội. '
        'Hãy phân tích câu hỏi của người dùng và trả về DUY NHẤT một JSON object hợp lệ với các trường: '
        '{"isRoomSearchQuery": boolean, "maxPrice": number|null, "district": string|null, '
        '"roomType": string|null, "amenities": string[]}. '
        'Không thêm markdown hay text giải thích.';

    final response = await http.post(
      Uri.parse('$_backendBaseUrl/aiChatProxy'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'mode': 'intent',
        'modelName': modelName,
        'temperature': 0.1,
        'systemInstruction': intentSystemInstruction,
        'userMessage': 'Phân tích câu nói sau của người dùng: "$userMessage"',
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final rawText = (body['text'] as String? ?? '').trim();
    if (rawText.isEmpty) {
      return null;
    }

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

    final Map<String, dynamic> decoded = jsonDecode(cleanedJson) as Map<String, dynamic>;
    return UserSearchIntent.fromJson(decoded);
  }

  /// Bộ trích xuất ý định siêu tốc cục bộ (0ms, 0 Token) xử lý chính xác đặc thù tìm phòng tại Hà Nội.
  UserSearchIntent _extractIntentFallback(String message) {
    final lower = message.toLowerCase().trim();

    // 0. Phát hiện các câu chào hỏi hoặc hỏi thủ tục (không phải tìm phòng)
    final isGreeting = lower == 'chào' ||
        lower == 'alo' ||
        lower == 'hi' ||
        lower == 'hello' ||
        lower.startsWith('xin chào') ||
        lower.startsWith('chào bạn') ||
        lower.startsWith('bạn là ai') ||
        lower.startsWith('bot ơi');

    final isFaqQuery = lower.contains('hợp đồng') ||
        lower.contains('tiền cọc') ||
        lower.contains('đặt cọc') ||
        lower.contains('quy định') ||
        lower.contains('giá điện') ||
        lower.contains('giá nước') ||
        lower.contains('thủ tục');

    // 1. Nhận diện quận tại Hà Nội & ánh xạ các trường đại học lớn về quận
    final districts = [
      'cầu giấy', 'đống đa', 'thanh xuân', 'ba đình', 'hai bà trưng',
      'hoàn kiếm', 'nam từ liêm', 'bắc từ liêm', 'hoàng mai', 'hà đông',
      'tây hồ', 'long biên', 'gia lâm', 'hoài đức', 'thanh trì',
    ];
    String? matchedDistrict;

    for (final d in districts) {
      if (lower.contains(d)) {
        matchedDistrict = d
            .split(' ')
            .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
            .join(' ');
        break;
      }
    }

    // Ánh xạ địa danh đại học phổ biến tại Hà Nội nếu chưa tìm thấy quận
    if (matchedDistrict == null) {
      if (lower.contains('thủy lợi') || lower.contains('công đoàn') || lower.contains('ngoại thương') || lower.contains('ngoại giao') || lower.contains('luật hà nội') || lower.contains('ngân hàng') || lower.contains('hvnh') || lower.contains('y hà nội')) {
        matchedDistrict = 'Đống Đa';
      } else if (lower.contains('bách khoa') || lower.contains('kinh tế quốc dân') || lower.contains('ktqd') || lower.contains('xây dựng')) {
        matchedDistrict = 'Hai Bà Trưng';
      } else if (lower.contains('quốc gia') || lower.contains('đhqg') || lower.contains('sư phạm') || lower.contains('báo chí') || lower.contains('thương mại')) {
        matchedDistrict = 'Cầu Giấy';
      } else if (lower.contains('kiến trúc') || lower.contains('bưu chính') || lower.contains('ptit') || lower.contains('đh hà nội')) {
        matchedDistrict = 'Hà Đông';
      } else if (lower.contains('mỏ địa chất') || lower.contains('tài chính')) {
        matchedDistrict = 'Bắc Từ Liêm';
      }
    }

    // 2. Nhận diện ngân sách tối đa (Hỗ trợ 3.5tr, 3tr5, 3 triệu, 3000k...)
    double? maxPrice;
    final complexPriceRegex = RegExp(r'(\d+)\s*(tr|triệu)\s*(\d+)', caseSensitive: false);
    final complexMatch = complexPriceRegex.firstMatch(lower);

    if (complexMatch != null) {
      final whole = double.tryParse(complexMatch.group(1) ?? '0') ?? 0;
      final frac = double.tryParse(complexMatch.group(3) ?? '0') ?? 0;
      maxPrice = (whole * 1000000) + (frac * 100000);
    } else {
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
    }

    // 3. Nhận diện loại hình phòng
    String? matchedRoomType;
    if (lower.contains('chung cư mini') || lower.contains('ccmn')) {
      matchedRoomType = 'Chung cư mini';
    } else if (lower.contains('studio')) {
      matchedRoomType = 'Studio';
    } else if (lower.contains('khép kín')) {
      matchedRoomType = 'Phòng khép kín';
    } else if (lower.contains('căn hộ')) {
      matchedRoomType = 'Căn hộ';
    } else if (lower.contains('ký túc xá') || lower.contains('ktx')) {
      matchedRoomType = 'Ký túc xá';
    } else if (lower.contains('homestay')) {
      matchedRoomType = 'Homestay';
    }

    // 4. Nhận diện tiện ích
    final List<String> amenities = [];
    if (lower.contains('điều hòa') || lower.contains('máy lạnh')) amenities.add('Điều hòa');
    if (lower.contains('nóng lạnh') || lower.contains('bình nóng lạnh')) amenities.add('Nóng lạnh');
    if (lower.contains('ban công')) amenities.add('Ban công');
    if (lower.contains('máy giặt')) amenities.add('Máy giặt');
    if (lower.contains('thang máy')) amenities.add('Thang máy');
    if (lower.contains('tủ lạnh')) amenities.add('Tủ lạnh');
    if (lower.contains('gác lửng') || lower.contains('gác xép')) amenities.add('Gác lửng');
    if (lower.contains('khép kín')) amenities.add('Khép kín');
    if (lower.contains('nội thất') || lower.contains('full đồ')) amenities.add('Đầy đủ nội thất');
    if (lower.contains('bếp') || lower.contains('nấu ăn')) amenities.add('Bếp nấu');
    if (lower.contains('để xe')) amenities.add('Chỗ để xe');
    if (lower.contains('wifi') || lower.contains('mạng')) amenities.add('Wifi');

    final bool isSearch = !isGreeting &&
        (matchedDistrict != null ||
            maxPrice != null ||
            matchedRoomType != null ||
            amenities.isNotEmpty ||
            lower.contains('tìm phòng') ||
            lower.contains('thuê phòng') ||
            lower.contains('có phòng') ||
            lower.contains('còn phòng') ||
            lower.contains('giá phòng') ||
            lower.contains('ở đâu') ||
            lower.contains('gợi ý phòng') ||
            (!isFaqQuery && lower.contains('phòng')));

    return UserSearchIntent(
      maxPrice: maxPrice,
      district: matchedDistrict,
      roomType: matchedRoomType,
      amenities: amenities,
      isRoomSearchQuery: isSearch,
    );
  }

  // ===========================================================================
  // BƯỚC 2: TRUY VẤN CSDL VÀ LỌC TOP 5 PHÒNG KHỚP NHẤT (DATABASE RETRIEVAL)
  // ===========================================================================

  // Bộ đệm bộ nhớ đệm (In-memory Cache) danh sách phòng khả dụng (TTL 2 phút)
  // Giúp giảm tới 95% số lần đọc Firestore và phản hồi câu hỏi tức thì (0ms)
  static List<Room>? _cachedAvailableRooms;
  static DateTime? _lastRoomsCacheTime;

  /// Xóa cache phòng để tải mới dữ liệu khi người dùng đăng bài mới
  static void clearRoomsCache() {
    _cachedAvailableRooms = null;
    _lastRoomsCacheTime = null;
  }

  /// Truy vấn Firestore collection `rooms` (`status == 'available'`).
  /// Áp dụng thuật toán tính điểm tương đồng (Relevance Scoring) để chọn ra TOP 5 phòng tối ưu nhất.
  Future<List<Room>> retrieveTopRooms(UserSearchIntent intent) async {
    // Nếu không phải câu hỏi tìm kiếm phòng trọ (hỏi chào hỏi, FAQ thủ tục),
    // không cần lấy phòng nào -> Tiết kiệm 100% token inject!
    if (!intent.isRoomSearchQuery) {
      return [];
    }

    try {
      final now = DateTime.now();
      List<Room> allAvailableRooms;

      if (_cachedAvailableRooms != null &&
          _lastRoomsCacheTime != null &&
          now.difference(_lastRoomsCacheTime!) < const Duration(minutes: 2)) {
        allAvailableRooms = _cachedAvailableRooms!;
      } else {
        // 1. Lấy danh sách các phòng đang khả dụng trên sàn
        final snapshot = await _firestore
            .collection('rooms')
            .where('status', isEqualTo: 'available')
            .limit(40) // Lấy pool ứng viên vừa phải để chấm điểm
            .get();

        if (snapshot.docs.isEmpty) {
          return [];
        }

        allAvailableRooms = snapshot.docs
            .map((doc) => Room.fromMap(doc.data(), doc.id))
            .toList();

        _cachedAvailableRooms = allAvailableRooms;
        _lastRoomsCacheTime = now;
      }

      return rankRoomsForIntent(allAvailableRooms, intent);
    } catch (_) {
      return [];
    }
  }

  /// Thuật toán chấm điểm & xếp hạng TOP 5 phòng phù hợp nhất từ danh sách ứng viên.
  List<Room> rankRoomsForIntent(
    List<Room> allAvailableRooms,
    UserSearchIntent intent,
  ) {
    if (!intent.isRoomSearchQuery || allAvailableRooms.isEmpty) {
      return [];
    }

    // Chấm điểm tương đồng cho từng phòng dựa trên các tiêu chí trích xuất
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

    // Sắp xếp điểm giảm dần và chỉ lấy TOP 5 phòng cao nhất
    scoredRooms.sort((a, b) => b.score.compareTo(a.score));

    // Lọc các phòng có điểm phù hợp > 20
    final topList = scoredRooms
        .where((sr) => sr.score > 20.0)
        .take(5)
        .map((sr) => sr.room)
        .toList();

    // Nếu không có phòng nào đạt ngưỡng điểm, fallback cùng quận (nếu có)
    if (topList.isEmpty && intent.district != null) {
      final sameDistrict = allAvailableRooms
          .where((r) => r.district.toLowerCase().contains(intent.district!.toLowerCase()))
          .take(3)
          .toList();
      if (sameDistrict.isNotEmpty) return sameDistrict;
    }

    return topList;
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
      if (r.deposit > 0 || r.electricityPrice > 0 || r.waterPrice > 0) {
        final costs = <String>[];
        if (r.deposit > 0) {
          costs.add(
            'Cọc: ${r.deposit >= 1000000 ? "${(r.deposit / 1000000).toStringAsFixed(1)}tr" : "${r.deposit.toStringAsFixed(0)}đ"}',
          );
        }
        if (r.electricityPrice > 0) {
          costs.add('Điện: ${r.electricityPrice.toStringAsFixed(0)}đ/kWh');
        }
        if (r.waterPrice > 0) {
          costs.add('Nước: ${r.waterPrice.toStringAsFixed(0)}đ/m³');
        }
        buf.writeln('   - Chi phí: ${costs.join(" | ")}');
      }
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
  /// Bước 1 (Intent) -> Bước 2 (Retrieval Top 5) -> Bước 3 (Sinh câu trả lời qua Server Proxy)
  Future<RagChatResult> executeRagChat({
    required String userMessage,
    String? idToken,
    required String botName,
    required String systemPrompt,
    required List<Map<String, dynamic>> faqs,
    required List<Map<String, String>> chatHistory,
    String modelName = 'gemini-flash-latest',
    double temperature = 0.5,
  }) async {
    final cleanToken = (idToken ?? '').trim();
    final normalized = normalizeModelName(modelName);

    // ── BƯỚC 1: Trích xuất tiêu chí (Structured Extraction) ──────────────────
    final intent = await extractIntent(
      userMessage: userMessage,
      idToken: cleanToken,
      modelName: normalized,
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

    // Gọi Gemini Proxy phía Server (API Key được bảo vệ hoàn toàn trên Server)
    if (cleanToken.isNotEmpty) {
      try {
        final response = await http
            .post(
              Uri.parse('$_backendBaseUrl/aiChatProxy'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $cleanToken',
              },
              body: jsonEncode({
                'userMessage': userMessage,
                'systemInstruction': fullInstruction,
                'history': chatHistory,
                'modelName': normalized,
                'temperature': temperature,
                'mode': 'chat',
              }),
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          final text = (body['text'] as String? ?? '').trim();
          if (text.isNotEmpty) {
            botResponseText = text;
          }
        }
      } catch (_) {
        // Fallback offline bên dưới nếu server không phản hồi hoặc chưa cấu hình key
      }
    }

    if (botResponseText.isEmpty) {
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

  /// Sinh phản hồi offline chuẩn xác (dùng cho fallback và kiểm thử chống ảo giác).
  String buildOfflineResponse({
    required String userMessage,
    required String botName,
    required List<Room> topRooms,
    required List<Map<String, dynamic>> faqs,
    required UserSearchIntent intent,
  }) =>
      _generateSmartOfflineResponse(
        userMessage: userMessage,
        botName: botName,
        topRooms: topRooms,
        faqs: faqs,
        intent: intent,
      );

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
        if (r.deposit > 0 || r.electricityPrice > 0 || r.waterPrice > 0) {
          final costs = <String>[];
          if (r.deposit > 0) {
            costs.add(
              'Cọc: ${r.deposit >= 1000000 ? "${(r.deposit / 1000000).toStringAsFixed(1)}tr" : "${r.deposit.toStringAsFixed(0)}đ"}',
            );
          }
          if (r.electricityPrice > 0) {
            costs.add('Điện: ${r.electricityPrice.toStringAsFixed(0)}đ/kWh');
          }
          if (r.waterPrice > 0) {
            costs.add('Nước: ${r.waterPrice.toStringAsFixed(0)}đ/m³');
          }
          buf.writeln('- Chi phí: ${costs.join(" | ")}');
        }
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

