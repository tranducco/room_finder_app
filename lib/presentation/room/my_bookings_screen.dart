import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/review_service.dart';
import '../../data/room_service.dart';
import '../../domain/models/review.dart';
import '../widgets/app_button_style.dart';
import '../widgets/app_image.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  final RoomService _roomService = RoomService();
  final ReviewService _reviewService = ReviewService();

  List<Map<String, dynamic>> _myBookings = [];
  List<Map<String, dynamic>> _ownerBookings = [];
  bool _isLoading = true;
  late TabController _tabController;

  final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final my = await _roomService.getMyBookings(user.uid);
      final owner = await _roomService.getBookingsForOwner(user.uid);
      if (mounted) {
        setState(() {
          _myBookings = my;
          _ownerBookings = owner;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String bookingId, String status) async {
    try {
      await _roomService.updateBookingStatus(bookingId, status);
      if (!mounted) return;

      String message;
      Color bgColor;

      switch (status) {
        case 'confirmed':
          message = '✅ Đã xác nhận lịch hẹn xem phòng';
          bgColor = Colors.teal;
          break;
        case 'cancelled':
          message = '❌ Đã hủy / từ chối lịch hẹn';
          bgColor = Colors.red;
          break;
        case 'completed':
          message = '🎉 Đã hoàn thành xem phòng! Bạn có thể đánh giá phòng ngay.';
          bgColor = const Color(0xFF00897B);
          break;
        default:
          message = 'Đã cập nhật trạng thái lịch hẹn';
          bgColor = Colors.blueGrey;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadBookings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  /// Mở trang chi tiết phòng
  Future<void> _openRoomDetail(String roomId) async {
    if (roomId.isEmpty) return;
    try {
      final room = await _roomService.getRoomById(roomId);
      if (!mounted) return;
      if (room != null) {
        Navigator.pushNamed(context, '/room-detail', arguments: room);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy thông tin phòng này.')),
        );
      }
    } catch (_) {}
  }

  /// Mở hộp thoại viết đánh giá cho phòng vừa hoàn thành xem
  void _openWriteReviewDialog(Map<String, dynamic> booking) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để đánh giá!')),
      );
      return;
    }

    final roomId = booking['roomId'] as String? ?? '';
    final roomTitle = booking['roomTitle'] as String? ?? 'Phòng trọ';
    final ownerId = booking['ownerId'] as String? ?? '';

    double selectedRating = 5.0;
    final commentController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Đánh giá phòng trọ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    Text(
                      roomTitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),

                    // Star selector
                    Center(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final starNum = index + 1;
                              return IconButton(
                                iconSize: 36,
                                onPressed: () {
                                  setModalState(() => selectedRating = starNum.toDouble());
                                },
                                icon: Icon(
                                  starNum <= selectedRating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: Colors.amber,
                                ),
                              );
                            }),
                          ),
                          Text(
                            selectedRating == 5
                                ? '⭐⭐⭐⭐⭐ Tuyệt vời!'
                                : selectedRating == 4
                                    ? '⭐⭐⭐⭐ Rất tốt'
                                    : selectedRating == 3
                                        ? '⭐⭐⭐ Bình thường'
                                        : selectedRating == 2
                                            ? '⭐⭐ Chưa hài lòng'
                                            : '⭐ Rất tệ',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: commentController,
                      decoration: InputDecoration(
                        labelText: 'Nhận xét của bạn *',
                        hintText: 'Cảm nhận về phòng: sạch sẽ, an ninh, chủ trọ thân thiện...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF00897B)),
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final comment = commentController.text.trim();
                                if (comment.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Vui lòng nhập nhận xét của bạn'),
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => isSubmitting = true);
                                final messenger = ScaffoldMessenger.of(context);
                                final nav = Navigator.of(ctx);

                                try {
                                  final rev = Review(
                                    reviewId: '',
                                    roomId: roomId,
                                    userId: user.uid,
                                    userName: user.displayName ?? 'Người dùng',
                                    userAvatar: user.photoURL ?? '',
                                    ownerId: ownerId,
                                    rating: selectedRating,
                                    comment: comment,
                                  );

                                  await _reviewService.addReview(rev);
                                  if (!mounted) return;
                                  nav.pop();
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('🎉 Gửi đánh giá thành công! Cảm ơn bạn.'),
                                      backgroundColor: Color(0xFF00897B),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Lỗi: $e')),
                                  );
                                }
                              },
                        style: AppButtonStyle.primary(hoverElevation: 3),
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'GỬI ĐÁNH GIÁ NGAY',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Lịch hẹn xem phòng',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadBookings,
            tooltip: 'Làm mới',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF00897B),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF00897B),
          tabs: [
            Tab(text: 'Lịch tôi đặt (${_myBookings.length})'),
            Tab(text: 'Khách đặt phòng tôi (${_ownerBookings.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00897B)),
            )
          : TabBarView(
              controller: _tabController,
              children: [_buildMyBookingsList(), _buildOwnerBookingsList()],
            ),
    );
  }

  Widget _buildMyBookingsList() {
    if (_myBookings.isEmpty) {
      return _emptyState(
        icon: Icons.calendar_today_outlined,
        message: 'Chưa có lịch hẹn nào',
        sub: 'Bấm "Đặt lịch xem phòng" trong trang chi tiết phòng để hẹn xem trực tiếp',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myBookings.length,
        itemBuilder: (context, index) {
          final booking = _myBookings[index];
          return _bookingCard(booking, isOwner: false);
        },
      ),
    );
  }

  Widget _buildOwnerBookingsList() {
    if (_ownerBookings.isEmpty) {
      return _emptyState(
        icon: Icons.inbox_outlined,
        message: 'Chưa có lịch hẹn từ khách',
        sub: 'Khi có người đặt lịch xem phòng của bạn, họ sẽ xuất hiện tại đây',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _ownerBookings.length,
        itemBuilder: (context, index) {
          final booking = _ownerBookings[index];
          return _bookingCard(booking, isOwner: true);
        },
      ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> booking, {required bool isOwner}) {
    final status = booking['status'] as String? ?? 'pending';
    final phone = booking['phone'] as String? ?? '';
    final note = booking['note'] as String? ?? '';
    final bookingId = booking['id'] as String? ?? '';
    final roomId = booking['roomId'] as String? ?? '';
    final roomTitle = booking['roomTitle'] as String? ?? 'Phòng trọ';
    final roomAddress = booking['roomAddress'] as String? ?? '';
    final roomImage = booking['roomImage'] as String? ?? '';
    final roomPrice = (booking['roomPrice'] ?? 0).toDouble();

    DateTime? appointmentDate;
    final rawDate = booking['appointmentDate'];
    if (rawDate is Timestamp) {
      appointmentDate = rawDate.toDate();
    } else if (rawDate is String) {
      appointmentDate = DateTime.tryParse(rawDate);
    }

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (status) {
      case 'confirmed':
        statusColor = Colors.teal;
        statusLabel = 'Đã xác nhận';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusLabel = isOwner ? 'Đã từ chối' : 'Đã hủy lịch';
        statusIcon = Icons.cancel_rounded;
        break;
      case 'completed':
        statusColor = const Color(0xFF00897B);
        statusLabel = 'Đã hoàn thành xem phòng';
        statusIcon = Icons.verified_rounded;
        break;
      default:
        statusColor = Colors.orange;
        statusLabel = 'Đang chờ xác nhận';
        statusIcon = Icons.pending_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // Header with status badge & appointment date
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(18),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (appointmentDate != null)
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(appointmentDate),
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),

          // Room brief row (clickable)
          InkWell(
            onTap: () => _openRoomDetail(roomId),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: roomImage.isNotEmpty
                          ? AppImage(
                              imageUrl: roomImage,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.home_rounded,
                                color: Colors.grey,
                                size: 36,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          roomTitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (roomAddress.isNotEmpty)
                          Text(
                            roomAddress,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        if (roomPrice > 0)
                          Text(
                            '${currencyFormatter.format(roomPrice)}/tháng',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00897B),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Booking contact details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (phone.isNotEmpty)
                  _infoRow(
                    Icons.phone_outlined,
                    isOwner ? 'SĐT của khách' : 'SĐT liên hệ',
                    phone,
                  ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _infoRow(Icons.notes_rounded, 'Lời nhắn', note),
                ],

                // ── HÀNH ĐỘNG DÀNH CHO KHÁCH (Lịch tôi đặt) ────────────────
                if (!isOwner) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Nút Hủy lịch nếu đang chờ hoặc đã xác nhận
                      if (status == 'pending' || status == 'confirmed')
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _updateStatus(bookingId, 'cancelled'),
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: const Text('Hủy lịch'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),

                      if (status == 'confirmed') const SizedBox(width: 10),

                      // Nút hoàn thành xem phòng
                      if (status == 'confirmed')
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _updateStatus(bookingId, 'completed'),
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                            label: const Text('Đã xem phòng'),
                            style: AppButtonStyle.primary(
                              borderRadius: 8,
                              hoverElevation: 3,
                            ),
                          ),
                        ),

                      // Nút đánh giá phòng khi đã hoàn thành
                      if (status == 'completed')
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openWriteReviewDialog(booking),
                            icon: const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                            label: const Text(
                              'Đánh giá phòng ngay',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: AppButtonStyle.primary(
                              borderRadius: 8,
                              hoverElevation: 3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],

                // ── HÀNH ĐỘNG DÀNH CHO CHỦ PHÒNG (Khách đặt phòng tôi) ─────
                if (isOwner) ...[
                  if (status == 'pending') ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _updateStatus(bookingId, 'cancelled'),
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: const Text('Từ chối'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _updateStatus(bookingId, 'confirmed'),
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text('Xác nhận lịch'),
                            style: AppButtonStyle.primary(
                              borderRadius: 8,
                              hoverElevation: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (status == 'confirmed') ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _updateStatus(bookingId, 'completed'),
                        icon: const Icon(Icons.verified_outlined, size: 16),
                        label: const Text('Đánh dấu đã tiếp khách xong (Hoàn thành)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00897B),
                          side: const BorderSide(color: Color(0xFF00897B)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String message,
    required String sub,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
