import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/admin_service.dart';
import '../../../data/room_service.dart';
import '../../../domain/models/report.dart';
import '../../widgets/app_button_style.dart';
import '../widgets/admin_room_detail_dialog.dart';

class AdminReportsTab extends StatefulWidget {
  const AdminReportsTab({super.key});

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab> {
  final AdminService _adminService = AdminService();
  final RoomService _roomService = RoomService();

  List<Report> _allReports = [];
  List<Report> _filteredReports = [];
  bool _isLoading = true;

  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final reports = await _adminService.getAllReports();
      if (mounted) {
        setState(() {
          _allReports = reports;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredReports = _allReports.where((r) {
        if (_selectedStatus == 'all') return true;
        return r.status == _selectedStatus;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tiếp nhận & Xử lý Báo cáo vi phạm',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kiểm tra phản ánh từ người dùng về tin phòng trọ gian lận, sai lệch hoặc vi phạm tiêu chuẩn cộng đồng',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _loadReports,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Làm mới'),
                  style: AppButtonStyle.primary(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Filter Chips
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Text(
                    'Trạng thái báo cáo: ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                  _statusChip('all', 'Tất cả (${_allReports.length})'),
                  const SizedBox(width: 8),
                  _statusChip(
                    'pending',
                    'Chờ xử lý (${_countStatus('pending')})',
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(width: 8),
                  _statusChip(
                    'resolved',
                    'Đã giải quyết (${_countStatus('resolved')})',
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  _statusChip(
                    'dismissed',
                    'Đã bác bỏ (${_countStatus('dismissed')})',
                    color: Colors.grey.shade700,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Content
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Color(0xFF00897B)),
                ),
              )
            else if (_filteredReports.isEmpty)
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
                    Icon(Icons.shield_rounded, size: 48, color: Colors.green.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'Không có báo cáo vi phạm nào trong mục này',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tất cả phản ánh vi phạm đã được xử lý triệt để.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredReports.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (ctx, index) {
                  final report = _filteredReports[index];
                  final isPending = report.status == 'pending';

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isPending
                            ? Colors.red.shade200
                            : Colors.grey.shade200,
                        width: isPending ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isPending
                              ? Colors.red.withAlpha(15)
                              : Colors.black.withAlpha(5),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isPending
                                    ? Colors.red.shade50
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.report_problem_rounded,
                                color: isPending
                                    ? Colors.red.shade700
                                    : Colors.grey.shade600,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        report.reason,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1A1A2E),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      _badgeForStatus(report.status),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tin phòng: ${report.roomTitle.isNotEmpty ? report.roomTitle : report.roomId}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF00897B),
                                    ),
                                  ),
                                  Text(
                                    'Người gửi: ${report.reporterEmail} • Lúc: ${report.createdAt != null ? dateFormat.format(report.createdAt!) : "Chưa rõ"}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 12),

                        // Description
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            report.description.isNotEmpty
                                ? report.description
                                : 'Không có mô tả chi tiết kèm theo.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade800,
                              height: 1.4,
                            ),
                          ),
                        ),

                        if (report.adminNote != null &&
                            report.adminNote!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Ghi chú của Admin: ${report.adminNote}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.blueGrey.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],

                        // Action Buttons if pending
                        if (isPending) ...[
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _viewReportedRoom(report.roomId),
                                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                label: const Text('Xem phòng bị tố cáo'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                              const SizedBox(width: 10),
                              TextButton.icon(
                                onPressed: () => _dismissReport(report),
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: const Text('Bác bỏ tố cáo'),
                                style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () => _resolveReport(report),
                                icon: const Icon(Icons.shield_rounded, size: 16),
                                label: const Text('Gỡ tin & Giải quyết'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  int _countStatus(String s) => _allReports.where((r) => r.status == s).length;

  Widget _statusChip(String key, String label, {Color? color}) {
    final isSelected = _selectedStatus == key;
    final chipColor = color ?? const Color(0xFF00897B);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedStatus = key);
          _applyFilters();
        }
      },
      selectedColor: chipColor.withAlpha(30),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? chipColor : Colors.grey.shade700,
      ),
    );
  }

  Widget _badgeForStatus(String s) {
    Color bg;
    Color fg;
    String text;

    switch (s) {
      case 'resolved':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        text = 'Đã giải quyết';
        break;
      case 'dismissed':
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        text = 'Đã bác bỏ';
        break;
      case 'pending':
      default:
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        text = 'Chờ xử lý';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  void _viewReportedRoom(String roomId) async {
    try {
      final rooms = await _roomService.getRooms();
      final room = rooms.firstWhere(
        (r) => r.roomId == roomId,
        orElse: () => throw Exception('Không tìm thấy phòng trọ này trong hệ thống.'),
      );

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AdminRoomDetailDialog(
          room: room,
          onApprove: () async {
            await _roomService.approveRoom(room.roomId, 'admin');
            _loadReports();
          },
          onReject: (reason) async {
            await _roomService.rejectRoom(room.roomId, 'admin', reason);
            _loadReports();
          },
          onHide: () async {
            await _roomService.hideRoom(room.roomId);
            _loadReports();
          },
          onRestore: () async {
            await _roomService.restoreRoom(room.roomId);
            _loadReports();
          },
          onDelete: () async {
            await _roomService.deleteRoom(room.roomId);
            _loadReports();
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  Future<void> _resolveReport(Report report) async {
    final noteController = TextEditingController();
    bool hideRoom = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Giải quyết báo cáo vi phạm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Xác nhận xử lý vi phạm cho tin đăng "${report.roomTitle}"?'),
              const SizedBox(height: 14),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tự động ẩn tin đăng này khỏi sàn (Chuyển sang Tạm ẩn)'),
                value: hideRoom,
                onChanged: (val) {
                  setDialogState(() => hideRoom = val ?? true);
                },
                activeColor: Colors.red.shade700,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú xử lý của Quản trị viên',
                  hintText: 'Ví dụ: Đã kiểm tra thực tế và xác nhận tin đăng không đúng giá...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Xác nhận giải quyết'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _adminService.resolveReport(
        reportId: report.id,
        roomId: report.roomId,
        hideRoom: hideRoom,
        adminNote: noteController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Đã giải quyết báo cáo vi phạm thành công!')),
      );
      _loadReports();
    }
  }

  Future<void> _dismissReport(Report report) async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bác bỏ báo cáo vi phạm?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Báo cáo sẽ được chuyển sang trạng thái "Đã bác bỏ" do không đủ căn cứ vi phạm.'),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Lý do bác bỏ (Tùy chọn)',
                hintText: 'Ví dụ: Thông tin phòng đã được kiểm chứng chính xác...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppButtonStyle.primary(),
            child: const Text('Bác bỏ'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _adminService.dismissReport(
        reportId: report.id,
        adminNote: noteController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ℹ️ Đã bác bỏ báo cáo vi phạm.')),
      );
      _loadReports();
    }
  }
}
