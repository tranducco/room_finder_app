import 'package:flutter_test/flutter_test.dart';
import 'package:room_finder_app/domain/models/package_order.dart';
import 'package:room_finder_app/domain/models/package_plan.dart';
import 'package:room_finder_app/domain/models/room.dart';
import 'package:room_finder_app/domain/models/room_promotion.dart';

void main() {
  group('PackagePlan Tests', () {
    test('Default packages match required business specifications', () {
      final plans = PackagePlan.defaultPlans;
      expect(plans.length, 3);

      final bronze = PackagePlan.getById('bronze');
      expect(bronze.id, 'bronze');
      expect(bronze.name, 'Gói Đồng');
      expect(bronze.price, 15000);
      expect(bronze.durationDays, 7);
      expect(bronze.priority, 1);
      expect(bronze.badgeText, 'ĐỒNG');

      final silver = PackagePlan.getById('silver');
      expect(silver.id, 'silver');
      expect(silver.name, 'Gói Bạc');
      expect(silver.price, 39000);
      expect(silver.durationDays, 15);
      expect(silver.priority, 2);
      expect(silver.badgeText, 'BẠC');

      final gold = PackagePlan.getById('gold');
      expect(gold.id, 'gold');
      expect(gold.name, 'Gói Vàng');
      expect(gold.price, 69000);
      expect(gold.durationDays, 30);
      expect(gold.priority, 3);
      expect(gold.badgeText, 'VÀNG');
      expect(gold.isPopular, isTrue);
    });

    test('getById fallback behavior', () {
      final fallback = PackagePlan.getById('non_existent_id');
      expect(fallback.id, 'bronze');
    });

    test('PackagePlan serialization and deserialization', () {
      final plan = PackagePlan.getById('gold');
      final map = plan.toMap();
      final fromMap = PackagePlan.fromMap(map, 'gold');

      expect(fromMap.id, 'gold');
      expect(fromMap.name, plan.name);
      expect(fromMap.price, 69000);
      expect(fromMap.durationDays, 30);
      expect(fromMap.priority, 3);
      expect(fromMap.isPopular, isTrue);
    });
  });

  group('PackageOrder Tests', () {
    test('PackageOrder status checks and getters', () {
      final now = DateTime.now();
      final orderPending = PackageOrder(
        orderId: 'ORDER_001',
        userId: 'user_1',
        roomId: 'room_1',
        roomTitle: 'Phòng trọ Cầu Giấy',
        packageId: 'gold',
        packageName: 'Gói Vàng',
        amount: 69000,
        durationDays: 30,
        priority: 3,
        status: 'pending',
        createdAt: now,
      );

      expect(orderPending.isPending, isTrue);
      expect(orderPending.isCompleted, isFalse);

      final orderCompleted = PackageOrder(
        orderId: 'ORDER_002',
        userId: 'user_1',
        roomId: 'room_1',
        roomTitle: 'Phòng trọ Cầu Giấy',
        packageId: 'gold',
        packageName: 'Gói Vàng',
        amount: 69000,
        durationDays: 30,
        priority: 3,
        status: 'completed',
        transactionId: 'MOMO_TRANS_123',
        createdAt: now,
        paidAt: now,
      );

      expect(orderCompleted.isCompleted, isTrue);
      expect(orderCompleted.isPending, isFalse);
      expect(orderCompleted.transactionId, 'MOMO_TRANS_123');
    });

    test('PackageOrder serialization and deserialization', () {
      final now = DateTime.now();
      final start = now;
      final expiry = now.add(const Duration(days: 30));

      final order = PackageOrder(
        orderId: 'ORDER_003',
        userId: 'user_test',
        userEmail: 'test@trotot.vn',
        userPhone: '0987654321',
        roomId: 'room_101',
        roomTitle: 'Phòng ban công thoáng',
        packageId: 'silver',
        packageName: 'Gói Bạc',
        amount: 39000,
        durationDays: 15,
        priority: 2,
        status: 'completed',
        paymentMethod: 'momo',
        transactionId: 'TRANS_99999',
        payUrl: 'https://test-payment.momo.vn/v2/gateway/pay?orderId=123',
        createdAt: now,
        paidAt: now,
        startAt: start,
        expiresAt: expiry,
      );

      final map = order.toMap();
      expect(map['orderId'], 'ORDER_003');
      expect(map['amount'], 39000);
      expect(map['paymentMethod'], 'momo');
      expect(map['transactionId'], 'TRANS_99999');

      final fromMap = PackageOrder.fromMap(map, 'ORDER_003');
      expect(fromMap.orderId, 'ORDER_003');
      expect(fromMap.userId, 'user_test');
      expect(fromMap.amount, 39000);
      expect(fromMap.isCompleted, isTrue);
      expect(fromMap.durationDays, 15);
      expect(fromMap.priority, 2);
    });
  });

  group('RoomPromotion Tests', () {
    test('RoomPromotion active status and remaining days', () {
      final now = DateTime.now();
      final futureExpiry = now.add(const Duration(days: 7, hours: 2));

      final promoActive = RoomPromotion(
        roomId: 'room_promo_1',
        ownerId: 'owner_1',
        packageId: 'bronze',
        packageName: 'Gói Đồng',
        priority: 1,
        status: 'active',
        startAt: now,
        expiresAt: futureExpiry,
        lastOrderId: 'ORDER_001',
        updatedAt: now,
      );

      expect(promoActive.isActive, isTrue);
      expect(promoActive.remainingDays, greaterThanOrEqualTo(7));

      final pastExpiry = now.subtract(const Duration(days: 1));
      final promoExpired = RoomPromotion(
        roomId: 'room_promo_2',
        ownerId: 'owner_1',
        packageId: 'bronze',
        packageName: 'Gói Đồng',
        priority: 1,
        status: 'active',
        startAt: now.subtract(const Duration(days: 8)),
        expiresAt: pastExpiry,
        lastOrderId: 'ORDER_001',
        updatedAt: now,
      );

      expect(promoExpired.isActive, isFalse);
      expect(promoExpired.remainingDays, 0);
    });

    test('RoomPromotion serialization with fromMap / toMap', () {
      final now = DateTime.now();
      final promo = RoomPromotion(
        roomId: 'room_test_123',
        ownerId: 'user_456',
        packageId: 'gold',
        packageName: 'Gói Vàng',
        priority: 3,
        status: 'active',
        startAt: now,
        expiresAt: now.add(const Duration(days: 30)),
        lastOrderId: 'ORDER_TEST',
        updatedAt: now,
      );

      final map = promo.toMap();
      final fromMap = RoomPromotion.fromMap(map, 'room_test_123');

      expect(fromMap.roomId, 'room_test_123');
      expect(fromMap.packageId, 'gold');
      expect(fromMap.priority, 3);
      expect(fromMap.isActive, isTrue);
    });
  });

  group('Room Model Promotion & Expiration Logic Tests', () {
    test('isPromotedActive and effectivePriority behavior', () {
      final now = DateTime.now();

      // Phòng có gói Vàng còn hạn
      final goldRoom = Room(
        roomId: 'gold_room',
        ownerId: 'owner_1',
        title: 'Phòng VIP Vàng',
        description: 'Mô tả phòng',
        price: 5000000,
        area: 35,
        address: 'Hà Nội',
        district: 'Cầu Giấy',
        images: ['img1.jpg'],
        amenities: ['wifi'],
        roomType: 'apartment',
        status: 'available',
        packageType: 'gold',
        priority: 3,
        packageStartAt: now,
        packageExpiresAt: now.add(const Duration(days: 15)),
      );

      expect(goldRoom.isPromotedActive, isTrue);
      expect(goldRoom.effectivePriority, 3);
      expect(goldRoom.effectivePackageType, 'gold');
      expect(goldRoom.packageRemainingDays, greaterThanOrEqualTo(15));
      expect(goldRoom.isVip, isTrue);

      // Phòng có gói Bạc đã hết hạn 1 tiếng trước
      final expiredSilverRoom = Room(
        roomId: 'expired_silver_room',
        ownerId: 'owner_2',
        title: 'Phòng VIP Bạc hết hạn',
        description: 'Mô tả phòng',
        price: 3500000,
        area: 25,
        address: 'Hà Nội',
        district: 'Đống Đa',
        images: ['img2.jpg'],
        amenities: ['wifi'],
        roomType: 'room',
        status: 'available',
        packageType: 'silver',
        priority: 2,
        packageStartAt: now.subtract(const Duration(days: 16)),
        packageExpiresAt: now.subtract(const Duration(hours: 1)),
      );

      // Phải tự động trở về tin thường khi hết hạn
      expect(expiredSilverRoom.isPromotedActive, isFalse);
      expect(expiredSilverRoom.effectivePriority, 0);
      expect(expiredSilverRoom.effectivePackageType, 'normal');
      expect(expiredSilverRoom.packageRemainingDays, 0);

      // Phòng thường không mua gói
      final normalRoom = Room(
        roomId: 'normal_room',
        ownerId: 'owner_3',
        title: 'Phòng thường',
        description: 'Mô tả phòng',
        price: 2500000,
        area: 20,
        address: 'Hà Nội',
        district: 'Thanh Xuân',
        images: ['img3.jpg'],
        amenities: ['wifi'],
        roomType: 'room',
        status: 'available',
        packageType: 'normal',
        priority: 0,
      );

      expect(normalRoom.isPromotedActive, isFalse);
      expect(normalRoom.effectivePriority, 0);
      expect(normalRoom.effectivePackageType, 'normal');
    });

    test('Sorting Hierarchy: Gold > Silver > Bronze > Normal', () {
      final now = DateTime.now();

      final normalRoom1 = Room(
        roomId: 'r_normal_1',
        ownerId: 'u1',
        title: 'Tin Thường Cũ',
        description: '',
        price: 2000000,
        area: 20,
        address: '',
        district: 'Cầu Giấy',
        images: [],
        amenities: [],
        roomType: 'room',
        status: 'available',
        priority: 0,
        createdAt: now.subtract(const Duration(days: 5)),
      );

      final normalRoomNew = Room(
        roomId: 'r_normal_new',
        ownerId: 'u2',
        title: 'Tin Thường Mới',
        description: '',
        price: 2200000,
        area: 20,
        address: '',
        district: 'Cầu Giấy',
        images: [],
        amenities: [],
        roomType: 'room',
        status: 'available',
        priority: 0,
        createdAt: now.subtract(const Duration(hours: 2)),
      );

      final bronzeRoom = Room(
        roomId: 'r_bronze',
        ownerId: 'u3',
        title: 'Tin Gói Đồng',
        description: '',
        price: 2500000,
        area: 22,
        address: '',
        district: 'Cầu Giấy',
        images: [],
        amenities: [],
        roomType: 'room',
        status: 'available',
        packageType: 'bronze',
        priority: 1,
        packageStartAt: now,
        packageExpiresAt: now.add(const Duration(days: 7)),
        createdAt: now.subtract(const Duration(days: 2)),
      );

      final silverRoom = Room(
        roomId: 'r_silver',
        ownerId: 'u4',
        title: 'Tin Gói Bạc',
        description: '',
        price: 3000000,
        area: 25,
        address: '',
        district: 'Cầu Giấy',
        images: [],
        amenities: [],
        roomType: 'room',
        status: 'available',
        packageType: 'silver',
        priority: 2,
        packageStartAt: now,
        packageExpiresAt: now.add(const Duration(days: 15)),
        createdAt: now.subtract(const Duration(days: 3)),
      );

      final goldRoom = Room(
        roomId: 'r_gold',
        ownerId: 'u5',
        title: 'Tin Gói Vàng',
        description: '',
        price: 4500000,
        area: 30,
        address: '',
        district: 'Cầu Giấy',
        images: [],
        amenities: [],
        roomType: 'room',
        status: 'available',
        packageType: 'gold',
        priority: 3,
        packageStartAt: now,
        packageExpiresAt: now.add(const Duration(days: 30)),
        createdAt: now.subtract(const Duration(days: 4)),
      );

      final expiredGoldRoom = Room(
        roomId: 'r_gold_expired',
        ownerId: 'u6',
        title: 'Tin Gói Vàng Hết Hạn',
        description: '',
        price: 4000000,
        area: 28,
        address: '',
        district: 'Cầu Giấy',
        images: [],
        amenities: [],
        roomType: 'room',
        status: 'available',
        packageType: 'gold',
        priority: 3,
        packageStartAt: now.subtract(const Duration(days: 35)),
        packageExpiresAt: now.subtract(const Duration(days: 5)),
        createdAt: now.subtract(const Duration(days: 1)),
      );

      final rooms = [
        normalRoom1,
        bronzeRoom,
        expiredGoldRoom,
        normalRoomNew,
        goldRoom,
        silverRoom,
      ];

      // Áp dụng thuật toán sắp xếp chính xác của trang chủ TroTot
      rooms.sort((a, b) {
        final pCompare = b.effectivePriority.compareTo(a.effectivePriority);
        if (pCompare != 0) return pCompare;
        final timeA = a.createdAt ?? DateTime(2000);
        final timeB = b.createdAt ?? DateTime(2000);
        return timeB.compareTo(timeA);
      });

      // Thứ tự mong đợi:
      // 1. goldRoom (effectivePriority = 3)
      // 2. silverRoom (effectivePriority = 2)
      // 3. bronzeRoom (effectivePriority = 1)
      // 4. expiredGoldRoom (effectivePriority = 0, createdAt = 1 ngày trước - mới nhất trong nhóm 0)
      // 5. normalRoomNew (effectivePriority = 0, createdAt = 2 giờ trước) -> wait!
      // 2 hours ago is newer than 1 day ago!
      // Let's verify createdAt ordering:
      // normalRoomNew: 2 hours ago (newest)
      // expiredGoldRoom: 1 day ago
      // normalRoom1: 5 days ago
      expect(rooms[0].roomId, 'r_gold');
      expect(rooms[1].roomId, 'r_silver');
      expect(rooms[2].roomId, 'r_bronze');
      expect(rooms[3].roomId, 'r_normal_new');
      expect(rooms[4].roomId, 'r_gold_expired');
      expect(rooms[5].roomId, 'r_normal_1');
    });
  });
}
