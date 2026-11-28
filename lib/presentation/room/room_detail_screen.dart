import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/guards/auth_guard.dart';
import '../../data/admin_service.dart';
import '../../data/review_service.dart';
import '../../data/room_service.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/report.dart';
import '../../domain/models/review.dart';
import '../../domain/models/room.dart';
import '../widgets/app_button_style.dart';
import '../widgets/room_google_map_card.dart';
import 'widgets/room_gallery_widget.dart';
import 'widgets/room_image_viewer_dialog.dart';
import 'widgets/room_owner_card.dart';
import 'widgets/room_post_metadata_card.dart';
import 'widgets/room_reviews_section.dart';
import 'widgets/room_utility_costs_card.dart';

class RoomDetailScreen extends StatefulWidget {
  const RoomDetailScreen({super.key});

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  final RoomService _roomService = RoomService();
  final ReviewService _reviewService = ReviewService();
  Room? _latestRoom;
  bool _isFavorite = false;
  bool _hasCheckedFavorite = false;
  AppUser? _ownerUser;
  Map<String, dynamic>? _ownerOverview;
  bool _isLoadingOwner = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasCheckedFavorite) {
      final room = ModalRoute.of(context)!.settings.arguments as Room;
      _checkFavorite();
      _loadOwnerInfo(room.ownerId);
      _hasCheckedFavorite = true;
    }
  }

  Future<void> _loadOwnerInfo(String ownerId) async {
    if (ownerId.isEmpty) {
      if (mounted) setState(() => _isLoadingOwner = false);
      return;
    }
    final user = await _roomService.getOwnerProfile(ownerId);
    final overview = await _roomService.getOwnerOverview(ownerId);
    if (mounted) {
      setState(() {
        _ownerUser = user;
        _ownerOverview = overview;
        _isLoadingOwner = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final room = ModalRoute.of(context)!.settings.arguments as Room;
    final isFav = await _roomService.isFavorite(user.uid, room.roomId);
    if (mounted) {
      setState(() => _isFavorite = isFav);
    }
  }

  Future<void> _toggleFavorite(Room room) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AuthGuard.requireLogin(context, featureName: 'Lưu phòng yêu thích');
      return;
    }

    setState(() => _isFavorite = !_isFavorite);
    final status = await _roomService.toggleFavorite(user.uid, room.roomId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status ? 'Đã lưu vào yêu thích' : 'Đã bỏ lưu yêu thích',
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ===== FULL-SCREEN IMAGE VIEWER =====
  void _openImageViewer(List<String> images, int startIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(230),
      builder: (ctx) => RoomImageViewerDialog(
        images: images,
        initialIndex: startIndex,
      ),
    );
  }

  String _formatDateVi(DateTime date) {
    const weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    final weekday = weekdays[(date.weekday - 1) % 7];
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year;
    return '$weekday, $d/$m/$y';
  }

  void _showReportDialog(Room room) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AuthGuard.requireLogin(context, featureName: 'Báo cáo vi phạm');
      return;
    }

    final reasonOptions = [
      'Giá phòng không đúng thực tế',
      'Phòng đã cho thuê nhưng không cập nhật',
      'Ảnh phòng giả mạo / Không đúng thực tế',
      'Số điện thoại / Địa chỉ liên hệ sai lệch',
      'Nghi vấn lừa đảo / Yêu cầu đặt cọc mờ ám',
      'Nội dung hoặc hình ảnh phản cảm',
      'Khác',
    ];

    String selectedReason = reasonOptions.first;
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.report_problem_rounded, color: Colors.red.shade600, size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Báo cáo tin đăng vi phạm',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tin đăng: ${room.title}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Lý do báo cáo: *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedReason,
                      items: reasonOptions.map((r) {
                        return DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedReason = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Mô tả chi tiết:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Cung cấp thêm chi tiết giúp Admin kiểm tra nhanh chóng...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final report = Report(
                  id: '',
                  roomId: room.roomId,
                  roomTitle: room.title,
                  reporterId: user.uid,
                  reporterEmail: user.email ?? 'Ẩn danh',
                  reason: selectedReason,
                  description: descController.text.trim(),
                  status: 'pending',
                  createdAt: DateTime.now(),
                );

                Navigator.pop(ctx);
                await AdminService().createReport(report);

                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('✅ Cảm ơn bạn! Báo cáo vi phạm đã được gửi tới Ban quản trị.'),
                      backgroundColor: Color(0xFF00897B),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Gửi báo cáo'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookingBottomSheet(Room room) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AuthGuard.requireLogin(context, featureName: 'Đặt lịch xem phòng');
      return;
    }

    if (user.uid == room.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn là chủ sở hữu, không thể tự đặt lịch xem phòng của chính mình!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
    final phoneController = TextEditingController(text: user.phoneNumber ?? '');
    final noteController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
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
                    // Handle bar
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
                          'Đặt lịch xem phòng',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(bottomSheetContext),
                        ),
                      ],
                    ),
                    Text(
                      room.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),

                    // Date picker tile
                    _bookingTile(
                      icon: Icons.calendar_month,
                      label: 'Ngày hẹn xem',
                      value: _formatDateVi(selectedDate),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 60),
                          ),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    _bookingTile(
                      icon: Icons.access_time_rounded,
                      label: 'Giờ hẹn',
                      value: selectedTime.format(context),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setModalState(() => selectedTime = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      decoration: InputDecoration(
                        labelText: 'Số điện thoại liên hệ *',
                        hintText: 'Nhập SĐT để chủ phòng liên hệ lại',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF00897B),
                          ),
                        ),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: 'Lời nhắn cho chủ trọ',
                        hintText: 'VD: Em muốn xem phòng buổi sáng...',
                        prefixIcon: const Icon(Icons.notes_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF00897B),
                          ),
                        ),
                        isDense: true,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final phone = phoneController.text.trim();
                                if (phone.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Vui lòng nhập số điện thoại',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setModalState(() => isSubmitting = true);
                                final messenger = ScaffoldMessenger.of(
                                  this.context,
                                );
                                final nav = Navigator.of(bottomSheetContext);
                                try {
                                  final appointmentDateTime = DateTime(
                                    selectedDate.year,
                                    selectedDate.month,
                                    selectedDate.day,
                                    selectedTime.hour,
                                    selectedTime.minute,
                                  );
                                  await _roomService.createBooking(
                                    roomId: room.roomId,
                                    roomTitle: room.title,
                                    roomAddress: room.address,
                                    roomPrice: room.price,
                                    roomImage: room.images.isNotEmpty ? room.images.first : '',
                                    userId: user.uid,
                                    userName: user.displayName ?? '',
                                    userEmail: user.email ?? '',
                                    ownerId: room.ownerId,
                                    appointmentDate: appointmentDateTime,
                                    phone: phone,
                                    note: noteController.text.trim(),
                                  );
                                  if (!mounted) return;
                                  nav.pop();
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '✅ Đã gửi lịch hẹn thành công!',
                                      ),
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
                                'XÁC NHẬN ĐẶT LỊCH HẸN',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
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

  void _showReviewBottomSheet(Room room) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AuthGuard.requireLogin(context, featureName: 'Viết đánh giá phòng trọ');
      return;
    }

    if (user.uid == room.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn là chủ phòng, không thể tự đánh giá phòng của chính mình!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
      builder: (bottomSheetContext) {
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
                          onPressed: () => Navigator.pop(bottomSheetContext),
                        ),
                      ],
                    ),
                    Text(
                      room.title,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),

                    // Interactive Star selector
                    Center(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final starNum = index + 1;
                              return IconButton(
                                iconSize: 32,
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                constraints: const BoxConstraints(),
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
                          const SizedBox(height: 4),
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
                                final messenger = ScaffoldMessenger.of(this.context);
                                final nav = Navigator.of(bottomSheetContext);

                                try {
                                  final rev = Review(
                                    reviewId: '',
                                    roomId: room.roomId,
                                    userId: user.uid,
                                    userName: user.displayName ?? 'Người dùng',
                                    userAvatar: user.photoURL ?? '',
                                    ownerId: room.ownerId,
                                    rating: selectedRating,
                                    comment: comment,
                                  );

                                  await _reviewService.addReview(rev);

                                  // Tải lại dữ liệu mới nhất của phòng
                                  final updatedRoom = await _roomService.getRoomById(room.roomId);
                                  if (mounted && updatedRoom != null) {
                                    setState(() => _latestRoom = updatedRoom);
                                  }

                                  nav.pop();
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('🎉 Cảm ơn bạn đã gửi đánh giá!'),
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
                                'GỬI ĐÁNH GIÁ',
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
    final Room initialRoom = ModalRoute.of(context)!.settings.arguments as Room;
    final Room room = _latestRoom ?? initialRoom;
    final currencyFormatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
    );
    final images = room.images;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0.5,
        title: Text(
          room.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : const Color(0xFF1A1A2E),
            ),
            onPressed: () => _toggleFavorite(room),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã sao chép liên kết phòng!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Báo cáo vi phạm',
            icon: Icon(Icons.outlined_flag_rounded, color: Colors.red.shade400),
            onPressed: () => _showReportDialog(room),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RoomGalleryWidget(
                  room: room,
                  images: images,
                  onOpenImageViewer: _openImageViewer,
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge + Status
                      Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00897B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          room.roomType,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: room.status == 'available'
                              ? Colors.teal.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          room.status == 'available' ? 'Còn trống' : 'Đã cho thuê',
                          style: TextStyle(
                            color: room.status == 'available'
                                ? Colors.teal.shade700
                                : Colors.red.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (room.isVip)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: switch (room.vipType) {
                              'diamond' => const LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFE91E63)]),
                              'gold' => const LinearGradient(colors: [Color(0xFFFFA000), Color(0xFFFF6F00)]),
                              'silver' => const LinearGradient(colors: [Color(0xFF78909C), Color(0xFF455A64)]),
                              _ => const LinearGradient(colors: [Color(0xFF00897B), Color(0xFF00695C)]),
                            },
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                switch (room.vipType) {
                                  'diamond' => Icons.diamond_rounded,
                                  'gold' => Icons.workspace_premium_rounded,
                                  _ => Icons.military_tech_rounded,
                                },
                                color: Colors.white,
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                switch (room.vipType) {
                                  'diamond' => 'VIP Kim Cương',
                                  'gold' => 'VIP Vàng',
                                  'silver' => 'VIP Bạc',
                                  _ => 'VIP',
                                },
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (room.averageRating > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${room.averageRating.toStringAsFixed(1)} (${room.totalReviews})',
                                style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (room.isPromotedActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: room.effectivePriority == 3 || room.packageType == 'gold'
                                  ? [const Color(0xFFFFB300), const Color(0xFFFFA000)]
                                  : (room.effectivePriority == 2 || room.packageType == 'silver'
                                      ? [const Color(0xFF90A4AE), const Color(0xFF78909C)]
                                      : [const Color(0xFFD7CCC8), const Color(0xFFCD7F32)]),
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(20),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                room.effectivePriority == 3 || room.packageType == 'gold'
                                    ? Icons.workspace_premium_rounded
                                    : (room.effectivePriority == 2 || room.packageType == 'silver'
                                        ? Icons.shield_rounded
                                        : Icons.military_tech_rounded),
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'GÓI ${room.packageType.toUpperCase()} • CÒN ${room.packageRemainingDays} NGÀY',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    room.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Price
                  Text(
                    '${currencyFormatter.format(room.price)}/tháng',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00897B),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick info chips
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _infoChip(
                          Icons.square_foot_rounded,
                          '${room.area} m²',
                          'Diện tích',
                        ),
                        _verticalDivider(),
                        _infoChip(
                          Icons.meeting_room_outlined,
                          room.roomType,
                          'Loại phòng',
                        ),
                        _verticalDivider(),
                        _infoChip(
                          Icons.location_city_rounded,
                          room.district,
                          'Khu vực',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Address section
                  _sectionTitle('📍 Địa chỉ'),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: Colors.red.shade400,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          room.address,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade800,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (room.address.trim().isNotEmpty || room.district.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    RoomGoogleMapCard(
                      address: room.address,
                      ward: room.ward,
                      district: room.district,
                    ),
                  ],

                  // Living costs (Deposit, Electric, Water)
                  RoomUtilityCostsCard(
                    room: room,
                    currencyFormatter: currencyFormatter,
                  ),
                  const SizedBox(height: 16),

                  // Thông tin người đăng (Chủ phòng)
                  RoomOwnerCard(
                    room: room,
                    ownerUser: _ownerUser,
                    ownerOverview: _ownerOverview,
                    isLoadingOwner: _isLoadingOwner,
                    onCopyPhone: _copyPhone,
                  ),
                  const SizedBox(height: 16),

                  // Thông tin bài đăng & Hạn tin 10 ngày & Gói VIP
                  RoomPostMetadataCard(room: room),
                  const SizedBox(height: 20),
                  const Divider(),

                  // Amenities
                  _sectionTitle('✨ Tiện ích phòng'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: room.amenities
                        .map(
                          (a) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00897B).withAlpha(15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF00897B).withAlpha(60),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: Color(0xFF00897B),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  a,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF00897B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),

                  // Description
                  _sectionTitle('📝 Mô tả chi tiết'),
                  const SizedBox(height: 8),
                  Text(
                    room.description,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Reviews & Ratings Section
                  RoomReviewsSection(
                    room: room,
                    reviewService: _reviewService,
                    onWriteReview: () => _showReviewBottomSheet(room),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
  bottomNavigationBar: Container(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Row(
                  children: [
                    // Nút gọi điện / liên hệ nhanh cho chủ phòng
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final phone = _ownerUser?.phoneNumber.isNotEmpty == true
                                ? _ownerUser!.phoneNumber
                                : '';
                            if (phone.isNotEmpty) {
                              _copyPhone(phone);
                            } else {
                              RoomOwnerCard.showProfileSheet(
                                context,
                                room: room,
                                ownerUser: _ownerUser,
                                ownerOverview: _ownerOverview,
                                onCopyPhone: _copyPhone,
                              );
                            }
                          },
                          icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                          label: const Text(
                            'Gọi điện',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00897B),
                            side: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Nút đặt lịch xem phòng
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () => _showBookingBottomSheet(room),
                          icon: const Icon(Icons.calendar_today_rounded, size: 17),
                          label: Text(
                            MediaQuery.of(context).size.width < 380
                                ? 'ĐẶT LỊCH'
                                : 'ĐẶT LỊCH XEM PHÒNG',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: AppButtonStyle.primary(hoverElevation: 4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  // ===== OWNER PROFILE & POST METADATA HELPERS =====
  Future<void> _copyPhone(String phone) async {
    if (phone.isEmpty || phone == 'Đang cập nhật') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chủ phòng chưa cập nhật số điện thoại.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: phone));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Đã sao chép SĐT: $phone vào bộ nhớ tạm!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF00897B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1A2E),
      ),
    );
  }

  Widget _infoChip(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF00897B), size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(width: 1, height: 40, color: Colors.grey.shade200);
  }

  Widget _bookingTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF00897B), size: 20),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.edit_calendar_outlined,
              color: Colors.grey.shade400,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
