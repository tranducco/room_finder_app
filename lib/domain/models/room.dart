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
  final String ward;             // Phường/xã
  final String street;           // Tên đường
  final double deposit;          // Tiền cọc
  final double electricityPrice; // Giá điện (VNĐ/kWh)
  final double waterPrice;       // Giá nước (VNĐ/m³)
  final double averageRating;    // Trung bình đánh giá (0.0 – 5.0)
  final int totalReviews;        // Tổng số lượt đánh giá
  final List<String> images;
  final List<String> amenities;
  final String roomType;
  final String status;
  final String? rejectionReason;
  final String? moderatedBy;
  final DateTime? createdAt;
  final DateTime? moderatedAt;

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
    this.moderatedAt,
  });

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
    };
    if (rejectionReason != null) map['rejectionReason'] = rejectionReason;
    if (moderatedBy != null) map['moderatedBy'] = moderatedBy;
    if (createdAt != null) map['createdAt'] = Timestamp.fromDate(createdAt!);
    if (moderatedAt != null) map['moderatedAt'] = Timestamp.fromDate(moderatedAt!);
    return map;
  }

  factory Room.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

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
      createdAt: parseDate(map['createdAt']),
      moderatedAt: parseDate(map['moderatedAt']),
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
    DateTime? moderatedAt,
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
      moderatedAt: moderatedAt ?? this.moderatedAt,
    );
  }
}
