import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_finder_app/presentation/widgets/room_google_map_card.dart';

void main() {
  group('RoomGoogleMapCard Tests', () {
    test('buildFullAddress combines address, ward, district and Hanoi without duplicates', () {
      expect(
        RoomGoogleMapCard.buildFullAddress(
          address: '175 Tây Sơn',
          ward: 'Trung Liệt',
          district: 'Đống Đa',
        ),
        '175 Tây Sơn, Trung Liệt, Đống Đa, Hà Nội',
      );

      expect(
        RoomGoogleMapCard.buildFullAddress(
          address: '123 Xuân Thủy, Dịch Vọng Hậu, Cầu Giấy, Hà Nội',
          ward: 'Dịch Vọng Hậu',
          district: 'Cầu Giấy',
        ),
        '123 Xuân Thủy, Dịch Vọng Hậu, Cầu Giấy, Hà Nội',
      );
    });

    test('buildEmbedUrl, buildSearchUrl and buildDirectionsUrl encode Vietnamese address cleanly', () {
      const fullAddr = '175 Tây Sơn, Đống Đa, Hà Nội';
      final embed = RoomGoogleMapCard.buildEmbedUrl(fullAddr);
      final search = RoomGoogleMapCard.buildSearchUrl(fullAddr);
      final directions = RoomGoogleMapCard.buildDirectionsUrl(fullAddr);

      expect(embed.host, 'maps.google.com');
      expect(embed.queryParameters['output'], 'embed');
      expect(embed.queryParameters['q'], fullAddr);

      expect(search.host, 'www.google.com');
      expect(search.path, '/maps/search/');
      expect(search.queryParameters['query'], fullAddr);

      expect(directions.host, 'www.google.com');
      expect(directions.path, '/maps/dir/');
      expect(directions.queryParameters['destination'], fullAddr);
    });

    testWidgets('RoomGoogleMapCard renders title, normalized address and action buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RoomGoogleMapCard(
                address: 'Ngõ 68 Cầu Giấy',
                ward: 'Quan Hoa',
                district: 'Cầu Giấy',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Bản đồ vị trí'), findsOneWidget);
      expect(find.text('Ngõ 68 Cầu Giấy, Quan Hoa, Cầu Giấy, Hà Nội'), findsWidgets);
      expect(find.text('Sao chép'), findsOneWidget);
      expect(find.text('Mở Google Maps'), findsOneWidget);
      expect(find.text('Chỉ đường'), findsOneWidget);
    });
  });
}
