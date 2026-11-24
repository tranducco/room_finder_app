import 'package:flutter_test/flutter_test.dart';
import 'package:room_finder_app/data/ai_service.dart';
import 'package:room_finder_app/data/rag_chat_service.dart';
import 'package:room_finder_app/domain/models/room.dart';

void main() {
  group('AI Service Model Normalization Tests', () {
    test('Normalizes 3.8 flash variations to gemini-3.8-flash', () {
      expect(AiService.normalizeModelName('3.8 flash'), 'gemini-3.8-flash');
      expect(AiService.normalizeModelName('gemini-3.8-flash'), 'gemini-3.8-flash');
      expect(AiService.normalizeModelName('3.8'), 'gemini-3.8-flash');
      expect(AiService.normalizeModelName('latest'), 'gemini-3.8-flash');
      expect(AiService.normalizeModelName('flash'), 'gemini-3.8-flash');
      expect(RagChatService.normalizeModelName('3.8 flash'), 'gemini-3.8-flash');
    });

    test('Normalizes 3.6, 3.5, and maps deprecated 1.5/2.0 to 3.8', () {
      expect(AiService.normalizeModelName('gemini-3.6-flash'), 'gemini-3.6-flash');
      expect(AiService.normalizeModelName('gemini-3.5-flash'), 'gemini-3.5-flash');
      expect(AiService.normalizeModelName('gemini-1.5-flash'), 'gemini-3.8-flash');
      expect(AiService.normalizeModelName('gemini-2.0-flash'), 'gemini-3.8-flash');
    });

    test('Handles null and empty string with default', () {
      expect(AiService.normalizeModelName(null), 'gemini-3.8-flash');
      expect(AiService.normalizeModelName('   '), 'gemini-3.8-flash');
      expect(AiService.normalizeModelName('unknown-xyz'), 'gemini-3.8-flash');
    });
  });

  group('RAG Context & Intent Offline Fallback Tests', () {
    final ragService = RagChatService();

    test('extractIntent fallback correctly detects district and maxPrice', () async {
      final intent = await ragService.extractIntent(
        userMessage: 'Tìm phòng trọ ở Cầu Giấy tầm 3 triệu có điều hòa',
        apiKey: '', // Offline mode
      );

      expect(intent.isRoomSearchQuery, isTrue);
      expect(intent.district, 'Cầu Giấy');
      expect(intent.maxPrice, 3000000.0);
      expect(intent.amenities.contains('Điều hòa'), isTrue);
    });

    test('extractIntent fast maps university landmarks and fractional price', () async {
      final intentThuyLoi = await ragService.extractIntent(
        userMessage: 'Có phòng gần ĐH Thủy Lợi tầm 3tr5 có ban công không',
        apiKey: '',
      );
      expect(intentThuyLoi.isRoomSearchQuery, isTrue);
      expect(intentThuyLoi.district, 'Đống Đa');
      expect(intentThuyLoi.maxPrice, 3500000.0);
      expect(intentThuyLoi.amenities.contains('Ban công'), isTrue);

      final greetingIntent = await ragService.extractIntent(
        userMessage: 'Xin chào bạn là ai',
        apiKey: '',
      );
      expect(greetingIntent.isRoomSearchQuery, isFalse);
    });

    test('formatRoomsContext produces structured prompt context with ROOM_ID', () {
      final sampleRoom = Room(
        roomId: 'room_cau_giay_01',
        ownerId: 'owner_123',
        title: 'Phòng khép kín ban công Cầu Giấy',
        description: 'Đầy đủ tiện nghi',
        price: 3500000,
        area: 25,
        address: '123 Cầu Giấy',
        district: 'Cầu Giấy',
        ward: 'Dịch Vọng',
        street: 'Cầu Giấy',
        images: [],
        roomType: 'Phòng khép kín',
        amenities: ['Điều hòa', 'Nóng lạnh'],
        status: 'available',
        createdAt: DateTime.now(),
        averageRating: 4.8,
        totalReviews: 12,
      );

      final formatted = ragService.formatRoomsContext([sampleRoom]);
      expect(formatted.contains('[MÃ: room_cau_giay_01]'), isTrue);
      expect(formatted.contains('3.5 triệu'), isTrue);
      expect(formatted.contains('Cầu Giấy'), isTrue);
      expect(formatted.contains('4.8/5⭐'), isTrue);
    });
  });
}
