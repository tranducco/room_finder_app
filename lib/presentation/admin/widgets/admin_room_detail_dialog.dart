import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/room.dart';
import '../../widgets/app_button_style.dart';
import '../../widgets/app_image.dart';

class AdminRoomDetailDialog extends StatelessWidget {
  final Room room;
  final VoidCallback onApprove;
  final Function(String reason) onReject;
  final VoidCallback onHide;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const AdminRoomDetailDialog({
    super.key,
    required this.room,
    required this.onApprove,
    required this.onReject,
    required this.onHide,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 760 ? 720.0 : screenWidth * 0.94;
    final isSmall = screenWidth < 720;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        color: Colors.white,
        child: Column(
          children: [
            // Topbar
            Container(
              padding: EdgeInsets.symmetric(horizontal: isSmall ? 14 : 24, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Row(
                children: [
                  _buildStatusBadge(room.status),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Chi tiết tin đăng #${room.roomId}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Images gallery
                    if (room.images.isNotEmpty) ...[
                      SizedBox(
                        height: 220,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: room.images.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (ctx, idx) => ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio: 16 / 10,
                              child: AppImage(
                                imageUrl: room.images[idx],
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Title & Price
                    Text(
                      room.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${currencyFormatter.format(room.price)} / tháng',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF00897B),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${room.area} m²',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            room.roomType,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Information rows
                    _infoRow(
                      Icons.location_on_outlined,
                      'Địa chỉ',
                      '${room.address} (${room.district})',
                    ),
                    const SizedBox(height: 10),
                    _infoRow(
                      Icons.person_outline,
                      'Chủ tin đăng (Owner ID)',
                      room.ownerId,
                    ),

                    // Utility Costs & Deposit
                    if (room.deposit > 0 ||
                        room.electricityPrice > 0 ||
                        room.waterPrice > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _costCell(
                                Icons.security_rounded,
                                'Tiền cọc',
                                room.deposit > 0
                                    ? currencyFormatter.format(room.deposit)
                                    : 'Không cọc',
                                Colors.deepPurple,
                              ),
                            ),
                            Expanded(
                              child: _costCell(
                                Icons.electric_bolt_rounded,
                                'Điện',
                                room.electricityPrice > 0
                                    ? '${currencyFormatter.format(room.electricityPrice)}/kWh'
                                    : 'Nhà nước',
                                Colors.amber.shade800,
                              ),
                            ),
                            Expanded(
                              child: _costCell(
                                Icons.water_drop_rounded,
                                'Nước',
                                room.waterPrice > 0
                                    ? '${currencyFormatter.format(room.waterPrice)}/m³'
                                    : 'Nhà nước',
                                Colors.blue.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (room.rejectionReason != null &&
                        room.rejectionReason!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.red.shade700, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Lý do từ chối: ${room.rejectionReason}',
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Text(
                      'Mô tả phòng',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      room.description.isNotEmpty
                          ? room.description
                          : 'Chưa có mô tả chi tiết.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      'Tiện ích có sẵn',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: room.amenities.map((amenity) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00897B).withAlpha(15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF00897B).withAlpha(40),
                            ),
                          ),
                          child: Text(
                            amenity,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF00897B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Actions Footer
            Container(
              padding: EdgeInsets.symmetric(horizontal: isSmall ? 14 : 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Xóa tin
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onDelete();
                    },
                    icon: Icon(Icons.delete_outline,
                        color: Colors.red.shade600, size: 18),
                    label: Text(
                      'Xóa bài đăng',
                      style: TextStyle(color: Colors.red.shade600),
                    ),
                  ),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Nếu là hidden -> Khôi phục
                      if (room.status == 'hidden') ...[
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            onRestore();
                          },
                          icon: const Icon(Icons.restore_rounded, size: 16),
                          label: const Text('Khôi phục hiển thị'),
                          style: AppButtonStyle.primary(),
                        ),
                      ],

                      // Nếu là available -> Ẩn
                      if (room.status == 'available') ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            onHide();
                          },
                          icon: const Icon(Icons.visibility_off_outlined, size: 16),
                          label: const Text('Ẩn tin'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade800,
                            side: BorderSide(color: Colors.orange.shade300),
                          ),
                        ),
                      ],

                      // Nếu đang chờ duyệt hoặc bị reject -> Cho phép Duyệt
                      if (room.status == 'pending_approval' ||
                          room.status == 'rejected') ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showRejectPrompt(context);
                          },
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Từ chối duyệt'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade300),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            onApprove();
                          },
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Duyệt tin ngay'),
                          style: AppButtonStyle.primary(),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectPrompt(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Lý do từ chối tin đăng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập lý do để thông báo cho người đăng bài:',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Ví dụ: Ảnh phòng không rõ ràng, thông tin địa chỉ chưa chính xác...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập lý do từ chối')),
                );
                return;
              }
              Navigator.pop(ctx);
              onReject(reason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác nhận từ chối'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF00897B)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _costCell(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case 'available':
        bg = const Color(0xFFE8F5E9);
        text = const Color(0xFF2E7D32);
        label = 'Còn trống / Đang hiển thị';
        break;
      case 'pending_approval':
        bg = const Color(0xFFFFF8E1);
        text = const Color(0xFFF57F17);
        label = 'Chờ duyệt';
        break;
      case 'rented':
        bg = const Color(0xFFE3F2FD);
        text = const Color(0xFF1565C0);
        label = 'Đã cho thuê';
        break;
      case 'rejected':
        bg = const Color(0xFFFFEBEE);
        text = const Color(0xFFC62828);
        label = 'Bị từ chối';
        break;
      case 'hidden':
      default:
        bg = const Color(0xFFF5F5F5);
        text = const Color(0xFF616161);
        label = 'Tạm ẩn';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

