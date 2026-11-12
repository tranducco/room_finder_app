import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/auth_service.dart';
import '../../data/room_service.dart';
import '../widgets/app_button_style.dart';
import '../widgets/app_image.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final RoomService _roomService = RoomService();
  final AuthService _authService = AuthService();
  int _myRoomsCount = 0;
  int _favCount = 0;
  int _bookingsCount = 0;
  bool _isLoading = true;

  String _fullName = '';
  String _phoneNumber = '';
  String _avatarUrl = '';
  String _role = 'user';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final myRoomsFuture = _roomService.getMyRooms(user.uid);
      final favIdsFuture = _roomService.getFavoriteRoomIds(user.uid);
      final bookingsFuture = _roomService.getMyBookings(user.uid);
      final profileFuture = _authService.getUserProfile(user.uid);

      final results = await Future.wait([
        myRoomsFuture,
        favIdsFuture,
        bookingsFuture,
        profileFuture,
      ]);

      final myRooms = results[0] as List;
      final favIds = results[1] as List;
      final bookings = results[2] as List;
      final profile = results[3] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _myRoomsCount = myRooms.length;
          _favCount = favIds.length;
          _bookingsCount = bookings.length;
          if (profile != null) {
            _fullName = profile['fullName'] as String? ?? user.displayName ?? '';
            _phoneNumber = profile['phoneNumber'] as String? ?? '';
            _avatarUrl = profile['avatarUrl'] as String? ?? user.photoURL ?? '';
            _role = profile['role'] as String? ?? 'user';
          } else {
            _fullName = user.displayName ?? '';
            _avatarUrl = user.photoURL ?? '';
            _role = 'user';
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final authService = AuthService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // ====== PROFILE HEADER ======
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00695C), Color(0xFF00897B)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    children: [
                      // Avatar with edit button
                      Stack(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withAlpha(30),
                              border: Border.all(
                                color: Colors.white.withAlpha(120),
                                width: 2.5,
                              ),
                            ),
                            child: ClipOval(
                              child: _avatarUrl.isNotEmpty
                                  ? AppImage(
                                      imageUrl: _avatarUrl,
                                      width: 88,
                                      height: 88,
                                      fit: BoxFit.cover,
                                      errorWidget: const Icon(
                                        Icons.person_rounded,
                                        size: 48,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_rounded,
                                      size: 48,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _openEditProfileDialog,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  size: 14,
                                  color: Color(0xFF00897B),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _fullName.isNotEmpty
                            ? _fullName
                            : (user?.displayName ??
                                user?.email?.split('@').first ??
                                'Người dùng'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_role == 'admin') ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade300,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_rounded, size: 13, color: Color(0xFF1A1A2E)),
                              SizedBox(width: 4),
                              Text(
                                'QUẢN TRỊ VIÊN',
                                style: TextStyle(
                                  color: Color(0xFF1A1A2E),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontSize: 13,
                        ),
                      ),
                      if (_phoneNumber.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.phone_android_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _phoneNumber,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Stats row
                      if (!_isLoading)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statItem(_myRoomsCount.toString(), 'Tin đăng'),
                            _divider(),
                            _statItem(_favCount.toString(), 'Yêu thích'),
                            _divider(),
                            _statItem(_bookingsCount.toString(), 'Lịch hẹn'),
                          ],
                        )
                      else
                        const CircularProgressIndicator(color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ====== MENU SECTION ======
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_role == 'admin') ...[
                    const SizedBox(height: 8),
                    _sectionHeader('Hệ thống Quản trị'),
                    const SizedBox(height: 8),
                    _menuCard([
                      _menuItem(
                        icon: Icons.admin_panel_settings_rounded,
                        color: const Color(0xFF00897B),
                        label: 'Bảng điều khiển Quản trị viên',
                        subtitle:
                            'Duyệt tin, quản lý người dùng, xử lý vi phạm',
                        onTap: () {
                          Navigator.pushNamed(context, '/admin');
                        },
                      ),
                    ]),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 8),
                  _sectionHeader('Quản lý tin đăng'),
                  const SizedBox(height: 8),
                  _menuCard([
                    _menuItem(
                      icon: Icons.add_circle_outline_rounded,
                      color: const Color(0xFF00897B),
                      label: 'Đăng phòng cho thuê',
                      subtitle:
                          'Đăng tin miễn phí, tiếp cận hàng nghìn người thuê',
                      onTap: () async {
                        final result = await Navigator.pushNamed(
                          context,
                          '/create-room',
                        );
                        if (result == true && mounted) _loadStats();
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    _menuItem(
                      icon: Icons.home_work_outlined,
                      color: Colors.blue.shade600,
                      label: 'Phòng tôi đã đăng',
                      subtitle: '$_myRoomsCount tin đăng đang hoạt động',
                      onTap: () async {
                        await Navigator.pushNamed(context, '/my-rooms');
                        if (mounted) _loadStats();
                      },
                    ),
                  ]),
                  const SizedBox(height: 16),

                  _sectionHeader('Hoạt động của bạn'),
                  const SizedBox(height: 8),
                  _menuCard([
                    _menuItem(
                      icon: Icons.calendar_month_outlined,
                      color: Colors.orange.shade600,
                      label: 'Lịch hẹn xem phòng',
                      subtitle: 'Xem trạng thái lịch hẹn đã đặt',
                      onTap: () => Navigator.pushNamed(context, '/my-bookings'),
                    ),
                    const Divider(height: 1, indent: 56),
                    _menuItem(
                      icon: Icons.favorite_outline_rounded,
                      color: Colors.red.shade400,
                      label: 'Phòng đã lưu',
                      subtitle: '$_favCount phòng yêu thích',
                      onTap: () {
                        // Switch tab về Favorites
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Xem tab "Đã lưu" bên dưới'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ]),
                  const SizedBox(height: 16),

                  _sectionHeader('Tài khoản'),
                  const SizedBox(height: 8),
                  _menuCard([
                    _menuItem(
                      icon: Icons.manage_accounts_outlined,
                      color: Colors.purple.shade400,
                      label: 'Thông tin cá nhân',
                      subtitle: 'Cập nhật họ tên, SĐT, ảnh đại diện',
                      onTap: _openEditProfileDialog,
                    ),
                    const Divider(height: 1, indent: 56),
                    _menuItem(
                      icon: Icons.logout_rounded,
                      color: Colors.red.shade400,
                      label: 'Đăng xuất',
                      subtitle: 'Thoát tài khoản hiện tại',
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: const Text('Đăng xuất?'),
                            content: const Text(
                              'Bạn có chắc chắn muốn đăng xuất không?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Hủy'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: AppButtonStyle.primary(
                                  baseColor: Colors.red.shade600,
                                  hoverColor: Colors.red.shade800,
                                ),
                                child: const Text('Đăng xuất'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && mounted) {
                          // ignore: use_build_context_synchronously
                          final nav = Navigator.of(context);
                          await authService.logout();
                          nav.pushReplacementNamed('/login');
                        }
                      },
                    ),
                  ]),
                  const SizedBox(height: 32),

                  // App version info
                  Center(
                    child: Text(
                      'RoomFinder v1.0 • Đồ án tốt nghiệp',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 12),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 36, color: Colors.white.withAlpha(60));
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF6B7280),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _menuCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required Color color,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  void _openEditProfileDialog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditProfileSheet(
        initialFullName: _fullName,
        initialPhone: _phoneNumber,
        initialAvatarUrl: _avatarUrl,
        userEmail: user.email ?? '',
        onSave: (fullName, phone, avatarUrl) async {
          try {
            await _authService.updateUserProfile(
              uid: user.uid,
              fullName: fullName,
              phoneNumber: phone,
              avatarUrl: avatarUrl,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Đã cập nhật thông tin cá nhân!'),
                backgroundColor: Color(0xFF00897B),
                behavior: SnackBarBehavior.floating,
              ),
            );
            _loadStats();
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi cập nhật: $e')),
            );
          }
        },
      ),
    );
  }
}

// ======================================================
// EDIT PROFILE BOTTOM SHEET WIDGET (TUẦN 6.3 - ĐÃ HOÀN THIỆN ẢNH HỒ SƠ)
// ======================================================
class _EditProfileSheet extends StatefulWidget {
  final String initialFullName;
  final String initialPhone;
  final String initialAvatarUrl;
  final String userEmail;
  final Function(String, String, String) onSave;

  const _EditProfileSheet({
    required this.initialFullName,
    required this.initialPhone,
    required this.initialAvatarUrl,
    required this.userEmail,
    required this.onSave,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _avatarCtrl;
  String _previewAvatar = '';
  bool _isSaving = false;
  bool _isPickingImage = false;

  final List<Map<String, String>> _sampleAvatars = [
    {
      'label': 'Sinh viên nam',
      'url': 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=250',
    },
    {
      'label': 'Sinh viên nữ',
      'url': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=250',
    },
    {
      'label': 'Công sở nam',
      'url': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=250',
    },
    {
      'label': 'Công sở nữ',
      'url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=250',
    },
    {
      'label': 'Năng động',
      'url': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=250',
    },
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialFullName);
    _phoneCtrl = TextEditingController(text: widget.initialPhone);
    _avatarCtrl = TextEditingController(text: widget.initialAvatarUrl);
    _previewAvatar = widget.initialAvatarUrl;

    _avatarCtrl.addListener(() {
      if (_avatarCtrl.text != _previewAvatar) {
        setState(() {
          _previewAvatar = _avatarCtrl.text.trim();
        });
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      setState(() => _isPickingImage = true);
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
      );

      if (file == null) {
        if (mounted) setState(() => _isPickingImage = false);
        return;
      }

      final rawBytes = await file.readAsBytes();
      if (rawBytes.isEmpty) {
        if (mounted) setState(() => _isPickingImage = false);
        return;
      }

      // Nén ảnh về kích thước nhỏ (~240px) để lưu vào Firestore an toàn (< 25KB)
      final compressed = await AppImage.compressImage(
        rawBytes,
        targetWidth: 240,
      );
      final base64Str = base64Encode(compressed);
      final ext = file.name.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final dataUri = 'data:$mimeType;base64,$base64Str';

      if (mounted) {
        setState(() {
          _previewAvatar = dataUri;
          _avatarCtrl.text = dataUri;
          _isPickingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Đã chọn ảnh hồ sơ! Bấm "LƯU THAY ĐỔI" để áp dụng.'),
            backgroundColor: Color(0xFF00897B),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPickingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải ảnh: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Chọn nguồn ảnh hồ sơ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF00897B)),
                title: const Text('Chọn từ thư viện ảnh'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF00897B)),
                title: const Text('Chụp ảnh từ Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar(ImageSource.camera);
                },
              ),
              if (_previewAvatar.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: const Text(
                    'Xóa ảnh đại diện hiện tại',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _previewAvatar = '';
                      _avatarCtrl.clear();
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '👤 Chỉnh sửa hồ sơ cá nhân',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Tài khoản: ${widget.userEmail}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Interactive Avatar Preview with Camera Badge
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: _showImageSourceDialog,
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF00897B).withAlpha(20),
                              border: Border.all(
                                color: const Color(0xFF00897B),
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _previewAvatar.isNotEmpty
                                  ? AppImage(
                                      imageUrl: _previewAvatar,
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.cover,
                                      errorWidget: const Icon(
                                        Icons.person_rounded,
                                        size: 52,
                                        color: Color(0xFF00897B),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_rounded,
                                      size: 52,
                                      color: Color(0xFF00897B),
                                    ),
                            ),
                          ),
                        ),
                        if (_isPickingImage)
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black38,
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _showImageSourceDialog,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00897B),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _showImageSourceDialog,
                          icon: const Icon(Icons.add_a_photo_outlined, size: 15),
                          label: const Text('Tải ảnh lên / Chụp ảnh'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00897B),
                            side: const BorderSide(color: Color(0xFF00897B)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (_previewAvatar.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _previewAvatar = '';
                                _avatarCtrl.clear();
                              });
                            },
                            icon: const Icon(Icons.delete_outline, size: 15, color: Colors.redAccent),
                            label: const Text(
                              'Xóa ảnh',
                              style: TextStyle(color: Colors.redAccent, fontSize: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Sample Avatars Selection
              const Text(
                'Hoặc chọn nhanh ảnh đại diện mẫu:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _sampleAvatars.length,
                  separatorBuilder: (ctx, i) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = _sampleAvatars[index];
                    final isSelected = _previewAvatar == item['url'];

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _previewAvatar = item['url']!;
                          _avatarCtrl.text = item['url']!;
                        });
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? const Color(0xFF00897B) : Colors.grey.shade300,
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF00897B).withAlpha(80),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                        child: ClipOval(
                          child: AppImage(
                            imageUrl: item['url']!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Full Name field
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Họ và tên *',
                  hintText: 'VD: Nguyễn Văn A',
                  prefixIcon: const Icon(
                    Icons.badge_outlined,
                    color: Color(0xFF00897B),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF00897B),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Phone number field
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Số điện thoại',
                  hintText: 'VD: 0912345678',
                  prefixIcon: const Icon(
                    Icons.phone_rounded,
                    color: Color(0xFF00897B),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF00897B),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Avatar URL field (optional direct link)
              TextFormField(
                controller: _avatarCtrl,
                decoration: InputDecoration(
                  labelText: 'Hoặc dán link ảnh trực tiếp (URL)',
                  hintText: 'https://...',
                  prefixIcon: const Icon(
                    Icons.link_rounded,
                    color: Color(0xFF00897B),
                  ),
                  suffixIcon: _avatarCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _avatarCtrl.clear();
                              _previewAvatar = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF00897B),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          setState(() => _isSaving = true);
                          final nav = Navigator.of(context);
                          await widget.onSave(
                            _nameCtrl.text.trim(),
                            _phoneCtrl.text.trim(),
                            _previewAvatar.trim(),
                          );
                          if (mounted) {
                            setState(() => _isSaving = false);
                            nav.pop();
                          }
                        },
                  style: AppButtonStyle.primary(hoverElevation: 3),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'LƯU THAY ĐỔI',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
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
