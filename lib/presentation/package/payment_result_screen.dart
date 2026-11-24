import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/package_plan.dart';
import '../../domain/models/room.dart';

class PaymentResultScreen extends StatelessWidget {
  final bool isSuccess;
  final String orderId;
  final PackagePlan package;
  final Room room;
  final DateTime? paidAt;
  final DateTime? expiresAt;
  final String? transId;
  final String? errorMessage;

  const PaymentResultScreen({
    super.key,
    required this.isSuccess,
    required this.orderId,
    required this.package,
    required this.room,
    this.paidAt,
    this.expiresAt,
    this.transId,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: Text(isSuccess ? 'Thanh Toán Thành Công' : 'Thanh Toán Thất Bại'),
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 48 : 20,
            vertical: 32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: isSuccess
                  ? _buildSuccessCard(context, currencyFormatter)
                  : _buildFailureCard(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessCard(BuildContext context, NumberFormat currencyFormatter) {
    final expiryFormatted = expiresAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(expiresAt!)
        : 'Sau ${package.durationDays} ngày';

    final isGold = package.id == 'gold';
    final isSilver = package.id == 'silver';
    final badgeColor = isGold
        ? const Color(0xFFFFA000)
        : (isSilver ? const Color(0xFF78909C) : const Color(0xFFCD7F32));

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Icon Thành công
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF4CAF50), width: 3),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF2E7D32),
              size: 48,
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Kích Hoạt Gói Thành Công! 🎉',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tin đăng của bạn đã được nâng cấp lên ${package.name} và đang được ưu tiên hiển thị cao nhất trên Trọ Tốt.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 24),

          // Tóm tắt thông tin gói và phòng
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Column(
              children: [
                _buildInfoRow('Mã đơn hàng:', orderId, isMonospace: true),
                if (transId != null && transId!.isNotEmpty)
                  _buildInfoRow('Mã GD MoMo:', transId!, isMonospace: true),
                _buildInfoRow('Phòng áp dụng:', room.title),
                _buildInfoRow(
                  'Gói kích hoạt:',
                  '${package.name} (Hạng ${package.priority})',
                  customBadgeColor: badgeColor,
                ),
                _buildInfoRow('Số tiền đã trả:', currencyFormatter.format(package.price)),
                _buildInfoRow('Thời hạn sử dụng:', '${package.durationDays} ngày'),
                const Divider(height: 16),
                _buildInfoRow(
                  'Có hiệu lực đến:',
                  expiryFormatted,
                  isBold: true,
                  highlightColor: const Color(0xFF00897B),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Nút bấm điều hướng
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00695C),
                    side: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Về Trang Chủ', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/my-packages');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Quản Lý Gói VIP', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFailureCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.red.shade400, width: 3),
            ),
            child: Icon(
              Icons.close_rounded,
              color: Colors.red.shade700,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Thanh Toán Chưa Thành Công',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage ?? 'Giao dịch trên cổng MoMo đã bị hủy hoặc chưa hoàn tất.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(context, '/my-rooms', (r) => false);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Về Phòng Của Tôi'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(
                      context,
                      '/order-confirmation',
                      arguments: {
                        'package': package,
                        'preselectedRoomId': room.roomId,
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Thử Lại'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isMonospace = false,
    bool isBold = false,
    Color? highlightColor,
    Color? customBadgeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(width: 12),
          Expanded(
            child: customBadgeColor != null
                ? Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: customBadgeColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                : Text(
                    value,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: isMonospace ? 'monospace' : null,
                      fontSize: 13,
                      fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                      color: highlightColor ?? const Color(0xFF1A1A2E),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
