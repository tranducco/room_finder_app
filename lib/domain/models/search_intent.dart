/// Model đại diện cho ý định tìm kiếm phòng của người dùng (Search Intent).
/// Được trích xuất từ câu hỏi tự nhiên của người dùng qua Bước 1 của kiến trúc RAG.
class UserSearchIntent {
  /// Ngân sách tối đa tính bằng VNĐ (Ví dụ: 3 triệu -> 3000000).
  /// Null nếu người dùng không nhắc đến mức giá.
  final double? maxPrice;

  /// Quận/khu vực tại Hà Nội (Ví dụ: 'Đống Đa', 'Cầu Giấy', 'Thanh Xuân',...).
  /// Null nếu người dùng không nhắc đến khu vực.
  final String? district;

  /// Danh sách tiện nghi mong muốn (Ví dụ: ['Điều hòa', 'Nóng lạnh', 'Ban công', 'Máy giặt']).
  final List<String> amenities;

  /// Loại hình phòng (Ví dụ: 'Phòng khép kín', 'Chung cư mini', 'Căn hộ', 'Ký túc xá').
  final String? roomType;

  /// Cờ xác định câu hỏi có phải là tìm kiếm phòng trọ hay không.
  /// True: người dùng đang muốn tìm/thuê/hỏi phòng.
  /// False: người dùng chỉ chào hỏi hoặc hỏi thủ tục, quy định, FAQ chung.
  final bool isRoomSearchQuery;

  const UserSearchIntent({
    this.maxPrice,
    this.district,
    this.amenities = const [],
    this.roomType,
    this.isRoomSearchQuery = true,
  });

  /// Parse an toàn từ JSON do Gemini API sinh ra (Structured Output)
  factory UserSearchIntent.fromJson(Map<String, dynamic> json) {
    // Chuẩn hoá giá: nếu LLM trả 3.0 (triệu), đổi sang 3000000 VNĐ
    double? parsedPrice;
    final rawPrice = json['maxPrice'];
    if (rawPrice != null) {
      final numVal = (rawPrice as num).toDouble();
      if (numVal > 0 && numVal < 1000) {
        // Ví dụ 3.5 -> 3,500,000 VNĐ
        parsedPrice = numVal * 1000000;
      } else if (numVal >= 1000) {
        parsedPrice = numVal;
      }
    }

    // Chuẩn hoá danh sách tiện ích
    List<String> parsedAmenities = [];
    if (json['amenities'] is List) {
      parsedAmenities = (json['amenities'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    String? parsedDistrict = json['district'] as String?;
    if (parsedDistrict != null) {
      parsedDistrict = parsedDistrict.trim();
      if (parsedDistrict.isEmpty || parsedDistrict.toLowerCase() == 'null') {
        parsedDistrict = null;
      }
    }

    String? parsedRoomType = json['roomType'] as String?;
    if (parsedRoomType != null) {
      parsedRoomType = parsedRoomType.trim();
      if (parsedRoomType.isEmpty || parsedRoomType.toLowerCase() == 'null') {
        parsedRoomType = null;
      }
    }

    final isSearch = json['isRoomSearchQuery'] is bool
        ? json['isRoomSearchQuery'] as bool
        : (parsedDistrict != null || parsedPrice != null || parsedAmenities.isNotEmpty);

    return UserSearchIntent(
      maxPrice: parsedPrice,
      district: parsedDistrict,
      amenities: parsedAmenities,
      roomType: parsedRoomType,
      isRoomSearchQuery: isSearch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isRoomSearchQuery': isRoomSearchQuery,
      'maxPrice': maxPrice,
      'district': district,
      'roomType': roomType,
      'amenities': amenities,
    };
  }

  @override
  String toString() {
    return 'UserSearchIntent(isSearch: $isRoomSearchQuery, district: $district, maxPrice: $maxPrice, roomType: $roomType, amenities: $amenities)';
  }
}

