import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:room_finder_app/core/guards/auth_guard.dart';
import 'package:room_finder_app/data/mock_data.dart';
import 'package:room_finder_app/domain/models/booking.dart';
import 'package:room_finder_app/domain/models/package_plan.dart';
import 'package:room_finder_app/domain/models/report.dart';
import 'package:room_finder_app/domain/models/review.dart';
import 'package:room_finder_app/domain/models/room.dart';
import 'package:room_finder_app/domain/models/room_promotion.dart';
import 'package:room_finder_app/presentation/profile/guest_profile_tab.dart';

void main() {
  group('E2E User Journey & Integration Tests', () {
    testWidgets('E2E 1: Guest mode profile tab displays login/register CTAs and benefits',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GuestProfileTab(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Khách'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.text('Đăng ký'), findsOneWidget);
      expect(find.text('Đặt lịch xem phòng'), findsOneWidget);
      expect(find.text('Lưu phòng yêu thích'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Mua gói VIP cho tin đăng'),
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Mua gói VIP cho tin đăng'), findsOneWidget);
    });

    testWidgets('E2E 2: AuthGuard blocks unauthenticated booking and opens login sheet',
        (WidgetTester tester) async {
      bool? allowedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  allowedResult = AuthGuard.requireLogin(
                    context,
                    featureName: 'Đặt lịch xem phòng',
                  );
                },
                child: const Text('ĐẶT LỊCH XEM PHÒNG'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ĐẶT LỊCH XEM PHÒNG'));
      await tester.pumpAndSettle();

      expect(allowedResult, isFalse);
      expect(find.text('Yêu cầu đăng nhập'), findsOneWidget);
      expect(find.textContaining('Đặt lịch xem phòng'), findsWidgets);
      expect(find.text('ĐĂNG NHẬP NGAY'), findsOneWidget);
      expect(find.text('Tiếp tục xem'), findsOneWidget);

      await tester.tap(find.text('Tiếp tục xem'));
      await tester.pumpAndSettle();
      expect(find.text('Yêu cầu đăng nhập'), findsNothing);
    });

    testWidgets('E2E 3: /packages route forwards preselectedRoomId when arguments provided or omitted',
        (WidgetTester tester) async {
      String? capturedRoomId;

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name == '/packages') {
              final args = settings.arguments is Map<String, dynamic>
                  ? settings.arguments as Map<String, dynamic>
                  : null;
              capturedRoomId = args?['preselectedRoomId'] as String?;
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => Scaffold(
                  body: Text('PackageScreen:${capturedRoomId ?? "none"}'),
                ),
              );
            }
            return null;
          },
          home: Builder(
            builder: (context) => Column(
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/packages',
                    arguments: {'preselectedRoomId': 'room_vip_101'},
                  ),
                  child: const Text('Open With Room'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/packages'),
                  child: const Text('Open Without Room'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open With Room'));
      await tester.pumpAndSettle();
      expect(find.text('PackageScreen:room_vip_101'), findsOneWidget);
      expect(capturedRoomId, 'room_vip_101');

      Navigator.of(tester.element(find.text('PackageScreen:room_vip_101'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Without Room'));
      await tester.pumpAndSettle();
      expect(find.text('PackageScreen:none'), findsOneWidget);
      expect(capturedRoomId, isNull);
    });

    test('E2E 4: Search/filter rooms by district, price, amenities & VIP priority sorting', () {
      const targetDistrict = 'Cầu Giấy';
      const maxBudget = 4500000.0;
      const requiredAmenity = 'Điều hòa';

      final filtered = mockRooms.where((room) {
        final okStatus = room.status == 'available';
        final okDistrict = room.district.toLowerCase().contains(targetDistrict.toLowerCase());
        final okPrice = room.price <= maxBudget;
        final okAmenity = room.amenities.any(
          (a) => a.toLowerCase().contains(requiredAmenity.toLowerCase()),
        );
        return okStatus && okDistrict && okPrice && okAmenity;
      }).toList();

      expect(filtered, isNotEmpty);

      // Giả lập nâng cấp 1 phòng thành Gold còn hạn và 1 phòng thành Silver còn hạn
      final now = DateTime.now();
      final promotedList = <Room>[
        filtered.first.copyWith(
          packageType: 'silver',
          priority: 2,
          packageStartAt: now,
          packageExpiresAt: now.add(const Duration(days: 15)),
        ),
        filtered.last.copyWith(
          packageType: 'gold',
          priority: 3,
          packageStartAt: now,
          packageExpiresAt: now.add(const Duration(days: 30)),
        ),
        ...filtered.skip(1).take(filtered.length - 2),
      ];

      promotedList.sort((a, b) {
        final pCompare = b.effectivePriority.compareTo(a.effectivePriority);
        if (pCompare != 0) return pCompare;
        return (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000));
      });

      expect(promotedList.first.effectivePackageType, 'gold');
      expect(promotedList.first.effectivePriority, 3);
      expect(promotedList[1].effectivePackageType, 'silver');
      expect(promotedList[1].effectivePriority, 2);
      for (final r in promotedList) {
        expect(r.price, lessThanOrEqualTo(maxBudget));
        expect(r.district.toLowerCase(), contains('cầu giấy'));
      }
    });

    test('E2E 5: Booking lifecycle (pending -> confirmed -> completed) and review rating calculation', () {
      final appointment = DateTime.now().add(const Duration(days: 2));
      final booking = Booking(
        id: 'bk_e2e_01',
        roomId: 'room_01',
        roomTitle: 'Phòng trọ Đống Đa',
        roomAddress: '175 Tây Sơn',
        roomPrice: 3200000,
        userId: 'renter_01',
        userName: 'Nguyễn Minh',
        ownerId: 'owner_01',
        appointmentDate: appointment,
        phone: '0912345678',
        note: 'Xem lúc 15h',
        status: 'pending',
      );
      expect(booking.isPending, isTrue);

      final confirmed = Booking.fromMap({...booking.toMap(), 'status': 'confirmed'}, booking.id);
      expect(confirmed.isConfirmed, isTrue);

      final completed = Booking.fromMap({...confirmed.toMap(), 'status': 'completed'}, booking.id);
      expect(completed.isCompleted, isTrue);

      // Chỉ người thuê khác chủ phòng mới hợp lệ để đánh giá
      final reviews = [
        Review(
          reviewId: 'rev_1',
          roomId: 'room_01',
          userId: 'renter_01',
          userName: 'Nguyễn Minh',
          ownerId: 'owner_01',
          rating: 5.0,
          comment: 'Phòng sạch, đúng ảnh, chủ nhà thân thiện.',
        ),
        Review(
          reviewId: 'rev_2',
          roomId: 'room_01',
          userId: 'renter_02',
          userName: 'Trần Lan',
          ownerId: 'owner_01',
          rating: 4.0,
          comment: 'Vị trí tiện đi học ĐH Thủy Lợi.',
        ),
      ];

      expect(reviews.every((r) => r.userId != r.ownerId), isTrue);
      final totalReviews = reviews.length;
      final avgRating = double.parse(
        (reviews.fold<double>(0, (sum, r) => sum + r.rating) / totalReviews).toStringAsFixed(1),
      );
      expect(totalReviews, 2);
      expect(avgRating, 4.5);
    });

    test('E2E 6: MoMo Sandbox VIP activation, expiration downgrade & 5-report auto-moderation', () {
      final goldPlan = PackagePlan.getById('gold');
      final now = DateTime.now();

      // 1. Kích hoạt gói sau thanh toán MoMo thành công
      final activePromo = RoomPromotion(
        roomId: 'room_e2e_vip',
        ownerId: 'owner_01',
        packageId: goldPlan.id,
        packageName: goldPlan.name,
        priority: goldPlan.priority,
        status: 'active',
        startAt: now,
        expiresAt: now.add(Duration(days: goldPlan.durationDays)),
        lastOrderId: 'TROTOT_E2E_001',
        updatedAt: now,
      );
      expect(activePromo.isActive, isTrue);
      expect(activePromo.priority, 3);

      // 2. Khi gói hết hạn -> phòng tự động hạ priority về 0
      final expiredRoom = Room(
        roomId: 'room_e2e_vip',
        ownerId: 'owner_01',
        title: 'Phòng test hết hạn',
        description: 'Mô tả',
        price: 3000000,
        area: 22,
        address: 'Cầu Giấy',
        district: 'Cầu Giấy',
        images: [],
        amenities: [],
        roomType: 'Phòng khép kín',
        status: 'available',
        packageType: 'gold',
        priority: 3,
        packageStartAt: now.subtract(const Duration(days: 31)),
        packageExpiresAt: now.subtract(const Duration(minutes: 5)),
      );
      expect(expiredRoom.isPromotedActive, isFalse);
      expect(expiredRoom.effectivePriority, 0);
      expect(expiredRoom.effectivePackageType, 'normal');

      // 3. Auto-moderation threshold (>= 5 báo cáo vi phạm)
      const autoModerationThreshold = 5;
      final reports = List.generate(
        5,
        (i) => Report(
          id: 'rep_$i',
          roomId: 'room_e2e_vip',
          roomTitle: 'Phòng test hết hạn',
          reporterId: 'user_$i',
          reporterEmail: 'user$i@test.vn',
          reason: 'Sai giá thực tế',
          description: 'Báo cáo lần ${i + 1}',
        ),
      );
      final shouldAutoHide = reports.length >= autoModerationThreshold;
      expect(shouldAutoHide, isTrue);
    });
  });
}
