import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/room.dart';
import '../../data/room_service.dart';
import '../../data/notification_service.dart';
import '../widgets/app_button_style.dart';
import '../widgets/room_card.dart';
import '../widgets/app_logo.dart';
import 'widgets/ai_chat_sheet.dart';
import 'widgets/home_app_footer.dart';
import 'widgets/home_banner_carousel.dart';
import 'widgets/home_pagination_bar.dart';
import 'widgets/notification_sheet.dart';
import 'widgets/room_filter_sheet.dart';

export 'widgets/notification_sheet.dart' show NotificationSheet;

class HomeTab extends StatefulWidget {
  final TextEditingController? searchController;

  const HomeTab({
    super.key,
    this.searchController,
  });

  @override
  State<HomeTab> createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab> {
  final RoomService _roomService = RoomService();
  late final TextEditingController _searchController;

  List<Room> _allRooms = [];
  List<Room> _filteredRooms = [];
  Set<String> _favoriteRoomIds = {};
  bool _isLoading = true;
  String _selectedDistrict = 'Tất cả';

  // Pagination
  int _currentPage = 0;
  static const int _roomsPerPage = 30;

  // Notification
  int _notificationCount = 0;
  StreamSubscription? _notifSubscription;
  final NotificationService _notificationService = NotificationService();

  List<Room> get _paginatedRooms {
    final start = _currentPage * _roomsPerPage;
    final end = (start + _roomsPerPage).clamp(0, _filteredRooms.length);
    return _filteredRooms.sublist(start, end);
  }

  int get _totalPages => (_filteredRooms.length / _roomsPerPage).ceil();

  // Advanced filters (Tuần 8.1)
  RangeValues _priceRange = const RangeValues(1, 15);
  RangeValues _areaRange = const RangeValues(15, 80);
  Set<String> _requiredAmenities = {};
  String _selectedRoomTypeFilter = 'Tất cả';

  int get _activeFilterCount {
    int count = 0;
    if (_priceRange.start > 1 || _priceRange.end < 15) count++;
    if (_areaRange.start > 15 || _areaRange.end < 80) count++;
    if (_requiredAmenities.isNotEmpty) count += _requiredAmenities.length;
    if (_selectedRoomTypeFilter != 'Tất cả') count++;
    return count;
  }

  final List<Map<String, dynamic>> _categories = [
    {'label': 'Tất cả', 'icon': Icons.apps_rounded},
    {'label': 'Cầu Giấy', 'icon': Icons.location_city},
    {'label': 'Đống Đa', 'icon': Icons.location_city},
    {'label': 'Thanh Xuân', 'icon': Icons.location_city},
    {'label': 'Nam Từ Liêm', 'icon': Icons.location_city},
    {'label': 'Ba Đình', 'icon': Icons.location_city},
    {'label': 'Hai Bà Trưng', 'icon': Icons.location_city},
  ];

  @override
  void initState() {
    super.initState();
    _searchController = widget.searchController ?? TextEditingController();
    _loadData();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    if (widget.searchController == null) {
      _searchController.dispose();
    }
    super.dispose();
  }

  void loadData() => _loadData();
  void openFilterSheet() => _openFilterSheet();
  int get activeFilterCount => _activeFilterCount;

  Future<void> seedData() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Đang nạp dữ liệu mẫu (210 phòng)...')),
    );
    await _roomService.seedMockData();
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Dữ liệu mẫu đã lên Firestore thành công!'),
        backgroundColor: Color(0xFF00897B),
      ),
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      _notificationService.ensureInitialData();
      if (user != null) {
        _notifSubscription?.cancel();
        _notifSubscription = _notificationService
            .getUserNotificationsStream(user.uid, user.email)
            .listen((notifs) {
          if (mounted) {
            setState(() {
              _notificationCount = notifs.where((n) => !n.isRead).length;
            });
          }
        });
      }

      final roomsFuture = _roomService.getRooms();
      final favFuture = user != null
          ? _roomService.getFavoriteRoomIds(user.uid)
          : Future.value(<String>[]);

      final results = await Future.wait([roomsFuture, favFuture]);
      final rooms = results[0] as List<Room>;
      final favIds = (results[1] as List<String>).toSet();

      if (mounted) {
        setState(() {
          _allRooms = rooms;
          _favoriteRoomIds = favIds;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    final minPrice = _priceRange.start * 1000000;
    final maxPrice = _priceRange.end >= 15
        ? double.infinity
        : _priceRange.end * 1000000;
    final minArea = _areaRange.start;
    final maxArea = _areaRange.end >= 80 ? double.infinity : _areaRange.end;

    setState(() {
      _currentPage = 0; // Reset về trang đầu khi lọc
      _filteredRooms = _allRooms.where((room) {
        final matchDistrict =
            _selectedDistrict == 'Tất cả' ||
            room.district.toLowerCase().contains(
              _selectedDistrict.toLowerCase(),
            ) ||
            room.address.toLowerCase().contains(
              _selectedDistrict.toLowerCase(),
            );

        final matchSearch =
            query.isEmpty ||
            room.title.toLowerCase().contains(query) ||
            room.address.toLowerCase().contains(query) ||
            room.district.toLowerCase().contains(query);

        final matchPrice =
            room.price >= minPrice &&
            (maxPrice == double.infinity || room.price <= maxPrice);

        final matchArea =
            room.area >= minArea &&
            (maxArea == double.infinity || room.area <= maxArea);

        final matchType =
            _selectedRoomTypeFilter == 'Tất cả' ||
            room.roomType == _selectedRoomTypeFilter;

        final matchAmenities =
            _requiredAmenities.isEmpty ||
            _requiredAmenities.every(
              (amenity) => room.amenities.contains(amenity),
            );

        final matchStatus = room.status != 'hidden' &&
            room.status != 'rejected' &&
            room.status != 'pending_approval';

        return matchDistrict &&
            matchSearch &&
            matchPrice &&
            matchArea &&
            matchType &&
            matchAmenities &&
            matchStatus;
      }).toList()
        ..sort((a, b) {
          // 1. ƯU TIÊN THEO HẠNG GÓI VIP (Vàng: 3 > Bạc: 2 > Đồng: 1 > Thường: 0)
          // Tự động kiểm tra thời hạn: nếu hết hạn thì effectivePriority = 0
          final priorityCompare = b.effectivePriority.compareTo(a.effectivePriority);
          if (priorityCompare != 0) return priorityCompare;

          // 2. Trong cùng một hạng: Tin kích hoạt gói mới hơn hoặc đăng gần nhất xếp trước
          final timeA = a.packageStartAt ?? a.createdAt ?? DateTime(2000);
          final timeB = b.packageStartAt ?? b.createdAt ?? DateTime(2000);
          return timeB.compareTo(timeA);
        });
    });
  }

  void _resetAllFilters() {
    setState(() {
      _selectedDistrict = 'Tất cả';
      _searchController.clear();
      _priceRange = const RangeValues(1, 15);
      _areaRange = const RangeValues(15, 80);
      _requiredAmenities = {};
      _selectedRoomTypeFilter = 'Tất cả';
    });
    _applyFilters();
  }

  Future<void> _toggleFavorite(String roomId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập để lưu phòng yêu thích!'),
          ),
        );
      }
      return;
    }

    final isFav = _favoriteRoomIds.contains(roomId);
    setState(() {
      if (isFav) {
        _favoriteRoomIds.remove(roomId);
      } else {
        _favoriteRoomIds.add(roomId);
      }
    });

    final success = await _roomService.toggleFavorite(user.uid, roomId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Đã thêm vào danh sách yêu thích' : 'Đã xóa khỏi yêu thích',
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 850;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        clipBehavior: Clip.hardEdge,
        slivers: [
          // ======= MOBILE HEADER BANNER (Ghim cố định nổi trên cùng không che khuất) =======
          if (!isDesktop)
            SliverAppBar(
              floating: false,
              snap: false,
              pinned: true,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              elevation: 4,
              backgroundColor: const Color(0xFF00695C),
              systemOverlayStyle: SystemUiOverlayStyle.light,
              toolbarHeight: 196,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00695C),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(22),
                      bottomRight: Radius.circular(22),
                    ),
                  ),
                  child: Stack(
                    children: [
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
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Top row: Logo + Branding + Actions (Mobile)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          padding: const EdgeInsets.all(4),
                                          clipBehavior: Clip.antiAlias,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withAlpha(30),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const AppLogo(size: 28),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Trọ Tốt',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 19,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              Text(
                                                'Tìm phòng nhanh & an toàn',
                                                style: TextStyle(
                                                  color: Colors.white.withAlpha(210),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _notificationBell(),
                                      const SizedBox(width: 6),
                                      _headerIconBtn(
                                        icon: Icons.cloud_upload_outlined,
                                        tooltip: 'Đẩy dữ liệu mẫu',
                                        onTap: seedData,
                                      ),
                                      const SizedBox(width: 6),
                                      _headerIconBtn(
                                        icon: Icons.refresh_rounded,
                                        tooltip: 'Làm mới',
                                        onTap: loadData,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Location badge (Mobile)
                              _statChip(Icons.location_on_rounded, 'Hà Nội'),

                              const SizedBox(height: 10),

                              // Search bar + Filter button (Mobile)
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 44,
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
                                        controller: _searchController,
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
                                          suffixIcon: _searchController.text.isNotEmpty
                                              ? IconButton(
                                                  icon: const Icon(Icons.clear, size: 18),
                                                  onPressed: () => _searchController.clear(),
                                                  color: Colors.grey,
                                                )
                                              : null,
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  HoverWidget(
                                    onTap: _openFilterSheet,
                                    builder: (context, isHovered) => AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      height: 44,
                                      width: 44,
                                      transform: Matrix4.translationValues(0, isHovered ? -2 : 0, 0),
                                      decoration: BoxDecoration(
                                        color: isHovered ? const Color(0xFFE0F2F1) : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isHovered ? const Color(0xFF00897B) : Colors.transparent,
                                          width: 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: isHovered
                                                ? const Color(0xFF00897B).withAlpha(40)
                                                : Colors.black.withAlpha(20),
                                            blurRadius: isHovered ? 12 : 10,
                                            offset: Offset(0, isHovered ? 6 : 4),
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Icon(
                                            Icons.tune_rounded,
                                            color: _activeFilterCount > 0 || isHovered
                                                ? const Color(0xFF00897B)
                                                : const Color(0xFF1A1A2E),
                                            size: 20,
                                          ),
                                          if (_activeFilterCount > 0)
                                            Positioned(
                                              top: 4,
                                              right: 4,
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
                                                  '$_activeFilterCount',
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
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ======= HERO AUTO BANNER CAROUSEL =======
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, isDesktop ? 16 : 12, 16, 0),
              child: HomeBannerCarousel(
                onExploreRooms: () => _resetAllFilters(),
                onViewLatest: () => _resetAllFilters(),
                onOpenChatbot: () => AiChatSheet.show(context),
                onSearchNearby: () {
                  setState(() => _selectedDistrict = 'Cầu Giấy');
                  _applyFilters();
                },
                onCreateRoom: () => Navigator.pushNamed(context, '/create-room'),
              ),
            ),
          ),

          // ======= DISTRICT FILTER =======
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Khu vực',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final label = cat['label'] as String;
                        final isSelected = label == _selectedDistrict;
                        return HoverWidget(
                          onTap: () {
                            setState(() => _selectedDistrict = label);
                            _applyFilters();
                          },
                          builder: (context, isHovered) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            transform: Matrix4.translationValues(0, isHovered && !isSelected ? -2 : 0, 0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isHovered ? const Color(0xFF00695C) : const Color(0xFF00897B))
                                  : (isHovered ? const Color(0xFFE0F2F1) : Colors.white),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected || isHovered
                                    ? const Color(0xFF00897B)
                                    : Colors.grey.shade200,
                                width: isHovered ? 1.2 : 1.0,
                              ),
                              boxShadow: isSelected || isHovered
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF00897B).withAlpha(isHovered ? 80 : 50),
                                        blurRadius: isHovered ? 10 : 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : (isHovered ? const Color(0xFF00695C) : Colors.grey.shade700),
                                fontWeight: isSelected || isHovered
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ======= ACTIVE FILTER TAGS (IF ANY) =======
          if (_activeFilterCount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_priceRange.start > 1 || _priceRange.end < 15)
                      _activeTag(
                        'Giá: ${_priceRange.start.toStringAsFixed(1)} - ${_priceRange.end >= 15 ? '15+ tr' : '${_priceRange.end.toStringAsFixed(1)} tr'}',
                        () {
                          setState(
                            () => _priceRange = const RangeValues(1, 15),
                          );
                          _applyFilters();
                        },
                      ),
                    if (_areaRange.start > 15 || _areaRange.end < 80)
                      _activeTag(
                        'DT: ${_areaRange.start.toStringAsFixed(0)} - ${_areaRange.end >= 80 ? '80+ m²' : '${_areaRange.end.toStringAsFixed(0)} m²'}',
                        () {
                          setState(() => _areaRange = const RangeValues(15, 80));
                          _applyFilters();
                        },
                      ),
                    if (_selectedRoomTypeFilter != 'Tất cả')
                      _activeTag(_selectedRoomTypeFilter, () {
                        setState(() => _selectedRoomTypeFilter = 'Tất cả');
                        _applyFilters();
                      }),
                    ..._requiredAmenities.map(
                      (amenity) => _activeTag(amenity, () {
                        setState(() => _requiredAmenities.remove(amenity));
                        _applyFilters();
                      }),
                    ),
                    ActionChip(
                      label: const Text(
                        'Xóa bộ lọc',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                      avatar: const Icon(
                        Icons.clear_all,
                        size: 16,
                        color: Colors.red,
                      ),
                      backgroundColor: Colors.red.shade50,
                      side: BorderSide(color: Colors.red.shade200),
                      padding: EdgeInsets.zero,
                      onPressed: _resetAllFilters,
                    ),
                  ],
                ),
              ),
            ),

          // ======= ROOMS HEADER =======
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Phòng phù hợp',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_selectedDistrict != 'Tất cả' ||
                      _searchController.text.isNotEmpty ||
                      _activeFilterCount > 0) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _resetAllFilters,
                      child: const Text(
                        'Đặt lại tất cả',
                        style: TextStyle(
                          color: Color(0xFF00897B),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ======= ROOMS GRID =======
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            sliver: _isLoading
                ? const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(48.0),
                        child: CircularProgressIndicator(
                          color: Color(0xFF00897B),
                        ),
                      ),
                    ),
                  )
                : _filteredRooms.isEmpty
                ? SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.search_off_rounded,
                                size: 40,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Không tìm thấy phòng trọ phù hợp',
                              style: TextStyle(
                                color: Color(0xFF1A1A2E),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Thử thay đổi bộ lọc hoặc từ khóa tìm kiếm',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : SliverGrid(
                    gridDelegate:
                        SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 240.0,
                          mainAxisSpacing: 14.0,
                          crossAxisSpacing: 14.0,
                          childAspectRatio: MediaQuery.of(context).size.width < 420
                              ? 0.60
                              : (MediaQuery.of(context).size.width < 600 ? 0.64 : 0.72),
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final room = _paginatedRooms[index];
                      final isFav = _favoriteRoomIds.contains(room.roomId);
                      return RoomCard(
                        room: room,
                        isFavorite: isFav,
                        onFavoriteToggle: () => _toggleFavorite(room.roomId),
                        onTap: () async {
                          await Navigator.pushNamed(
                            context,
                            '/room-detail',
                            arguments: room,
                          );
                          if (mounted) {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              final favIds = await _roomService
                                  .getFavoriteRoomIds(user.uid);
                              if (mounted) {
                                setState(
                                  () => _favoriteRoomIds = favIds.toSet(),
                                );
                              }
                            }
                          }
                        },
                      );
                    }, childCount: _paginatedRooms.length),
                  ),
          ),

          // ======= PAGINATION BAR =======
          if (!_isLoading && _filteredRooms.isNotEmpty && _totalPages > 1)
            SliverToBoxAdapter(
              child: HomePaginationBar(
                currentPage: _currentPage,
                totalPages: _totalPages,
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
              ),
            ),

          // ======= FOOTER =======
          const SliverToBoxAdapter(
            child: HomeAppFooter(),
          ),

          // Bottom spacing for FAB
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00897B).withAlpha(70),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          tooltip: 'Trợ lý ảo TroTot AI',
          onPressed: () => AiChatSheet.show(context),
          backgroundColor: Colors.white,
          elevation: 0,
          highlightElevation: 2,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            clipBehavior: Clip.antiAlias,
            child: ClipOval(
              child: Image.asset(
                'assets/images/ai_bot.png',
                width: 58,
                height: 58,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.smart_toy_rounded,
                  color: Color(0xFF00897B),
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _notificationBell() {
    return Tooltip(
      message: 'Thông báo',
      child: HoverWidget(
        onTap: () {
          setState(() => _notificationCount = 0);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => NotificationSheet(
              onNavigateToBookings: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/my-bookings');
              },
              onNavigateToLogin: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/login');
              },
            ),
          );
        },
        builder: (context, isHovered) {
          final isDesk = MediaQuery.of(context).size.width >= 1024;
          final btnSize = isDesk ? 40.0 : 36.0;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: btnSize,
            height: btnSize,
            transform: Matrix4.translationValues(0, isHovered ? -2 : 0, 0),
            decoration: BoxDecoration(
              color: isHovered
                  ? Colors.white.withAlpha(55)
                  : Colors.white.withAlpha(25),
              shape: BoxShape.circle,
              border: Border.all(
                color: isHovered ? Colors.white : Colors.white.withAlpha(70),
                width: isHovered ? 1.5 : 1.0,
              ),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.notifications_outlined, color: Colors.white, size: isDesk ? 20 : 18),
                if (_notificationCount > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '$_notificationCount',
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _headerIconBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: HoverWidget(
        onTap: onTap,
        builder: (context, isHovered) {
          final isDesk = MediaQuery.of(context).size.width >= 1024;
          final btnSize = isDesk ? 40.0 : 36.0;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: btnSize,
            height: btnSize,
            transform: Matrix4.translationValues(0, isHovered ? -2 : 0, 0),
            decoration: BoxDecoration(
              color: isHovered
                  ? Colors.white.withAlpha(55)
                  : Colors.white.withAlpha(25),
              shape: BoxShape.circle,
              border: Border.all(
                color: isHovered ? Colors.white : Colors.white.withAlpha(70),
                width: isHovered ? 1.5 : 1.0,
              ),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Icon(icon, color: Colors.white, size: isDesk ? 20 : 18),
          );
        },
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _activeTag(String label, VoidCallback onRemove) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF00897B))),
      deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFF00897B)),
      onDeleted: onRemove,
      backgroundColor: const Color(0xFF00897B).withAlpha(20),
      side: BorderSide(color: const Color(0xFF00897B).withAlpha(60)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RoomFilterSheet(
        initialPriceRange: _priceRange,
        initialAreaRange: _areaRange,
        initialRoomType: _selectedRoomTypeFilter,
        initialAmenities: _requiredAmenities,
        onApply: (price, area, roomType, amenities) {
          setState(() {
            _priceRange = price;
            _areaRange = area;
            _selectedRoomTypeFilter = roomType;
            _requiredAmenities = amenities;
          });
          _applyFilters();
        },
      ),
    );
  }
}

