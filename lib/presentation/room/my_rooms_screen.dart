import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/room_service.dart';
import '../../domain/models/room.dart';
import '../widgets/room_card.dart';

class MyRoomsScreen extends StatefulWidget {
  const MyRoomsScreen({super.key});

  @override
  State<MyRoomsScreen> createState() => _MyRoomsScreenState();
}

class _MyRoomsScreenState extends State<MyRoomsScreen> {
  final RoomService _roomService = RoomService();
  List<Room> _myRooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyRooms();
  }

  Future<void> _loadMyRooms() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final rooms = await _roomService.getMyRooms(user.uid);
      if (mounted) {
        setState(() {
          _myRooms = rooms;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelete(Room room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa phòng'),
        content: Text(
          'Bạn có chắc chắn muốn xóa bài đăng "${room.title}" không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa ngay'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _roomService.deleteRoom(room.roomId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa phòng thành công')),
        );
        _loadMyRooms();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi khi xóa phòng: $e')));
      }
    }
  }

  Future<void> _toggleStatus(Room room, String newStatus) async {
    try {
      await _roomService.updateRoomStatus(room.roomId, newStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'available'
                ? 'Đã chuyển trạng thái: Còn trống'
                : newStatus == 'rented'
                    ? 'Đã chuyển trạng thái: Đã cho thuê'
                    : 'Đã chuyển trạng thái: Tạm ẩn',
          ),
          backgroundColor: const Color(0xFF00897B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadMyRooms();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phòng tôi đã đăng'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMyRooms),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/create-room');
          if (result == true) {
            _loadMyRooms();
          }
        },
        backgroundColor: Theme.of(context).primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Đăng phòng mới',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: user == null
          ? const Center(
              child: Text('Vui lòng đăng nhập để xem phòng đã đăng.'),
            )
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myRooms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.home_work_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Bạn chưa đăng phòng trọ nào.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.pushNamed(
                        context,
                        '/create-room',
                      );
                      if (result == true) {
                        _loadMyRooms();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Đăng tin ngay'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadMyRooms,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: _myRooms.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final room = _myRooms[index];
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        RoomCard(
                          room: room,
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/room-detail',
                            arguments: room,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (room.status == 'pending_approval')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.amber.shade300),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.hourglass_top_rounded,
                                        size: 14,
                                        color: Colors.amber.shade800,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Chờ duyệt',
                                        style: TextStyle(
                                          color: Colors.amber.shade900,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (room.status == 'rejected')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.red.shade300),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.cancel_outlined,
                                        size: 14,
                                        color: Colors.red.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Bị từ chối',
                                        style: TextStyle(
                                          color: Colors.red.shade800,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                PopupMenuButton<String>(
                                  initialValue: room.status,
                                  tooltip: 'Đổi trạng thái',
                                  onSelected: (newStatus) =>
                                      _toggleStatus(room, newStatus),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: room.status == 'available'
                                          ? Colors.teal.shade50
                                          : room.status == 'rented'
                                              ? Colors.blue.shade50
                                              : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: room.status == 'available'
                                            ? Colors.teal.shade200
                                            : room.status == 'rented'
                                                ? Colors.blue.shade200
                                                : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          room.status == 'available'
                                              ? Icons.check_circle_outline
                                              : room.status == 'rented'
                                                  ? Icons.key_rounded
                                                  : Icons.visibility_off_outlined,
                                          size: 14,
                                          color: room.status == 'available'
                                              ? Colors.teal
                                              : room.status == 'rented'
                                                  ? Colors.blue
                                                  : Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          room.status == 'available'
                                              ? 'Còn trống'
                                              : room.status == 'rented'
                                                  ? 'Đã thuê'
                                                  : 'Tạm ẩn',
                                          style: TextStyle(
                                            color: room.status == 'available'
                                                ? Colors.teal
                                                : room.status == 'rented'
                                                    ? Colors.blue
                                                    : Colors.grey,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.arrow_drop_down,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                      ],
                                    ),
                                  ),
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'available',
                                      child: Text('🟢 Còn trống (Hiển thị)'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'rented',
                                      child: Text('🔵 Đã cho thuê'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'hidden',
                                      child: Text('⚪ Tạm ẩn'),
                                    ),
                                  ],
                                ),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () async {
                                      final res = await Navigator.pushNamed(
                                        context,
                                        '/create-room',
                                        arguments: room,
                                      );
                                      if (res == true) _loadMyRooms();
                                    },
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: Color(0xFF00897B),
                                    ),
                                    label: const Text(
                                      'Sửa',
                                      style: TextStyle(
                                        color: Color(0xFF00897B),
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _confirmDelete(room),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    label: const Text(
                                      'Xóa',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (room.status == 'rejected' &&
                            room.rejectionReason != null &&
                            room.rejectionReason!.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.error_outline,
                                    size: 16, color: Colors.red.shade700),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Lý do từ chối: ${room.rejectionReason}. Bạn hãy nhấn "Sửa" để cập nhật lại thông tin.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
