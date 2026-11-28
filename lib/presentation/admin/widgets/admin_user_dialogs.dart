import 'package:flutter/material.dart';

import '../../../data/admin_service.dart';
import '../../../data/notification_service.dart';
import '../../../domain/models/app_user.dart';
import '../../../domain/models/room.dart';
import '../../widgets/app_button_style.dart';

/// Displays a dialog listing all rooms posted by [user].
void showAdminUserRoomsDialog(
  BuildContext context, {
  required AdminService adminService,
  required AppUser user,
}) {
  showDialog(
    context: context,
    builder: (dialogCtx) => FutureBuilder<List<Room>>(
      future: adminService.getUserRooms(user.uid),
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

/// Opens a dialog for the admin to send a direct notification to [targetUser].
void showAdminSendNotificationDialog(
  BuildContext context, {
  required AppUser targetUser,
}) {
  final titleController = TextEditingController();
  final bodyController = TextEditingController();
  bool isSending = false;

  final displayName = targetUser.fullName.isNotEmpty
      ? targetUser.fullName
      : (targetUser.email.isNotEmpty ? targetUser.email : 'Người dùng');

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (dialogCtx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.notifications_active_rounded, color: Color(0xFF00897B)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Gửi thông báo tới $displayName',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
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
