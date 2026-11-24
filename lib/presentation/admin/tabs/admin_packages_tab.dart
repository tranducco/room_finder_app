import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/package_service.dart';
import '../../../domain/models/package_order.dart';
import '../../../domain/models/package_plan.dart';
import '../../../domain/models/room_promotion.dart';
import '../widgets/admin_stat_card.dart';

class AdminPackagesTab extends StatefulWidget {
  const AdminPackagesTab({super.key});

  @override
  State<AdminPackagesTab> createState() => _AdminPackagesTabState();
}

class _AdminPackagesTabState extends State<AdminPackagesTab> with SingleTickerProviderStateMixin {
  final PackageService _packageService = PackageService();
  late final TabController _tabController;

  String _statusFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  Map<String, dynamic> _revenueStats = {
    'totalRevenue': 0.0,
    'completedOrders': 0,
    'goldCount': 0,
    'silverCount': 0,
    'bronzeCount': 0,
  };
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _packageService.getRevenueStats();
    if (mounted) {
      setState(() {
        _revenueStats = stats;
        _isLoadingStats = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── 1. HEADER & THỐNG KÊ DOANH THU THỰC TẾ ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quản lý Gói VIP & Doanh thu MoMo',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Thống kê giao dịch thực tế đã xác minh phía server và đối soát đơn hàng',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _isLoadingStats
                      ? null
                      : () async {
                          setState(() => _isLoadingStats = true);
                          await _loadStats();
                        },
                  icon: _isLoadingStats
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(_isLoadingStats ? 'Đang tải...' : 'Làm mới số liệu'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // STAT CARDS
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 260,
                  child: AdminStatCard(
                    title: 'Doanh thu đã xác minh',
                    value: currencyFormatter.format(_revenueStats['totalRevenue'] ?? 0),
                    icon: Icons.monetization_on_rounded,
                    color: const Color(0xFF2E7D32),
                    subtitle: 'Từ cổng MoMo IPN',
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: AdminStatCard(
                    title: 'Đơn hàng thành công',
                    value: '${_revenueStats['completedOrders'] ?? 0}',
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF00897B),
                    subtitle: 'Đã kích hoạt tin VIP',
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: AdminStatCard(
                    title: 'Gói Vàng (69.000đ)',
                    value: '${_revenueStats['goldCount'] ?? 0} đơn',
                    icon: Icons.workspace_premium_rounded,
                    color: const Color(0xFFFFA000),
                    subtitle: 'Ưu tiên hạng 3',
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: AdminStatCard(
                    title: 'Bạc & Đồng',
                    value: '${_revenueStats['silverCount'] ?? 0} Bạc • ${_revenueStats['bronzeCount'] ?? 0} Đồng',
                    icon: Icons.shield_rounded,
                    color: const Color(0xFF78909C),
                    subtitle: 'Hạng 2 & Hạng 1',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ─── 2. SUB-TABS ───
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF00897B),
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: const Color(0xFF00897B),
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(text: 'Tất cả Đơn hàng & Giao dịch', icon: Icon(Icons.receipt_long_rounded, size: 20)),
                      Tab(text: 'Gói đang áp dụng (Phòng trọ)', icon: Icon(Icons.bolt_rounded, size: 20)),
                      Tab(text: 'Bảng cấu hình gói', icon: Icon(Icons.settings_suggest_rounded, size: 20)),
                    ],
                  ),
                  SizedBox(
                    height: 600,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOrdersSubTab(currencyFormatter),
                        _buildPromotionsSubTab(),
                        _buildPlansConfigSubTab(currencyFormatter),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SUB-TAB 1: TẤT CẢ ĐƠN HÀNG & GIAO DỊCH ───
  Widget _buildOrdersSubTab(NumberFormat currencyFormatter) {
    return Column(
      children: [
        // Filter bar & Search
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm theo Mã đơn hàng, Phòng, User ID...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _statusFilter,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tất cả trạng thái')),
                  DropdownMenuItem(value: 'completed', child: Text('🟢 Thành công')),
                  DropdownMenuItem(value: 'pending', child: Text('🟡 Chờ thanh toán')),
                  DropdownMenuItem(value: 'failed', child: Text('🔴 Thất bại / Hủy')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _statusFilter = val);
                },
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Stream danh sách đơn hàng
        Expanded(
          child: StreamBuilder<List<PackageOrder>>(
            stream: _packageService.getAllOrders(statusFilter: _statusFilter),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF00897B)));
              }

              var orders = snapshot.data ?? [];

              if (_searchQuery.isNotEmpty) {
                orders = orders.where((o) {
                  return o.orderId.toLowerCase().contains(_searchQuery) ||
                      o.roomTitle.toLowerCase().contains(_searchQuery) ||
                      o.userId.toLowerCase().contains(_searchQuery) ||
                      (o.transactionId?.toLowerCase().contains(_searchQuery) ?? false);
                }).toList();
              }

              if (orders.isEmpty) {
                return const Center(
                  child: Text('Không tìm thấy đơn hàng nào phù hợp bộ lọc.'),
                );
              }

              return ListView.separated(
                itemCount: orders.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return _buildOrderListTile(order, currencyFormatter);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrderListTile(PackageOrder order, NumberFormat currencyFormatter) {
    Color statusColor;
    String statusLabel;

    if (order.status == 'completed') {
      statusColor = Colors.green;
      statusLabel = 'Thành công';
    } else if (order.status == 'pending') {
      statusColor = Colors.orange;
      statusLabel = 'Chờ thanh toán';
    } else {
      statusColor = Colors.red;
      statusLabel = 'Thất bại';
    }

    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt);

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFFCE4EC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Text(
            'MoMo',
            style: TextStyle(
              color: Color(0xFFD82D8B),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Text(
            order.orderId,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, fontFamily: 'monospace'),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(25),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      subtitle: Text(
        'Phòng: ${order.roomTitle} • Gói: ${order.packageName} • Ngày: $dateStr\n'
        'Người mua: ${order.userId} • GD MoMo: ${order.transactionId ?? "Chưa có"}',
        style: const TextStyle(fontSize: 12, height: 1.35),
      ),
      trailing: Text(
        currencyFormatter.format(order.amount),
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1A1A2E)),
      ),
      isThreeLine: true,
      onTap: () => _showOrderDetailDialog(order, currencyFormatter),
    );
  }

  void _showOrderDetailDialog(PackageOrder order, NumberFormat currencyFormatter) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Chi tiết đơn hàng: ${order.orderId}'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Mã đơn hàng:', order.orderId),
              _detailRow('Người mua (User ID):', order.userId),
              _detailRow('Phòng áp dụng:', order.roomTitle),
              _detailRow('ID Phòng:', order.roomId),
              _detailRow('Gói đăng tin:', '${order.packageName} (Ưu tiên ${order.priority})'),
              _detailRow('Thời hạn:', '${order.durationDays} ngày'),
              _detailRow('Số tiền thanh toán:', currencyFormatter.format(order.amount)),
              _detailRow('Trạng thái:', order.status.toUpperCase()),
              _detailRow('Cổng thanh toán:', order.paymentMethod.toUpperCase()),
              _detailRow('Mã GD MoMo (transId):', order.transactionId ?? 'Chưa phát sinh'),
              if (order.paidAt != null)
                _detailRow('Thời điểm thanh toán:', DateFormat('dd/MM/yyyy HH:mm:ss').format(order.paidAt!)),
              if (order.expiresAt != null)
                _detailRow('Thời điểm hết hạn:', DateFormat('dd/MM/yyyy HH:mm:ss').format(order.expiresAt!)),
              if (order.note != null && order.note!.isNotEmpty)
                _detailRow('Ghi chú lỗi:', order.note!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 180, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }

  // ─── SUB-TAB 2: GÓI ĐANG ÁP DỤNG TRÊN PHÒNG TRỌ ───
  Widget _buildPromotionsSubTab() {
    return StreamBuilder<List<RoomPromotion>>(
      stream: _packageService.getAllPromotions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00897B)));
        }

        final promotions = snapshot.data ?? [];

        if (promotions.isEmpty) {
          return const Center(child: Text('Chưa có gói xúc tiến nào được kích hoạt.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: promotions.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final promo = promotions[index];
            final isActive = promo.isActive;
            final expiryFormatted = DateFormat('dd/MM/yyyy HH:mm').format(promo.expiresAt);

            return ListTile(
              leading: Icon(
                promo.packageId == 'gold'
                    ? Icons.workspace_premium_rounded
                    : (promo.packageId == 'silver' ? Icons.shield_rounded : Icons.military_tech_rounded),
                color: promo.packageId == 'gold'
                    ? Colors.amber.shade800
                    : (promo.packageId == 'silver' ? Colors.blueGrey : const Color(0xFFCD7F32)),
                size: 32,
              ),
              title: Row(
                children: [
                  Text(
                    'Phòng: ${promo.roomId}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.shade50 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isActive ? 'Đang hoạt động (còn ${promo.remainingDays}d)' : 'Đã hết hạn',
                      style: TextStyle(
                        color: isActive ? Colors.green.shade800 : Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                'Gói: ${promo.packageName} (Ưu tiên ${promo.priority}) • Chủ phòng: ${promo.ownerId}\n'
                'Thời hạn: Đến hết ngày $expiryFormatted • Đơn hàng cuối: ${promo.lastOrderId}',
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
            );
          },
        );
      },
    );
  }

  // ─── SUB-TAB 3: BẢNG CẤU HÌNH GÓI ───
  Widget _buildPlansConfigSubTab(NumberFormat currencyFormatter) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Cấu hình 3 gói tiêu chuẩn (TroTot Rules)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await _packageService.seedDefaultPlans();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã đồng bộ 3 gói mặc định lên Firestore!')),
                    );
                  }
                },
                icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                label: const Text('Đồng bộ lên Firestore'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...PackagePlan.defaultPlans.map((plan) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: plan.id == 'gold'
                          ? Colors.amber.shade100
                          : (plan.id == 'silver' ? Colors.grey.shade200 : const Color(0xFFFBE9E7)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        plan.badgeText,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          color: plan.id == 'gold'
                              ? Colors.amber.shade900
                              : (plan.id == 'silver' ? Colors.blueGrey.shade800 : const Color(0xFFCD7F32)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${plan.name} – Priority ${plan.priority}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          'Thời hạn: ${plan.durationDays} ngày • ${plan.description}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    currencyFormatter.format(plan.price),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF00897B)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
