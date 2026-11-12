import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:room_finder_app/domain/models/room.dart';
import 'package:room_finder_app/presentation/widgets/room_card.dart';

void main() {
  testWidgets('RoomCard smoke test', (WidgetTester tester) async {
    final testRoom = Room(
      roomId: 'test_1',
      ownerId: 'owner_1',
      title: 'Phòng trọ Cầu Giấy tiện nghi',
      description: 'Phòng đẹp đầy đủ đồ',
      price: 3500000,
      area: 25,
      address: 'Số 10 Dịch Vọng Hậu',
      district: 'Cầu Giấy',
      images: [],
      amenities: ['Wifi', 'Điều hòa'],
      roomType: 'Phòng trọ khép kín',
      status: 'available',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 250,
              child: RoomCard(
                room: testRoom,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Phòng trọ Cầu Giấy tiện nghi'), findsOneWidget);
    expect(find.textContaining('3.500.000'), findsOneWidget);
  });
}

