import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tabs/admin_ai_monitor_tab.dart';
import 'tabs/admin_notifications_tab.dart';
import 'tabs/admin_overview_tab.dart';
import 'tabs/admin_packages_tab.dart';
import 'tabs/admin_reports_tab.dart';
import 'tabs/admin_rooms_tab.dart';
import 'tabs/admin_users_tab.dart';
import 'widgets/admin_sidebar.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentTabIndex = 0;
  String? _roomStatusFilterOverride;

  int _pendingRoomsCount = 0;
  int _pendingReportsCount = 0;

  @override
  void initState() {
    super.initState();
    _subscribeBadgeCounts();
  }

  void _subscribeBadgeCounts() {
    // Lắng nghe realtime số lượng tin chờ duyệt
    FirebaseFirestore.instance
        .collection('rooms')
        .where('status', isEqualTo: 'pending_approval')
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() => _pendingRoomsCount = snap.docs.length);
      }
    });

    // Lắng nghe realtime số lượng báo cáo chờ xử lý
    FirebaseFirestore.instance
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() => _pendingReportsCount = snap.docs.length);
      }
    });
  }

  void _onNavigateToTab(int index, {String? statusFilter}) {
    setState(() {
      _currentTabIndex = index;
      if (index == 1) {
        _roomStatusFilterOverride = statusFilter;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final user = FirebaseAuth.instance.currentUser;

    final List<Widget> tabs = [
      AdminOverviewTab(onNavigateToTab: _onNavigateToTab),
      AdminRoomsTab(
        key: ValueKey('rooms_${_roomStatusFilterOverride ?? "all"}'),
        initialStatusFilter: _roomStatusFilterOverride,
      ),
      const AdminUsersTab(),
      const AdminReportsTab(),
      const AdminNotificationsTab(),
      const AdminAiMonitorTab(),
      const AdminPackagesTab(),
    ];

    final tabTitles = [
      'Tổng quan hệ thống',
      'Quản lý tin đăng',
      'Quản lý người dùng',
      'Báo cáo vi phạm',
      'Gửi thông báo',
      'Trợ lý AI & Tri thức',
      'Quản lý Gói & Doanh thu',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      drawer: isDesktop
          ? null
          : Drawer(
              child: AdminSidebar(
                selectedIndex: _currentTabIndex,
                onDestinationSelected: (index) => _onNavigateToTab(index),
                pendingRoomsCount: _pendingRoomsCount,
                pendingReportsCount: _pendingReportsCount,
                isDrawer: true,
              ),
            ),
      body: Row(
        children: [
          // Sidebar cố định cho màn hình Desktop
          if (isDesktop)
            AdminSidebar(
              selectedIndex: _currentTabIndex,
              onDestinationSelected: (index) => _onNavigateToTab(index),
              pendingRoomsCount: _pendingRoomsCount,
              pendingReportsCount: _pendingReportsCount,
              isDrawer: false,
            ),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top AppBar with SafeArea & dark status bar icons for mobile punch-hole cameras
                AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle.dark.copyWith(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.dark,
                    statusBarBrightness: Brightness.light,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                      ),
                    ),
                    child: SafeArea(
                      top: !isDesktop,
                      bottom: false,
                      child: SizedBox(
                        height: isDesktop ? 64 : 54,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 10),
                          child: Row(
                            children: [
                              if (!isDesktop) ...[
                                Builder(
                                  builder: (ctx) => IconButton(
                                    icon: const Icon(Icons.menu_rounded),
                                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  tabTitles[_currentTabIndex],
                                  style: TextStyle(
                                    fontSize: isDesktop ? 18 : 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1A1A2E),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Admin pill badge
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isDesktop ? 12 : 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00897B).withAlpha(15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF00897B).withAlpha(40),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.verified_user_rounded,
                                      size: 16,
                                      color: Color(0xFF00897B),
                                    ),
                                    if (isDesktop) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        user?.email ?? 'Admin',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF00897B),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Nút về trang chủ User
                              Tooltip(
                                message: 'Mở ứng dụng người dùng',
                                child: isDesktop
                                    ? OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.pushReplacementNamed(context, '/home');
                                        },
                                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                        label: const Text('Xem trang User'),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: Colors.grey.shade300),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      )
                                    : IconButton(
                                        onPressed: () {
                                          Navigator.pushReplacementNamed(context, '/home');
                                        },
                                        icon: const Icon(Icons.open_in_new_rounded, size: 20),
                                        tooltip: 'Xem trang User',
                                        style: IconButton.styleFrom(
                                          foregroundColor: const Color(0xFF00897B),
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

                // Active tab view
                Expanded(
                  child: IndexedStack(
                    index: _currentTabIndex,
                    children: tabs,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

