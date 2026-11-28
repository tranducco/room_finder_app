import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/package_service.dart';
import '../../domain/models/package_order.dart';
import '../../domain/models/package_plan.dart';
import '../../domain/models/room.dart';

class PaymentProcessingScreen extends StatefulWidget {
  final String orderId;
  final PackagePlan package;
  final Room room;
  final String? payUrl;
  final String? qrCodeUrl;
  final String? deeplink;

  const PaymentProcessingScreen({
    super.key,
    required this.orderId,
    required this.package,
    required this.room,
    this.payUrl,
    this.qrCodeUrl,
    this.deeplink,
  });

  @override
  State<PaymentProcessingScreen> createState() => _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends State<PaymentProcessingScreen> {
  final PackageService _packageService = PackageService();

  int _remainingSeconds = 15 * 60; // 15 phút đếm ngược
  Timer? _countdownTimer;
  bool _isCheckingStatus = false;
  StreamSubscription<PackageOrder?>? _orderSubscription;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _listenOrderRealtime();

    // Tự động mở link thanh toán MoMo ngay khi vào màn hình
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openMoMo();
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        _onPaymentTimeout();
      }
    });
  }

  void _listenOrderRealtime() {
    _orderSubscription = _packageService.streamOrder(widget.orderId).listen((order) {
      if (!mounted || order == null) return;

      if (order.status == 'completed') {
        _countdownTimer?.cancel();
        _orderSubscription?.cancel();
        Navigator.pushReplacementNamed(
          context,
          '/payment-result',
          arguments: {
            'isSuccess': true,
            'orderId': widget.orderId,
            'package': widget.package,
            'room': widget.room,
            'paidAt': order.paidAt ?? DateTime.now(),
            'expiresAt': order.expiresAt,
            'transId': order.transactionId,
          },
        );
      } else if (order.status == 'failed' || order.status == 'cancelled') {
        _countdownTimer?.cancel();
        _orderSubscription?.cancel();
        Navigator.pushReplacementNamed(
          context,
          '/payment-result',
          arguments: {
            'isSuccess': false,
            'orderId': widget.orderId,
            'package': widget.package,
            'room': widget.room,
            'errorMessage': order.note ?? 'Giao dịch MoMo không thành công hoặc đã bị hủy.',
          },
        );
      }
    });
  }

  Future<void> _openMoMo() async {
    final payUrl = widget.payUrl ?? '';
    final deeplink = widget.deeplink ?? '';

    // Trên trình duyệt Web luôn ưu tiên HTTPS payUrl; trên Mobile ưu tiên deeplink
    final targetUrl = kIsWeb
        ? (payUrl.isNotEmpty ? payUrl : deeplink)
        : (deeplink.isNotEmpty ? deeplink : payUrl);

    if (targetUrl.isEmpty) return;

    try {
      final uri = Uri.parse(targetUrl);
      if (kIsWeb) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
      } else if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (payUrl.isNotEmpty) {
        await launchUrl(Uri.parse(payUrl), mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _manualCheckStatus() async {
    setState(() => _isCheckingStatus = true);

    try {
      final result = await _packageService.checkPaymentStatus(widget.orderId);
      if (!mounted) return;
      setState(() => _isCheckingStatus = false);

      if (result['isCompleted'] == true || result['status'] == 'completed') {
        _countdownTimer?.cancel();
        _orderSubscription?.cancel();
        Navigator.pushReplacementNamed(
          context,
          '/payment-result',
          arguments: {
            'isSuccess': true,
            'orderId': widget.orderId,
            'package': widget.package,
            'room': widget.room,
            'paidAt': DateTime.now(),
            'expiresAt': DateTime.now().add(Duration(days: widget.package.durationDays)),
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['momoMessage'] ?? 'Hệ thống chưa nhận được tiền từ MoMo. Vui lòng hoàn tất thanh toán trên MoMo.',
            ),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingStatus = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi kiểm tra trạng thái: $e')),
      );
    }
  }

  void _onPaymentTimeout() {
    Navigator.pushReplacementNamed(
      context,
      '/payment-result',
      arguments: {
        'isSuccess': false,
        'orderId': widget.orderId,
        'package': widget.package,
        'room': widget.room,
        'errorMessage': 'Đơn hàng đã hết thời gian chờ thanh toán (15 phút).',
      },
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _orderSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _confirmCancelPayment();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('Thanh Toán MoMo'),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _confirmCancelPayment,
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 48 : 20,
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── THÔNG BÁO ĐANG CHỜ THANH TOÁN ───
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFCE4EC),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFD82D8B), width: 2),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Color(0xFFD82D8B),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Đang chờ thanh toán MoMo',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Mã đơn hàng: ${widget.orderId}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_outlined, color: Colors.red.shade700, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Thời gian còn lại: $minutes:$seconds',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── THÔNG TIN ĐƠN HÀNG ───
                  Container(
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
                          'Chi tiết đơn hàng',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildRow('Gói dịch vụ:', widget.package.name),
                        _buildRow('Thời hạn:', '${widget.package.durationDays} ngày'),
                        _buildRow('Phòng áp dụng:', widget.room.title),
                        _buildRow(
                          'Số tiền cần thanh toán:',
                          currencyFormatter.format(widget.package.price),
                          isHighlight: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── NÚT MỞ ỨNG DỤNG MOMO ───
                  ElevatedButton.icon(
                    onPressed: _openMoMo,
                    icon: const Icon(Icons.open_in_new_rounded, size: 20),
                    label: const Text(
                      'Mở ứng dụng MoMo / Web để thanh toán',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD82D8B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ─── NÚT KIỂM TRA LẠI KẾT QUẢ THỦ CÔNG ───
                  OutlinedButton.icon(
                    onPressed: _isCheckingStatus ? null : _manualCheckStatus,
                    icon: _isCheckingStatus
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00897B)),
                          )
                        : const Icon(Icons.sync_rounded, size: 20),
                    label: Text(
                      _isCheckingStatus
                          ? 'Đang kiểm tra từ MoMo...'
                          : 'Tôi đã thanh toán – Kiểm tra kết quả ngay',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00695C),
                      side: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── HƯỚNG DẪN BẰNG 3 BƯỚC ĐƠN GIẢN ───
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1).withAlpha(120),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFB2DFDB)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hướng dẫn thanh toán MoMo Sandbox / Thật:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF004D40),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '1. Bấm nút "Mở MoMo để thanh toán" ở trên.\n'
                          '2. Xác nhận thanh toán số tiền hiển thị trên cổng MoMo.\n'
                          '3. Khi giao dịch thành công, hệ thống TroTot sẽ tự động nhận diện trong 1–3 giây và kích hoạt gói cho phòng trọ của bạn.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF004D40),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Nút hủy
                  Center(
                    child: TextButton(
                      onPressed: _confirmCancelPayment,
                      child: const Text(
                        'Hủy giao dịch này',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13.5)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isHighlight ? 16 : 13.5,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
                color: isHighlight ? const Color(0xFFD82D8B) : const Color(0xFF1A1A2E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancelPayment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy thanh toán?'),
        content: const Text(
          'Bạn có chắc chắn muốn hủy giao dịch mua gói này không? Đơn hàng sẽ bị hủy trên hệ thống.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tiếp tục thanh toán'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hủy giao dịch'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.pop(context);
    }
  }
}
