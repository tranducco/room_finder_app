import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/package_service.dart';
import '../../domain/models/package_plan.dart';

class PackagesScreen extends StatefulWidget {
  final String? preselectedRoomId;

  const PackagesScreen({super.key, this.preselectedRoomId});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  final PackageService _packageService = PackageService();
  List<PackagePlan> _plans = PackagePlan.defaultPlans;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final plans = await _packageService.getPackagePlans();
    if (mounted) {
      setState(() {
        _plans = plans;
        _isLoading = false;
      });
    }
  }

  void _onSelectPlan(PackagePlan plan) {
    Navigator.pushNamed(
      context,
      '/order-confirmation',
      arguments: {
        'package': plan,
        'preselectedRoomId': widget.preselectedRoomId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Bảng Giá Gói Đăng Tin VIP'),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/my-packages'),
            icon: const Icon(Icons.history_rounded, size: 20),
            label: const Text('Gói của tôi'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF00695C),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00897B)))
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 48 : 16,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    children: [
                      // ─── HERO HEADER ───
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00695C), Color(0xFF00897B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00695C).withAlpha(60),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withAlpha(40),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.bolt_rounded, color: Colors.amber, size: 16),
                                            SizedBox(width: 4),
                                            Text(
                                              'TỐI ĐA LƯỢT XEM',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Đẩy Tin Lên Đầu – Tìm Khách Thuê Siêu Nhanh',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tin đăng VIP được ưu tiên xuất hiện đầu trang chủ, gợi ý nổi bật cho Chatbot AI và tiếp cận gấp 4 lần người tìm trọ tại Hà Nội.',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(220),
                                      fontSize: 13.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isDesktop) ...[
                              const SizedBox(width: 24),
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(30),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.rocket_launch_rounded,
                                  color: Colors.white,
                                  size: 48,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ─── 3 GÓI ĐĂNG TIN (ĐỒNG - BẠC - VÀNG) ───
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _plans.map((plan) {
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: _buildPlanCard(plan, currencyFormatter),
                              ),
                            );
                          }).toList(),
                        )
                      else
                        Column(
                          children: _plans.map((plan) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: _buildPlanCard(plan, currencyFormatter),
                            );
                          }).toList(),
                        ),

                      const SizedBox(height: 32),

                      // ─── BẢNG SO SÁNH QUYỀN LỢI ───
                      _buildComparisonCard(),

                      const SizedBox(height: 32),

                      // ─── CHÍNH SÁCH CAM KẾT & THANH TOÁN AN TOÀN ───
                      _buildSecurityFooter(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildPlanCard(PackagePlan plan, NumberFormat currencyFormatter) {
    final isGold = plan.id == 'gold';
    final isSilver = plan.id == 'silver';

    // Màu sắc nhận diện từng gói
    Color badgeColor;
    Color gradientStart;
    Color gradientEnd;
    IconData tierIcon;

    if (isGold) {
      badgeColor = const Color(0xFFFFA000);
      gradientStart = const Color(0xFFFFF8E1);
      gradientEnd = Colors.white;
      tierIcon = Icons.workspace_premium_rounded;
    } else if (isSilver) {
      badgeColor = const Color(0xFF78909C);
      gradientStart = const Color(0xFFECEFF1);
      gradientEnd = Colors.white;
      tierIcon = Icons.shield_rounded;
    } else {
      // Bronze
      badgeColor = const Color(0xFFCD7F32);
      gradientStart = const Color(0xFFFBE9E7);
      gradientEnd = Colors.white;
      tierIcon = Icons.military_tech_rounded;
    }

    final pricePerDay = (plan.price / plan.durationDays).round();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGold
              ? const Color(0xFFFFA000)
              : (isSilver ? const Color(0xFFB0BEC5) : const Color(0xFFD7CCC8)),
          width: isGold ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isGold
                ? const Color(0xFFFFA000).withAlpha(45)
                : Colors.black.withAlpha(15),
            blurRadius: isGold ? 18 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Badge / Popular Tag
            if (isGold)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                color: const Color(0xFFFFA000),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'KHUYÊN DÙNG – HIỆU QUẢ CAO NHẤT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

            // Card Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [gradientStart, gradientEnd],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: badgeColor, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(tierIcon, color: badgeColor, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'HẠNG ${plan.priority}',
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${plan.durationDays} ngày',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    plan.name,
                    style: TextStyle(
                      color: const Color(0xFF1A1A2E),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plan.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        currencyFormatter.format(plan.price),
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '/ gói',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chỉ ~${currencyFormatter.format(pricePerDay)}/ngày',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

            // Danh sách quyền lợi
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quyền lợi gói:',
                    style: TextStyle(
                      color: Color(0xFF1A1A2E),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...plan.benefits.map((benefit) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 17,
                            color: isGold
                                ? const Color(0xFF00897B)
                                : const Color(0xFF26A69A),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              benefit,
                              style: const TextStyle(
                                color: Color(0xFF37474F),
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Nút bấm Chọn Gói
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: ElevatedButton(
                onPressed: () => _onSelectPlan(plan),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isGold
                      ? const Color(0xFFFFA000)
                      : (isSilver ? const Color(0xFF00897B) : const Color(0xFF00695C)),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: isGold ? 4 : 2,
                ),
                child: Text(
                  'Chọn ${plan.name}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.compare_arrows_rounded, color: Color(0xFF00897B)),
              SizedBox(width: 8),
              Text(
                'Quy tắc hiển thị ưu tiên',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Tin đăng trên TroTot được xếp hạng theo thứ tự minh bạch:\n'
            '1. 🥇 Tin Gói VÀNG (Priority 3) – Xuất hiện trên cùng trang chủ và bộ lọc.\n'
            '2. 🥈 Tin Gói BẠC (Priority 2) – Xuất hiện ngay sau Gói Vàng.\n'
            '3. 🥉 Tin Gói ĐỒNG (Priority 1) – Xuất hiện trên tin đăng thường.\n'
            '4. 📋 Tin đăng thường (Priority 0) – Xếp sau toàn bộ tin có gói ưu tiên.\n\n'
            '• Lưu ý: Gói chỉ có hiệu lực với các tin đăng đã được Admin phê duyệt (Available) và chưa bị ẩn/cho thuê.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF455A64),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1).withAlpha(150),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF80CBC4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_rounded, color: Color(0xFF00695C), size: 28),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Thanh toán an toàn qua Cổng MoMo chính thức. Xác minh tự động và kích hoạt gói ngay sau khi hoàn tất giao dịch. Không lưu thông tin thẻ ngân hàng trên ứng dụng.',
              style: TextStyle(
                color: Color(0xFF004D40),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
