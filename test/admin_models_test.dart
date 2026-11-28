import 'package:flutter_test/flutter_test.dart';
import 'package:room_finder_app/data/admin_service.dart';
import 'package:room_finder_app/data/mock_data.dart';
import 'package:room_finder_app/domain/models/app_user.dart';
import 'package:room_finder_app/domain/models/chat_message.dart';
import 'package:room_finder_app/domain/models/chat_session.dart';
import 'package:room_finder_app/domain/models/report.dart';
import 'package:room_finder_app/domain/models/app_notification.dart';
import 'package:room_finder_app/domain/models/booking.dart';
import 'package:room_finder_app/domain/models/review.dart';
import 'package:room_finder_app/domain/models/room.dart';
import 'package:room_finder_app/domain/models/search_intent.dart';

void main() {
  group('Admin Models & Domain Tests', () {
    test('AppUser model parsing & role check', () {
      final userMap = {
        'email': 'admin@trotot.vn',
        'fullName': 'Quản Trị Viên',
        'phoneNumber': '0912345678',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'role': 'admin',
        'status': 'active',
      };

      final user = AppUser.fromMap(userMap, 'uid_123');
      expect(user.uid, 'uid_123');
      expect(user.isAdmin, isTrue);
      expect(user.isBlocked, isFalse);
      expect(user.email, 'admin@trotot.vn');
      expect(user.avatarUrl, 'https://example.com/avatar.jpg');

      final userRegular = AppUser.fromMap({
        'email': 'user@trotot.vn',
        'role': 'user',
        'status': 'blocked',
      }, 'uid_456');

      expect(userRegular.isAdmin, isFalse);
      expect(userRegular.isBlocked, isTrue);

      final userBase64Avatar = AppUser.fromMap({
        'email': 'user_avatar@trotot.vn',
        'avatarUrl': 'data:image/jpeg;base64,/9j/4AAQSkZJRg...',
        'role': 'user',
      }, 'uid_789');
      expect(userBase64Avatar.avatarUrl.startsWith('data:image'), isTrue);

      final userFlexible = AppUser.fromMap({
        'fullName': 'Nguyễn Văn Bình',
        'userEmail': 'binh@gmail.com',
        'phone': '0923723253',
        'timestamp': DateTime(2026, 10, 20).millisecondsSinceEpoch,
      }, 'uid_binh');

      expect(userFlexible.fullName, 'Nguyễn Văn Bình');
      expect(userFlexible.email, 'binh@gmail.com');
      expect(userFlexible.phoneNumber, '0923723253');
      expect(userFlexible.createdAt, isNotNull);
    });

    test('Report model parsing', () {
      final reportMap = {
        'roomId': 'room_01',
        'roomTitle': 'Phòng trọ Cầu Giấy',
        'reporterId': 'user_01',
        'reporterEmail': 'reporter@gmail.com',
        'reason': 'Lừa đảo',
        'description': 'Đòi cọc trước',
        'status': 'pending',
      };

      final report = Report.fromMap(reportMap, 'rep_01');
      expect(report.id, 'rep_01');
      expect(report.reason, 'Lừa đảo');
      expect(report.status, 'pending');

      final toMap = report.toMap();
      expect(toMap['reason'], 'Lừa đảo');
      expect(toMap['status'], 'pending');
    });

    test('AppNotification model serialization', () {
      final notif = AppNotification(
        id: 'notif_01',
        recipientId: 'all',
        title: 'Thông báo toàn sàn',
        body: 'Hệ thống bảo trì',
        type: 'system',
      );

      final map = notif.toMap();
      expect(map['recipientId'], 'all');
      expect(map['title'], 'Thông báo toàn sàn');

      final fromMap = AppNotification.fromMap(map, 'notif_01');
      expect(fromMap.title, 'Thông báo toàn sàn');
      expect(fromMap.isRead, isFalse);
    });

    test('Room backward compatibility', () {
      final legacyMap = {
        'ownerId': 'owner_1',
        'title': 'Phòng giá rẻ',
        'description': 'Mô tả',
        'price': 2500000,
        'area': 20,
        'address': 'Ngõ 10 Cầu Giấy',
        'district': 'Cầu Giấy',
        'images': ['https://example.com/img1.jpg'],
        'amenities': ['Wifi'],
        'roomType': 'Phòng trọ khép kín',
        'status': 'available',
      };

      final room = Room.fromMap(legacyMap, 'doc_001');
      expect(room.roomId, 'doc_001');
      expect(room.status, 'available');
      expect(room.rejectionReason, isNull);
      expect(room.moderatedBy, isNull);
    });

    test('Room VIP & expiration calculation', () {
      final now = DateTime.now();
      final room = Room(
        roomId: 'room_vip',
        ownerId: 'owner_99',
        title: 'Phòng VIP Hoàng Gia',
        description: 'Mô tả',
        price: 5000000,
        area: 35,
        address: '123 Kim Mã',
        district: 'Ba Đình',
        images: [],
        amenities: [],
        roomType: 'Chung cư mini',
        status: 'available',
        createdAt: now,
        expiredAt: now.add(const Duration(days: 10)),
        vipType: 'gold',
      );

      expect(room.isVip, isTrue);
      expect(room.vipType, 'gold');
      expect(room.isExpired, isFalse);
      expect(room.remainingDays, inInclusiveRange(9, 10));

      final map = room.toMap();
      expect(map['vipType'], 'gold');
      expect(map['expiredAt'], isNotNull);

      final fallbackMap = {
        'ownerId': 'owner_1',
        'title': 'Phòng thường',
        'description': 'Mô tả',
        'price': 2000000,
        'area': 18,
        'address': 'Đống Đa',
        'district': 'Đống Đa',
        'images': <String>[],
        'amenities': <String>[],
        'roomType': 'Phòng trọ',
        'status': 'available',
        'createdAt': now,
      };
      final fallbackRoom = Room.fromMap(fallbackMap, 'room_normal');
      expect(fallbackRoom.isVip, isFalse);
      expect(fallbackRoom.vipType, 'normal');
      expect(fallbackRoom.expiredAt, isNotNull);
      expect(fallbackRoom.remainingDays, inInclusiveRange(9, 10));
    });

    test('ChatSession and ChatMessage model tests', () {
      final session = ChatSession(
        id: 'session_01',
        userId: 'user_01',
        title: 'Tìm phòng Cầu Giấy',
        lastMessage: 'Dưới 3.5 triệu',
      );
      expect(session.id, 'session_01');
      expect(session.title, 'Tìm phòng Cầu Giấy');

      final sessionMap = session.toMap();
      expect(sessionMap['userId'], 'user_01');
      expect(sessionMap['lastMessage'], 'Dưới 3.5 triệu');

      final message = ChatMessage(
        id: 'msg_01',
        sender: 'model',
        text: 'Gợi ý phòng cho bạn [ROOM_ID: room_abc]',
        suggestedRoomIds: ['room_abc'],
      );
      expect(message.isModel, isTrue);
      expect(message.isUser, isFalse);
      expect(message.suggestedRoomIds, contains('room_abc'));

      final msgMap = message.toMap();
      expect(msgMap['sender'], 'model');
      expect(msgMap['suggestedRoomIds'], ['room_abc']);
    });

    test('AdminDashboardStats metric validation', () {
      final stats = AdminDashboardStats(
        totalRooms: 10,
        availableRooms: 6,
        pendingRooms: 2,
        rentedRooms: 1,
        hiddenRooms: 1,
        rejectedRooms: 0,
        totalUsers: 5,
        blockedUsers: 1,
        totalBookings: 8,
        totalReports: 3,
        pendingReports: 1,
        totalAiSessions: 12,
      );

      expect(stats.totalRooms, 10);
      expect(stats.pendingRooms, 2);
      expect(stats.totalAiSessions, 12);
    });

    test('UserSearchIntent JSON parsing and fallback extraction', () {
      final json = {
        'isRoomSearchQuery': true,
        'maxPrice': 3.5, // 3.5 triệu
        'district': 'Đống Đa',
        'roomType': 'Chung cư mini',
        'amenities': ['Điều hòa', 'Nóng lạnh'],
      };

      final intent = UserSearchIntent.fromJson(json);
      expect(intent.isRoomSearchQuery, isTrue);
      expect(intent.maxPrice, 3500000.0);
      expect(intent.district, 'Đống Đa');
      expect(intent.roomType, 'Chung cư mini');
      expect(intent.amenities, contains('Điều hòa'));
      expect(intent.amenities, contains('Nóng lạnh'));
    });

    test('Booking model serialization & status checks', () {
      final now = DateTime(2026, 11, 15, 14, 30);
      final booking = Booking(
        id: 'booking_123',
        roomId: 'room_01',
        roomTitle: 'Phòng khép kín Cầu Giấy',
        roomAddress: '123 Cầu Giấy',
        roomPrice: 3500000,
        userId: 'user_guest',
        userName: 'Nguyễn Văn A',
        ownerId: 'owner_host',
        appointmentDate: now,
        phone: '0987654321',
        note: 'Xem phòng chiều thứ 7',
        status: 'confirmed',
      );

      expect(booking.isConfirmed, isTrue);
      expect(booking.isPending, isFalse);
      expect(booking.isCompleted, isFalse);

      final map = booking.toMap();
      expect(map['roomTitle'], 'Phòng khép kín Cầu Giấy');
      expect(map['phone'], '0987654321');
      expect(map['status'], 'confirmed');

      final fromMap = Booking.fromMap(map, 'booking_123');
      expect(fromMap.id, 'booking_123');
      expect(fromMap.roomTitle, 'Phòng khép kín Cầu Giấy');
      expect(fromMap.roomPrice, 3500000);
      expect(fromMap.appointmentDate.day, 15);
    });

    test('Review model parsing with reviewer avatar and name', () {
      final map = {
        'roomId': 'room_01',
        'userId': 'user_01',
        'userName': 'Trần Văn B',
        'userAvatar': 'https://example.com/b.jpg',
        'ownerId': 'owner_01',
        'rating': 4.5,
        'comment': 'Phòng rất thoáng và sạch sẽ, chủ trọ thân thiện.',
      };

      final review = Review.fromMap(map, 'rev_999');
      expect(review.reviewId, 'rev_999');
      expect(review.userName, 'Trần Văn B');
      expect(review.userAvatar, 'https://example.com/b.jpg');
      expect(review.rating, 4.5);
      expect(review.comment, contains('thoáng và sạch sẽ'));
    });

    test('Mock Rooms comprehensive dataset verification (>= 200 rooms, 3 images each, full fields)', () {
      expect(mockRooms.length, greaterThanOrEqualTo(200));
      for (final r in mockRooms) {
        expect(r.roomId.isNotEmpty, isTrue);
        expect(r.ownerId.isNotEmpty, isTrue);
        expect(r.title.isNotEmpty, isTrue);
        expect(r.description.isNotEmpty, isTrue);
        expect(r.address.isNotEmpty, isTrue);
        expect(r.district.isNotEmpty, isTrue);
        expect(r.ward.isNotEmpty, isTrue);
        expect(r.street.isNotEmpty, isTrue);
        expect(r.price, greaterThan(0));
        expect(r.area, greaterThan(0));
        expect(r.deposit, greaterThan(0));
        expect(r.electricityPrice, greaterThan(0));
        expect(r.waterPrice, greaterThan(0));
        expect(r.images.length, equals(3));
        expect(r.amenities.isNotEmpty, isTrue);
        expect(r.roomType.isNotEmpty, isTrue);
        expect(r.status.isNotEmpty, isTrue);
        expect(['normal', 'bronze', 'silver', 'gold'], contains(r.vipType));
        expect(r.averageRating, equals(0.0));
        expect(r.totalReviews, equals(0));
      }
    });
  });
}

