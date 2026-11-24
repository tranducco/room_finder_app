import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

/// Dữ liệu mô tả 1 banner trong Carousel
class BannerItem {
  final String imagePath;
  final String fallbackImagePath;
  final String title;
  final String subtitle;
  final String badgeText;
  final VoidCallback? onTap;

  const BannerItem({
    required this.imagePath,
    required this.fallbackImagePath,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    this.onTap,
  });
}

/// Widget Auto Carousel Banner cho trang chủ TroTot
/// Tự động chuyển ảnh mỗi 4.5s, hiển thị đúng 100% tỉ lệ gốc 1024x341 (~3.0:1)
/// Hiển thị trọn vẹn, tuyệt đối không cắt khuất bất kỳ góc cạnh/chữ/chi tiết nào.
/// Hỗ trợ vuốt chạm trên mobile, kéo chuột trên web, nút điều hướng hai bên trên desktop,
/// và indicator đặt phía dưới banner chống che khuất nội dung.
class HomeBannerCarousel extends StatefulWidget {
  final VoidCallback? onExploreRooms;
  final VoidCallback? onViewLatest;
  final VoidCallback? onOpenChatbot;
  final VoidCallback? onSearchNearby;
  final VoidCallback? onCreateRoom;

  const HomeBannerCarousel({
    super.key,
    this.onExploreRooms,
    this.onViewLatest,
    this.onOpenChatbot,
    this.onSearchNearby,
    this.onCreateRoom,
  });

  @override
  State<HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<HomeBannerCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;
  bool _isHovered = false;

  /// Tỉ lệ chuẩn pixel của toàn bộ ảnh banner (1024 x 341)
  static const double _bannerAspectRatio = 1024.0 / 341.0;

  late final List<BannerItem> _banners = [
    BannerItem(
      imagePath: 'assets/images/banners/banner_1.jpg',
      fallbackImagePath: 'assets/images/banner_1.jpg',
      title: 'Tìm phòng trọ phù hợp với bạn',
      subtitle: 'Gần trường • Giá tốt • An toàn',
      badgeText: 'Nổi bật',
      onTap: widget.onExploreRooms,
    ),
    BannerItem(
      imagePath: 'assets/images/banners/banner_2.jpg',
      fallbackImagePath: 'assets/images/banner_2.jpg',
      title: 'Phòng trọ mới cập nhật mỗi ngày',
      subtitle: 'Nhiều lựa chọn • Ảnh thật • Thông tin rõ ràng',
      badgeText: 'Mới nhất',
      onTap: widget.onViewLatest,
    ),
    BannerItem(
      imagePath: 'assets/images/banners/banner_3.jpg',
      fallbackImagePath: 'assets/images/banner_3.jpg',
      title: 'Chatbot AI hỗ trợ tìm phòng',
      subtitle: 'Tư vấn theo nhu cầu • Gợi ý phòng • Giải đáp 24/7',
      badgeText: 'AI Trợ lý',
      onTap: widget.onOpenChatbot,
    ),
    BannerItem(
      imagePath: 'assets/images/banners/banner_4.jpg',
      fallbackImagePath: 'assets/images/banner_4.jpg',
      title: 'Tìm phòng quanh bạn',
      subtitle: 'Gần trường đại học • Tiện di chuyển',
      badgeText: 'Vị trí',
      onTap: widget.onSearchNearby,
    ),
    BannerItem(
      imagePath: 'assets/images/banners/banner_5.jpg',
      fallbackImagePath: 'assets/images/banner_5.jpg',
      title: 'Nâng cấp tin đăng Nổi bật hơn',
      subtitle: 'Tăng lượt xem • Tìm khách nhanh hơn',
      badgeText: 'Ưu đãi VIP',
      onTap: widget.onCreateRoom,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 4500), (timer) {
      if (!mounted || _isHovered) return;
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _banners.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _goToPrevious() {
    if (!_pageController.hasClients) return;
    final prevPage = (_currentPage - 1 + _banners.length) % _banners.length;
    _pageController.animateToPage(
      prevPage,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  void _goToNext() {
    if (!_pageController.hasClients) return;
    final nextPage = (_currentPage + 1) % _banners.length;
    _pageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  void _goToPage(int index) {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= 768;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ─── 1. HÀNG BANNER & NÚT ĐIỀU HƯỚNG HAI BÊN (DESKTOP) ───
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isDesktop) ...[
                  _ArrowNavButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'Banner trước',
                    onTap: _goToPrevious,
                  ),
                  const SizedBox(width: 8),
                ],

                // Vùng hiển thị banner với đúng tỉ lệ chuẩn 1024:341
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _isHovered = true),
                      onExit: (_) => setState(() => _isHovered = false),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(20),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                            BoxShadow(
                              color: const Color(0xFF00897B).withAlpha(15),
                              blurRadius: 14,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AspectRatio(
                            aspectRatio: _bannerAspectRatio,
                            child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context).copyWith(
                                dragDevices: {
                                  PointerDeviceKind.touch,
                                  PointerDeviceKind.mouse,
                                  PointerDeviceKind.trackpad,
                                },
                              ),
                              child: PageView.builder(
                                controller: _pageController,
                                itemCount: _banners.length,
                                onPageChanged: (index) {
                                  setState(() => _currentPage = index);
                                },
                                itemBuilder: (context, index) {
                                  final banner = _banners[index];
                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: banner.onTap,
                                      child: Image.asset(
                                        banner.imagePath,
                                        fit: BoxFit.contain,
                                        width: double.infinity,
                                        height: double.infinity,
                                        errorBuilder: (_, _, _) => Image.asset(
                                          banner.fallbackImagePath,
                                          fit: BoxFit.contain,
                                          width: double.infinity,
                                          height: double.infinity,
                                          errorBuilder: (_, _, _) => Container(
                                            color: const Color(0xFF00695C),
                                            alignment: Alignment.center,
                                            child: Text(
                                              banner.title,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                if (isDesktop) ...[
                  const SizedBox(width: 8),
                  _ArrowNavButton(
                    icon: Icons.chevron_right_rounded,
                    tooltip: 'Banner tiếp theo',
                    onTap: _goToNext,
                  ),
                ],
              ],
            ),

            // ─── 2. DOT INDICATOR ĐẶT PHÍA DƯỚI (KHÔNG CHE KHUẤT ẢNH BANNER) ───
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_banners.length, (index) {
                  final isActive = index == _currentPage;
                  return GestureDetector(
                    onTap: () => _goToPage(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF00897B)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF00897B).withAlpha(120),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Nút bấm tròn điều hướng mũi tên cho Web / Desktop
class _ArrowNavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ArrowNavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          hoverColor: const Color(0xFFE0F2F1),
          child: Padding(
            padding: const EdgeInsets.all(7.0),
            child: Icon(
              icon,
              size: 22,
              color: const Color(0xFF00695C),
            ),
          ),
        ),
      ),
    );
  }
}
