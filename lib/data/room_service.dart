import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/room.dart';
import 'mock_data.dart';
import 'notification_service.dart';

class RoomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Lấy danh sách tất cả phòng trọ
  Future<List<Room>> getRooms() async {
    final snapshot = await _firestore.collection('rooms').get();
    return snapshot.docs
        .map((doc) => Room.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Lấy chi tiết một phòng theo ID
  Future<Room?> getRoomById(String roomId) async {
    try {
      final doc = await _firestore.collection('rooms').doc(roomId).get();
      if (doc.exists && doc.data() != null) {
        return Room.fromMap(doc.data()!, doc.id);
      }
    } catch (_) {}
    return null;
  }

  // Lấy danh sách phòng của một User cụ thể
  Future<List<Room>> getMyRooms(String userId) async {
    final snapshot = await _firestore
        .collection('rooms')
        .where('ownerId', isEqualTo: userId)
        .get();
    return snapshot.docs
        .map((doc) => Room.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Thêm phòng mới vào Firestore
  Future<String> createRoom(Room room) async {
    final docRef = await _firestore.collection('rooms').add(room.toMap());
    return docRef.id;
  }

  // Xóa phòng khỏi Firestore
  Future<void> deleteRoom(String roomId) async {
    await _firestore.collection('rooms').doc(roomId).delete();
  }

  // Cập nhật thông tin phòng (do chủ phòng thực hiện).
  //
  // Luồng bảo mật:
  //   1. Đọc trạng thái hiện tại từ Firestore để không phụ thuộc vào client truyền lên.
  //   2. Nếu Admin vừa từ chối (status == 'rejected') và chủ phòng đã sửa lại
  //      => tự động reset về 'pending_approval' + xoá rejectionReason.
  //   3. Nếu status không phải 'rejected' nhưng client vô tình truyền 'available'
  //      => ép về 'pending_approval' để chờ Admin duyệt (chỉ Admin mới set 'available').
  //   4. Payload cuối cùng được sanitize trước khi ghi lên Firestore.
  Future<void> updateRoom(Room room) async {
    final docRef = _firestore.collection('rooms').doc(room.roomId);

    // Đọc document hiện tại để lấy trạng thái thật trên server (1 read thêm, nhưng bảo mật tuyệt đối)
    final currentDoc = await docRef.get();
    if (!currentDoc.exists) {
      throw Exception('Phòng không tồn tại hoặc đã bị xoá.');
    }

    final currentStatus = currentDoc.data()?['status'] as String? ?? '';

    // Chuẩn bị payload từ model (đã bao gồm tất cả field)
    final payload = room.toMap();

    if (currentStatus == 'rejected') {
      // Chủ phòng sửa lại bản tin bị từ chối → chuyển về chờ duyệt lại
      payload['status'] = 'pending_approval';
      payload['rejectionReason'] = null; // xoá lý do từ chối cũ
    } else {
      // Ngăn chặn client tự set 'available' (chỉ Admin mới có quyền này)
      // Các status hợp lệ mà user được phép gán: 'pending_approval', 'hidden'
      const allowedUserStatuses = ['pending_approval', 'hidden'];
      if (!allowedUserStatuses.contains(payload['status'])) {
        // Giữ nguyên status hiện tại, không cho client can thiệp
        payload['status'] = currentStatus;
      }
    }

    await docRef.update(payload);
  }

  // Chuyển đổi trạng thái phòng (available / rented / hidden)
  Future<void> updateRoomStatus(String roomId, String status) async {
    await _firestore.collection('rooms').doc(roomId).update({'status': status});
  }

  // Duyệt tin đăng (Admin)
  Future<void> approveRoom(String roomId, String adminUid) async {
    final doc = await _firestore.collection('rooms').doc(roomId).get();
    final data = doc.data();
    final ownerId = data?['ownerId'] as String? ?? '';
    final title = data?['title'] as String? ?? 'Phòng trọ';

    await _firestore.collection('rooms').doc(roomId).update({
      'status': 'available',
      'moderatedBy': adminUid,
      'moderatedAt': FieldValue.serverTimestamp(),
      'rejectionReason': null,
    });

    // Tự động gửi thông báo thật cho chủ phòng
    if (ownerId.isNotEmpty) {
      await NotificationService().sendUserNotification(
        userId: ownerId,
        title: 'Tin đăng đã được phê duyệt! 🎉',
        body: 'Tin đăng "$title" của bạn đã được Admin duyệt và hiển thị công khai trên Trọ Tốt.',
        type: 'room_approved',
      );
    }
  }

  // Từ chối duyệt tin (Admin)
  Future<void> rejectRoom(String roomId, String adminUid, String reason) async {
    final doc = await _firestore.collection('rooms').doc(roomId).get();
    final data = doc.data();
    final ownerId = data?['ownerId'] as String? ?? '';
    final title = data?['title'] as String? ?? 'Phòng trọ';

    await _firestore.collection('rooms').doc(roomId).update({
      'status': 'rejected',
      'moderatedBy': adminUid,
      'moderatedAt': FieldValue.serverTimestamp(),
      'rejectionReason': reason,
    });

    // Tự động gửi thông báo thật cho chủ phòng kèm lý do
    if (ownerId.isNotEmpty) {
      await NotificationService().sendUserNotification(
        userId: ownerId,
        title: 'Tin đăng chưa được duyệt ⚠️',
        body: 'Tin đăng "$title" bị từ chối duyệt. Lý do: $reason. Vui lòng chỉnh sửa lại thông tin.',
        type: 'room_rejected',
      );
    }
  }

  // Ẩn phòng vi phạm (Admin)
  Future<void> hideRoom(String roomId) async {
    await _firestore.collection('rooms').doc(roomId).update({
      'status': 'hidden',
    });
  }

  // Khôi phục phòng (Admin)
  Future<void> restoreRoom(String roomId) async {
    await _firestore.collection('rooms').doc(roomId).update({
      'status': 'available',
      'rejectionReason': null,
    });
  }

  // Lấy danh sách ID các phòng yêu thích của user
  Future<List<String>> getFavoriteRoomIds(String userId) async {
    final snapshot = await _firestore
        .collection('favorites')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs.map((doc) => doc.data()['roomId'] as String).toList();
  }

  // Kiểm tra phòng có được yêu thích hay không
  Future<bool> isFavorite(String userId, String roomId) async {
    final snapshot = await _firestore
        .collection('favorites')
        .where('userId', isEqualTo: userId)
        .where('roomId', isEqualTo: roomId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // Thêm hoặc xóa yêu thích (Toggle)
  Future<bool> toggleFavorite(String userId, String roomId) async {
    final query = await _firestore
        .collection('favorites')
        .where('userId', isEqualTo: userId)
        .where('roomId', isEqualTo: roomId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      // Đã có -> Xóa bỏ
      await query.docs.first.reference.delete();
      return false;
    } else {
      // Chưa có -> Thêm mới
      await _firestore.collection('favorites').add({
        'userId': userId,
        'roomId': roomId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    }
  }

  // Lấy toàn bộ danh sách phòng yêu thích của user
  Future<List<Room>> getFavoriteRooms(String userId) async {
    final favIds = await getFavoriteRoomIds(userId);
    if (favIds.isEmpty) return [];

    final List<Room> favoriteRooms = [];
    // Firestore whereIn giới hạn 10 items, lặp qua theo từng batch nhỏ nếu cần
    for (int i = 0; i < favIds.length; i += 10) {
      final end = (i + 10 < favIds.length) ? i + 10 : favIds.length;
      final subList = favIds.sublist(i, end);
      final snapshot = await _firestore
          .collection('rooms')
          .where(FieldPath.documentId, whereIn: subList)
          .get();

      favoriteRooms.addAll(
        snapshot.docs.map((doc) => Room.fromMap(doc.data(), doc.id)),
      );
    }
    return favoriteRooms;
  }

  // Tạo lịch hẹn xem phòng với thông tin phòng & khách đầy đủ
  Future<void> createBooking({
    required String roomId,
    required String userId,
    required String ownerId,
    required DateTime appointmentDate,
    required String phone,
    required String note,
    String? roomTitle,
    String? roomAddress,
    double? roomPrice,
    String? roomImage,
    String? userName,
    String? userEmail,
  }) async {
    // Nếu chưa truyền thông tin phòng, tự động tải từ document phòng
    String effectiveTitle = roomTitle ?? '';
    String effectiveAddress = roomAddress ?? '';
    double effectivePrice = roomPrice ?? 0.0;
    String effectiveImage = roomImage ?? '';

    if (effectiveTitle.isEmpty) {
      try {
        final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
        if (roomDoc.exists && roomDoc.data() != null) {
          final data = roomDoc.data()!;
          effectiveTitle = data['title'] as String? ?? 'Phòng trọ';
          effectiveAddress = data['address'] as String? ?? '';
          effectivePrice = (data['price'] ?? 0).toDouble();
          final imgs = List<String>.from(data['images'] ?? []);
          if (imgs.isNotEmpty) effectiveImage = imgs.first;
        }
      } catch (_) {}
    }

    await _firestore.collection('bookings').add({
      'roomId': roomId,
      'roomTitle': effectiveTitle,
      'roomAddress': effectiveAddress,
      'roomPrice': effectivePrice,
      'roomImage': effectiveImage,
      'userId': userId,
      'userName': userName ?? 'Khách thuê',
      'userEmail': userEmail ?? '',
      'ownerId': ownerId,
      'appointmentDate': Timestamp.fromDate(appointmentDate),
      'phone': phone,
      'note': note,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Thông báo cho chủ phòng
    if (ownerId.isNotEmpty) {
      await NotificationService().sendUserNotification(
        userId: ownerId,
        title: 'Có khách đặt lịch xem phòng! 📅',
        body: 'Khách hẹn xem phòng "$effectiveTitle" với SĐT $phone vào ${appointmentDate.day}/${appointmentDate.month}/${appointmentDate.year}.',
        type: 'booking',
      );
    }
  }

  // Lấy danh sách lịch hẹn của người dùng (đã đặt)
  Future<List<Map<String, dynamic>>> getMyBookings(String userId) async {
    final snapshot = await _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .get();

    final list = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

    // Sắp xếp lịch hẹn mới nhất lên đầu
    list.sort((a, b) {
      final dateA = (a['appointmentDate'] as Timestamp?)?.toDate() ?? DateTime(2000);
      final dateB = (b['appointmentDate'] as Timestamp?)?.toDate() ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    // Bù đắp dữ liệu phòng cho các booking cũ nếu thiếu
    for (var b in list) {
      if ((b['roomTitle'] as String? ?? '').isEmpty) {
        final rId = b['roomId'] as String? ?? '';
        if (rId.isNotEmpty) {
          final r = await getRoomById(rId);
          if (r != null) {
            b['roomTitle'] = r.title;
            b['roomAddress'] = r.address;
            b['roomPrice'] = r.price;
            b['roomImage'] = r.images.isNotEmpty ? r.images.first : '';
          }
        }
      }
    }

    return list;
  }

  // Lấy danh sách lịch hẹn khách gửi đến phòng của mình (owner)
  Future<List<Map<String, dynamic>>> getBookingsForOwner(String ownerId) async {
    final snapshot = await _firestore
        .collection('bookings')
        .where('ownerId', isEqualTo: ownerId)
        .get();

    final list = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

    list.sort((a, b) {
      final dateA = (a['appointmentDate'] as Timestamp?)?.toDate() ?? DateTime(2000);
      final dateB = (b['appointmentDate'] as Timestamp?)?.toDate() ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    for (var b in list) {
      if ((b['roomTitle'] as String? ?? '').isEmpty) {
        final rId = b['roomId'] as String? ?? '';
        if (rId.isNotEmpty) {
          final r = await getRoomById(rId);
          if (r != null) {
            b['roomTitle'] = r.title;
            b['roomAddress'] = r.address;
            b['roomPrice'] = r.price;
            b['roomImage'] = r.images.isNotEmpty ? r.images.first : '';
          }
        }
      }
    }

    return list;
  }

  // Cập nhật trạng thái lịch hẹn.
  // Các trạng thái hợp lệ: 'pending' | 'confirmed' | 'cancelled' | 'completed'
  Future<void> updateBookingStatus(String bookingId, String status) async {
    assert(
      ['pending', 'confirmed', 'cancelled', 'completed'].contains(status),
      'status không hợp lệ: $status',
    );

    final doc = await _firestore.collection('bookings').doc(bookingId).get();
    final data = doc.data();
    final guestUserId = data?['userId'] as String? ?? '';

    await _firestore.collection('bookings').doc(bookingId).update({
      'status': status,
    });

    // Thông báo cho người đặt lịch
    if (guestUserId.isNotEmpty) {
      String title;
      String body;

      switch (status) {
        case 'confirmed':
          title = 'Lịch hẹn đã được xác nhận! ✅';
          body = 'Chủ trọ đã đồng ý lịch hẹn xem phòng của bạn. Vui lòng đến đúng giờ đã hẹn!';
          break;
        case 'cancelled':
          title = 'Lịch hẹn bị từ chối ❌';
          body = 'Rất tiếc, chủ trọ hiện không thể tiếp bạn vào khung giờ đã chọn.';
          break;
        case 'completed':
          title = 'Lịch hẹn đã hoàn thành 🎉';
          body = 'Lịch xem phòng của bạn đã được đánh dấu hoàn thành. Hãy chia sẻ đánh giá về phòng nhé!';
          break;
        default:
          return; // Không gửi thông báo cho trạng thái 'pending'
      }

      await NotificationService().sendUserNotification(
        userId: guestUserId,
        title: title,
        body: body,
        type: 'booking',
      );
    }
  }

  // Đẩy dữ liệu mẫu lên Firestore (Chỉ dùng cho bước Development)
  Future<void> seedMockData() async {
    final batch = _firestore.batch();

    for (var room in mockRooms) {
      final docRef = _firestore.collection('rooms').doc(room.roomId);
      batch.set(docRef, room.toMap());
    }

    await batch.commit();
  }
}
