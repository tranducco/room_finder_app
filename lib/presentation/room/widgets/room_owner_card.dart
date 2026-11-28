import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/app_user.dart';
import '../../../domain/models/room.dart';
import '../../widgets/app_image.dart';

class RoomOwnerCard extends StatelessWidget {
  final Room room;
  final AppUser? ownerUser;
  final Map<String, dynamic>? ownerOverview;
  final bool isLoadingOwner;
  final ValueChanged<String> onCopyPhone;

  const RoomOwnerCard({
    super.key,
    required this.room,
    required this.ownerUser,
    required this.ownerOverview,
    required this.isLoadingOwner,
    required this.onCopyPhone,
  });

  static String _formatJoinDuration(DateTime? createdAt) {
    if (createdAt == null) return 'Mới tham gia';
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    final days = difference.inDays;
    if (days < 30) {
      if (days <= 0) return 'Mới tham gia';
      return 'Tham gia $days ngày';
    }
    final months = (days / 30).floor();
    if (months < 12) {
      return '$months tháng';
    }
    final years = (months / 12).floor();
    final remainingMonths = months % 12;
    if (remainingMonths == 0) {
      return '$years năm';
    }
    return '$years năm $remainingMonths tháng';
  }

  static String _formatDateOnly(DateTime? dt) {
    if (dt == null) return 'Chưa rõ';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    return '$d/$m/$y';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingOwner) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF00897B),
          ),
        ),
      );
    }

    final ownerName = ownerUser?.fullName.isNotEmpty == true
        ? ownerUser!.fullName
        : 'Chủ phòng Trọ Tốt';
    final phone = ownerUser?.phoneNumber.isNotEmpty == true
        ? ownerUser!.phoneNumber
        : 'Đang cập nhật';
    final roomCount = ownerOverview?['roomCount'] ?? 1;
    final avgRating = (ownerOverview?['averageRating'] as num?)?.toDouble() ?? room.averageRating;
    final totalReviews = (ownerOverview?['totalReviews'] as num?)?.toInt() ?? room.totalReviews;
    final durationStr = _formatJoinDuration(ownerUser?.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_pin_circle_rounded, color: Color(0xFF00897B), size: 18),
              const SizedBox(width: 6),
              Text(
                'THÔNG TIN NGƯỜI ĐĂNG',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _showOwnerProfileBottomSheet(context),
                child: const Row(
                  children: [
                    Text(
                      'Xem hồ sơ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00897B),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF00897B)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              GestureDetector(
                onTap: () => _showOwnerProfileBottomSheet(context),
                child: Stack(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF00897B), width: 1.5),
                      ),
                      child: ClipOval(
                        child: ownerUser?.avatarUrl.isNotEmpty == true
                            ? AppImage(imageUrl: ownerUser!.avatarUrl, fit: BoxFit.cover)
                            : Container(
                                color: const Color(0xFFE0F2F1),
                                child: Center(
                                  child: Text(
                                    ownerName.isNotEmpty ? ownerName[0].toUpperCase() : 'U',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF00897B),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF00897B),
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _showOwnerProfileBottomSheet(context),
                      child: Text(
                        ownerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (avgRating > 0) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(
                                '${avgRating.toStringAsFixed(1)} ($totalReviews)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ],
                          ),
                          Text('•', style: TextStyle(color: Colors.grey.shade400)),
                        ],
                        Text(
                          '$roomCount tin đăng',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text('•', style: TextStyle(color: Colors.grey.shade400)),
                        Text(
                          durationStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.phone_rounded, size: 13, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            phone,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF00796B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.phone_in_talk_rounded,
                    color: Color(0xFF00897B),
                    size: 20,
                  ),
                ),
                tooltip: 'Sao chép số điện thoại',
                onPressed: () => onCopyPhone(phone),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showOwnerProfileBottomSheet(BuildContext context) {
    showProfileSheet(
      context,
      room: room,
      ownerUser: ownerUser,
      ownerOverview: ownerOverview,
      onCopyPhone: onCopyPhone,
    );
  }

  static void showProfileSheet(
    BuildContext context, {
    required Room room,
    required AppUser? ownerUser,
    required Map<String, dynamic>? ownerOverview,
    required ValueChanged<String> onCopyPhone,
  }) {
    final ownerName = ownerUser?.fullName.isNotEmpty == true
        ? ownerUser!.fullName
        : 'Chủ phòng Trọ Tốt';
    final phone = ownerUser?.phoneNumber.isNotEmpty == true
        ? ownerUser!.phoneNumber
        : 'Đang cập nhật';
    final email = ownerUser?.email.isNotEmpty == true ? ownerUser!.email : '';
    final roomCount = ownerOverview?['roomCount'] ?? 1;
    final avgRating = (ownerOverview?['averageRating'] as num?)?.toDouble() ?? room.averageRating;
    final totalReviews = (ownerOverview?['totalReviews'] as num?)?.toInt() ?? room.totalReviews;
    final durationStr = _formatJoinDuration(ownerUser?.createdAt);
    final joinedDateStr = _formatDateOnly(ownerUser?.createdAt);
    final List<Room> otherRooms = (ownerOverview?['rooms'] as List<Room>?) ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF00897B),
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: ownerUser?.avatarUrl.isNotEmpty == true
                                    ? AppImage(imageUrl: ownerUser!.avatarUrl, fit: BoxFit.cover)
                                    : Container(
                                        color: const Color(0xFFE0F2F1),
                                        child: Center(
                                          child: Text(
                                            ownerName.isNotEmpty ? ownerName[0].toUpperCase() : 'U',
                                            style: const TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF00897B),
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.verified_rounded,
                                  color: Color(0xFF00897B),
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        ownerName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined, size: 14, color: Color(0xFF00796B)),
                            SizedBox(width: 4),
                            Text(
                              'Chủ phòng xác thực Trọ Tốt',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF00796B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.calendar_month_outlined,
                              title: 'Tham gia',
                              value: durationStr,
                              subvalue: 'Từ $joinedDateStr',
                              color: const Color(0xFF00897B),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.home_work_outlined,
                              title: 'Tin đăng',
                              value: '$roomCount tin',
                              subvalue: 'Trên Trọ Tốt',
                              color: const Color(0xFF1E88E5),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.star_rounded,
                              title: 'Đánh giá',
                              value: avgRating > 0 ? '${avgRating.toStringAsFixed(1)} ★' : 'Mới',
                              subvalue: '$totalReviews nhận xét',
                              color: const Color(0xFFFFA000),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.contact_phone_rounded, size: 18, color: Color(0xFF00897B)),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Số điện thoại liên hệ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Text(
                                    'Đã xác thực SĐT',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.phone_rounded, color: Color(0xFF00897B)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      phone,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A2E),
                                        letterSpacing: 0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => onCopyPhone(phone),
                                    icon: const Icon(Icons.copy_rounded, size: 15),
                                    label: const Text('Sao chép'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00897B),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (otherRooms.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.apartment_rounded, color: Color(0xFF00897B), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Các tin đăng khác của chủ trọ (${otherRooms.length})',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: otherRooms.length > 5 ? 5 : otherRooms.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, idx) {
                            final r = otherRooms[idx];
                            final isCurrent = r.roomId == room.roomId;
                            return InkWell(
                              onTap: isCurrent
                                  ? null
                                  : () {
                                      Navigator.pop(ctx);
                                      Navigator.pushReplacementNamed(
                                        context,
                                        '/room-detail',
                                        arguments: r,
                                      );
                                    },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isCurrent ? const Color(0xFFE0F2F1) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCurrent
                                        ? const Color(0xFF00897B)
                                        : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 60,
                                        height: 60,
                                        child: r.images.isNotEmpty
                                            ? AppImage(imageUrl: r.images.first, fit: BoxFit.cover)
                                            : Container(
                                                color: Colors.grey.shade200,
                                                child: const Icon(Icons.home, color: Colors.grey),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            r.title,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: isCurrent ? const Color(0xFF004D40) : const Color(0xFF1A1A2E),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(r.price)}/tháng • ${r.area}m²',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF00897B),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            r.district,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isCurrent)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00897B),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Đang xem',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildMetricTile({
    required IconData icon,
    required String title,
    required String value,
    required String subvalue,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          Text(
            subvalue,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
