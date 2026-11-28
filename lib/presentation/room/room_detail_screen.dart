import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/guards/auth_guard.dart';
import '../../data/review_service.dart';
import '../../data/room_service.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/room.dart';
import '../widgets/app_button_style.dart';
import '../widgets/room_google_map_card.dart';
import 'widgets/room_detail_sheets.dart';
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
            onPressed: () => showRoomReportDialog(context, room: room),
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
                    onWriteReview: () => showRoomReviewBottomSheet(
                      context,
                      room: room,
                      roomService: _roomService,
                      reviewService: _reviewService,
                      onRoomUpdated: (updated) {
                        if (mounted) setState(() => _latestRoom = updated);
                      },
                    ),
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
                          onPressed: () => showRoomBookingBottomSheet(context, room: room, roomService: _roomService),
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

}
