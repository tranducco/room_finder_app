import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/utils/app_validator.dart';
import '../../data/auth_service.dart';
import '../widgets/app_button_style.dart';
import '../widgets/app_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;
  final _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─────────────────────── Xử lý đăng nhập ───────────────────────
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    try {
      await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;

      final role = await _authService.getCurrentUserRole();
      if (!mounted) return;

      if (role == 'admin') {
        nav.pushReplacementNamed('/admin');
      } else {
        nav.pushReplacementNamed('/home');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final String message = switch (e.code) {
        'user-not-found' => 'Không tìm thấy tài khoản với email này!',
        'wrong-password' => 'Mật khẩu không đúng, vui lòng thử lại!',
        'invalid-credential' => 'Email hoặc mật khẩu không chính xác!',
        'too-many-requests' =>
          'Quá nhiều lần thử. Vui lòng đợi một lúc rồi thử lại!',
        'user-disabled' => 'Tài khoản này đã bị vô hiệu hóa!',
        'network-request-failed' => 'Lỗi kết nối mạng, vui lòng thử lại!',
        _ => 'Đã xảy ra lỗi: ${e.message ?? e.code}',
      };
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            msg.contains('bị khóa')
                ? 'Tài khoản của bạn đã bị khóa bởi Quản trị viên!'
                : 'Đã xảy ra lỗi: $msg',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────── Hỗ trợ người dùng ───────────────────────
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: Color(0xFF00897B)),
            SizedBox(width: 10),
            Text(
              'Hỗ trợ Đăng nhập',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nếu bạn gặp sự cố khi đăng nhập vào hệ thống Trọ Tốt:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              Icons.email_outlined,
              'Email hỗ trợ',
              'support@trotot.vn',
            ),
            const SizedBox(height: 8),
            _buildHelpItem(
              Icons.phone_in_talk_outlined,
              'Hotline CSKH',
              '1900 6868 (8:00 - 21:00)',
            ),
            const SizedBox(height: 8),
            _buildHelpItem(
              Icons.lock_reset_outlined,
              'Quên mật khẩu?',
              'Nhấn "Quên mật khẩu" tại màn hình đăng nhập để nhận liên kết khôi phục.',
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00897B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF00897B)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────── Input Decoration ───────────────────────
  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF00897B), size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  // ─────────────────────── Box Form Đăng nhập chung ───────────────────────
  Widget _buildLoginFormCard({required bool isDesktop}) {
    return Container(
      width: isDesktop ? 430 : double.infinity,
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isDesktop ? 16 : 20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDesktop ? 30 : 15),
            blurRadius: isDesktop ? 28 : 20,
            offset: Offset(0, isDesktop ? 10 : 6),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tiêu đề box đăng nhập
            Row(
              children: [
                const Text(
                  'Đăng nhập',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const Spacer(),
                if (isDesktop)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 14,
                          color: Color(0xFF00897B),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Trọ Tốt ID',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF00796B),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Chào mừng bạn đến với cộng đồng Trọ Tốt',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),

            // Email Field
            TextFormField(
              controller: _emailController,
              validator: AppValidator.validateEmail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                label: 'Email',
                hint: 'example@gmail.com',
                icon: Icons.email_outlined,
              ),
            ),
            const SizedBox(height: 16),

            // Password Field
            TextFormField(
              controller: _passwordController,
              validator: AppValidator.validatePassword,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleLogin(),
              decoration: _inputDecoration(
                label: 'Mật khẩu',
                hint: '••••••••',
                icon: Icons.lock_outline,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Duy trì đăng nhập & Quên mật khẩu
            Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: (val) =>
                        setState(() => _rememberMe = val ?? true),
                    activeColor: const Color(0xFF00897B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  child: Text(
                    'Duy trì đăng nhập',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/forgot-password'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Quên mật khẩu?',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF00897B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Nút Đăng nhập
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: AppButtonStyle.primary(hoverElevation: 4),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'ĐĂNG NHẬP',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Phân cách HOẶC
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'HOẶC',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),

            const SizedBox(height: 20),

            // Link chuyển sang Đăng ký
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isDesktop ? 'Bạn mới biết đến Trọ Tốt? ' : 'Chưa có tài khoản? ',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                HoverWidget(
                  onTap: () => Navigator.pushNamed(context, '/register'),
                  builder: (context, isHovered) => Text(
                    'Đăng ký ngay',
                    style: TextStyle(
                      fontSize: 13,
                      color: isHovered
                          ? const Color(0xFF004D40)
                          : const Color(0xFF00897B),
                      fontWeight: FontWeight.bold,
                      decoration: isHovered
                          ? TextDecoration.underline
                          : TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────── Giao diện Desktop/Laptop (2 cột như Shopee) ───────────────────────
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── TOP HEADER TRẮNG NHƯ SHOPEE ──
            Container(
              height: 84,
              padding: const EdgeInsets.symmetric(horizontal: 48),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Row(
                    children: [
                      // Logo TroTot bo tròn
                      const AppLogo(
                        size: 46,
                        isCircle: true,
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Trọ Tốt',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF00897B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        height: 28,
                        width: 1.5,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Đăng nhập',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF212121),
                        ),
                      ),
                      const Spacer(),
                      // Link trợ giúp
                      TextButton.icon(
                        onPressed: _showHelpDialog,
                        icon: const Icon(
                          Icons.help_outline_rounded,
                          size: 18,
                          color: Color(0xFF00897B),
                        ),
                        label: const Text(
                          'Bạn cần giúp đỡ?',
                          style: TextStyle(
                            color: Color(0xFF00897B),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── KHU VỰC CHÍNH: BANNER MÀU THƯƠNG HIỆU + 2 CỘT (NHƯ SHOPEE) ──
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF00897B),
                    Color(0xFF00695C),
                    Color(0xFF004D40),
                  ],
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 56,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // CỘT TRÁI: LOGO, LỜI CHÀO, SLOGAN, BADGES
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 48),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Logo bo tròn nổi bật
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      clipBehavior: Clip.antiAlias,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(50),
                                            blurRadius: 20,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: const AppLogo(
                                        size: 64,
                                        isCircle: true,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Trọ Tốt',
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        Text(
                                          'NỀN TẢNG PHÒNG TRỌ THÔNG MINH',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF80CBC4),
                                            letterSpacing: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),

                                // Slogan lớn phong cách Shopee Sale / Chiến dịch
                                const Text(
                                  'TÌM PHÒNG NHANH CHÓNG\nAN TÂM LỰA CHỌN',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.25,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Hệ sinh thái kết nối trực tiếp chủ nhà và người thuê, tích hợp Chatbot AI tư vấn thông minh 24/7.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.white.withAlpha(235),
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 28),

                                // Các thẻ tính năng nổi bật (tương tự huy hiệu Shopee)
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _buildFeaturePill(
                                      icon: Icons.auto_awesome,
                                      title: 'Trợ lý AI Gemini',
                                      subtitle: 'Tư vấn tìm phòng 24/7',
                                      color: const Color(0xFFFFB300),
                                    ),
                                    _buildFeaturePill(
                                      icon: Icons.verified,
                                      title: '100% Đã duyệt',
                                      subtitle: 'Tin đăng xác thực',
                                      color: const Color(0xFF64FFDA),
                                    ),
                                    _buildFeaturePill(
                                      icon: Icons.calendar_month_rounded,
                                      title: 'Đặt lịch online',
                                      subtitle: 'Xem phòng trực tiếp',
                                      color: const Color(0xFFFF8A80),
                                    ),
                                    _buildFeaturePill(
                                      icon: Icons.rate_review_rounded,
                                      title: 'Review thực tế',
                                      subtitle: 'Đánh giá minh bạch',
                                      color: const Color(0xFF80D8FF),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // CỘT PHẢI: BOX ĐĂNG NHẬP
                        _buildLoginFormCard(isDesktop: true),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── FOOTER DƯỚI ĐÁY ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 32),
              color: const Color(0xFFFAFAFA),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFooterLink('CHÍNH SÁCH BẢO MẬT'),
                          _buildFooterDivider(),
                          _buildFooterLink('ĐIỀU KHOẢN DỊCH VỤ'),
                          _buildFooterDivider(),
                          _buildFooterLink('QUY CHẾ HOẠT ĐỘNG'),
                          _buildFooterDivider(),
                          _buildFooterLink('HỖ TRỢ KHÁCH HÀNG'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '© 2026 Trọ Tốt - Ứng dụng tìm kiếm và cho thuê phòng trọ tích hợp Chatbot AI.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePill({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withAlpha(200),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
      ),
    );
  }

  Widget _buildFooterDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        '|',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
      ),
    );
  }

  // ─────────────────────── Giao diện Mobile App (giữ nguyên & tối ưu) ───────────────────────
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header logo có bo góc
                Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    padding: const EdgeInsets.all(12),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00897B).withAlpha(45),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const AppLogo(
                      size: 66,
                      isCircle: true,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Trọ Tốt',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF00897B),
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Chào mừng trở lại!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Đăng nhập để tiếp tục tìm phòng trọ',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Card form đăng nhập
                _buildLoginFormCard(isDesktop: false),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────── Hàm Build chính (Responsive) ───────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Màn hình laptop / web lớn (>= 850px) chia 2 bên như Shopee
        // Màn hình mobile / tablet nhỏ (< 850px) giữ nguyên bố cục app
        final isDesktop = constraints.maxWidth >= 850;
        if (isDesktop) {
          return _buildDesktopLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }
}
