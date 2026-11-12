import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Widget hiển thị ảnh đa năng: hỗ trợ cả URL mạng (http/https) và ảnh Base64 (data:image)
class AppImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AppImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();

    if (cleanUrl.isEmpty) {
      return _buildErrorWidget();
    }

    // 1. Ảnh dạng Base64 data URI (tải từ máy hoặc paste base64)
    if (cleanUrl.startsWith('data:image')) {
      try {
        final commaIndex = cleanUrl.indexOf(',');
        final base64Data = commaIndex != -1
            ? cleanUrl.substring(commaIndex + 1)
            : cleanUrl;
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, _, _) => _buildErrorWidget(),
        );
      } catch (_) {
        return _buildErrorWidget();
      }
    }

    // 2. Ảnh từ URL mạng (http / https)
    return Image.network(
      cleanUrl,
      fit: fit,
      width: width,
      height: height,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return placeholder ??
            Container(
              width: width,
              height: height,
              color: Colors.grey.shade100,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                    color: const Color(0xFF00897B),
                  ),
                ),
              ),
            );
      },
      errorBuilder: (_, _, _) => _buildErrorWidget(),
    );
  }

  Widget _buildErrorWidget() {
    return errorWidget ??
        Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.grey,
              size: 28,
            ),
          ),
        );
  }

  /// Tiện ích nén và thu nhỏ ảnh bytes để lưu vào Firestore vừa vặn (< 80KB)
  static Future<Uint8List> compressImage(
    Uint8List rawBytes, {
    int targetWidth = 600,
  }) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(rawBytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final codec = await descriptor.instantiateCodec(targetWidth: targetWidth);
      final frame = await codec.getNextFrame();
      final byteData =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (_) {
      // Nếu resize bằng ImageDescriptor lỗi, thử instantiateImageCodec cổ điển
      try {
        @pragma('vm:entry-point')
        final codec = await ui.instantiateImageCodec(
          rawBytes,
          targetWidth: targetWidth,
        );
        final frame = await codec.getNextFrame();
        final byteData =
            await frame.image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          return byteData.buffer.asUint8List();
        }
      } catch (_) {}
    }
    return rawBytes;
  }
}
