import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/app_logo.dart';
import '../../widgets/app_image.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final int pendingRoomsCount;
  final int pendingReportsCount;
  final bool isDrawer;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.pendingRoomsCount = 0,
    this.pendingReportsCount = 0,
    this.isDrawer = false,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final navItems = [
      _NavItem(
        index: 0,
        title: 'Tổng quan',
        icon: Icons.dashboard_rounded,
      ),
      _NavItem(
        index: 1,
        title: 'Quản lý tin đăng',
        icon: Icons.apartment_rounded,
        badgeCount: pendingRoomsCount,
        badgeColor: Colors.amber.shade700,
      ),
      _NavItem(
        index: 2,
        title: 'Quản lý người dùng',
        icon: Icons.people_alt_rounded,
      ),
      _NavItem(
        index: 3,
        title: 'Báo cáo vi phạm',
        icon: Icons.report_problem_rounded,
        badgeCount: pendingReportsCount,
        badgeColor: Colors.red.shade600,
      ),
      _NavItem(
        index: 4,
        title: 'Gửi thông báo',
        icon: Icons.notifications_active_rounded,
      ),
      _NavItem(
        index: 5,
        title: 'Trợ lý AI & Tri thức',
        icon: Icons.smart_toy_rounded,
      ),
    ];

    return Container(
      width: isDrawer ? 280 : 260,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header / Logo
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade100, width: 1),
              ),
            ),
            child: Row(
              children: [
                const AppLogo(size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trọ Tốt',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF00897B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00897B).withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ADMIN DASHBOARD',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF00897B),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Menu items list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    'MENU QUẢN TRỊ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade400,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                ...navItems.map((item) {
                  final isSelected = selectedIndex == item.index;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          onDestinationSelected(item.index);
                          if (isDrawer) {
                            Navigator.of(context).pop();
                          }
                        },
                        hoverColor: const Color(0xFF00897B).withAlpha(15),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF00897B).withAlpha(25)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(
                                    color: const Color(0xFF00897B).withAlpha(60),
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                size: 20,
                                color: isSelected
                                    ? const Color(0xFF00897B)
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? const Color(0xFF00897B)
                                        : const Color(0xFF2C3E50),
                                  ),
                                ),
                              ),
                              if (item.badgeCount != null && item.badgeCount! > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: item.badgeColor ?? Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${item.badgeCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Footer Admin Profile & Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              border: Border(
                top: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF00897B),
                      ),
                      child: ClipOval(
                        child: (user?.photoURL?.isNotEmpty == true)
                            ? AppImage(
                                imageUrl: user!.photoURL!,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorWidget: Center(
                                  child: Text(
                                    (user.email?.isNotEmpty == true
                                            ? user.email![0]
                                            : 'A')
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  (user?.email?.isNotEmpty == true
                                          ? user!.email![0]
                                          : 'A')
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName?.isNotEmpty == true
                                ? user!.displayName!
                                : 'Quản trị viên',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            user?.email ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Tooltip(
                        message: 'Quay lại giao diện người dùng',
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/home');
                          },
                          icon: const Icon(Icons.arrow_back_rounded, size: 14),
                          label: const Text('Về User', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Đăng xuất',
                      child: IconButton(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Xác nhận đăng xuất?'),
                              content: const Text(
                                'Bạn có chắc chắn muốn đăng xuất khỏi trang quản trị?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Hủy'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Đăng xuất'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              Navigator.pushReplacementNamed(context, '/login');
                            }
                          }
                        },
                        icon: Icon(
                          Icons.logout_rounded,
                          size: 18,
                          color: Colors.red.shade400,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final int index;
  final String title;
  final IconData icon;
  final int? badgeCount;
  final Color? badgeColor;

  _NavItem({
    required this.index,
    required this.title,
    required this.icon,
    this.badgeCount,
    this.badgeColor,
  });
}
