/// Tập trung toàn bộ logic validate dữ liệu đầu vào phía Client.
/// Dùng với TextFormField(validator: ...) trong Flutter Form.
class AppValidator {
  AppValidator._(); // Ngăn khởi tạo instance - chỉ dùng static methods

  // ─────────────────────── EMAIL ───────────────────────
  /// Chỉ chấp nhận đúng định dạng @gmail.com (không chấp nhận @yahoo, @hotmail, v.v.)
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập email';
    }
    // Regex: phần local + bắt buộc kết thúc @gmail.com
    final regex = RegExp(r'^[a-zA-Z0-9._%+\-]+@gmail\.com$');
    if (!regex.hasMatch(value.trim())) {
      return 'Email phải có định dạng @gmail.com';
    }
    return null;
  }

  // ─────────────────────── MẬT KHẨU ───────────────────────
  /// Mật khẩu mạnh: ≥8 ký tự, ≥1 chữ HOA, ≥1 chữ số, ≥1 ký tự đặc biệt (!@#\$%^&*)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    if (value.length < 8) {
      return 'Mật khẩu phải có ít nhất 8 ký tự';
    }
    // Kiểm tra có ít nhất 1 chữ hoa
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Mật khẩu phải chứa ít nhất 1 chữ cái viết hoa';
    }
    // Kiểm tra có ít nhất 1 chữ số
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Mật khẩu phải chứa ít nhất 1 chữ số';
    }
    // Kiểm tra có ít nhất 1 ký tự đặc biệt trong tập !@#$%^&*
    if (!RegExp(r'[!@#\$%^&*]').hasMatch(value)) {
      return 'Mật khẩu phải chứa ít nhất 1 ký tự đặc biệt (!@#\$%^&*)';
    }
    return null;
  }

  // ─────────────────────── XÁC NHẬN MẬT KHẨU ───────────────────────
  /// Kiểm tra mật khẩu xác nhận khớp với mật khẩu gốc
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng xác nhận mật khẩu';
    }
    if (value != password) {
      return 'Mật khẩu xác nhận không khớp';
    }
    return null;
  }

  // ─────────────────────── HỌ TÊN ───────────────────────
  /// Họ tên không được bỏ trống, tối thiểu 2 ký tự
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập họ tên';
    }
    if (value.trim().length < 2) {
      return 'Họ tên phải có ít nhất 2 ký tự';
    }
    return null;
  }

  // ─────────────────────── SỐ ĐIỆN THOẠI ───────────────────────
  /// Số điện thoại Việt Nam: 10 chữ số, bắt đầu bằng 0
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập số điện thoại';
    }
    // Regex: bắt đầu bằng 0, tiếp theo là 9 chữ số (tổng 10 số)
    final regex = RegExp(r'^0[0-9]{9}$');
    if (!regex.hasMatch(value.trim())) {
      return 'Số điện thoại không hợp lệ (10 chữ số, bắt đầu bằng 0)';
    }
    return null;
  }
}

