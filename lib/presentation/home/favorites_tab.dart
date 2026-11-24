import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/room_service.dart';
import '../../domain/models/room.dart';
import '../widgets/room_card.dart';

class FavoritesTab extends StatefulWidget {
  const FavoritesTab({super.key});

  @override
  State<FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<FavoritesTab> {
  final RoomService _roomService = RoomService();
  List<Room> _favoriteRooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final rooms = await _roomService.getFavoriteRooms(user.uid);
      if (mounted) {
        setState(() {
          _favoriteRooms = rooms;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFavorite(String roomId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _favoriteRooms.removeWhere((r) => r.roomId == roomId);
    });

    await _roomService.toggleFavorite(user.uid, roomId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã bỏ lưu phòng'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Phòng đã lưu'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFavorites,
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Vui lòng đăng nhập để xem phòng đã lưu.'))
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favoriteRooms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có phòng nào được lưu.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hãy nhấn vào biểu tượng trái tim để lưu lại.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadFavorites,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.builder(
                  clipBehavior: Clip.hardEdge,
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 250.0,
                    mainAxisSpacing: 16.0,
                    crossAxisSpacing: 16.0,
                    childAspectRatio:
                        MediaQuery.of(context).size.width < 420 ? 0.60 : 0.68,
                  ),
                  itemCount: _favoriteRooms.length,
                  itemBuilder: (context, index) {
                    final room = _favoriteRooms[index];
                    return RoomCard(
                      room: room,
                      isFavorite: true,
                      onFavoriteToggle: () => _removeFavorite(room.roomId),
                      onTap: () async {
                        await Navigator.pushNamed(
                          context,
                          '/room-detail',
                          arguments: room,
                        );
                        _loadFavorites();
                      },
                    );
                  },
                ),
              ),
            ),
    );
  }
}
