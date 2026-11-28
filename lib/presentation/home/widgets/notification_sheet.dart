import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/notification_service.dart';
import '../../../domain/models/app_notification.dart';

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
      onEnter: (_) {
        if (widget.onTap != null) setState(() => _hovered = true);
      },
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
