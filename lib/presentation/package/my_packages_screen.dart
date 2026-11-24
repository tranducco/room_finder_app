import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/package_service.dart';
import '../../domain/models/package_order.dart';
import '../../domain/models/package_plan.dart';
import '../../domain/models/room_promotion.dart';

class MyPackagesScreen extends StatefulWidget {
  const MyPackagesScreen({super.key});

  @override
  State<MyPackagesScreen> createState() => _MyPackagesScreenState();
}

class _MyPackagesScreenState extends State<MyPackagesScreen> with SingleTickerProviderStateMixin {
  final PackageService _packageService = PackageService();
  late final TabController _tabController;

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
    final user = FirebaseAuth.instance.currentUser;
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gói Của Tôi')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Vui lòng đăng nhập để xem thông tin gói'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: const Text('Đăng nhập ngay'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Quản Lý Gói Đăng Tin'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Bảng giá các gói',
            icon: const Icon(Icons.add_shopping_cart_rounded),
            onPressed: () => Navigator.pushNamed(context, '/packages'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF00897B),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF00897B),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Gói đang áp dụng', icon: Icon(Icons.verified_rounded, size: 20)),
            Tab(text: 'Lịch sử mua gói', icon: Icon(Icons.receipt_long_rounded, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActivePromotionsTab(user.uid),
          _buildOrderHistoryTab(user.uid, currencyFormatter),
        ],
      ),
    );
  }

  Widget _buildActivePromotionsTab(String userId) {
    return StreamBuilder<List<RoomPromotion>>(
      stream: _packageService.getMyPromotions(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00897B)));
        }

        final promotions = snapshot.data ?? [];

        if (promotions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
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
                    child: Icon(Icons.star_border_rounded, size: 40, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có phòng nào được kích hoạt gói VIP',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đăng ký gói Đồng, Bạc hoặc Vàng để đưa tin đăng của bạn lên đỉnh tìm kiếm!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/packages'),
                    icon: const Icon(Icons.bolt_rounded),
                    label: const Text('Xem Bảng Giá Gói VIP'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: promotions.length,
          itemBuilder: (context, index) {
            final promo = promotions[index];
            return _buildActivePromotionCard(promo);
          },
        );
      },
    );
  }

  Widget _buildActivePromotionCard(RoomPromotion promo) {
    final isGold = promo.packageId == 'gold';
    final isSilver = promo.packageId == 'silver';
    final badgeColor = isGold
        ? const Color(0xFFFFA000)
        : (isSilver ? const Color(0xFF78909C) : const Color(0xFFCD7F32));

    final expiryFormatted = DateFormat('dd/MM/yyyy HH:mm').format(promo.expiresAt);
    final daysLeft = promo.remainingDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withAlpha(120), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withAlpha(20),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGold
                          ? Icons.workspace_premium_rounded
                          : (isSilver ? Icons.shield_rounded : Icons.military_tech_rounded),
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      promo.packageName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Còn $daysLeft ngày',
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Phòng trọ mã: ${promo.roomId}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.event_available_rounded, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                'Hạn sử dụng: $expiryFormatted',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final plan = PackagePlan.getById(promo.packageId);
                    Navigator.pushNamed(
                      context,
                      '/order-confirmation',
                      arguments: {
                        'package': plan,
                        'preselectedRoomId': promo.roomId,
                      },
                    );
                  },
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Gia hạn gói này'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00695C),
                    side: const BorderSide(color: Color(0xFF00897B)),
                  ),
                ),
              ),
              if (!isGold) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final goldPlan = PackagePlan.getById('gold');
                      Navigator.pushNamed(
                        context,
                        '/order-confirmation',
                        arguments: {
                          'package': goldPlan,
                          'preselectedRoomId': promo.roomId,
                        },
                      );
                    },
                    icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                    label: const Text('Nâng cấp VÀNG'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFA000),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderHistoryTab(String userId, NumberFormat currencyFormatter) {
    return StreamBuilder<List<PackageOrder>>(
      stream: _packageService.getMyOrders(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00897B)));
        }

        final orders = snapshot.data ?? [];

        if (orders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('Chưa có lịch sử giao dịch nào', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _buildOrderCard(order, currencyFormatter);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(PackageOrder order, NumberFormat currencyFormatter) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (order.status == 'completed') {
      statusColor = Colors.green;
      statusText = 'Thành công';
      statusIcon = Icons.check_circle_rounded;
    } else if (order.status == 'pending') {
      statusColor = Colors.orange;
      statusText = 'Chờ thanh toán';
      statusIcon = Icons.hourglass_top_rounded;
    } else {
      statusColor = Colors.red;
      statusText = 'Thất bại / Hủy';
      statusIcon = Icons.cancel_rounded;
    }

    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.orderId,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${order.packageName} • Phòng: ${order.roomTitle}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateStr,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              Text(
                currencyFormatter.format(order.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: Color(0xFFD82D8B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
