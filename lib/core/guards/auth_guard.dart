import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../presentation/auth/login_screen.dart';

/// AuthGuard – tiện ích kiểm tra đăng nhập & hiển thị yêu cầu đăng nhập
/// cho các tính năng bị hạn chế khi dùng chế độ khách (guest).
class AuthGuard {
  AuthGuard._();

  /// Kiểm tra người dùng đã đăng nhập chưa
  static bool isLoggedIn() => FirebaseAuth.instance.currentUser != null;

  /// Hiển thị bottom sheet yêu cầu đăng nhập.
  /// - [featureName] : tên tính năng bị hạn chế (vd: "Đặt lịch xem phòng")
  /// - Trả về true nếu người dùng đã đăng nhập, false nếu chưa (và bottom sheet đã được hiện)
  static bool requireLogin(
    BuildContext context, {
    String featureName = 'tính năng này',
  }) {
    if (isLoggedIn()) return true;
    _showLoginBottomSheet(context, featureName: featureName);
    return false;
  }

  static void _showLoginBottomSheet(
    BuildContext context, {
    required String featureName,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LoginRequiredSheet(featureName: featureName),
    );
  }
}

class _LoginRequiredSheet extends StatelessWidget {
  final String featureName;
  const _LoginRequiredSheet({required this.featureName});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00897B), Color(0xFF00695C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00897B).withAlpha(60),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),

          // Title
          const Text(
            'Yêu cầu đăng nhập',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 10),

          // Subtitle
          Text(
            'Bạn cần đăng nhập để sử dụng\n"$featureName".',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // Đăng nhập button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              icon: const Icon(Icons.login_rounded),
              label: const Text(
                'ĐĂNG NHẬP NGAY',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tiếp tục xem
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Tiếp tục xem',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
