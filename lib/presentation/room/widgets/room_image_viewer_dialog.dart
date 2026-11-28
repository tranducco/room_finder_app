import 'package:flutter/material.dart';

import '../../widgets/app_image.dart';

// ======================================================
// FULL-SCREEN IMAGE VIEWER DIALOG
// ======================================================
class RoomImageViewerDialog extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const RoomImageViewerDialog({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<RoomImageViewerDialog> createState() => _RoomImageViewerDialogState();
}

class _RoomImageViewerDialogState extends State<RoomImageViewerDialog> {
  late int _current;
  late PageController _pageCtrl;
  late ScrollController _thumbCtrl;
  late List<TransformationController> _transformControllers;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    _thumbCtrl = ScrollController();
    _transformControllers = List.generate(
      widget.images.length,
      (_) => TransformationController(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollThumbTo(_current);
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _thumbCtrl.dispose();
    for (final c in _transformControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.images.length) return;
    setState(() => _current = index);
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _scrollThumbTo(index);
  }

  void _scrollThumbTo(int index) {
    if (!_thumbCtrl.hasClients) return;
    const thumbW = 72.0;
    final target = (index * thumbW).clamp(
      0.0,
      _thumbCtrl.position.maxScrollExtent,
    );
    _thumbCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _resetZoom(int index) {
    _transformControllers[index].value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final isFirst = _current == 0;
    final isLast = _current == images.length - 1;

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // ---- Main zoomable PageView ----
          PageView.builder(
            controller: _pageCtrl,
            itemCount: images.length,
            onPageChanged: (i) {
              setState(() => _current = i);
              _scrollThumbTo(i);
            },
            itemBuilder: (ctx, index) {
              return GestureDetector(
                onDoubleTapDown: (details) {
                  final controller = _transformControllers[index];
                  if (controller.value != Matrix4.identity()) {
                    controller.value = Matrix4.identity();
                  } else {
                    final pos = details.localPosition;
                    const scale = 2.5;
                    controller.value = Matrix4.identity()
                      ..translateByDouble(-pos.dx * (scale - 1), -pos.dy * (scale - 1), 0.0, 0.0)
                      ..scaleByDouble(scale, scale, 1.0, 1.0);
                  }
                },
                child: InteractiveViewer(
                  transformationController: _transformControllers[index],
                  panEnabled: true,
                  scaleEnabled: true,
                  minScale: 1.0,
                  maxScale: 5.0,
                  child: Center(
                    child: AppImage(
                      imageUrl: images[index],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),

          // ---- Top bar: counter + close ----
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 8,
                bottom: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(160),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(120),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.photo_library_outlined,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_current + 1} / ${images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(140),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---- Hint: double-tap to zoom ----
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: 0.7,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(80),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Chạm 2 lần để phóng to • Kéo để thu nhỏ',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
              ),
            ),
          ),

          // ---- Left arrow ----
          if (!isFirst)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    _resetZoom(_current);
                    _goTo(_current - 1);
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(120),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withAlpha(60),
                      ),
                    ),
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),

          // ---- Right arrow ----
          if (!isLast)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    _resetZoom(_current);
                    _goTo(_current + 1);
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(120),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withAlpha(60),
                      ),
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),

          // ---- Bottom thumbnail strip ----
          if (images.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom,
              left: 0,
              right: 0,
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withAlpha(200),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                child: ListView.builder(
                  controller: _thumbCtrl,
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  itemBuilder: (ctx, index) {
                    final isSel = index == _current;
                    return GestureDetector(
                      onTap: () {
                        _resetZoom(_current);
                        _goTo(index);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 64,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSel
                                ? const Color(0xFF26A69A)
                                : Colors.white.withAlpha(60),
                            width: isSel ? 2.5 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Opacity(
                            opacity: isSel ? 1.0 : 0.55,
                            child: AppImage(
                              imageUrl: images[index],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
