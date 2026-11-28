import 'package:flutter/material.dart';

import '../../../domain/models/room.dart';

class RoomPostMetadataCard extends StatelessWidget {
  final Room room;

  const RoomPostMetadataCard({
    super.key,
    required this.room,
  });

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Chưa rõ';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y lúc $hh:$mm';
  }

  String _formatDateOnly(DateTime? dt) {
    if (dt == null) return 'Chưa rõ';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    return '$d/$m/$y';
  }

  @override
  Widget build(BuildContext context) {
    final createdStr = _formatDateTime(room.createdAt);
    final expiredStr = _formatDateOnly(room.expiredAt);
    final remaining = room.remainingDays;
    final isExpired = room.isExpired;

    final vipConfig = switch (room.vipType) {
      'diamond' => (
          label: 'TIN VIP KIM CƯƠNG',
          sublabel: 'Ưu tiên hiển thị cao nhất sàn',
          icon: Icons.diamond_rounded,
          gradient: const LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFE91E63)]),
          borderColor: const Color(0xFFE91E63),
        ),
      'gold' => (
          label: 'TIN VIP VÀNG',
          sublabel: 'Tin nổi bật hàng đầu',
          icon: Icons.workspace_premium_rounded,
          gradient: const LinearGradient(colors: [Color(0xFFFFA000), Color(0xFFFF6F00)]),
          borderColor: const Color(0xFFFFA000),
        ),
      'silver' => (
          label: 'TIN VIP BẠC',
          sublabel: 'Tin ưu tiên',
          icon: Icons.military_tech_rounded,
          gradient: const LinearGradient(colors: [Color(0xFF78909C), Color(0xFF455A64)]),
          borderColor: const Color(0xFF90A4AE),
        ),
      _ => (
          label: 'Tin Tiêu Chuẩn',
          sublabel: 'Đang hiển thị bình thường',
          icon: Icons.check_circle_outline_rounded,
          gradient: const LinearGradient(colors: [Color(0xFF00897B), Color(0xFF00695C)]),
          borderColor: const Color(0xFF80CBC4),
        ),
    };

    return Container(
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
              const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF00897B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'THÔNG TIN BÀI ĐĂNG',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: vipConfig.gradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: room.isVip
                      ? [
                          BoxShadow(
                            color: vipConfig.borderColor.withAlpha(80),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(vipConfig.icon, size: 13, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      vipConfig.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildMetaRow(
            icon: Icons.tag_rounded,
            label: 'Mã tin:',
            value: '#${room.roomId.length > 8 ? room.roomId.substring(0, 8).toUpperCase() : room.roomId}',
          ),
          const SizedBox(height: 8),
          _buildMetaRow(
            icon: Icons.access_time_rounded,
            label: 'Ngày đăng tin:',
            value: createdStr,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.hourglass_bottom_rounded, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                'Hạn hiển thị (10 ngày):',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      expiredStr,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isExpired
                            ? Colors.red.shade50
                            : (remaining <= 3 ? Colors.amber.shade50 : Colors.teal.shade50),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isExpired
                              ? Colors.red.shade300
                              : (remaining <= 3 ? Colors.amber.shade400 : Colors.teal.shade300),
                        ),
                      ),
                      child: Text(
                        isExpired ? 'Đã hết hạn' : 'Còn $remaining ngày',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isExpired
                              ? Colors.red.shade700
                              : (remaining <= 3 ? Colors.amber.shade900 : Colors.teal.shade800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }
}
