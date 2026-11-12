import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/room_service.dart';
import '../../../domain/models/room.dart';
import '../../widgets/app_button_style.dart';
import '../widgets/admin_room_detail_dialog.dart';

class AdminRoomsTab extends StatefulWidget {
  final String? initialStatusFilter;

  const AdminRoomsTab({super.key, this.initialStatusFilter});

  @override
  State<AdminRoomsTab> createState() => _AdminRoomsTabState();
}

class _AdminRoomsTabState extends State<AdminRoomsTab> {
  final RoomService _roomService = RoomService();
  final TextEditingController _searchController = TextEditingController();

  List<Room> _allRooms = [];
  List<Room> _filteredRooms = [];
  bool _isLoading = true;

  String _selectedStatus = 'all';
  String _selectedDistrict = 'Tất cả';

  final List<String> _districts = [
    'Tất cả',
    'Cầu Giấy',
    'Đống Đa',
    'Thanh Xuân',
    'Nam Từ Liêm',
    'Bắc Từ Liêm',
    'Ba Đình',
    'Hai Bà Trưng',
    'Hoàng Mai',
    'Hà Đông',
    'Tây Hồ',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialStatusFilter != null) {
      _selectedStatus = widget.initialStatusFilter!;
    }
    _loadRooms();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    setState(() => _isLoading = true);
    try {
      final rooms = await _roomService.getRooms();
      if (mounted) {
        setState(() {
          _allRooms = rooms;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredRooms = _allRooms.where((room) {
        // Lọc trạng thái
        final matchStatus = _selectedStatus == 'all' || room.status == _selectedStatus;

        // Lọc quận
        final matchDistrict = _selectedDistrict == 'Tất cả' ||
            room.district.toLowerCase().contains(_selectedDistrict.toLowerCase()) ||
            room.address.toLowerCase().contains(_selectedDistrict.toLowerCase());

        // Tìm kiếm từ khóa
        final matchSearch = query.isEmpty ||
            room.title.toLowerCase().contains(query) ||
            room.address.toLowerCase().contains(query) ||
            room.roomId.toLowerCase().contains(query) ||
            room.ownerId.toLowerCase().contains(query);

        return matchStatus && matchDistrict && matchSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top title & stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quản lý & Kiểm duyệt tin đăng',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tìm kiếm, duyệt, từ chối, ẩn hoặc xóa tin đăng toàn sàn',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _loadRooms,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Làm mới'),
                  style: AppButtonStyle.primary(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Filter & Search Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(6),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search row & District Dropdown
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Tìm kiếm theo tên phòng, địa chỉ, mã tin, Owner ID...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedDistrict,
                            items: _districts.map((d) {
                              return DropdownMenuItem(value: d, child: Text(d));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedDistrict = val);
                                _applyFilters();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Status Filter Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _statusFilterChip('all', 'Tất cả (${_allRooms.length})'),
                      _statusFilterChip(
                        'pending_approval',
                        'Chờ duyệt (${_countStatus('pending_approval')})',
                        color: Colors.amber.shade800,
                      ),
                      _statusFilterChip(
                        'available',
                        'Đang hiển thị (${_countStatus('available')})',
                        color: const Color(0xFF00897B),
                      ),
                      _statusFilterChip(
                        'rented',
                        'Đã cho thuê (${_countStatus('rented')})',
                        color: Colors.blue.shade700,
                      ),
                      _statusFilterChip(
                        'hidden',
                        'Tạm ẩn (${_countStatus('hidden')})',
                        color: Colors.grey.shade700,
                      ),
                      _statusFilterChip(
                        'rejected',
                        'Bị từ chối (${_countStatus('rejected')})',
                        color: Colors.red.shade700,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Content List
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Color(0xFF00897B)),
                ),
              )
            else if (_filteredRooms.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(48),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'Không tìm thấy tin đăng nào phù hợp',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Thử thay đổi bộ lọc trạng thái hoặc từ khóa tìm kiếm',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(6),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredRooms.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final room = _filteredRooms[index];
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Thumbnail
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 80,
                              height: 80,
                              child: room.images.isNotEmpty
                                  ? Image.network(
                                      room.images.first,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.apartment, size: 30),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.apartment, size: 30),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _buildBadge(room.status),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Mã tin: ${room.roomId}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  room.title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '${currencyFormatter.format(room.price)}/tháng',
                                      style: const TextStyle(
                                        color: Color(0xFF00897B),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '${room.area}m²',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '${room.address} (${room.district})',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Action Buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Nếu là pending -> Có nút duyệt ngay
                              if (room.status == 'pending_approval' ||
                                  room.status == 'rejected')
                                Tooltip(
                                  message: 'Duyệt bài đăng',
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: Color(0xFF00897B),
                                      size: 22,
                                    ),
                                    onPressed: () => _approve(room),
                                  ),
                                ),

                              // Nếu là available -> Có nút ẩn
                              if (room.status == 'available')
                                Tooltip(
                                  message: 'Ẩn tin vi phạm',
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.visibility_off_outlined,
                                      color: Colors.orange.shade800,
                                      size: 22,
                                    ),
                                    onPressed: () => _hide(room),
                                  ),
                                ),

                              // Nếu là hidden -> Có nút khôi phục
                              if (room.status == 'hidden')
                                Tooltip(
                                  message: 'Khôi phục hiển thị',
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.restore_rounded,
                                      color: Color(0xFF00897B),
                                      size: 22,
                                    ),
                                    onPressed: () => _restore(room),
                                  ),
                                ),

                              // Chi tiết
                              Tooltip(
                                message: 'Xem chi tiết & thao tác',
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.remove_red_eye_outlined,
                                    color: Color(0xFF2C3E50),
                                    size: 22,
                                  ),
                                  onPressed: () => _openDetailDialog(room),
                                ),
                              ),

                              // Xóa
                              Tooltip(
                                message: 'Xóa bài đăng vĩnh viễn',
                                child: IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.red.shade600,
                                    size: 22,
                                  ),
                                  onPressed: () => _confirmDelete(room),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _countStatus(String status) {
    return _allRooms.where((r) => r.status == status).length;
  }

  Widget _statusFilterChip(String statusKey, String label, {Color? color}) {
    final isSelected = _selectedStatus == statusKey;
    final chipColor = color ?? const Color(0xFF00897B);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedStatus = statusKey);
          _applyFilters();
        }
      },
      selectedColor: chipColor.withAlpha(35),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? chipColor : Colors.grey.shade700,
      ),
      side: BorderSide(
        color: isSelected ? chipColor : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildBadge(String status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case 'available':
        bg = const Color(0xFFE8F5E9);
        text = const Color(0xFF2E7D32);
        label = 'Còn trống';
        break;
      case 'pending_approval':
        bg = const Color(0xFFFFF8E1);
        text = const Color(0xFFF57F17);
        label = 'Chờ duyệt';
        break;
      case 'rented':
        bg = const Color(0xFFE3F2FD);
        text = const Color(0xFF1565C0);
        label = 'Đã thuê';
        break;
      case 'rejected':
        bg = const Color(0xFFFFEBEE);
        text = const Color(0xFFC62828);
        label = 'Bị từ chối';
        break;
      case 'hidden':
      default:
        bg = const Color(0xFFF5F5F5);
        text = const Color(0xFF616161);
        label = 'Tạm ẩn';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _approve(Room room) async {
    final admin = FirebaseAuth.instance.currentUser;
    await _roomService.approveRoom(room.roomId, admin?.uid ?? 'admin');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Đã duyệt tin đăng thành công!')),
    );
    _loadRooms();
  }

  Future<void> _hide(Room room) async {
    await _roomService.hideRoom(room.roomId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('⚠️ Đã ẩn tin đăng khỏi danh sách công khai')),
    );
    _loadRooms();
  }

  Future<void> _restore(Room room) async {
    await _roomService.restoreRoom(room.roomId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Đã khôi phục tin đăng')),
    );
    _loadRooms();
  }

  Future<void> _confirmDelete(Room room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa vĩnh viễn?'),
        content: Text(
          'Bạn có chắc chắn muốn xóa bài đăng "${room.title}" không? Thao tác này không thể hoàn tác.',
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
            child: const Text('Xóa ngay'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _roomService.deleteRoom(room.roomId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ Đã xóa bài đăng thành công')),
      );
      _loadRooms();
    }
  }

  void _openDetailDialog(Room room) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AdminRoomDetailDialog(
        room: room,
        onApprove: () async {
          final admin = FirebaseAuth.instance.currentUser;
          await _roomService.approveRoom(room.roomId, admin?.uid ?? 'admin');
          _loadRooms();
        },
        onReject: (reason) async {
          final admin = FirebaseAuth.instance.currentUser;
          await _roomService.rejectRoom(room.roomId, admin?.uid ?? 'admin', reason);
          _loadRooms();
        },
        onHide: () async {
          await _roomService.hideRoom(room.roomId);
          _loadRooms();
        },
        onRestore: () async {
          await _roomService.restoreRoom(room.roomId);
          _loadRooms();
        },
        onDelete: () async {
          await _roomService.deleteRoom(room.roomId);
          _loadRooms();
        },
      ),
    );
  }
}

