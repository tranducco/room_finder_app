import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/admin_service.dart';
import '../../../data/notification_service.dart';
import '../../../domain/models/app_notification.dart';
import '../../../domain/models/app_user.dart';
import '../../widgets/app_button_style.dart';
import '../../widgets/app_image.dart';

class AdminNotificationsTab extends StatefulWidget {
  const AdminNotificationsTab({super.key});

  @override
  State<AdminNotificationsTab> createState() => _AdminNotificationsTabState();
}

class _AdminNotificationsTabState extends State<AdminNotificationsTab> {
  final NotificationService _notificationService = NotificationService();
  final AdminService _adminService = AdminService();

  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _userIdController = TextEditingController();

  bool _isBroadcast = true;
  bool _isSending = false;
  bool _isLoadingHistory = true;

  List<AppNotification> _notifications = [];
  List<AppUser> _allUsers = [];
  AppUser? _selectedUser;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final list = await _notificationService.getAllNotificationsAdmin();
      final users = await _adminService.getAllUsers();
      if (mounted) {
        setState(() {
          _notifications = list;
          _allUsers = users;
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _showUserPickerModal() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = _allUsers.where((u) {
            final q = searchQuery.toLowerCase();
            return u.fullName.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q) ||
                u.phoneNumber.contains(q) ||
                u.uid.toLowerCase().contains(q);
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Chọn người nhận thông báo',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên, email, SĐT hoặc UID...',
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00897B)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (val) {
                    setSheetState(() => searchQuery = val.trim());
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'Không tìm thấy người dùng phù hợp.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (c, i) {
                            final u = filtered[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              leading: ClipOval(
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  color: const Color(0xFF00897B).withAlpha(20),
                                  child: u.avatarUrl.isNotEmpty
                                      ? AppImage(
                                          imageUrl: u.avatarUrl,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                        )
                                      : Center(
                                          child: Text(
                                            (u.fullName.isNotEmpty
                                                    ? u.fullName[0]
                                                    : u.email.isNotEmpty
                                                        ? u.email[0]
                                                        : 'U')
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF00897B),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              title: Text(
                                u.fullName.isNotEmpty ? u.fullName : (u.email.isNotEmpty ? u.email : 'Người dùng'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Text(
                                '${u.email.isNotEmpty ? u.email : "Chưa có email"} ${u.phoneNumber.isNotEmpty ? "• SĐT: ${u.phoneNumber}" : ""}\nUID: ${u.uid}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                              onTap: () {
                                setState(() {
                                  _selectedUser = u;
                                  _userIdController.text = u.uid;
                                });
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _sendNotification() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ Tiêu đề và Nội dung!')),
      );
      return;
    }

    final targetId = _selectedUser?.uid ?? _userIdController.text.trim();

    if (!_isBroadcast && targetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn hoặc nhập UID/Email người nhận!')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      if (_isBroadcast) {
        await _notificationService.sendBroadcastNotification(
          title: title,
          body: body,
          type: 'system',
        );
      } else {
        await _notificationService.sendUserNotification(
          userId: targetId,
          title: title,
          body: body,
          type: 'system',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Đã gửi thông báo thành công!')),
      );

      _titleController.clear();
      _bodyController.clear();
      _userIdController.clear();
      setState(() => _selectedUser = null);
      _loadHistory();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi gửi thông báo: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _getRecipientLabel(String recipientId) {
    if (recipientId == 'all') return 'Toàn sàn';
    try {
      final u = _allUsers.firstWhere(
        (x) => x.uid == recipientId || (x.email.isNotEmpty && x.email == recipientId),
      );
      final name = u.fullName.isNotEmpty ? u.fullName : (u.email.isNotEmpty ? u.email : u.uid);
      return 'Tới: $name';
    } catch (_) {
      return 'UID: ${recipientId.length > 8 ? "${recipientId.substring(0, 8)}..." : recipientId}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final isSmall = MediaQuery.of(context).size.width < 720;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isSmall ? 12 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Gửi Thông báo Hệ thống',
              style: TextStyle(
                fontSize: isSmall ? 18 : 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Phát thông báo đẩy tới toàn bộ người dùng hoặc gửi trực tiếp cho một tài khoản cụ thể',
              style: TextStyle(fontSize: isSmall ? 12 : 13, color: Colors.grey.shade600),
              maxLines: isSmall ? 1 : 2,
              overflow: TextOverflow.ellipsis,
            ),

            SizedBox(height: isSmall ? 14 : 24),

            // Form Compose Box
            Container(
              padding: EdgeInsets.all(isSmall ? 12 : 24),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Soạn thông điệp mới',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Broadcast vs Targeted Selection
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment<bool>(
                        value: true,
                        label: Text(isSmall ? 'Toàn bộ' : 'Gửi toàn bộ người dùng (Broadcast)'),
                        icon: const Icon(Icons.campaign_rounded),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        label: Text(isSmall ? 'Cá nhân' : 'Gửi riêng cho một người dùng (UID/Email)'),
                        icon: const Icon(Icons.person_rounded),
                      ),
                    ],
                    selected: {_isBroadcast},
                    onSelectionChanged: (newSelection) {
                      setState(() => _isBroadcast = newSelection.first);
                    },
                  ),

                  if (!_isBroadcast) ...[
                    const SizedBox(height: 16),

                    if (_selectedUser != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00897B).withAlpha(15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF00897B).withAlpha(50)),
                        ),
                        child: Row(
                          children: [
                            ClipOval(
                              child: Container(
                                width: 40,
                                height: 40,
                                color: const Color(0xFF00897B).withAlpha(30),
                                child: _selectedUser!.avatarUrl.isNotEmpty
                                    ? AppImage(
                                        imageUrl: _selectedUser!.avatarUrl,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                      )
                                    : Center(
                                        child: Text(
                                          (_selectedUser!.fullName.isNotEmpty
                                                  ? _selectedUser!.fullName[0]
                                                  : _selectedUser!.email.isNotEmpty
                                                      ? _selectedUser!.email[0]
                                                      : 'U')
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: Color(0xFF00897B),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedUser!.fullName.isNotEmpty
                                        ? _selectedUser!.fullName
                                        : 'Người dùng',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    '${_selectedUser!.email.isNotEmpty ? _selectedUser!.email : "Chưa có email"} • UID: ${_selectedUser!.uid}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              tooltip: 'Bỏ chọn người này',
                              onPressed: () {
                                setState(() {
                                  _selectedUser = null;
                                  _userIdController.clear();
                                });
                              },
                            ),
                          ],
                        ),
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showUserPickerModal,
                              icon: const Icon(Icons.person_search_rounded, color: Color(0xFF00897B)),
                              label: const Text('🔍 Chọn người nhận từ danh sách thành viên'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF00897B),
                                side: const BorderSide(color: Color(0xFF00897B)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _userIdController,
                        decoration: const InputDecoration(
                          labelText: 'Hoặc nhập UID / Email người nhận',
                          hintText: 'Nhập UID hoặc địa chỉ Email của người dùng...',
                          prefixIcon: Icon(Icons.fingerprint_rounded, color: Color(0xFF00897B)),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 16),

                  // Title
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề thông báo *',
                      hintText: 'Ví dụ: Cảnh báo tài khoản, Thông báo lịch hẹn...',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Body
                  TextField(
                    controller: _bodyController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Nội dung chi tiết *',
                      hintText: 'Nhập nội dung đầy đủ của thông báo gửi tới người dùng...',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Send button
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendNotification,
                      icon: _isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_isSending ? 'Đang gửi...' : 'Gửi thông báo ngay'),
                      style: AppButtonStyle.primary(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // History Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Lịch sử thông báo đã gửi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                IconButton(
                  onPressed: _loadHistory,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Tải lại danh sách',
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_isLoadingHistory)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: Color(0xFF00897B)),
                ),
              )
            else if (_notifications.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Text(
                    'Chưa có thông báo nào được gửi.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _notifications.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final notif = _notifications[index];
                    final isAll = notif.recipientId == 'all';
                    final recipientBadge = _getRecipientLabel(notif.recipientId);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00897B).withAlpha(15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: Color(0xFF00897B),
                          size: 20,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              notif.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAll ? Colors.blue.shade50 : Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              recipientBadge,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isAll ? Colors.blue.shade700 : Colors.purple.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            notif.body,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notif.createdAt != null
                                ? dateFormat.format(notif.createdAt!)
                                : 'Chưa rõ',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                        onPressed: () async {
                          await _notificationService.deleteNotification(notif.id);
                          _loadHistory();
                        },
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
}

