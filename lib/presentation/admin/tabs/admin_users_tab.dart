import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../data/admin_service.dart';
import '../../../data/notification_service.dart';
import '../../../domain/models/app_user.dart';
import '../../../domain/models/room.dart';
import '../../widgets/app_button_style.dart';
import '../../widgets/app_image.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();

  List<AppUser> _allUsers = [];
  List<AppUser> _filteredUsers = [];
  bool _isLoading = true;

  String _selectedRole = 'all';
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _adminService.getAllUsers();
      if (mounted) {
        setState(() {
          _allUsers = users;
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
      _filteredUsers = _allUsers.where((u) {
        final matchRole = _selectedRole == 'all' || u.role == _selectedRole;
        final matchStatus = _selectedStatus == 'all' || u.status == _selectedStatus;

        final matchSearch = query.isEmpty ||
            u.email.toLowerCase().contains(query) ||
            u.fullName.toLowerCase().contains(query) ||
            u.phoneNumber.toLowerCase().contains(query) ||
            u.uid.toLowerCase().contains(query);

        return matchRole && matchStatus && matchSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentAdmin = FirebaseAuth.instance.currentUser;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Refresh
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quản lý Người dùng & Trạng thái Tài khoản',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Danh sách thành viên, kiểm tra vai trò và quản lý khóa tài khoản vi phạm',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _loadUsers,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Làm mới'),
                  style: AppButtonStyle.primary(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Filter & Search bar
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
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm người dùng theo Email, Họ tên, SĐT hoặc UID...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => _searchController.clear(),
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
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Role filter
                      const Text(
                        'Vai trò: ',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      _filterChip('all', 'Tất cả (${_allUsers.length})', _selectedRole, (val) {
                        setState(() => _selectedRole = val);
                        _applyFilters();
                      }),
                      const SizedBox(width: 8),
                      _filterChip('user', 'Người dùng', _selectedRole, (val) {
                        setState(() => _selectedRole = val);
                        _applyFilters();
                      }),
                      const SizedBox(width: 8),
                      _filterChip('admin', 'Quản trị viên', _selectedRole, (val) {
                        setState(() => _selectedRole = val);
                        _applyFilters();
                      }, color: const Color(0xFF00897B)),

                      const SizedBox(width: 24),
                      // Status filter
                      const Text(
                        'Trạng thái: ',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      _filterChip('all', 'Tất cả', _selectedStatus, (val) {
                        setState(() => _selectedStatus = val);
                        _applyFilters();
                      }),
                      const SizedBox(width: 8),
                      _filterChip('active', 'Hoạt động', _selectedStatus, (val) {
                        setState(() => _selectedStatus = val);
                        _applyFilters();
                      }, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      _filterChip('blocked', 'Bị khóa', _selectedStatus, (val) {
                        setState(() => _selectedStatus = val);
                        _applyFilters();
                      }, color: Colors.red.shade700),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Users Table
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Color(0xFF00897B)),
                ),
              )
            else if (_filteredUsers.isEmpty)
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
                    Icon(Icons.person_search_rounded, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'Không tìm thấy người dùng phù hợp',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
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
                  itemCount: _filteredUsers.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final user = _filteredUsers[index];
                    final isCurrentAdmin = user.uid == currentAdmin?.uid;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: user.isAdmin
                                  ? const Color(0xFF00897B)
                                  : Colors.grey.shade200,
                            ),
                            child: ClipOval(
                              child: user.avatarUrl.isNotEmpty
                                  ? AppImage(
                                      imageUrl: user.avatarUrl,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorWidget: Center(
                                        child: Text(
                                          (user.fullName.isNotEmpty
                                                  ? user.fullName[0]
                                                  : user.email.isNotEmpty
                                                      ? user.email[0]
                                                      : 'U')
                                              .toUpperCase(),
                                          style: TextStyle(
                                            color: user.isAdmin
                                                ? Colors.white
                                                : const Color(0xFF1A1A2E),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        (user.fullName.isNotEmpty
                                                ? user.fullName[0]
                                                : user.email.isNotEmpty
                                                    ? user.email[0]
                                                    : 'U')
                                            .toUpperCase(),
                                        style: TextStyle(
                                          color: user.isAdmin
                                              ? Colors.white
                                              : const Color(0xFF1A1A2E),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Name & Email
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      user.fullName.isNotEmpty
                                          ? user.fullName
                                          : (user.email.isNotEmpty
                                              ? user.email.split('@').first
                                              : 'Người dùng'),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                    ),
                                    if (isCurrentAdmin) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Bạn',
                                          style: TextStyle(
                                            color: Colors.blue.shade800,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                // Hiển thị email nếu có, hoặc thông báo Chưa có email
                                Text(
                                  user.email.isNotEmpty ? user.email : 'Chưa có email',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: user.email.isNotEmpty
                                        ? Colors.grey.shade600
                                        : Colors.amber.shade900,
                                    fontStyle: user.email.isEmpty
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                ),
                                if (user.phoneNumber.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'SĐT: ${user.phoneNumber}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                // UID kèm nút sao chép 1-chạm
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: user.uid));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('📋 Đã sao chép UID: ${user.uid}'),
                                        duration: const Duration(seconds: 1),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.fingerprint_rounded, size: 12, color: Colors.grey.shade500),
                                      const SizedBox(width: 3),
                                      Text(
                                        'UID: ${user.uid.length > 12 ? "${user.uid.substring(0, 8)}..." : user.uid}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.copy_rounded, size: 11, color: Colors.grey.shade500),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Role Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: user.isAdmin
                                  ? const Color(0xFF00897B).withAlpha(20)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: user.isAdmin
                                    ? const Color(0xFF00897B).withAlpha(50)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              user.isAdmin ? 'Admin' : 'User',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: user.isAdmin
                                    ? const Color(0xFF00897B)
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: user.isBlocked
                                  ? Colors.red.shade50
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              user.isBlocked ? 'Bị khóa' : 'Hoạt động',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: user.isBlocked
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Created date
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Text(
                                user.createdAt != null
                                    ? dateFormat.format(user.createdAt!)
                                    : (user.updatedAt != null
                                        ? dateFormat.format(user.updatedAt!)
                                        : 'Chưa có ngày tạo'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: (user.createdAt != null || user.updatedAt != null)
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(width: 16),

                          // Action Buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Gửi thông báo riêng
                              Tooltip(
                                message: 'Gửi thông báo riêng cho người này',
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.send_rounded,
                                    size: 18,
                                    color: Color(0xFF00897B),
                                  ),
                                  onPressed: () => _openSendNotificationDialog(user),
                                ),
                              ),

                              // Xem phòng đăng
                              Tooltip(
                                message: 'Xem các phòng do user này đăng',
                                child: IconButton(
                                  icon: const Icon(Icons.holiday_village_outlined, size: 20),
                                  onPressed: () => _viewUserRooms(user),
                                ),
                              ),

                              // Đổi role
                              if (!isCurrentAdmin)
                                Tooltip(
                                  message: user.isAdmin
                                      ? 'Hạ quyền xuống User'
                                      : 'Thăng quyền lên Admin',
                                  child: IconButton(
                                    icon: Icon(
                                      user.isAdmin
                                          ? Icons.admin_panel_settings_rounded
                                          : Icons.admin_panel_settings_outlined,
                                      size: 20,
                                      color: user.isAdmin
                                          ? const Color(0xFF00897B)
                                          : Colors.grey.shade600,
                                    ),
                                    onPressed: () => _toggleRole(user),
                                  ),
                                ),

                              // Khóa / Mở khóa
                              if (!isCurrentAdmin)
                                Tooltip(
                                  message: user.isBlocked
                                      ? 'Mở khóa tài khoản'
                                      : 'Khóa tài khoản này',
                                  child: IconButton(
                                    icon: Icon(
                                      user.isBlocked
                                          ? Icons.lock_open_rounded
                                          : Icons.lock_outline_rounded,
                                      size: 20,
                                      color: user.isBlocked
                                          ? Colors.green.shade700
                                          : Colors.red.shade600,
                                    ),
                                    onPressed: () => _toggleBlock(user),
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

  Widget _filterChip(
    String key,
    String label,
    String currentSelected,
    ValueChanged<String> onSelected, {
    Color? color,
  }) {
    final isSelected = currentSelected == key;
    final chipColor = color ?? const Color(0xFF00897B);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) onSelected(key);
      },
      selectedColor: chipColor.withAlpha(30),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? chipColor : Colors.grey.shade700,
      ),
    );
  }

  Future<void> _toggleBlock(AppUser user) async {
    final willBlock = !user.isBlocked;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(willBlock ? 'Xác nhận khóa tài khoản?' : 'Mở khóa tài khoản?'),
        content: Text(
          willBlock
              ? 'Tài khoản "${user.email}" sẽ bị đăng xuất và không thể tiếp tục sử dụng ứng dụng.'
              : 'Tài khoản "${user.email}" sẽ được phép đăng nhập và sử dụng lại bình thường.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: willBlock ? Colors.red.shade600 : const Color(0xFF00897B),
              foregroundColor: Colors.white,
            ),
            child: Text(willBlock ? 'Khóa tài khoản' : 'Mở khóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _adminService.toggleUserBlock(user.uid, willBlock);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(willBlock ? '🔒 Đã khóa tài khoản thành công' : '🔓 Đã mở khóa tài khoản'),
        ),
      );
      _loadUsers();
    }
  }

  Future<void> _toggleRole(AppUser user) async {
    final newRole = user.isAdmin ? 'user' : 'admin';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Thay đổi vai trò: $newRole?'),
        content: Text(
          'Bạn có chắc muốn cấp vai trò "$newRole" cho người dùng "${user.email}" không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppButtonStyle.primary(),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _adminService.changeUserRole(user.uid, newRole);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Đã cập nhật vai trò người dùng thành $newRole')),
      );
      _loadUsers();
    }
  }

  void _viewUserRooms(AppUser user) async {
    showDialog(
      context: context,
      builder: (dialogCtx) => FutureBuilder<List<Room>>(
        future: _adminService.getUserRooms(user.uid),
        builder: (ctx, snap) {
          return AlertDialog(
            title: Text('Tin đăng của ${user.fullName.isNotEmpty ? user.fullName : user.email}'),
            content: SizedBox(
              width: 520,
              height: 400,
              child: snap.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : (snap.data?.isEmpty ?? true)
                      ? const Center(
                          child: Text('Người dùng này chưa đăng bài phòng trọ nào.'),
                        )
                      : ListView.separated(
                          itemCount: snap.data!.length,
                          separatorBuilder: (_, _) => const Divider(),
                          itemBuilder: (c, idx) {
                            final r = snap.data![idx];
                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: r.images.isNotEmpty
                                      ? Image.network(r.images.first, fit: BoxFit.cover)
                                      : const Icon(Icons.apartment),
                                ),
                              ),
                              title: Text(
                                r.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                maxLines: 1,
                              ),
                              subtitle: Text(
                                '${r.district} • ${r.status}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          },
                        ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Đóng'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openSendNotificationDialog(AppUser targetUser) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    bool isSending = false;

    final displayName = targetUser.fullName.isNotEmpty
        ? targetUser.fullName
        : (targetUser.email.isNotEmpty ? targetUser.email : 'Người dùng');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Color(0xFF00897B), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Gửi thông báo riêng',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Tới: $displayName (${targetUser.uid.length > 8 ? "${targetUser.uid.substring(0, 8)}..." : targetUser.uid})',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề thông báo *',
                  hintText: 'Nhập tiêu đề...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: bodyController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Nội dung thông báo *',
                  hintText: 'Nhập nội dung nhắn gửi tới tài khoản này...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: isSending
                  ? null
                  : () async {
                      final title = titleController.text.trim();
                      final body = bodyController.text.trim();
                      if (title.isEmpty || body.isEmpty) return;

                      setDialogState(() => isSending = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);

                      try {
                        await NotificationService().sendUserNotification(
                          userId: targetUser.uid,
                          title: title,
                          body: body,
                          type: 'system',
                        );
                        nav.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('🎉 Đã gửi thông báo riêng tới $displayName!'),
                            backgroundColor: const Color(0xFF00897B),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isSending = false);
                        messenger.showSnackBar(
                          SnackBar(content: Text('Lỗi gửi thông báo: $e')),
                        );
                      }
                    },
              style: AppButtonStyle.primary(),
              child: isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Gửi ngay'),
            ),
          ],
        ),
      ),
    );
  }
}

