import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../data/auth_service.dart';
import '../../../data/notification_service.dart';
import '../../../data/room_service.dart';
import '../../../domain/models/app_notification.dart';
import '../../widgets/app_logo.dart';
import '../home_tab.dart';

class DesktopHeader extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final TextEditingController? searchController;
  final VoidCallback? onRefresh;
  final VoidCallback? onSeedMockData;
  final VoidCallback? onOpenFilter;
  final int activeFilterCount;

  const DesktopHeader({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    this.searchController,
    this.onRefresh,
    this.onSeedMockData,
    this.onOpenFilter,
    this.activeFilterCount = 0,
  });

  @override
  State<DesktopHeader> createState() => _DesktopHeaderState();
}

class _DesktopHeaderState extends State<DesktopHeader> {
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final RoomService _roomService = RoomService();

  Map<String, dynamic>? _userProfile;
  String _userRole = 'user';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        _loadUserProfile();
      }
    });
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final profile = await _authService.getUserProfile(user.uid);
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _userRole = profile?['role'] as String? ?? 'user';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _userProfile = null;
          _userRole = 'user';
        });
      }
    }
  }

  void _openNotificationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
          child: NotificationSheet(
            onNavigateToBookings: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/my-bookings');
            },
            onNavigateToLogin: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/login');
            },
          ),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(40),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = _userProfile?['fullName'] as String? ??
        user?.displayName ??
        (user?.email != null ? user!.email!.split('@').first : 'Người dùng');
    final avatarUrl = _userProfile?['avatarUrl'] as String? ?? user?.photoURL ?? '';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF00695C),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background image: header_bg.png (Dùng ảnh header-bg làm toàn bộ nền header)
          Positioned.fill(
            child: Image.asset(
              'assets/images/header_bg.png',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              errorBuilder: (_, _, _) => Image.network(
                'header_bg.png',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                errorBuilder: (_, _, _) => const SizedBox(),
              ),
            ),
          ),

          // Nội dung Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── 1. HÀNG ĐIỀU HƯỚNG & TIỆN ÍCH TRÊN CÙNG ───
                Row(
                  children: [
                    // LOGO & TÊN THƯƠNG HIỆU (Bấm để về Home)
                    InkWell(
                      onTap: () => widget.onTabSelected(0),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const AppLogo(size: 30),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Trọ Tốt',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  'Tìm phòng trọ Hà Nội',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(210),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // CÁC NÚT ĐIỀU HƯỚNG TRANG CHỦ & ĐÃ LƯU
                    _navItem(
                      icon: Icons.home_rounded,
                      label: 'Trang chủ',
                      isSelected: widget.currentIndex == 0,
                      onTap: () => widget.onTabSelected(0),
                    ),
                    const SizedBox(width: 6),

                    // Nút "Đã lưu" có badge đếm số phòng yêu thích
                    if (user != null)
                      StreamBuilder<List<String>>(
                        stream: _roomService.getFavoriteRoomIdsStream(user.uid),
                        builder: (context, snapshot) {
                          final count = (snapshot.data ?? []).length;
                          return _navItem(
                            icon: count > 0 ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            label: 'Đã lưu',
                            badgeCount: count,
                            isSelected: widget.currentIndex == 1,
                            onTap: () => widget.onTabSelected(1),
                          );
                        },
                      )
                    else
                      _navItem(
                        icon: Icons.favorite_border_rounded,
                        label: 'Đã lưu',
                        isSelected: widget.currentIndex == 1,
                        onTap: () => widget.onTabSelected(1),
                      ),
                    const SizedBox(width: 6),
                    _navItem(
                      icon: Icons.bolt_rounded,
                      label: 'Gói VIP',
                      isSelected: false,
                      onTap: () => Navigator.pushNamed(context, '/packages'),
                    ),

                    const Spacer(),

                    // CÁC TIỆN ÍCH PHẢI: THÔNG BÁO, LỊCH HẸN, DỮ LIỆU MẪU, LÀM MỚI
                    if (user != null)
                      StreamBuilder<List<AppNotification>>(
                        stream: _notificationService.getUserNotificationsStream(user.uid, user.email),
                        builder: (context, snapshot) {
                          final unreadCount = (snapshot.data ?? []).where((n) => !n.isRead).length;
                          return _headerIconButton(
                            icon: Icons.notifications_outlined,
                            tooltip: 'Thông báo',
                            badgeCount: unreadCount,
                            onTap: () => _openNotificationsDialog(context),
                          );
                        },
                      )
                    else
                      _headerIconButton(
                        icon: Icons.notifications_outlined,
                        tooltip: 'Thông báo',
                        onTap: () => _openNotificationsDialog(context),
                      ),
                    const SizedBox(width: 6),

                    _headerIconButton(
                      icon: Icons.calendar_month_outlined,
                      tooltip: 'Lịch hẹn xem phòng',
                      onTap: () => Navigator.pushNamed(context, '/my-bookings'),
                    ),
                    const SizedBox(width: 6),

                    if (widget.onSeedMockData != null) ...[
                      _headerIconButton(
                        icon: Icons.cloud_upload_outlined,
                        tooltip: 'Đẩy dữ liệu mẫu',
                        onTap: widget.onSeedMockData!,
                      ),
                      const SizedBox(width: 6),
                    ],

                    if (widget.onRefresh != null) ...[
                      _headerIconButton(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Làm mới',
                        onTap: widget.onRefresh!,
                      ),
                      const SizedBox(width: 10),
                    ],

                    // TÀI KHOẢN NGƯỜI DÙNG (CHỢ TỐT STYLE)
                    if (user == null)
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        icon: const Icon(Icons.login_rounded, size: 16),
                        label: const Text('Đăng nhập'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      )
                    else
                      Theme(
                        data: Theme.of(context).copyWith(
                          hoverColor: Colors.transparent,
                        ),
                        child: PopupMenuButton<String>(
                          offset: const Offset(0, 46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                          onSelected: (value) async {
                            if (value == 'profile') {
                              widget.onTabSelected(2);
                            } else if (value == 'my_rooms') {
                              Navigator.pushNamed(context, '/my-rooms');
                            } else if (value == 'bookings') {
                              Navigator.pushNamed(context, '/my-bookings');
                            } else if (value == 'admin') {
                              Navigator.pushNamed(context, '/admin');
                            } else if (value == 'logout') {
                              await _authService.logout();
                              if (context.mounted) {
                                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                              }
                            }
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem<String>(
                              enabled: false,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: const Color(0xFF00695C).withAlpha(40),
                                      backgroundImage: (avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
                                          ? NetworkImage(avatarUrl)
                                          : null,
                                      child: (avatarUrl.isEmpty || !avatarUrl.startsWith('http'))
                                          ? Text(
                                              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF00695C),
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            displayName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Color(0xFF1A1A2E),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            user.email ?? '',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _userRole == 'admin' ? Colors.amber.shade100 : const Color(0xFFE0F2F1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _userRole == 'admin' ? 'Quản trị viên (Admin)' : 'Người dùng',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: _userRole == 'admin' ? Colors.amber.shade900 : const Color(0xFF00796B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'profile',
                              child: Row(
                                children: [
                                  Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF00897B)),
                                  SizedBox(width: 10),
                                  Text('Trang cá nhân', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'my_rooms',
                              child: Row(
                                children: [
                                  Icon(Icons.home_work_outlined, size: 18, color: Color(0xFF00897B)),
                                  SizedBox(width: 10),
                                  Text('Tin đăng của tôi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'bookings',
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_month_outlined, size: 18, color: Color(0xFF00897B)),
                                  SizedBox(width: 10),
                                  Text('Lịch hẹn xem phòng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            if (_userRole == 'admin') ...[
                              const PopupMenuDivider(),
                              const PopupMenuItem<String>(
                                value: 'admin',
                                child: Row(
                                  children: [
                                    Icon(Icons.admin_panel_settings_outlined, size: 18, color: Colors.amber),
                                    SizedBox(width: 10),
                                    Text('Admin Dashboard', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amber)),
                                  ],
                                ),
                              ),
                            ],
                            const PopupMenuDivider(),
                            const PopupMenuItem<String>(
                              value: 'logout',
                              child: Row(
                                children: [
                                  Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                                  SizedBox(width: 10),
                                  Text('Đăng xuất', style: TextStyle(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(35),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withAlpha(60)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.white,
                                  backgroundImage: (avatarUrl.isNotEmpty && avatarUrl.startsWith('http'))
                                      ? NetworkImage(avatarUrl)
                                      : null,
                                  child: (avatarUrl.isEmpty || !avatarUrl.startsWith('http'))
                                      ? Text(
                                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF00695C),
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 90),
                                  child: Text(
                                    displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(width: 12),

                    // NÚT NỔI BẬT ĐĂNG TIN (CHỢ TỐT STYLE)
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/create-room'),
                      icon: const Icon(Icons.post_add_rounded, size: 18),
                      label: const Text(
                        'ĐĂNG TIN',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: Colors.black45,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),

                // ─── 2. SLOGAN & THANH TÌM KIẾM (CHỈ KHI Ở TRANG CHỦ) ───
                if (widget.currentIndex == 0) ...[
                  const SizedBox(height: 12),
                  // Slogan & Location
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hệ thống Tìm kiếm & Cho thuê Phòng trọ Hà Nội',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _statChip(Icons.location_on_rounded, 'Hà Nội'),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Thanh tìm kiếm + Nút Lọc
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(20),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: widget.searchController,
                            style: const TextStyle(fontSize: 13.5, color: Color(0xFF1A1A2E)),
                            decoration: InputDecoration(
                              hintText: 'Tìm theo khu vực, tên đường...',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 13.5,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: Colors.grey.shade500,
                                size: 20,
                              ),
                              suffixIcon: (widget.searchController != null)
                                  ? ValueListenableBuilder<TextEditingValue>(
                                      valueListenable: widget.searchController!,
                                      builder: (context, value, _) {
                                        if (value.text.isEmpty) return const SizedBox.shrink();
                                        return IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
                                          onPressed: () => widget.searchController!.clear(),
                                          color: Colors.grey,
                                        );
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onOpenFilter,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(20),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  color: widget.activeFilterCount > 0
                                      ? const Color(0xFF00897B)
                                      : const Color(0xFF1A1A2E),
                                  size: 20,
                                ),
                                if (widget.activeFilterCount > 0)
                                  Positioned(
                                    top: 5,
                                    right: 5,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      child: Text(
                                        '${widget.activeFilterCount}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withAlpha(50) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: Colors.white.withAlpha(120), width: 1.2)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(35),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(50)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 19),
              if (badgeCount > 0)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
