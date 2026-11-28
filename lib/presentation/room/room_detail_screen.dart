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
import '../widgets/app_image.dart';

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
  int _currentImageIndex = 0;
  late PageController _pageController;
  late ScrollController _thumbnailScrollController;

  AppUser? _ownerUser;
  Map<String, dynamic>? _ownerOverview;
  bool _isLoadingOwner = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _thumbnailScrollController = ScrollController();
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
    _pageController.dispose();
    _thumbnailScrollController.dispose();
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

  void _goToImage(int index, int totalImages) {
    setState(() => _currentImageIndex = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    _scrollThumbnailTo(index);
  }

  void _scrollThumbnailTo(int index) {
    final thumbWidth = 98.0;
    final targetOffset = index * thumbWidth;
    if (_thumbnailScrollController.hasClients) {
      _thumbnailScrollController.animateTo(
        targetOffset.clamp(
          0.0,
          _thumbnailScrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ===== FULL-SCREEN IMAGE VIEWER =====
  void _openImageViewer(List<String> images, int startIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(230),
      builder: (ctx) => _ImageViewerDialog(
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
    final hasImages = images.isNotEmpty;

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
                _buildGallery(room, images, hasImages),
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

                  // Living costs (Deposit, Electric, Water)
                  _buildUtilityCosts(room, currencyFormatter),
                  const SizedBox(height: 16),

                  // Thông tin người đăng (Chủ phòng)
                  _buildOwnerCard(room),
                  const SizedBox(height: 16),

                  // Thông tin bài đăng & Hạn tin 10 ngày & Gói VIP
                  _buildPostMetadataCard(room),
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
                  _buildReviewsSection(room),
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
                              _showOwnerProfileBottomSheet(room);
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

  String _formatJoinDuration(DateTime? createdAt) {
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

  Widget _buildOwnerCard(Room room) {
    if (_isLoadingOwner) {
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

    final ownerName = _ownerUser?.fullName.isNotEmpty == true
        ? _ownerUser!.fullName
        : 'Chủ phòng Trọ Tốt';
    final phone = _ownerUser?.phoneNumber.isNotEmpty == true
        ? _ownerUser!.phoneNumber
        : 'Đang cập nhật';
    final roomCount = _ownerOverview?['roomCount'] ?? 1;
    final avgRating = (_ownerOverview?['averageRating'] as num?)?.toDouble() ?? room.averageRating;
    final totalReviews = (_ownerOverview?['totalReviews'] as num?)?.toInt() ?? room.totalReviews;
    final durationStr = _formatJoinDuration(_ownerUser?.createdAt);

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
                onTap: () => _showOwnerProfileBottomSheet(room),
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
                onTap: () => _showOwnerProfileBottomSheet(room),
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
                        child: _ownerUser?.avatarUrl.isNotEmpty == true
                            ? AppImage(imageUrl: _ownerUser!.avatarUrl, fit: BoxFit.cover)
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
                      onTap: () => _showOwnerProfileBottomSheet(room),
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
                onPressed: () => _copyPhone(phone),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showOwnerProfileBottomSheet(Room room) {
    final ownerName = _ownerUser?.fullName.isNotEmpty == true
        ? _ownerUser!.fullName
        : 'Chủ phòng Trọ Tốt';
    final phone = _ownerUser?.phoneNumber.isNotEmpty == true
        ? _ownerUser!.phoneNumber
        : 'Đang cập nhật';
    final email = _ownerUser?.email.isNotEmpty == true ? _ownerUser!.email : '';
    final roomCount = _ownerOverview?['roomCount'] ?? 1;
    final avgRating = (_ownerOverview?['averageRating'] as num?)?.toDouble() ?? room.averageRating;
    final totalReviews = (_ownerOverview?['totalReviews'] as num?)?.toInt() ?? room.totalReviews;
    final durationStr = _formatJoinDuration(_ownerUser?.createdAt);
    final joinedDateStr = _formatDateOnly(_ownerUser?.createdAt);
    final List<Room> otherRooms = (_ownerOverview?['rooms'] as List<Room>?) ?? [];

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
                                child: _ownerUser?.avatarUrl.isNotEmpty == true
                                    ? AppImage(imageUrl: _ownerUser!.avatarUrl, fit: BoxFit.cover)
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
                                    onPressed: () => _copyPhone(phone),
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

  Widget _buildMetricTile({
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

  Widget _buildPostMetadataCard(Room room) {
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
                        isExpired
                            ? 'Đã hết hạn'
                            : 'Còn $remaining ngày',
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

  // ===== GALLERY WIDGET =====
  Widget _buildGallery(Room room, List<String> images, bool hasImages) {
    if (!hasImages) {
      return Container(
        height: 260,
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 768;
    final galleryHeight = isDesktop ? 460.0 : 320.0;

    return Column(
      children: [
        // Main image with left/right arrows
        Container(
          height: galleryHeight,
          margin: isDesktop ? const EdgeInsets.fromLTRB(16, 12, 16, 0) : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: isDesktop ? BorderRadius.circular(16) : BorderRadius.zero,
            boxShadow: isDesktop
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // PageView for swipe
              PageView.builder(
                controller: _pageController,
                itemCount: images.length,
                onPageChanged: (idx) {
                  setState(() => _currentImageIndex = idx);
                  _scrollThumbnailTo(idx);
                },
                itemBuilder: (context, index) {
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => _openImageViewer(images, index),
                      child: Container(
                        color: const Color(0xFF18181B),
                        child: Center(
                          child: AppImage(
                            imageUrl: images[index],
                            fit: BoxFit.contain, // 100% full uncropped image!
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Left navigation arrow
              if (images.length > 1)
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: HoverWidget(
                      onTap: () {
                        if (_currentImageIndex > 0) {
                          _goToImage(_currentImageIndex - 1, images.length);
                        } else {
                          _goToImage(images.length - 1, images.length);
                        }
                      },
                      builder: (context, isHovered) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isHovered
                              ? Colors.black.withAlpha(190)
                              : Colors.black.withAlpha(120),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isHovered
                                ? Colors.white.withAlpha(220)
                                : Colors.white.withAlpha(90),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(40),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),

              // Right navigation arrow
              if (images.length > 1)
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: HoverWidget(
                      onTap: () {
                        if (_currentImageIndex < images.length - 1) {
                          _goToImage(_currentImageIndex + 1, images.length);
                        } else {
                          _goToImage(0, images.length);
                        }
                      },
                      builder: (context, isHovered) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isHovered
                              ? Colors.black.withAlpha(190)
                              : Colors.black.withAlpha(120),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isHovered
                                ? Colors.white.withAlpha(220)
                                : Colors.white.withAlpha(90),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(40),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),

              // Zoom hint badge
              Positioned(
                bottom: 12,
                left: 14,
                child: HoverWidget(
                  onTap: () => _openImageViewer(images, _currentImageIndex),
                  builder: (context, isHovered) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isHovered
                          ? const Color(0xFF00897B).withAlpha(230)
                          : Colors.black.withAlpha(140),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withAlpha(isHovered ? 180 : 80),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 5),
                        Text(
                          'Xem toàn màn hình',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Counter badge
              Positioned(
                bottom: 12,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(150),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_library_outlined, color: Colors.white, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        '${_currentImageIndex + 1} / ${images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Room type badge top-left
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00695C),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(30),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    room.roomType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Thumbnail strip
        if (images.length > 1)
          Container(
            height: 90,
            margin: isDesktop ? const EdgeInsets.fromLTRB(16, 8, 16, 0) : EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isDesktop ? Colors.grey.shade50 : Colors.grey.shade100,
              borderRadius: isDesktop ? BorderRadius.circular(12) : BorderRadius.zero,
            ),
            child: ListView.builder(
              controller: _thumbnailScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final isSelected = index == _currentImageIndex;
                return HoverWidget(
                  onTap: () {
                    _goToImage(index, images.length);
                  },
                  builder: (context, isHovered) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 90,
                    margin: const EdgeInsets.only(right: 8),
                    transform: Matrix4.translationValues(0, isHovered ? -2 : 0, 0),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF00897B)
                            : (isHovered ? const Color(0xFF26A69A) : Colors.transparent),
                        width: isSelected ? 2.8 : (isHovered ? 2.0 : 1.0),
                      ),
                      boxShadow: isSelected || isHovered
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00897B).withAlpha(isHovered ? 60 : 40),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AppImage(
                            imageUrl: images[index],
                            fit: BoxFit.cover,
                          ),
                          if (!isSelected && !isHovered)
                            Container(
                              color: Colors.black.withAlpha(40),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
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

  Widget _buildUtilityCosts(Room room, NumberFormat currencyFormatter) {
    final hasCosts = room.deposit > 0 || room.electricityPrice > 0 || room.waterPrice > 0;
    if (!hasCosts) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('💰 Chi phí & Tiền cọc'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _costItem(
                  icon: Icons.security_rounded,
                  label: 'Tiền đặt cọc',
                  value: room.deposit > 0
                      ? currencyFormatter.format(room.deposit)
                      : 'Không cọc',
                  color: Colors.deepPurple,
                ),
              ),
              Expanded(
                child: _costItem(
                  icon: Icons.electric_bolt_rounded,
                  label: 'Giá điện',
                  value: room.electricityPrice > 0
                      ? '${currencyFormatter.format(room.electricityPrice)}/kWh'
                      : 'Giá nhà nước',
                  color: Colors.amber.shade800,
                ),
              ),
              Expanded(
                child: _costItem(
                  icon: Icons.water_drop_rounded,
                  label: 'Giá nước',
                  value: room.waterPrice > 0
                      ? '${currencyFormatter.format(room.waterPrice)}/m³'
                      : 'Giá nhà nước',
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _costItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withAlpha(25),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildReviewsSection(Room room) {
    return StreamBuilder<List<Review>>(
      stream: _reviewService.reviewsStream(room.roomId),
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? [];

        // Tính toán rating thực tế dựa trên reviews hiện có
        final totalReviews = reviews.isNotEmpty
            ? reviews.length
            : (snapshot.connectionState == ConnectionState.waiting
                ? room.totalReviews
                : 0);
        final averageRating = reviews.isNotEmpty
            ? (reviews.map((r) => r.rating).reduce((a, b) => a + b) /
                reviews.length)
            : (snapshot.connectionState == ConnectionState.waiting
                ? room.averageRating
                : 0.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('⭐ Đánh giá & Nhận xét'),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          averageRating > 0
                              ? averageRating.toStringAsFixed(1)
                              : 'Chưa có đánh giá',
                          style: TextStyle(
                            fontSize: averageRating > 0 ? 20 : 15,
                            fontWeight: FontWeight.bold,
                            color: averageRating > 0
                                ? const Color(0xFF1A1A2E)
                                : Colors.grey.shade600,
                          ),
                        ),
                        if (averageRating > 0) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(5, (index) {
                              return Icon(
                                index < averageRating.round()
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: Colors.amber,
                                size: 16,
                              );
                            }),
                          ),
                          Text(
                            '($totalReviews)',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showReviewBottomSheet(room),
                  icon: const Icon(Icons.rate_review_outlined, size: 15),
                  label: const Text('Viết đánh giá'),
                  style: AppButtonStyle.primary(
                    borderRadius: 8,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: Color(0xFF00897B)),
                ),
              )
            else if (reviews.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.star_outline_rounded,
                        size: 36, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    const Text(
                      'Chưa có đánh giá nào cho phòng này',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hãy là người đầu tiên trải nghiệm và để lại nhận xét cho phòng trọ này nhé!',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reviews.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final r = reviews[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              const Color(0xFF00897B).withAlpha(30),
                          backgroundImage: r.userAvatar.isNotEmpty
                              ? NetworkImage(r.userAvatar)
                              : null,
                          child: r.userAvatar.isEmpty
                              ? Text(
                                  r.userName.isNotEmpty
                                      ? r.userName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Color(0xFF00897B),
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.userName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (r.createdAt != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('dd/MM/yyyy HH:mm')
                                          .format(r.createdAt!),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: List.generate(5, (sIndex) {
                                  return Icon(
                                    sIndex < r.rating.round()
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: Colors.amber,
                                    size: 16,
                                  );
                                }),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                r.comment,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF1F2937),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
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

// ======================================================
// FULL-SCREEN IMAGE VIEWER DIALOG
// ======================================================
class _ImageViewerDialog extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _ImageViewerDialog({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<_ImageViewerDialog> {
  late int _current;
  late PageController _pageCtrl;
  late ScrollController _thumbCtrl;
  // One TransformationController per image for independent zoom state
  late List<TransformationController> _transformControllers;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    _thumbCtrl = ScrollController();
    _transformControllers = List.generate(
      widget.images.length,
      (_) => TransformationController(),
    );
    // Scroll thumbnail to initial position after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollThumbTo(_current);
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _thumbCtrl.dispose();
    for (final c in _transformControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.images.length) return;
    setState(() => _current = index);
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _scrollThumbTo(index);
  }

  void _scrollThumbTo(int index) {
    if (!_thumbCtrl.hasClients) return;
    const thumbW = 72.0;
    final target = (index * thumbW).clamp(
      0.0,
      _thumbCtrl.position.maxScrollExtent,
    );
    _thumbCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // Double-tap to reset zoom
  void _resetZoom(int index) {
    _transformControllers[index].value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final isFirst = _current == 0;
    final isLast = _current == images.length - 1;

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // ---- Main zoomable PageView ----
          PageView.builder(
            controller: _pageCtrl,
            itemCount: images.length,
            onPageChanged: (i) {
              setState(() => _current = i);
              _scrollThumbTo(i);
            },
            itemBuilder: (ctx, index) {
              return GestureDetector(
                onDoubleTapDown: (details) {
                  final controller = _transformControllers[index];
                  if (controller.value != Matrix4.identity()) {
                    // Already zoomed — reset
                    controller.value = Matrix4.identity();
                  } else {
                    // Zoom in 2.5x at tap position
                    final pos = details.localPosition;
                    const scale = 2.5;
                    controller.value = Matrix4.identity()
                      ..translateByDouble(-pos.dx * (scale - 1), -pos.dy * (scale - 1), 0.0, 0.0)
                      ..scaleByDouble(scale, scale, 1.0, 1.0);
                  }
                },
                child: InteractiveViewer(
                  transformationController: _transformControllers[index],
                  panEnabled: true,
                  scaleEnabled: true,
                  minScale: 1.0,
                  maxScale: 5.0,
                  child: Center(
                    child: AppImage(
                      imageUrl: images[index],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),

          // ---- Top bar: counter + close ----
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 8,
                bottom: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(160),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Counter
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(120),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.photo_library_outlined,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_current + 1} / ${images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Close button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(140),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---- Hint: double-tap to zoom ----
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: 0.7,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(80),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Chạm 2 lần để phóng to • Kéo để thu nhỏ',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
              ),
            ),
          ),

          // ---- Left arrow ----
          if (!isFirst)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    _resetZoom(_current);
                    _goTo(_current - 1);
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(120),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withAlpha(60),
                      ),
                    ),
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),

          // ---- Right arrow ----
          if (!isLast)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    _resetZoom(_current);
                    _goTo(_current + 1);
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(120),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withAlpha(60),
                      ),
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),

          // ---- Bottom thumbnail strip ----
          if (images.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom,
              left: 0,
              right: 0,
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withAlpha(200),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                child: ListView.builder(
                  controller: _thumbCtrl,
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  itemBuilder: (ctx, index) {
                    final isSel = index == _current;
                    return GestureDetector(
                      onTap: () {
                        _resetZoom(_current);
                        _goTo(index);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 64,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSel
                                ? const Color(0xFF26A69A)
                                : Colors.white.withAlpha(60),
                            width: isSel ? 2.5 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Opacity(
                            opacity: isSel ? 1.0 : 0.55,
                            child: AppImage(
                              imageUrl: images[index],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

