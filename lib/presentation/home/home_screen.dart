import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/guards/auth_guard.dart';
import 'home_tab.dart';
import 'favorites_tab.dart';
import '../profile/profile_tab.dart';
import '../profile/guest_profile_tab.dart';
import 'widgets/desktop_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  DateTime? _lastBackPressed;
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<HomeTabState> _homeTabKey = GlobalKey<HomeTabState>();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nhấn Back lần nữa để thoát ứng dụng'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    // Thoát ứng dụng hoàn toàn
    SystemNavigator.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 850;

    final isGuest = FirebaseAuth.instance.currentUser == null;

    final tabs = [
      HomeTab(
        key: _homeTabKey,
        searchController: _searchController,
      ),
      // Khách thấy màn hình guest profile thay cho FavoritesTab
      isGuest ? const GuestProfileTab() : const FavoritesTab(),
      // Khách thấy GuestProfileTab, người dùng thấy ProfileTab
      isGuest ? const GuestProfileTab() : const ProfileTab(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: Scaffold(
        body: isDesktop
            ? Stack(
                children: [
                  // 1. Vùng nội dung cuộn (nằm phía dưới)
                  Positioned.fill(
                    child: Column(
                      children: [
                        // Khoảng trống bằng chiều cao của DesktopHeader để nội dung bắt đầu dưới header
                        SizedBox(
                          height: _currentIndex == 0 ? 186 : 70,
                        ),
                        Expanded(
                          child: IndexedStack(
                            index: _currentIndex,
                            children: tabs,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. DesktopHeader nổi lên trên cùng (Z-Index cao nhất, luôn ghim ở đầu trang)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: DesktopHeader(
                      currentIndex: _currentIndex,
                      onTabSelected: (index) {
                        setState(() => _currentIndex = index);
                      },
                      searchController: _searchController,
                      onRefresh: () {
                        _homeTabKey.currentState?.loadData();
                      },
                      onSeedMockData: () {
                        _homeTabKey.currentState?.seedData();
                      },
                      onOpenFilter: () {
                        _homeTabKey.currentState?.openFilterSheet();
                      },
                      activeFilterCount:
                          _homeTabKey.currentState?.activeFilterCount ?? 0,
                    ),
                  ),
                ],
              )
            : IndexedStack(
                index: _currentIndex,
                children: tabs,
              ),
        // Desktop web loại bỏ thanh ngang dưới đáy, chuyển toàn bộ lên Header
        bottomNavigationBar: isDesktop
            ? null
            : NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  // Tab 1 (Đã lưu) yêu cầu đăng nhập
                  if (index == 1 && FirebaseAuth.instance.currentUser == null) {
                    AuthGuard.requireLogin(context, featureName: 'Danh sách phòng đã lưu');
                    return;
                  }
                  setState(() {
                    _currentIndex = index;
                  });
                },
                backgroundColor: Colors.white,
                elevation: 2,
                indicatorColor: const Color(0xFF00897B).withAlpha(30),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home, color: Color(0xFF00897B)),
                    label: 'Trang chủ',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.favorite_outline),
                    selectedIcon: Icon(Icons.favorite, color: Color(0xFF00897B)),
                    label: 'Đã lưu',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person, color: Color(0xFF00897B)),
                    label: 'Cá nhân',
                  ),
                ],
              ),
      ),
    );
  }
}
