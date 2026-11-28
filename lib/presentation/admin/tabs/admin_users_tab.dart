import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/admin_service.dart';
import '../../../domain/models/app_user.dart';
import '../../widgets/app_button_style.dart';
import '../widgets/admin_user_dialogs.dart';
import '../widgets/admin_user_list_item.dart';

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
    final isSmall = MediaQuery.of(context).size.width < 720;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isSmall ? 12 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Refresh
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quản lý Người dùng & Trạng thái',
                        style: TextStyle(
                          fontSize: isSmall ? 18 : 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Danh sách thành viên, kiểm tra vai trò và quản lý khóa tài khoản vi phạm',
                        style: TextStyle(fontSize: isSmall ? 12 : 13, color: Colors.grey.shade600),
                        maxLines: isSmall ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                isSmall
                    ? IconButton(
                        onPressed: _loadUsers,
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00897B)),
                        tooltip: 'Làm mới',
                      )
                    : ElevatedButton.icon(
                        onPressed: _loadUsers,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Làm mới'),
                        style: AppButtonStyle.primary(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
              ],
            ),

            SizedBox(height: isSmall ? 12 : 20),

            // Filter & Search bar
            Container(
              padding: EdgeInsets.all(isSmall ? 10 : 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
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
                  SizedBox(
                    height: isSmall ? 40 : 48,
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: isSmall ? 13 : 14),
                      decoration: InputDecoration(
                        hintText: isSmall
                            ? 'Tìm theo Email, tên, SĐT, UID...'
                            : 'Tìm kiếm người dùng theo Email, Họ tên, SĐT hoặc UID...',
                        hintStyle: TextStyle(fontSize: isSmall ? 12 : 13),
                        prefixIcon: Icon(Icons.search, size: isSmall ? 18 : 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isSmall ? 8 : 12),
                  if (isSmall) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text(
                            'Vai trò: ',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          _filterChip('all', 'Tất cả (${_allUsers.length})', _selectedRole, (val) {
                            setState(() => _selectedRole = val);
                            _applyFilters();
                          }),
                          const SizedBox(width: 4),
                          _filterChip('user', 'Người dùng', _selectedRole, (val) {
                            setState(() => _selectedRole = val);
                            _applyFilters();
                          }),
                          const SizedBox(width: 4),
                          _filterChip('admin', 'Quản trị viên', _selectedRole, (val) {
                            setState(() => _selectedRole = val);
                            _applyFilters();
                          }, color: const Color(0xFF00897B)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text(
                            'Trạng thái: ',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          _filterChip('all', 'Tất cả', _selectedStatus, (val) {
                            setState(() => _selectedStatus = val);
                            _applyFilters();
                          }),
                          const SizedBox(width: 4),
                          _filterChip('active', 'Hoạt động', _selectedStatus, (val) {
                            setState(() => _selectedStatus = val);
                            _applyFilters();
                          }, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          _filterChip('blocked', 'Bị khóa', _selectedStatus, (val) {
                            setState(() => _selectedStatus = val);
                            _applyFilters();
                          }, color: Colors.red.shade700),
                        ],
                      ),
                    ),
                  ] else ...[
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Vai trò: ',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            _filterChip('all', 'Tất cả (${_allUsers.length})', _selectedRole, (val) {
                              setState(() => _selectedRole = val);
                              _applyFilters();
                            }),
                            _filterChip('user', 'Người dùng', _selectedRole, (val) {
                              setState(() => _selectedRole = val);
                              _applyFilters();
                            }),
                            _filterChip('admin', 'Quản trị viên', _selectedRole, (val) {
                              setState(() => _selectedRole = val);
                              _applyFilters();
                            }, color: const Color(0xFF00897B)),
                          ],
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Trạng thái: ',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            _filterChip('all', 'Tất cả', _selectedStatus, (val) {
                              setState(() => _selectedStatus = val);
                              _applyFilters();
                            }),
                            _filterChip('active', 'Hoạt động', _selectedStatus, (val) {
                              setState(() => _selectedStatus = val);
                              _applyFilters();
                            }, color: Colors.green.shade700),
                            _filterChip('blocked', 'Bị khóa', _selectedStatus, (val) {
                              setState(() => _selectedStatus = val);
                              _applyFilters();
                            }, color: Colors.red.shade700),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(height: isSmall ? 12 : 20),

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
                    return AdminUserListItem(
                      user: user,
                      isCurrentAdmin: isCurrentAdmin,
                      isSmall: isSmall,
                      dateFormat: dateFormat,
                      onSendNotification: () => showAdminSendNotificationDialog(
                        context,
                        targetUser: user,
                      ),
                      onViewRooms: () => showAdminUserRoomsDialog(
                        context,
                        adminService: _adminService,
                        user: user,
                      ),
                      onToggleRole: () => _toggleRole(user),
                      onToggleBlock: () => _toggleBlock(user),
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
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

}

