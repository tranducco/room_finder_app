import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../data/admin_service.dart';
import '../../../data/room_service.dart';
import '../../../domain/models/report.dart';
import '../../../domain/models/room.dart';
import '../widgets/admin_room_detail_dialog.dart';
import '../widgets/admin_stat_card.dart';

class AdminOverviewTab extends StatefulWidget {
  final Function(int tabIndex, {String? statusFilter}) onNavigateToTab;

  const AdminOverviewTab({super.key, required this.onNavigateToTab});

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  final AdminService _adminService = AdminService();
  final RoomService _roomService = RoomService();

  bool _isLoading = true;
  AdminDashboardStats? _stats;
  List<Room> _pendingRooms = [];
  List<Report> _pendingReports = [];

  @override
  void initState() {
    super.initState();
    _loadOverviewData();
  }

  Future<void> _loadOverviewData() async {
    setState(() => _isLoading = true);
    try {
      final statsFuture = _adminService.getDashboardStats();
      final roomsFuture = _roomService.getRooms();
      final reportsFuture = _adminService.getAllReports();

      final results = await Future.wait([statsFuture, roomsFuture, reportsFuture]);
      final stats = results[0] as AdminDashboardStats;
      final allRooms = results[1] as List<Room>;
      final allReports = results[2] as List<Report>;

      final pendingR = allRooms.where((r) => r.status == 'pending_approval').toList();
      final pendingRep = allReports.where((r) => r.status == 'pending').toList();

      if (mounted) {
        setState(() {
          _stats = stats;
          _pendingRooms = pendingR;
          _pendingReports = pendingRep;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF00897B)),
            SizedBox(height: 16),
            Text(
              'Đang tải dữ liệu thống kê hệ thống...',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
          ],
        ),
      );
    }

    final stats = _stats;
    final isSmall = MediaQuery.of(context).size.width < 720;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmall ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng quan hệ thống',
                      style: TextStyle(
                        fontSize: isSmall ? 18 : 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Báo cáo và các chỉ số vận hành thời gian thực của sàn Trọ Tốt',
                      style: TextStyle(fontSize: isSmall ? 12 : 13, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              isSmall
                  ? IconButton.filled(
                      onPressed: _loadOverviewData,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFF00897B)),
                    )
                  : ElevatedButton.icon(
                      onPressed: _loadOverviewData,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Làm mới số liệu'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
            ],
          ),

          SizedBox(height: isSmall ? 14 : 24),

          // KPI Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isSmallScreen = width < 640;
              final crossAxisCount = isSmallScreen
                  ? 2
                  : (width < 960 ? 2 : (width < 1280 ? 3 : 4));
              final childAspectRatio = isSmallScreen ? 1.35 : 1.8;

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: isSmallScreen ? 10 : 16,
                mainAxisSpacing: isSmallScreen ? 10 : 16,
                childAspectRatio: childAspectRatio,
                children: [
                  AdminStatCard(
                    title: 'TỔNG TIN ĐĂNG PHÒNG',
                    value: '${stats?.totalRooms ?? 0}',
                    subtitle: '${stats?.availableRooms ?? 0} tin đang hoạt động',
                    icon: Icons.apartment_rounded,
                    color: const Color(0xFF00897B),
                    onTap: () => widget.onNavigateToTab(1),
                  ),
                  AdminStatCard(
                    title: 'TIN CHỜ PHÊ DUYỆT',
                    value: '${stats?.pendingRooms ?? 0}',
                    subtitle: (stats?.pendingRooms ?? 0) > 0
                        ? 'Cần quản trị viên kiểm tra'
                        : 'Không có tin chờ duyệt',
                    icon: Icons.pending_actions_rounded,
                    color: Colors.amber.shade800,
                    onTap: () => widget.onNavigateToTab(1, statusFilter: 'pending_approval'),
                  ),
                  AdminStatCard(
                    title: 'NGƯỜI DÙNG ĐĂNG KÝ',
                    value: '${stats?.totalUsers ?? 0}',
                    subtitle: '${stats?.blockedUsers ?? 0} tài khoản bị khóa',
                    icon: Icons.people_alt_rounded,
                    color: Colors.indigo.shade600,
                    onTap: () => widget.onNavigateToTab(2),
                  ),
                  AdminStatCard(
                    title: 'BÁO CÁO VI PHẠM',
                    value: '${stats?.totalReports ?? 0}',
                    subtitle: '${stats?.pendingReports ?? 0} tố cáo chờ xử lý',
                    icon: Icons.report_problem_rounded,
                    color: Colors.red.shade600,
                    onTap: () => widget.onNavigateToTab(3),
                  ),
                  AdminStatCard(
                    title: 'LỊCH HẸN XEM PHÒNG',
                    value: '${stats?.totalBookings ?? 0}',
                    subtitle: 'Lịch xem phòng của khách',
                    icon: Icons.calendar_month_rounded,
                    color: Colors.teal.shade700,
                  ),
                  AdminStatCard(
                    title: 'TƯ VẤN CHATBOT AI',
                    value: '${stats?.totalAiSessions ?? 0}',
                    subtitle: 'Phiên hội thoại Gemini AI',
                    icon: Icons.smart_toy_rounded,
                    color: const Color(0xFF004D40),
                    onTap: () => widget.onNavigateToTab(5),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 32),

          // Two Sections: Pending Rooms & Recent Reports
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _buildPendingRoomsCard(),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: _buildPendingReportsCard(),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildPendingRoomsCard(),
                    const SizedBox(height: 20),
                    _buildPendingReportsCard(),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRoomsCard() {
    final isSmall = MediaQuery.of(context).size.width < 720;
    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.hourglass_top_rounded,
                        size: 20,
                        color: Colors.amber.shade800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Tin đăng chờ duyệt gần đây',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: () => widget.onNavigateToTab(1, statusFilter: 'pending_approval'),
                child: const Text('Xem tất cả'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_pendingRooms.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 40, color: Colors.green.shade400),
                  const SizedBox(height: 10),
                  Text(
                    'Tất cả tin đăng đều đã được xử lý xong!',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pendingRooms.length.clamp(0, 5),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, index) {
                final room = _pendingRooms[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: room.images.isNotEmpty
                          ? Image.network(
                              room.images.first,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.apartment, size: 24),
                              ),
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.apartment, size: 24),
                            ),
                    ),
                  ),
                  title: Text(
                    room.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${room.district} • ${room.area}m²',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Duyệt nhanh',
                        icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF00897B)),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final admin = FirebaseAuth.instance.currentUser;
                          await _roomService.approveRoom(room.roomId, admin?.uid ?? 'admin');
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(content: Text('✅ Đã duyệt tin thành công!')),
                          );
                          _loadOverviewData();
                        },
                      ),
                      IconButton(
                        tooltip: 'Xem chi tiết',
                        icon: const Icon(Icons.remove_red_eye_outlined),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (dialogCtx) => AdminRoomDetailDialog(
                              room: room,
                              onApprove: () async {
                                final admin = FirebaseAuth.instance.currentUser;
                                await _roomService.approveRoom(room.roomId, admin?.uid ?? 'admin');
                                _loadOverviewData();
                              },
                              onReject: (reason) async {
                                final admin = FirebaseAuth.instance.currentUser;
                                await _roomService.rejectRoom(room.roomId, admin?.uid ?? 'admin', reason);
                                _loadOverviewData();
                              },
                              onHide: () async {
                                await _roomService.hideRoom(room.roomId);
                                _loadOverviewData();
                              },
                              onRestore: () async {
                                await _roomService.restoreRoom(room.roomId);
                                _loadOverviewData();
                              },
                              onDelete: () async {
                                await _roomService.deleteRoom(room.roomId);
                                _loadOverviewData();
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPendingReportsCard() {
    final isSmall = MediaQuery.of(context).size.width < 720;
    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Báo cáo vi phạm mới',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: () => widget.onNavigateToTab(3),
                child: const Text('Xem tất cả'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_pendingReports.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.shield_outlined,
                      size: 40, color: Colors.blue.shade300),
                  const SizedBox(height: 10),
                  Text(
                    'Không có báo cáo vi phạm nào cần xử lý.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pendingReports.length.clamp(0, 5),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, index) {
                final report = _pendingReports[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.flag_rounded, size: 18, color: Colors.red.shade600),
                  ),
                  title: Text(
                    report.reason,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    report.roomTitle.isNotEmpty
                        ? 'Phòng: ${report.roomTitle}'
                        : 'Mã phòng: ${report.roomId}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () => widget.onNavigateToTab(3),
                );
              },
            ),
        ],
      ),
    );
  }
}
