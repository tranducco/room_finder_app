import 'package:flutter_test/flutter_test.dart';
import 'package:room_finder_app/data/mock_data.dart';
import 'package:room_finder_app/data/rag_chat_service.dart';
import 'package:room_finder_app/domain/models/room.dart';
import 'package:room_finder_app/domain/models/search_intent.dart';

void main() {
  group('Chatbot AI RAG & Anti-Hallucination Evaluation Tests', () {
    final ragService = RagChatService();

    test('Eval 1: Extracts district, price variants, roomType and amenities accurately', () async {
      final q1 = await ragService.extractIntent(
        userMessage: 'Tìm chung cư mini ở Thanh Xuân giá dưới 4tr2 có thang máy và máy giặt',
      );
      expect(q1.isRoomSearchQuery, isTrue);
      expect(q1.district, 'Thanh Xuân');
      expect(q1.maxPrice, 4200000.0);
      expect(q1.roomType, 'Chung cư mini');
      expect(q1.amenities, containsAll(['Thang máy', 'Máy giặt']));

      final q2 = await ragService.extractIntent(
        userMessage: 'Có studio nào tầm 2500k ở Ba Đình có gác xép không?',
      );
      expect(q2.isRoomSearchQuery, isTrue);
      expect(q2.district, 'Ba Đình');
      expect(q2.maxPrice, 2500000.0);
      expect(q2.roomType, 'Studio');
      expect(q2.amenities, contains('Gác lửng'));
    });

    test('Eval 2: Maps major Hanoi university landmarks to exact districts', () async {
      final cases = <String, String>{
        'Tìm phòng gần ĐH Thủy Lợi giá 3 triệu': 'Đống Đa',
        'Có phòng quanh Bách Khoa tầm 3.5tr không': 'Hai Bà Trưng',
        'Phòng trọ gần ĐHQG có điều hòa': 'Cầu Giấy',
        'Thuê phòng gần PTIT Hà Nội': 'Hà Đông',
        'Tìm trọ khu vực Mỏ Địa Chất': 'Bắc Từ Liêm',
      };

      for (final entry in cases.entries) {
        final intent = await ragService.extractIntent(userMessage: entry.key);
        expect(intent.isRoomSearchQuery, isTrue, reason: entry.key);
        expect(intent.district, entry.value, reason: entry.key);
      }
    });

    test('Eval 3: Distinguishes greetings and FAQ procedures from room search queries', () async {
      const nonSearchQueries = [
        'Xin chào',
        'Hi',
        'Bot ơi bạn là ai',
        'Thủ tục đặt cọc và hợp đồng thuê trọ cần lưu ý gì?',
        'Giá điện nước theo quy định ra sao?',
      ];

      for (final q in nonSearchQueries) {
        final intent = await ragService.extractIntent(userMessage: q);
        expect(intent.isRoomSearchQuery, isFalse, reason: q);
      }
    });

    test('Eval 4: RAG rankRoomsForIntent returns at most TOP 5 relevant rooms sorted by score', () {
      const intent = UserSearchIntent(
        isRoomSearchQuery: true,
        district: 'Cầu Giấy',
        maxPrice: 4000000,
        amenities: ['Điều hòa', 'Nóng lạnh'],
      );

      final ranked = ragService.rankRoomsForIntent(mockRooms, intent);

      expect(ranked, isNotEmpty);
      expect(ranked.length, lessThanOrEqualTo(5));
      expect(ranked.first.district.toLowerCase(), contains('cầu giấy'));
      expect(ranked.first.price, lessThanOrEqualTo(4000000));
    });

    test('Eval 5: Anti-Hallucination when matches exist - every [ROOM_ID] exists in retrieved rooms',
        () {
      final intent = const UserSearchIntent(
        isRoomSearchQuery: true,
        district: 'Đống Đa',
        maxPrice: 4500000,
      );
      final topRooms = ragService.rankRoomsForIntent(mockRooms, intent);
      expect(topRooms, isNotEmpty);

      final context = ragService.formatRoomsContext(topRooms);
      final reply = ragService.buildOfflineResponse(
        userMessage: 'Tìm phòng Đống Đa dưới 4.5 triệu',
        botName: 'Trợ lý ảo TroTot AI',
        topRooms: topRooms,
        faqs: const [],
        intent: intent,
      );

      final validIds = topRooms.map((r) => r.roomId).toSet();
      final matches = RegExp(r'\[ROOM_ID:\s*([a-zA-Z0-9_\-]+)\]').allMatches(reply).toList();

      expect(matches, isNotEmpty);
      for (final m in matches) {
        final id = m.group(1);
        expect(validIds, contains(id), reason: 'Hallucinated ROOM_ID: $id');
        expect(context, contains('[MÃ: $id]'));
      }
    });

    test('Eval 6: Anti-Hallucination when NO room matches & accurate FAQ answer', () {
      const emptyIntent = UserSearchIntent(
        isRoomSearchQuery: true,
        district: 'Sóc Sơn',
        maxPrice: 500000,
      );
      final emptyRooms = <Room>[];

      final context = ragService.formatRoomsContext(emptyRooms);
      expect(context, contains('KHÔNG TÌM THẤY'));

      final replyNoMatch = ragService.buildOfflineResponse(
        userMessage: 'Tìm phòng ở Sóc Sơn giá 500k',
        botName: 'Trợ lý ảo TroTot AI',
        topRooms: emptyRooms,
        faqs: const [],
        intent: emptyIntent,
      );

      // Tuyệt đối không bịa ra bất kỳ mã [ROOM_ID: ...] nào khi không có phòng phù hợp
      final fabricatedIds = RegExp(r'\[ROOM_ID:').allMatches(replyNoMatch);
      expect(fabricatedIds, isEmpty);
      expect(replyNoMatch, contains('chưa tìm thấy'));

      // Trả lời FAQ chính xác theo tri thức cấu hình
      final faqReply = ragService.buildOfflineResponse(
        userMessage: 'Khi ký hợp đồng thuê trọ cần chú ý những gì?',
        botName: 'Trợ lý ảo TroTot AI',
        topRooms: const [],
        faqs: const [
          {
            'question': 'Khi ký hợp đồng thuê trọ cần chú ý những gì?',
            'answer': 'Kiểm tra kỹ tiền cọc, giá điện nước và điều khoản trả phòng.',
          },
        ],
        intent: const UserSearchIntent(isRoomSearchQuery: false),
      );
      expect(faqReply, contains('Kiểm tra kỹ tiền cọc, giá điện nước và điều khoản trả phòng.'));
    });
  });
}
