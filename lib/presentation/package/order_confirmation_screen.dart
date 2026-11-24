import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/package_service.dart';
import '../../data/room_service.dart';
import '../../domain/models/package_plan.dart';
import '../../domain/models/room.dart';
import '../widgets/app_image.dart';

class OrderConfirmationScreen extends StatefulWidget {
  final PackagePlan package;
  final String? preselectedRoomId;

  const OrderConfirmationScreen({
    super.key,
    required this.package,
    this.preselectedRoomId,
  });

  @override
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  final RoomService _roomService = RoomService();
  final PackageService _packageService = PackageService();

  List<Room> _myRooms = [];
  Room? _selectedRoom;
  bool _isLoadingRooms = true;
  bool _isCreatingOrder = false;
  String _selectedPaymentMethod = 'momo';

  @override
  void initState() {
    super.initState();
    _loadUserRooms();
  }

  Future<void> _loadUserRooms() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingRooms = false);
      return;
    }

    try {
      final rooms = await _roomService.getMyRooms(user.uid);
      if (mounted) {
        setState(() {
          _myRooms = rooms;
          if (_myRooms.isNotEmpty) {
            if (widget.preselectedRoomId != null) {
              _selectedRoom = _myRooms.firstWhere(
                (r) => r.roomId == widget.preselectedRoomId,
                orElse: () => _myRooms.first,
              );
            } else {
              _selectedRoom = _myRooms.first;
            }
          }
          _isLoadingRooms = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRooms = false);
    }
  }

  Future<void> _processPayment() async {
    if (_selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn phòng muốn áp dụng gói!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isCreatingOrder = true);

    try {
      final result = await _packageService.createMoMoPayment(
        roomId: _selectedRoom!.roomId,
        packageId: widget.package.id,
      );

      if (!mounted) return;
      setState(() => _isCreatingOrder = false);

      final orderId = result['orderId'] as String;
      final payUrl = result['payUrl'] as String?;
      final qrCodeUrl = result['qrCodeUrl'] as String?;
      final deeplink = result['deeplink'] as String?;

      Navigator.pushReplacementNamed(
        context,
        '/payment-processing',
        arguments: {
          'orderId': orderId,
          'package': widget.package,
          'room': _selectedRoom!,
          'payUrl': payUrl,
          'qrCodeUrl': qrCodeUrl,
          'deeplink': deeplink,
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreatingOrder = false);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Không thể tạo đơn hàng'),
            ],
          ),
          content: Text(
            e.toString().replaceAll('Exception:', '').trim(),
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
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Xác Nhận Đơn Hàng'),
        elevation: 0,
      ),
      body: _isLoadingRooms
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00897B)))
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 48 : 16,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ─── 1. TÓM TẮT GÓI ĐÃ CHỌN ───
                      _buildPackageSummary(currencyFormatter),

                      const SizedBox(height: 20),

                      // ─── 2. CHỌN PHÒNG ÁP DỤNG GÓI ───
                      _buildRoomSelectorCard(),

                      const SizedBox(height: 20),

                      // ─── 3. PHƯƠNG THỨC THANH TOÁN (MOMO) ───
                      _buildPaymentMethodCard(),

                      const SizedBox(height: 20),

                      // ─── 4. CHI TIẾT HÓA ĐƠN & TỔNG TIỀN ───
                      _buildInvoiceCard(currencyFormatter),

                      const SizedBox(height: 24),

                      // ─── NÚT TIẾN HÀNH THANH TOÁN ───
                      ElevatedButton(
                        onPressed: _isCreatingOrder || _myRooms.isEmpty
                            ? null
                            : _processPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD82D8B), // MoMo pink-magenta
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                        ),
                        child: _isCreatingOrder
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Đang kết nối cổng MoMo...',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.payment_rounded, size: 22),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Thanh toán ${currencyFormatter.format(widget.package.price)} bằng MoMo',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          'Bằng việc xác nhận thanh toán, bạn đồng ý với Điều khoản dịch vụ của TroTot.',
                          style: TextStyle(color: Colors.grey, fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildPackageSummary(NumberFormat currencyFormatter) {
    final isGold = widget.package.id == 'gold';
    final isSilver = widget.package.id == 'silver';
    final badgeColor = isGold
        ? const Color(0xFFFFA000)
        : (isSilver ? const Color(0xFF78909C) : const Color(0xFFCD7F32));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withAlpha(100), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isGold
                  ? Icons.workspace_premium_rounded
                  : (isSilver ? Icons.shield_rounded : Icons.military_tech_rounded),
              color: badgeColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.package.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.package.badgeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Thời hạn: ${widget.package.durationDays} ngày • Hạng ưu tiên ${widget.package.priority}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            currencyFormatter.format(widget.package.price),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomSelectorCard() {
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
              Icon(Icons.home_work_rounded, color: Color(0xFF00897B), size: 20),
              SizedBox(width: 8),
              Text(
                'Chọn phòng áp dụng gói',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_myRooms.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                children: [
                  const Text(
                    'Bạn chưa có tin đăng phòng trọ nào để áp dụng gói.',
                    style: TextStyle(color: Color(0xFF795548), fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/create-room'),
                    icon: const Icon(Icons.add_home_rounded, size: 18),
                    label: const Text('Đăng tin phòng ngay'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Room>(
                  isExpanded: true,
                  value: _selectedRoom,
                  items: _myRooms.map((room) {
                    final hasPromo = room.isPromotedActive;
                    return DropdownMenuItem<Room>(
                      value: room,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 38,
                              height: 38,
                              child: AppImage(
                                imageUrl: room.images.isNotEmpty ? room.images.first : '',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  room.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  hasPromo
                                      ? 'Đang có gói ${room.packageType.toUpperCase()} (còn ${room.packageRemainingDays} ngày)'
                                      : '${room.district} • ${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(room.price)}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: hasPromo ? Colors.orange.shade800 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (newRoom) {
                    if (newRoom != null) {
                      setState(() => _selectedRoom = newRoom);
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Tính toán trước thời hạn sau khi mua
            if (_selectedRoom != null) _buildExpiryCalculationPreview(),
          ],
        ],
      ),
    );
  }

  Widget _buildExpiryCalculationPreview() {
    final now = DateTime.now();
    DateTime newExpiresAt;
    final currentExpires = _selectedRoom!.packageExpiresAt;
    final hasActive = _selectedRoom!.isPromotedActive && currentExpires != null;

    if (hasActive) {
      if (_selectedRoom!.priority == widget.package.priority) {
        // Cộng dồn
        newExpiresAt = currentExpires.add(Duration(days: widget.package.durationDays));
      } else {
        // Nâng cấp: tính từ hôm nay + hạn gói mới + số ngày còn lại
        final remainingDays = currentExpires.difference(now).inDays;
        newExpiresAt = now.add(Duration(days: widget.package.durationDays + (remainingDays > 0 ? remainingDays : 0)));
      }
    } else {
      newExpiresAt = now.add(Duration(days: widget.package.durationDays));
    }

    final dateStr = DateFormat('dd/MM/yyyy').format(newExpiresAt);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFAED581)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available_rounded, color: Color(0xFF558B2F), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasActive
                  ? 'Gia hạn/Nâng cấp: Thời hạn mới sẽ kéo dài đến hết ngày $dateStr.'
                  : 'Gói sẽ được kích hoạt ngay và có hiệu lực đến hết ngày $dateStr.',
              style: const TextStyle(
                color: Color(0xFF33691E),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard() {
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
              Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF00897B), size: 20),
              SizedBox(width: 8),
              Text(
                'Phương thức thanh toán',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // MoMo Gateway option
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD82D8B), width: 1.5),
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFFCE4EC).withAlpha(120),
            ),
            child: Row(
              children: [
                Radio<String>(
                  value: 'momo',
                  groupValue: _selectedPaymentMethod,
                  activeColor: const Color(0xFFD82D8B),
                  onChanged: (val) => setState(() => _selectedPaymentMethod = val!),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD82D8B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'MoMo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ví điện tử MoMo & Quét mã QR',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      Text(
                        'Thanh toán an toàn, tức thì qua MoMo App / QR Code',
                        style: TextStyle(color: Colors.grey, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Sandbox Test',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(NumberFormat currencyFormatter) {
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
          const Text(
            'Chi tiết thanh toán',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Giá gói cước (${widget.package.name}):', style: const TextStyle(fontSize: 13.5)),
              Text(
                currencyFormatter.format(widget.package.price),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Phí xử lý giao dịch MoMo:', style: TextStyle(fontSize: 13.5)),
              Text(
                '0đ (Miễn phí)',
                style: TextStyle(fontSize: 13.5, color: Colors.green, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, thickness: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tổng thanh toán:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                currencyFormatter.format(widget.package.price),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
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
