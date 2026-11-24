/// Mô tả cấu hình của 1 Gói Đăng Tin (Đồng, Bạc, Vàng)
class PackagePlan {
  final String id; // 'bronze' | 'silver' | 'gold'
  final String name; // 'Gói Đồng' | 'Gói Bạc' | 'Gói Vàng'
  final double price; // 15000, 39000, 69000
  final int durationDays; // 7, 15, 30
  final int priority; // 1, 2, 3
  final String badgeText; // 'ĐỒNG', 'BẠC', 'VÀNG'
  final String colorHex; // '#CD7F32', '#78909C', '#FFA000'
  final String description;
  final List<String> benefits;
  final bool isPopular;

  const PackagePlan({
    required this.id,
    required this.name,
    required this.price,
    required this.durationDays,
    required this.priority,
    required this.badgeText,
    required this.colorHex,
    required this.description,
    required this.benefits,
    this.isPopular = false,
  });

  /// Danh sách 3 gói chuẩn theo yêu cầu dự án TroTot
  static const List<PackagePlan> defaultPlans = [
    PackagePlan(
      id: 'bronze',
      name: 'Gói Đồng',
      price: 15000,
      durationDays: 7,
      priority: 1,
      badgeText: 'ĐỒNG',
      colorHex: '#CD7F32',
      description: 'Lựa chọn tiết kiệm, đẩy tin nhẹ nhàng tiếp cận sinh viên & người thuê.',
      benefits: [
        'Ưu tiên hiển thị trên tin đăng thường (Priority 1)',
        'Gắn huy hiệu ĐỒNG nổi bật trên thẻ phòng',
        'Thời hạn sử dụng liên tục 7 ngày',
        'Tự động hoàn về tin thường khi hết hạn',
      ],
      isPopular: false,
    ),
    PackagePlan(
      id: 'silver',
      name: 'Gói Bạc',
      price: 39000,
      durationDays: 15,
      priority: 2,
      badgeText: 'BẠC',
      colorHex: '#78909C',
      description: 'Tối ưu chi phí và hiệu quả, tiếp cận lượng người thuê phòng gấp 2.5 lần.',
      benefits: [
        'Ưu tiên hiển thị trên Gói Đồng & Tin thường (Priority 2)',
        'Gắn huy hiệu BẠC kim loại lấp lánh',
        'Thời hạn sử dụng 15 ngày (2 tuần + 1 ngày)',
        'Được gắn nhãn Gợi ý nổi bật trong kết quả tìm kiếm',
        'Hỗ trợ đẩy tin nhanh chóng khi có khách tìm quanh khu vực',
      ],
      isPopular: false,
    ),
    PackagePlan(
      id: 'gold',
      name: 'Gói Vàng',
      price: 69000,
      durationDays: 30,
      priority: 3,
      badgeText: 'VÀNG',
      colorHex: '#FFA000',
      description: 'Gói cao cấp nhất! Hiển thị trên đỉnh trang chủ, tìm khách thuê nhanh nhất.',
      benefits: [
        'ƯU TIÊN CAO NHẤT toàn hệ thống (Priority 3, đỉnh danh sách)',
        'Huy hiệu VÀNG VIP sang trọng kèm ngôi sao tỏa sáng',
        'Thời hạn sử dụng tối đa 30 ngày (1 tháng)',
        'Hiển thị đầu tiên khi tìm kiếm theo khu vực / quận huyện',
        'Ưu tiên gợi ý cho Chatbot AI khi người dùng hỏi tư vấn',
        'Khả năng cho thuê phòng nhanh gấp 4 lần tin thường',
      ],
      isPopular: true,
    ),
  ];

  static PackagePlan getById(String id) {
    return defaultPlans.firstWhere(
      (p) => p.id == id,
      orElse: () => defaultPlans.first,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'durationDays': durationDays,
      'priority': priority,
      'badgeText': badgeText,
      'colorHex': colorHex,
      'description': description,
      'benefits': benefits,
      'isPopular': isPopular,
    };
  }

  factory PackagePlan.fromMap(Map<String, dynamic> map, String docId) {
    return PackagePlan(
      id: docId.isNotEmpty ? docId : (map['id'] ?? 'bronze'),
      name: map['name'] ?? 'Gói Đăng Tin',
      price: (map['price'] ?? 15000).toDouble(),
      durationDays: (map['durationDays'] ?? 7) as int,
      priority: (map['priority'] ?? 1) as int,
      badgeText: map['badgeText'] ?? 'VIP',
      colorHex: map['colorHex'] ?? '#00897B',
      description: map['description'] ?? '',
      benefits: List<String>.from(map['benefits'] ?? []),
      isPopular: map['isPopular'] as bool? ?? false,
    );
  }
}
