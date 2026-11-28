import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../domain/models/room.dart';
import '../../domain/models/app_notification.dart';
import '../../data/room_service.dart';
import '../../data/notification_service.dart';
import '../widgets/room_card.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_button_style.dart';
import 'widgets/ai_chat_sheet.dart';
import 'widgets/home_banner_carousel.dart';

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
              child: _PaginationBar(
                currentPage: _currentPage,
                totalPages: _totalPages,
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
              ),
            ),

          // ======= FOOTER =======
          SliverToBoxAdapter(
            child: _AppFooter(),
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
      builder: (ctx) => _FilterSheet(
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

// ======================================================
// NOTIFICATION SHEET WIDGET
// ======================================================
class NotificationSheet extends StatefulWidget {
  final VoidCallback onNavigateToBookings;
  final VoidCallback onNavigateToLogin;

  const NotificationSheet({
    super.key,
    required this.onNavigateToBookings,
    required this.onNavigateToLogin,
  });

  @override
  State<NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<NotificationSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final user = FirebaseAuth.instance.currentUser;

  final NotificationService _notificationService = NotificationService();

  String _formatNotifTime(DateTime? dt) {
    if (dt == null) return 'Gần đây';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'room_approved':
        return Icons.verified_rounded;
      case 'room_rejected':
        return Icons.error_outline_rounded;
      case 'booking':
        return Icons.calendar_today_rounded;
      case 'review':
        return Icons.star_rounded;
      case 'package_activated':
        return Icons.workspace_premium_rounded;
      case 'system':
      default:
        return Icons.campaign_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'room_approved':
        return Colors.green.shade700;
      case 'room_rejected':
        return Colors.red.shade700;
      case 'booking':
        return const Color(0xFF00897B);
      case 'review':
        return Colors.amber.shade700;
      case 'package_activated':
        return Colors.orange.shade700;
      case 'system':
      default:
        return Colors.blue.shade700;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: StreamBuilder<List<AppNotification>>(
        stream: user != null
            ? _notificationService.getUserNotificationsStream(user!.uid, user?.email)
            : const Stream.empty(),
        builder: (context, snapshot) {
          final allNotifs = snapshot.data ?? [];
          final activityNotifs = allNotifs
              .where((n) => n.recipientId != 'all')
              .toList();
          final newsNotifs = allNotifs
              .where((n) => n.recipientId == 'all')
              .toList();
          final unreadActivityCount =
              activityNotifs.where((n) => !n.isRead).length;

          return Column(
            children: [
              // ---- Drag handle ----
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ---- Header ----
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Thông Báo',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: Colors.grey.shade600),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // ---- Tab bar ----
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF00897B),
                unselectedLabelColor: Colors.grey.shade500,
                indicatorColor: const Color(0xFF00897B),
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Hoạt Động'),
                        if (unreadActivityCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00897B),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$unreadActivityCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: 'Tin Tức / Hệ Thống'),
                ],
              ),
              const Divider(height: 1),

              // ---- Tab content ----
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab Hoạt Động
                    user == null
                        ? _buildLoginPrompt()
                        : _buildNotificationList(activityNotifs, isActivity: true),

                    // Tab Tin Tức
                    _buildNotificationList(newsNotifs, isActivity: false),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationList(List<AppNotification> list, {required bool isActivity}) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_none_rounded, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 14),
              Text(
                isActivity
                    ? 'Bạn chưa có thông báo hoạt động nào.'
                    : 'Chưa có thông báo tin tức hệ thống.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade100),
      itemBuilder: (context, index) {
        final n = list[index];
        final isBooking = n.type == 'booking';
        final isRoomUpdate = n.type == 'room_approved' || n.type == 'room_rejected';

        return _NotifTile(
          icon: _iconForType(n.type),
          iconColor: _colorForType(n.type),
          title: n.title,
          body: n.body,
          time: _formatNotifTime(n.createdAt),
          isRead: n.isRead,
          actionLabel: isBooking
              ? 'Xem lịch hẹn →'
              : isRoomUpdate
                  ? 'Xem tin của tôi →'
                  : null,
          onTap: () async {
            final nav = Navigator.of(context);
            if (!n.isRead) {
              await _notificationService.markAsRead(n.id);
            }
            if (isBooking) {
              widget.onNavigateToBookings();
            } else if (isRoomUpdate) {
              nav.pop();
              nav.pushNamed('/my-rooms');
            }
          },
        );
      },
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.notifications_off_outlined, size: 40, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),
            const Text(
              'Vui lòng đăng nhập để xem\ndanh sách hoạt động',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: widget.onNavigateToLogin,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1A1A2E), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  'Đăng ký / Đăng nhập',
                  style: TextStyle(
                    color: Color(0xFF1A1A2E),
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
  }
}

class _NotifTile extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final String time;
  final bool isRead;
  final VoidCallback? onTap;
  final String? actionLabel;

  const _NotifTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.time,
    required this.isRead,
    required this.onTap,
    required this.actionLabel,
  });

  @override
  State<_NotifTile> createState() => _NotifTileState();
}

class _NotifTileState extends State<_NotifTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) { if (widget.onTap != null) setState(() => _hovered = true); },
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          color: _hovered
              ? const Color(0xFF00897B).withAlpha(12)
              : widget.isRead
                  ? Colors.transparent
                  : const Color(0xFF00897B).withAlpha(8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon với chấm unread
              Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.iconColor.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: widget.iconColor, size: 22),
                  ),
                  if (!widget.isRead)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00897B),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              // Nội dung
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: TextStyle(
                              fontWeight: widget.isRead ? FontWeight.w500 : FontWeight.bold,
                              fontSize: 14,
                              color: const Color(0xFF1A1A2E),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.time,
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.body,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                    ),
                    if (widget.actionLabel != null) ...[
                      const SizedBox(height: 8),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        style: TextStyle(
                          color: _hovered ? const Color(0xFF004D40) : const Color(0xFF00897B),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        child: Text(widget.actionLabel!),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================
// PAGINATION BAR WIDGET
// ======================================================
class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Tạo danh sách trang hiển thị (tối đa 7 nút, dùng dấu ... nếu nhiều)
    List<int?> pages = [];
    if (totalPages <= 7) {
      pages = List.generate(totalPages, (i) => i);
    } else {
      pages.add(0);
      if (currentPage > 2) pages.add(null); // dấu ...
      for (int i = (currentPage - 1).clamp(1, totalPages - 2);
           i <= (currentPage + 1).clamp(1, totalPages - 2);
           i++) {
        pages.add(i);
      }
      if (currentPage < totalPages - 3) pages.add(null); // dấu ...
      pages.add(totalPages - 1);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Nút trang trước
            _PageBtn(
              label: null,
              icon: Icons.chevron_left_rounded,
              isEnabled: currentPage > 0,
              isSelected: false,
              onTap: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
            ),
            const SizedBox(width: 4),
            // Các số trang
            ...pages.map((p) {
              if (p == null) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('...', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _PageBtn(
                  label: '${p + 1}',
                  icon: null,
                  isEnabled: true,
                  isSelected: p == currentPage,
                  onTap: () => onPageChanged(p),
                ),
              );
            }),
            const SizedBox(width: 4),
            // Nút trang sau
            _PageBtn(
              label: null,
              icon: Icons.chevron_right_rounded,
              isEnabled: currentPage < totalPages - 1,
              isSelected: false,
              onTap: currentPage < totalPages - 1 ? () => onPageChanged(currentPage + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PageBtn extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final bool isEnabled;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PageBtn({
    required this.label,
    required this.icon,
    required this.isEnabled,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_PageBtn> createState() => _PageBtnState();
}

class _PageBtnState extends State<_PageBtn> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected;
    final enabled = widget.isEnabled;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) { if (enabled) setState(() => _isHovered = true); },
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 36,
          height: 36,
          transform: Matrix4.translationValues(0, _isHovered && !active ? -2 : 0, 0),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF00897B)
                : _isHovered
                    ? const Color(0xFFE0F2F1)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? const Color(0xFF00897B)
                  : _isHovered
                      ? const Color(0xFF00897B)
                      : Colors.grey.shade300,
            ),
            boxShadow: _isHovered && !active
                ? [BoxShadow(color: const Color(0xFF00897B).withAlpha(40), blurRadius: 6, offset: const Offset(0, 2))]
                : [],
          ),
          child: Center(
            child: widget.icon != null
                ? Icon(
                    widget.icon,
                    size: 18,
                    color: !enabled
                        ? Colors.grey.shade300
                        : active || _isHovered
                            ? const Color(0xFF00897B)
                            : Colors.grey.shade600,
                  )
                : Text(
                    widget.label!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.bold : FontWeight.w500,
                      color: active
                          ? Colors.white
                          : _isHovered
                              ? const Color(0xFF00897B)
                              : Colors.grey.shade700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ======================================================
// APP FOOTER WIDGET
// ======================================================
class _AppFooter extends StatelessWidget {
  const _AppFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Main footer content ----
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Wrap(
              spacing: 32,
              runSpacing: 28,
              children: [
                // Cột 1: App info
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            padding: const EdgeInsets.all(4),
                            clipBehavior: Clip.antiAlias,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const AppLogo(size: 30),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Trọ Tốt',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ứng dụng tìm phòng trọ uy tín, an toàn và nhanh chóng tại Hà Nội.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: 14),
                      // App store badges
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StoreBadge(
                            icon: Icons.apple,
                            label: 'App Store',
                            sublabel: 'Download on the',
                          ),
                          _StoreBadge(
                            icon: Icons.android,
                            label: 'Google Play',
                            sublabel: 'Get it on',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Cột 2: Về chúng tôi
                SizedBox(
                  width: 160,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Về Trọ Tốt',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _FooterLink('Về chúng tôi'),
                      _FooterLink('Quy chế hoạt động'),
                      _FooterLink('Chính sách bảo mật'),
                      _FooterLink('Giải quyết tranh chấp'),
                      _FooterLink('Điều khoản sử dụng'),
                    ],
                  ),
                ),

                // Cột 3: Liên hệ & mạng xã hội
                SizedBox(
                  width: 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Liên kết',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Social icons
                      Row(
                        children: [
                          _SocialBtn(icon: Icons.business, color: const Color(0xFF0A66C2), tooltip: 'LinkedIn'),
                          const SizedBox(width: 8),
                          _SocialBtn(icon: Icons.play_circle_fill, color: const Color(0xFFFF0000), tooltip: 'YouTube'),
                          const SizedBox(width: 8),
                          _SocialBtn(icon: Icons.facebook, color: const Color(0xFF1877F2), tooltip: 'Facebook'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _FooterInfoRow(Icons.email_outlined, 'trotot@gmail.com'),
                      const SizedBox(height: 6),
                      _FooterInfoRow(Icons.support_agent_rounded, 'CSKH: 1900 1234 (1.000đ/phút)'),
                      const SizedBox(height: 6),
                      _FooterInfoRow(
                        Icons.location_on_outlined,
                        'Tầng 5, Tòa nhà ABC,\n175 Tây Sơn, Đống Đa,\nHà Nội, Việt Nam',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ---- Bottom bar ----
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E).withAlpha(8),
              border: Border(
                top: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  '© 2025 Trọ Tốt. Đồ án tốt nghiệp - Đại học Thủy lợi.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, color: const Color(0xFF00897B), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Đã đăng ký BCTT',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
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

class _StoreBadge extends StatefulWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  const _StoreBadge({required this.icon, required this.label, required this.sublabel});
  @override
  State<_StoreBadge> createState() => _StoreBadgeState();
}

class _StoreBadgeState extends State<_StoreBadge> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _hovered ? const Color(0xFF1A1A2E).withAlpha(230) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(8),
          boxShadow: _hovered
              ? [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.sublabel, style: const TextStyle(color: Colors.white70, fontSize: 9)),
                Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterLink extends StatefulWidget {
  final String label;
  const _FooterLink(this.label);
  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: TextStyle(
            fontSize: 13,
            color: _hovered ? const Color(0xFF00897B) : Colors.grey.shade600,
            fontWeight: _hovered ? FontWeight.w500 : FontWeight.normal,
            decoration: _hovered ? TextDecoration.underline : TextDecoration.none,
            decorationColor: const Color(0xFF00897B),
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

class _SocialBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  const _SocialBtn({required this.icon, required this.color, required this.tooltip});
  @override
  State<_SocialBtn> createState() => _SocialBtnState();
}

class _SocialBtnState extends State<_SocialBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 36,
          height: 36,
          transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: _hovered ? widget.color : widget.color.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: widget.color.withAlpha(_hovered ? 0 : 60)),
            boxShadow: _hovered
                ? [BoxShadow(color: widget.color.withAlpha(60), blurRadius: 8, offset: const Offset(0, 3))]
                : [],
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: _hovered ? Colors.white : widget.color,
          ),
        ),
      ),
    );
  }
}

class _FooterInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FooterInfoRow(this.icon, this.text);
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF00897B)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, height: 1.4),
          ),
        ),
      ],
    );
  }
}

// ======================================================
// ADVANCED FILTER BOTTOM SHEET WIDGET (TUẦN 8.1)
// ======================================================
class _FilterSheet extends StatefulWidget {
  final RangeValues initialPriceRange;
  final RangeValues initialAreaRange;
  final String initialRoomType;
  final Set<String> initialAmenities;
  final Function(RangeValues, RangeValues, String, Set<String>) onApply;

  const _FilterSheet({
    required this.initialPriceRange,
    required this.initialAreaRange,
    required this.initialRoomType,
    required this.initialAmenities,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late RangeValues _price;
  late RangeValues _area;
  late String _roomType;
  late Set<String> _amenities;

  final List<String> _roomTypes = [
    'Tất cả',
    'Phòng trọ khép kín',
    'Chung cư mini',
    'Ở ghép',
    'Nhà nguyên căn',
  ];

  final List<String> _allAmenities = [
    'Điều hòa',
    'Nóng lạnh',
    'Wifi',
    'Máy giặt',
    'Tủ lạnh',
    'Chỗ để xe',
    'Ban công',
    'Thang máy',
    'Giờ giấc tự do',
    'Camera an ninh',
  ];

  @override
  void initState() {
    super.initState();
    _price = widget.initialPriceRange;
    _area = widget.initialAreaRange;
    _roomType = widget.initialRoomType;
    _amenities = Set.from(widget.initialAmenities);
  }

  void _reset() {
    setState(() {
      _price = const RangeValues(1, 15);
      _area = const RangeValues(15, 80);
      _roomType = 'Tất cả';
      _amenities.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '🎛️ Bộ lọc nâng cao',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _reset,
                      child: const Text('Đặt lại', style: TextStyle(color: Colors.red)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content scrollable
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ====== 1. KHOẢNG GIÁ ======
                _sectionHeader(
                  'Khoảng giá (triệu/tháng)',
                  '${_price.start.toStringAsFixed(1)} - ${_price.end >= 15 ? '15+ tr' : '${_price.end.toStringAsFixed(1)} tr'}',
                ),
                RangeSlider(
                  values: _price,
                  min: 1.0,
                  max: 15.0,
                  divisions: 28,
                  activeColor: const Color(0xFF00897B),
                  inactiveColor: Colors.grey.shade200,
                  labels: RangeLabels(
                    '${_price.start.toStringAsFixed(1)} tr',
                    _price.end >= 15 ? '15+ tr' : '${_price.end.toStringAsFixed(1)} tr',
                  ),
                  onChanged: (vals) => setState(() => _price = vals),
                ),
                const SizedBox(height: 20),

                // ====== 2. DIỆN TÍCH ======
                _sectionHeader(
                  'Diện tích (m²)',
                  '${_area.start.toStringAsFixed(0)} m² - ${_area.end >= 80 ? '80+ m²' : '${_area.end.toStringAsFixed(0)} m²'}',
                ),
                RangeSlider(
                  values: _area,
                  min: 15.0,
                  max: 80.0,
                  divisions: 13,
                  activeColor: const Color(0xFF00897B),
                  inactiveColor: Colors.grey.shade200,
                  labels: RangeLabels(
                    '${_area.start.toStringAsFixed(0)} m²',
                    _area.end >= 80 ? '80+ m²' : '${_area.end.toStringAsFixed(0)} m²',
                  ),
                  onChanged: (vals) => setState(() => _area = vals),
                ),
                const SizedBox(height: 20),

                // ====== 3. LOẠI PHÒNG ======
                const Text(
                  'Loại phòng',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _roomTypes.map((type) {
                    final selected = _roomType == type;
                    return ChoiceChip(
                      label: Text(type),
                      selected: selected,
                      selectedColor: const Color(0xFF00897B),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.grey.shade800,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      onSelected: (_) => setState(() => _roomType = type),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // ====== 4. TIỆN ÍCH BẮT BUỘC ======
                const Text(
                  'Tiện ích bắt buộc phải có',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Chỉ hiển thị phòng có ĐỦ các tiện ích được tích chọn',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allAmenities.map((amenity) {
                    final isChecked = _amenities.contains(amenity);
                    return FilterChip(
                      label: Text(amenity),
                      selected: isChecked,
                      selectedColor: const Color(0xFF00897B).withAlpha(40),
                      checkmarkColor: const Color(0xFF00897B),
                      labelStyle: TextStyle(
                        color: isChecked ? const Color(0xFF00897B) : Colors.grey.shade800,
                        fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      side: BorderSide(
                        color: isChecked ? const Color(0xFF00897B) : Colors.grey.shade300,
                      ),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _amenities.add(amenity);
                          } else {
                            _amenities.remove(amenity);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Bottom sticky apply button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_price, _area, _roomType, _amenities);
                    Navigator.pop(context);
                  },
                  style: AppButtonStyle.primary(),
                  child: const Text(
                    'ÁP DỤNG BỘ LỌC',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String value) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2F1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF00796B),
            ),
          ),
        ),
      ],
    );
  }
}
