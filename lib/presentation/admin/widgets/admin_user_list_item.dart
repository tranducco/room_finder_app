import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/app_user.dart';
import '../../widgets/app_image.dart';

/// Item row / card displaying a single user in the admin user list.
class AdminUserListItem extends StatelessWidget {
  final AppUser user;
  final bool isCurrentAdmin;
  final bool isSmall;
  final DateFormat dateFormat;
  final VoidCallback onSendNotification;
  final VoidCallback onViewRooms;
  final VoidCallback onToggleRole;
  final VoidCallback onToggleBlock;

  const AdminUserListItem({
    super.key,
    required this.user,
    required this.isCurrentAdmin,
    required this.isSmall,
    required this.dateFormat,
    required this.onSendNotification,
    required this.onViewRooms,
    required this.onToggleRole,
    required this.onToggleBlock,
  });

  String get _initialLetter =>
      (user.fullName.isNotEmpty
              ? user.fullName[0]
              : user.email.isNotEmpty
                  ? user.email[0]
                  : 'U')
          .toUpperCase();

  String get _displayName =>
      user.fullName.isNotEmpty
          ? user.fullName
          : (user.email.isNotEmpty ? user.email.split('@').first : 'Người dùng');

  void _copyUid(BuildContext context) {
    Clipboard.setData(ClipboardData(text: user.uid));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 Đã sao chép UID: ${user.uid}'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildAvatar({required double size, required double fontSize}) {
    final fallback = Center(
      child: Text(
        _initialLetter,
        style: TextStyle(
          color: user.isAdmin ? Colors.white : const Color(0xFF1A1A2E),
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: user.isAdmin ? const Color(0xFF00897B) : Colors.grey.shade200,
      ),
      child: ClipOval(
        child: user.avatarUrl.isNotEmpty
            ? AppImage(
                imageUrl: user.avatarUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorWidget: fallback,
              )
            : fallback,
      ),
    );
  }

  Widget _buildRoleBadge({required EdgeInsets padding, required double radius, required double fontSize}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: user.isAdmin ? const Color(0xFF00897B).withAlpha(20) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: user.isAdmin ? const Color(0xFF00897B).withAlpha(50) : Colors.grey.shade300,
        ),
      ),
      child: Text(
        user.isAdmin ? 'Admin' : 'User',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: user.isAdmin ? const Color(0xFF00897B) : Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildStatusBadge({required EdgeInsets padding, required double radius, required double fontSize}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: user.isBlocked ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        user.isBlocked ? 'Bị khóa' : 'Hoạt động',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: user.isBlocked ? Colors.red.shade700 : Colors.green.shade700,
        ),
      ),
    );
  }

  Widget _buildCurrentAdminTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isSmall) {
      return _buildMobileLayout(context);
    }
    return _buildDesktopLayout(context);
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(size: 42, fontSize: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _displayName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrentAdmin) ...[
                          const SizedBox(width: 6),
                          _buildCurrentAdminTag(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email.isNotEmpty ? user.email : 'Chưa có email',
                      style: TextStyle(
                        fontSize: 12,
                        color: user.email.isNotEmpty ? Colors.grey.shade600 : Colors.amber.shade900,
                        fontStyle: user.email.isEmpty ? FontStyle.italic : FontStyle.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user.phoneNumber.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'SĐT: ${user.phoneNumber}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildRoleBadge(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                radius: 6,
                fontSize: 11,
              ),
              _buildStatusBadge(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                radius: 6,
                fontSize: 11,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded, size: 11, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    user.createdAt != null
                        ? dateFormat.format(user.createdAt!)
                        : (user.updatedAt != null
                            ? dateFormat.format(user.updatedAt!)
                            : 'Chưa có ngày'),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _copyUid(context),
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fingerprint_rounded, size: 11, color: Colors.grey.shade500),
                    const SizedBox(width: 3),
                    Text(
                      'UID: ${user.uid.length > 8 ? "${user.uid.substring(0, 6)}..." : user.uid}',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.copy_rounded, size: 10, color: Colors.grey.shade500),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.send_rounded, size: 18, color: Color(0xFF00897B)),
                tooltip: 'Gửi thông báo',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
                onPressed: onSendNotification,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.holiday_village_outlined, size: 18),
                tooltip: 'Xem phòng đăng',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
                onPressed: onViewRooms,
              ),
              if (!isCurrentAdmin) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    user.isAdmin ? Icons.admin_panel_settings_rounded : Icons.admin_panel_settings_outlined,
                    size: 18,
                    color: user.isAdmin ? const Color(0xFF00897B) : Colors.grey.shade600,
                  ),
                  tooltip: user.isAdmin ? 'Hạ quyền' : 'Thăng quyền',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                  onPressed: onToggleRole,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    user.isBlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                    size: 18,
                    color: user.isBlocked ? Colors.green.shade700 : Colors.red.shade600,
                  ),
                  tooltip: user.isBlocked ? 'Mở khóa' : 'Khóa tài khoản',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                  onPressed: onToggleBlock,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          _buildAvatar(size: 44, fontSize: 15),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    if (isCurrentAdmin) ...[
                      const SizedBox(width: 8),
                      _buildCurrentAdminTag(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  user.email.isNotEmpty ? user.email : 'Chưa có email',
                  style: TextStyle(
                    fontSize: 12,
                    color: user.email.isNotEmpty ? Colors.grey.shade600 : Colors.amber.shade900,
                    fontStyle: user.email.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                if (user.phoneNumber.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'SĐT: ${user.phoneNumber}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => _copyUid(context),
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
          _buildRoleBadge(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            radius: 8,
            fontSize: 12,
          ),
          const SizedBox(width: 16),
          _buildStatusBadge(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            radius: 8,
            fontSize: 12,
          ),
          const SizedBox(width: 16),
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Gửi thông báo riêng cho người này',
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, size: 18, color: Color(0xFF00897B)),
                  onPressed: onSendNotification,
                ),
              ),
              Tooltip(
                message: 'Xem các phòng do user này đăng',
                child: IconButton(
                  icon: const Icon(Icons.holiday_village_outlined, size: 20),
                  onPressed: onViewRooms,
                ),
              ),
              if (!isCurrentAdmin)
                Tooltip(
                  message: user.isAdmin ? 'Hạ quyền xuống User' : 'Thăng quyền lên Admin',
                  child: IconButton(
                    icon: Icon(
                      user.isAdmin ? Icons.admin_panel_settings_rounded : Icons.admin_panel_settings_outlined,
                      size: 20,
                      color: user.isAdmin ? const Color(0xFF00897B) : Colors.grey.shade600,
                    ),
                    onPressed: onToggleRole,
                  ),
                ),
              if (!isCurrentAdmin)
                Tooltip(
                  message: user.isBlocked ? 'Mở khóa tài khoản' : 'Khóa tài khoản này',
                  child: IconButton(
                    icon: Icon(
                      user.isBlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                      size: 20,
                      color: user.isBlocked ? Colors.green.shade700 : Colors.red.shade600,
                    ),
                    onPressed: onToggleBlock,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
