import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/guards/auth_guard.dart';
import '../../../data/admin_service.dart';
import '../../../data/review_service.dart';
import '../../../data/room_service.dart';
import '../../../domain/models/report.dart';
import '../../../domain/models/review.dart';
import '../../../domain/models/room.dart';
import '../../widgets/app_button_style.dart';

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

/// Opens the violation report dialog for [room].
void showRoomReportDialog(BuildContext context, {required Room room}) {
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
      builder: (dialogContext, setModalState) => AlertDialog(
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

              if (context.mounted) {
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

/// Opens the room viewing booking bottom sheet for [room].
void showRoomBookingBottomSheet(
  BuildContext context, {
  required Room room,
  required RoomService roomService,
}) {
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
        builder: (sheetCtx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
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
                  _BookingTile(
                    icon: Icons.calendar_month,
                    label: 'Ngày hẹn xem',
                    value: _formatDateVi(selectedDate),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: sheetCtx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  _BookingTile(
                    icon: Icons.access_time_rounded,
                    label: 'Giờ hẹn',
                    value: selectedTime.format(sheetCtx),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: sheetCtx,
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
                        borderSide: const BorderSide(color: Color(0xFF00897B)),
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
                        borderSide: const BorderSide(color: Color(0xFF00897B)),
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
                                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Vui lòng nhập số điện thoại'),
                                  ),
                                );
                                return;
                              }
                              setModalState(() => isSubmitting = true);
                              final messenger = ScaffoldMessenger.of(context);
                              final nav = Navigator.of(bottomSheetContext);
                              try {
                                final appointmentDateTime = DateTime(
                                  selectedDate.year,
                                  selectedDate.month,
                                  selectedDate.day,
                                  selectedTime.hour,
                                  selectedTime.minute,
                                );
                                await roomService.createBooking(
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
                                if (!context.mounted) return;
                                nav.pop();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Đã gửi lịch hẹn thành công!'),
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

/// Opens the review & star rating bottom sheet for [room].
void showRoomReviewBottomSheet(
  BuildContext context, {
  required Room room,
  required RoomService roomService,
  required ReviewService reviewService,
  required ValueChanged<Room> onRoomUpdated,
}) {
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
        builder: (sheetCtx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
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
                                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Vui lòng nhập nhận xét của bạn'),
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              final messenger = ScaffoldMessenger.of(context);
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

                                await reviewService.addReview(rev);

                                final updatedRoom = await roomService.getRoomById(room.roomId);
                                if (context.mounted && updatedRoom != null) {
                                  onRoomUpdated(updatedRoom);
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

class _BookingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _BookingTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
