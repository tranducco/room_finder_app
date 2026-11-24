import 'package:cloud_firestore/cloud_firestore.dart';

class Room {
  final String roomId;
  final String ownerId;
  final String title;
  final String description;
  final double price;
  final double area;
  final String address;
  final String district;
  final String ward; // Phường/xã
  final String street; // Tên đường
  final double deposit; // Tiền cọc
  final double electricityPrice; // Giá điện (VNĐ/kWh)
  final double waterPrice; // Giá nước (VNĐ/m³)
  final double averageRating; // Trung bình đánh giá (0.0 – 5.0)
  final int totalReviews; // Tổng số lượt đánh giá
  final List<String> images;
  final List<String> amenities;
  final String roomType;
  final String status;
  final String? rejectionReason;
  final String? moderatedBy;
  final DateTime? createdAt;
  final DateTime? expiredAt; // Ngày hết hạn tin đăng thường (10 ngày)
  final String vipType; // Tương thích cũ
  final DateTime? moderatedAt;

  // ─── THÔNG TIN GÓI ĐĂNG TIN ĐỒNG - BẠC - VÀNG (MỚI) ───
  final String packageType; // 'normal' | 'bronze' | 'silver' | 'gold'
  final int priority; // 0: Thường, 1: Đồng, 2: Bạc, 3: Vàng
  final DateTime? packageStartAt; // Thời điểm kích hoạt gói
  final DateTime? packageExpiresAt; // Thời điểm gói hết hạn

  Room({
    required this.roomId,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.price,
    required this.area,
    required this.address,
    required this.district,
    this.ward = '',
    this.street = '',
    this.deposit = 0.0,
    this.electricityPrice = 0.0,
    this.waterPrice = 0.0,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    required this.images,
    required this.amenities,
    required this.roomType,
    required this.status,
    this.rejectionReason,
    this.moderatedBy,
    this.createdAt,
    this.expiredAt,
    this.vipType = 'normal',
    this.moderatedAt,
    this.packageType = 'normal',
    this.priority = 0,
    this.packageStartAt,
    this.packageExpiresAt,
  });

  /// Kiểm tra xem gói VIP (Đồng/Bạc/Vàng) còn trong thời hạn sử dụng hay không
  bool get isPromotedActive {
    if (priority <= 0) return false;
    if (packageExpiresAt == null) return false;
    return packageExpiresAt!.isAfter(DateTime.now());
  }

  /// Priority thực tế (nếu đã hết hạn thì trả về 0 để trở về tin thường tự động)
  int get effectivePriority => isPromotedActive ? priority : 0;

  /// Loại gói thực tế (nếu đã hết hạn thì trả về 'normal')
  String get effectivePackageType => isPromotedActive ? packageType : 'normal';

  /// Số ngày còn lại của gói trả phí
  int get packageRemainingDays {
    if (!isPromotedActive || packageExpiresAt == null) return 0;
    final diff = packageExpiresAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff + 1;
  }

  bool get isVip => vipType != 'normal' || effectivePriority > 0;

  bool get isExpired {
    if (expiredAt == null) return false;
    return DateTime.now().isAfter(expiredAt!);
  }

  int get remainingDays {
    if (expiredAt == null) return 10;
    final diff = expiredAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'roomId': roomId,
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'price': price,
      'area': area,
      'address': address,
      'district': district,
      'ward': ward,
      'street': street,
      'deposit': deposit,
      'electricityPrice': electricityPrice,
      'waterPrice': waterPrice,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'images': images,
      'amenities': amenities,
      'roomType': roomType,
      'status': status,
      'vipType': vipType,
      'packageType': packageType,
      'priority': priority,
    };
    if (rejectionReason != null) map['rejectionReason'] = rejectionReason;
    if (moderatedBy != null) map['moderatedBy'] = moderatedBy;
    if (createdAt != null) map['createdAt'] = Timestamp.fromDate(createdAt!);
    if (expiredAt != null) map['expiredAt'] = Timestamp.fromDate(expiredAt!);
    if (moderatedAt != null) map['moderatedAt'] = Timestamp.fromDate(moderatedAt!);
    if (packageStartAt != null) map['packageStartAt'] = Timestamp.fromDate(packageStartAt!);
    if (packageExpiresAt != null) map['packageExpiresAt'] = Timestamp.fromDate(packageExpiresAt!);
    return map;
  }

  factory Room.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime? parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final created = parseDate(map['createdAt']);
    DateTime? expired = parseDate(map['expiredAt']);
    if (expired == null && created != null) {
      expired = created.add(const Duration(days: 10));
    }

    // Tương thích ngược: map từ vipType cũ nếu packageType chưa có
    String pkgType = map['packageType'] as String? ?? '';
    int prio = (map['priority'] ?? 0) as int;
    final rawVip = (map['vipType'] as String? ?? 'normal').toLowerCase();

    if (pkgType.isEmpty || pkgType == 'normal') {
      if (rawVip == 'gold' || rawVip == 'diamond') {
        pkgType = 'gold';
        if (prio == 0) prio = 3;
      } else if (rawVip == 'silver') {
        pkgType = 'silver';
        if (prio == 0) prio = 2;
      } else if (rawVip == 'bronze') {
        pkgType = 'bronze';
        if (prio == 0) prio = 1;
      } else {
        pkgType = 'normal';
      }
    }

    DateTime? pkgStart = parseDate(map['packageStartAt']);
    DateTime? pkgExpires = parseDate(map['packageExpiresAt']);

    return Room(
      roomId: documentId,
      ownerId: map['ownerId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      area: (map['area'] ?? 0).toDouble(),
      address: map['address'] ?? '',
      district: map['district'] ?? '',
      ward: map['ward'] as String? ?? '',
      street: map['street'] as String? ?? '',
      deposit: (map['deposit'] ?? 0).toDouble(),
      electricityPrice: (map['electricityPrice'] ?? 0).toDouble(),
      waterPrice: (map['waterPrice'] ?? 0).toDouble(),
      averageRating: (map['averageRating'] ?? 0).toDouble(),
      totalReviews: (map['totalReviews'] ?? 0) as int,
      images: List<String>.from(map['images'] ?? []),
      amenities: List<String>.from(map['amenities'] ?? []),
      roomType: map['roomType'] ?? '',
      status: map['status'] ?? 'available',
      rejectionReason: map['rejectionReason'] as String?,
      moderatedBy: map['moderatedBy'] as String?,
      createdAt: created,
      expiredAt: expired,
      vipType: map['vipType'] as String? ?? 'normal',
      moderatedAt: parseDate(map['moderatedAt']),
      packageType: pkgType,
      priority: prio,
      packageStartAt: pkgStart,
      packageExpiresAt: pkgExpires,
    );
  }

  Room copyWith({
    String? roomId,
    String? ownerId,
    String? title,
    String? description,
    double? price,
    double? area,
    String? address,
    String? district,
    String? ward,
    String? street,
    double? deposit,
    double? electricityPrice,
    double? waterPrice,
    double? averageRating,
    int? totalReviews,
    List<String>? images,
    List<String>? amenities,
    String? roomType,
    String? status,
    String? rejectionReason,
    String? moderatedBy,
    DateTime? createdAt,
    DateTime? expiredAt,
    String? vipType,
    DateTime? moderatedAt,
    String? packageType,
    int? priority,
    DateTime? packageStartAt,
    DateTime? packageExpiresAt,
  }) {
    return Room(
      roomId: roomId ?? this.roomId,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      area: area ?? this.area,
      address: address ?? this.address,
      district: district ?? this.district,
      ward: ward ?? this.ward,
      street: street ?? this.street,
      deposit: deposit ?? this.deposit,
      electricityPrice: electricityPrice ?? this.electricityPrice,
      waterPrice: waterPrice ?? this.waterPrice,
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
      images: images ?? this.images,
      amenities: amenities ?? this.amenities,
      roomType: roomType ?? this.roomType,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      moderatedBy: moderatedBy ?? this.moderatedBy,
      createdAt: createdAt ?? this.createdAt,
      expiredAt: expiredAt ?? this.expiredAt,
      vipType: vipType ?? this.vipType,
      moderatedAt: moderatedAt ?? this.moderatedAt,
      packageType: packageType ?? this.packageType,
      priority: priority ?? this.priority,
      packageStartAt: packageStartAt ?? this.packageStartAt,
      packageExpiresAt: packageExpiresAt ?? this.packageExpiresAt,
    );
  }
}
