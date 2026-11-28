import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/auth_service.dart';
import '../../data/room_service.dart';
import '../widgets/app_button_style.dart';
import '../widgets/app_image.dart';
import 'widgets/edit_profile_sheet.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final RoomService _roomService = RoomService();
  final AuthService _authService = AuthService();
  int _myRoomsCount = 0;
  int _favCount = 0;
  int _bookingsCount = 0;
  bool _isLoading = true;

  String _fullName = '';
  String _phoneNumber = '';
  String _avatarUrl = '';
  String _role = 'user';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final myRoomsFuture = _roomService.getMyRooms(user.uid);
      final favIdsFuture = _roomService.getFavoriteRoomIds(user.uid);
      final bookingsFuture = _roomService.getMyBookings(user.uid);
      final profileFuture = _authService.getUserProfile(user.uid);

      final results = await Future.wait([
        myRoomsFuture,
        favIdsFuture,
        bookingsFuture,
        profileFuture,
      ]);

      final myRooms = results[0] as List;
      final favIds = results[1] as List;
      final bookings = results[2] as List;
      final profile = results[3] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _myRoomsCount = myRooms.length;
          _favCount = favIds.length;
          _bookingsCount = bookings.length;
          if (profile != null) {
            _fullName = profile['fullName'] as String? ?? user.displayName ?? '';
            _phoneNumber = profile['phoneNumber'] as String? ?? '';
            _avatarUrl = profile['avatarUrl'] as String? ?? user.photoURL ?? '';
            _role = profile['role'] as String? ?? 'user';
          } else {
            _fullName = user.displayName ?? '';
            _avatarUrl = user.photoURL ?? '';
            _role = 'user';
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final authService = AuthService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // ====== PROFILE HEADER ======
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00695C), Color(0xFF00897B)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    children: [
                      // Avatar with edit button
                      Stack(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withAlpha(30),
                              border: Border.all(
                                color: Colors.white.withAlpha(120),
                                width: 2.5,
                              ),
                            ),
                            child: ClipOval(
                              child: _avatarUrl.isNotEmpty
                                  ? AppImage(
                                      imageUrl: _avatarUrl,
                                      width: 88,
                                      height: 88,
                                      fit: BoxFit.cover,
                                      errorWidget: const Icon(
                                        Icons.person_rounded,
                                        size: 48,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_rounded,
                                      size: 48,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _openEditProfileDialog,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  size: 14,
                                  color: Color(0xFF00897B),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _fullName.isNotEmpty
                            ? _fullName
                            : (user?.displayName ??
                                user?.email?.split('@').first ??
                                'Người dùng'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_role == 'admin') ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade300,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_rounded, size: 13, color: Color(0xFF1A1A2E)),
                              SizedBox(width: 4),
                              Text(
                                'QUẢN TRỊ VIÊN',
                                style: TextStyle(
                                  color: Color(0xFF1A1A2E),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontSize: 13,
                        ),
                      ),
                      if (_phoneNumber.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.phone_android_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _phoneNumber,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Stats row
                      if (!_isLoading)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statItem(_myRoomsCount.toString(), 'Tin đăng'),
                            _divider(),
                            _statItem(_favCount.toString(), 'Yêu thích'),
                            _divider(),
                            _statItem(_bookingsCount.toString(), 'Lịch hẹn'),
                          ],
                        )
                      else
                        const CircularProgressIndicator(color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ====== MENU SECTION ======
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_role == 'admin') ...[
                    const SizedBox(height: 8),
                    _sectionHeader('Hệ thống Quản trị'),
                    const SizedBox(height: 8),
                    _menuCard([
                      _menuItem(
                        icon: Icons.admin_panel_settings_rounded,
                        color: const Color(0xFF00897B),
                        label: 'Bảng điều khiển Quản trị viên',
                        subtitle:
                            'Duyệt tin, quản lý người dùng, xử lý vi phạm',
                        onTap: () {
                          Navigator.pushNamed(context, '/admin');
                        },
                      ),
                    ]),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 8),
                  _sectionHeader('Quản lý tin đăng'),
                  const SizedBox(height: 8),
                  _menuCard([
                    _menuItem(
                      icon: Icons.add_circle_outline_rounded,
                      color: const Color(0xFF00897B),
                      label: 'Đăng phòng cho thuê',
                      subtitle:
                          'Đăng tin miễn phí, tiếp cận hàng nghìn người thuê',
                      onTap: () async {
                        final result = await Navigator.pushNamed(
                          context,
                          '/create-room',
                        );
                        if (result == true && mounted) _loadStats();
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    _menuItem(
                      icon: Icons.home_work_outlined,
                      color: Colors.blue.shade600,
                      label: 'Phòng tôi đã đăng',
                      subtitle: '$_myRoomsCount tin đăng đang hoạt động',
                      onTap: () async {
                        await Navigator.pushNamed(context, '/my-rooms');
                        if (mounted) _loadStats();
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    _menuItem(
                      icon: Icons.bolt_rounded,
                      color: Colors.amber.shade800,
                      label: 'Bảng giá Gói VIP (Đồng – Bạc – Vàng)',
                      subtitle: 'Đẩy tin lên đầu, tiếp cận gấp 4 lần khách thuê',
                      onTap: () => Navigator.pushNamed(context, '/packages'),
                    ),
                    const Divider(height: 1, indent: 56),
                    _menuItem(
                      icon: Icons.receipt_long_rounded,
                      color: const Color(0xFF00897B),
                      label: 'Quản lý gói & Lịch sử mua',
                      subtitle: 'Theo dõi thời hạn gói và hóa đơn thanh toán',
                      onTap: () => Navigator.pushNamed(context, '/my-packages'),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  _sectionHeader('Hoạt động của bạn'),
                  const SizedBox(height: 8),
                  _menuCard([
                    _menuItem(
                      icon: Icons.calendar_month_outlined,
                      color: Colors.orange.shade600,
                      label: 'Lịch hẹn xem phòng',
                      subtitle: 'Xem trạng thái lịch hẹn đã đặt',
                      onTap: () => Navigator.pushNamed(context, '/my-bookings'),
                    ),
                    const Divider(height: 1, indent: 56),
                    _menuItem(
                      icon: Icons.favorite_outline_rounded,
                      color: Colors.red.shade400,
                      label: 'Phòng đã lưu',
                      subtitle: '$_favCount phòng yêu thích',
                      onTap: () {
                        // Switch tab về Favorites
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Xem tab "Đã lưu" bên dưới'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ]),
                  const SizedBox(height: 16),

                  _sectionHeader('Tài khoản'),
                  const SizedBox(height: 8),
                  _menuCard([
                    _menuItem(
                      icon: Icons.manage_accounts_outlined,
                      color: Colors.purple.shade400,
                      label: 'Thông tin cá nhân',
                      subtitle: 'Cập nhật họ tên, SĐT, ảnh đại diện',
                      onTap: _openEditProfileDialog,
                    ),
                    const Divider(height: 1, indent: 56),
                    _menuItem(
                      icon: Icons.logout_rounded,
                      color: Colors.red.shade400,
                      label: 'Đăng xuất',
                      subtitle: 'Thoát tài khoản hiện tại',
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: const Text('Đăng xuất?'),
                            content: const Text(
                              'Bạn có chắc chắn muốn đăng xuất không?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Hủy'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: AppButtonStyle.primary(
                                  baseColor: Colors.red.shade600,
                                  hoverColor: Colors.red.shade800,
                                ),
                                child: const Text('Đăng xuất'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && mounted) {
                          // ignore: use_build_context_synchronously
                          final nav = Navigator.of(context);
                          await authService.logout();
                          nav.pushReplacementNamed('/login');
                        }
                      },
                    ),
                  ]),
                  const SizedBox(height: 32),

                  // App version info
                  Center(
                    child: Text(
                      'RoomFinder v1.0 • Đồ án tốt nghiệp',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 12),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 36, color: Colors.white.withAlpha(60));
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF6B7280),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _menuCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required Color color,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  void _openEditProfileDialog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditProfileSheet(
        initialFullName: _fullName,
        initialPhone: _phoneNumber,
        initialAvatarUrl: _avatarUrl,
        userEmail: user.email ?? '',
        onSave: (fullName, phone, avatarUrl) async {
          try {
            await _authService.updateUserProfile(
              uid: user.uid,
              fullName: fullName,
              phoneNumber: phone,
              avatarUrl: avatarUrl,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Đã cập nhật thông tin cá nhân!'),
                backgroundColor: Color(0xFF00897B),
                behavior: SnackBarBehavior.floating,
              ),
            );
            _loadStats();
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi cập nhật: $e')),
            );
          }
        },
      ),
    );
  }
}
