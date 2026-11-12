import 'package:flutter/material.dart';

/// Widget hiển thị Logo chính thức của ứng dụng Trọ Tốt
class AppLogo extends StatelessWidget {
  final double size;
  final bool showBackground;
  final BorderRadius? borderRadius;

  const AppLogo({
    super.key,
    this.size = 48,
    this.showBackground = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final imageWidget = Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Image.network(
        'logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF00897B),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.home_rounded,
            color: Colors.white,
            size: size * 0.6,
          ),
        ),
      ),
    );

    if (!showBackground) {
      return imageWidget;
    }

    return Container(
      width: size + 16,
      height: size + 16,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: imageWidget,
    );
  }
}
