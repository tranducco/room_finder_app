import 'package:flutter/material.dart';

/// Widget hiển thị Logo chính thức của ứng dụng Trọ Tốt (mặc định bo tròn hoàn hảo)
class AppLogo extends StatelessWidget {
  final double size;
  final bool showBackground;
  final bool isCircle;
  final BorderRadius? borderRadius;

  const AppLogo({
    super.key,
    this.size = 48,
    this.showBackground = false,
    this.isCircle = true,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Image.network(
        'logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF00897B),
            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isCircle ? null : borderRadius,
          ),
          child: Icon(
            Icons.home_rounded,
            color: Colors.white,
            size: size * 0.6,
          ),
        ),
      ),
    );

    if (isCircle) {
      imageWidget = ClipOval(child: imageWidget);
    } else if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    if (!showBackground) {
      return imageWidget;
    }

    return Container(
      width: size + 16,
      height: size + 16,
      padding: const EdgeInsets.all(8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : borderRadius?.add(BorderRadius.circular(4)),
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
