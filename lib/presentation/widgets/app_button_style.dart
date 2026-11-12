import 'package:flutter/material.dart';

/// Các style nút và widget hỗ trợ hover cho ứng dụng Trọ Tốt
class AppButtonStyle {
  /// Kiểu nút chính (Primary) - tự động đổi màu sẫm hơn và tăng độ nổi khi hover
  static ButtonStyle primary({
    Color baseColor = const Color(0xFF00897B),
    Color hoverColor = const Color(0xFF00695C),
    Color textColor = Colors.white,
    double borderRadius = 12,
    double elevation = 0,
    double hoverElevation = 3,
    EdgeInsetsGeometry? padding,
  }) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.grey.shade300;
        }
        if (states.contains(WidgetState.pressed)) {
          return const Color(0xFF004D40);
        }
        if (states.contains(WidgetState.hovered)) {
          return hoverColor;
        }
        return baseColor;
      }),
      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.grey.shade500;
        }
        return textColor;
      }),
      elevation: WidgetStateProperty.resolveWith<double>((states) {
        if (states.contains(WidgetState.hovered)) {
          return hoverElevation;
        }
        return elevation;
      }),
      shadowColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.hovered)) {
          return hoverColor.withAlpha(90);
        }
        return Colors.black.withAlpha(20);
      }),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
      padding: padding != null ? WidgetStateProperty.all(padding) : null,
    );
  }

  /// Kiểu nút viền (Outlined) - đổi màu viền và thêm màu nền nhạt khi hover
  static ButtonStyle outlined({
    Color color = const Color(0xFF00897B),
    Color hoverColor = const Color(0xFF00695C),
    double borderRadius = 12,
    EdgeInsetsGeometry? padding,
  }) {
    return ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.hovered)) return hoverColor;
        return color;
      }),
      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.hovered)) return color.withAlpha(25);
        return Colors.transparent;
      }),
      side: WidgetStateProperty.resolveWith<BorderSide>((states) {
        if (states.contains(WidgetState.hovered)) {
          return BorderSide(color: hoverColor, width: 1.5);
        }
        return BorderSide(color: color, width: 1.0);
      }),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
      padding: padding != null ? WidgetStateProperty.all(padding) : null,
    );
  }

  /// Kiểu nút chữ (Text Button) - thêm màu nền nhẹ khi hover
  static ButtonStyle text({
    Color color = const Color(0xFF00897B),
    Color hoverColor = const Color(0xFF004D40),
    double borderRadius = 8,
  }) {
    return ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.hovered)) return hoverColor;
        return color;
      }),
      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.hovered)) return color.withAlpha(25);
        return Colors.transparent;
      }),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
    );
  }
}

/// Widget tiện ích bọc các phần tử để tạo hiệu ứng hover mượt mà
class HoverWidget extends StatefulWidget {
  final Widget Function(BuildContext context, bool isHovered) builder;
  final VoidCallback? onTap;
  final MouseCursor cursor;

  const HoverWidget({
    super.key,
    required this.builder,
    this.onTap,
    this.cursor = SystemMouseCursors.click,
  });

  @override
  State<HoverWidget> createState() => _HoverWidgetState();
}

class _HoverWidgetState extends State<HoverWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: widget.builder(context, _isHovered),
      ),
    );
  }
}
