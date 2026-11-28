import 'package:flutter/material.dart';

import '../../../domain/models/room.dart';
import '../../widgets/app_button_style.dart';
import '../../widgets/app_image.dart';

class RoomGalleryWidget extends StatefulWidget {
  final Room room;
  final List<String> images;
  final void Function(List<String> images, int startIndex) onOpenImageViewer;

  const RoomGalleryWidget({
    super.key,
    required this.room,
    required this.images,
    required this.onOpenImageViewer,
  });

  @override
  State<RoomGalleryWidget> createState() => _RoomGalleryWidgetState();
}

class _RoomGalleryWidgetState extends State<RoomGalleryWidget> {
  int _currentImageIndex = 0;
  late final PageController _pageController;
  late final ScrollController _thumbnailScrollController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _thumbnailScrollController = ScrollController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    super.dispose();
  }

  void _goToImage(int index) {
    setState(() => _currentImageIndex = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    _scrollThumbnailTo(index);
  }

  void _scrollThumbnailTo(int index) {
    const thumbWidth = 98.0;
    final targetOffset = index * thumbWidth;
    if (_thumbnailScrollController.hasClients) {
      _thumbnailScrollController.animateTo(
        targetOffset.clamp(
          0.0,
          _thumbnailScrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    if (images.isEmpty) {
      return Container(
        height: 260,
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 768;
    final galleryHeight = isDesktop ? 460.0 : 320.0;

    return Column(
      children: [
        // Main image with left/right arrows
        Container(
          height: galleryHeight,
          margin: isDesktop ? const EdgeInsets.fromLTRB(16, 12, 16, 0) : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: isDesktop ? BorderRadius.circular(16) : BorderRadius.zero,
            boxShadow: isDesktop
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // PageView for swipe
              PageView.builder(
                controller: _pageController,
                itemCount: images.length,
                onPageChanged: (idx) {
                  setState(() => _currentImageIndex = idx);
                  _scrollThumbnailTo(idx);
                },
                itemBuilder: (context, index) {
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => widget.onOpenImageViewer(images, index),
                      child: Container(
                        color: const Color(0xFF18181B),
                        child: Center(
                          child: AppImage(
                            imageUrl: images[index],
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Left navigation arrow
              if (images.length > 1)
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: HoverWidget(
                      onTap: () {
                        if (_currentImageIndex > 0) {
                          _goToImage(_currentImageIndex - 1);
                        } else {
                          _goToImage(images.length - 1);
                        }
                      },
                      builder: (context, isHovered) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isHovered
                              ? Colors.black.withAlpha(190)
                              : Colors.black.withAlpha(120),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isHovered
                                ? Colors.white.withAlpha(220)
                                : Colors.white.withAlpha(90),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(40),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),

              // Right navigation arrow
              if (images.length > 1)
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: HoverWidget(
                      onTap: () {
                        if (_currentImageIndex < images.length - 1) {
                          _goToImage(_currentImageIndex + 1);
                        } else {
                          _goToImage(0);
                        }
                      },
                      builder: (context, isHovered) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isHovered
                              ? Colors.black.withAlpha(190)
                              : Colors.black.withAlpha(120),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isHovered
                                ? Colors.white.withAlpha(220)
                                : Colors.white.withAlpha(90),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(40),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),

              // Zoom hint badge
              Positioned(
                bottom: 12,
                left: 14,
                child: HoverWidget(
                  onTap: () => widget.onOpenImageViewer(images, _currentImageIndex),
                  builder: (context, isHovered) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isHovered
                          ? const Color(0xFF00897B).withAlpha(230)
                          : Colors.black.withAlpha(140),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withAlpha(isHovered ? 180 : 80),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 5),
                        Text(
                          'Xem toàn màn hình',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Counter badge
              Positioned(
                bottom: 12,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(150),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_library_outlined, color: Colors.white, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        '${_currentImageIndex + 1} / ${images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Room type badge top-left
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00695C),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(30),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.room.roomType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Thumbnail strip
        if (images.length > 1)
          Container(
            height: 90,
            margin: isDesktop ? const EdgeInsets.fromLTRB(16, 8, 16, 0) : EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isDesktop ? Colors.grey.shade50 : Colors.grey.shade100,
              borderRadius: isDesktop ? BorderRadius.circular(12) : BorderRadius.zero,
            ),
            child: ListView.builder(
              controller: _thumbnailScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final isSelected = index == _currentImageIndex;
                return HoverWidget(
                  onTap: () => _goToImage(index),
                  builder: (context, isHovered) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 90,
                    margin: const EdgeInsets.only(right: 8),
                    transform: Matrix4.translationValues(0, isHovered ? -2 : 0, 0),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF00897B)
                            : (isHovered ? const Color(0xFF26A69A) : Colors.transparent),
                        width: isSelected ? 2.8 : (isHovered ? 2.0 : 1.0),
                      ),
                      boxShadow: isSelected || isHovered
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00897B).withAlpha(isHovered ? 60 : 40),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AppImage(
                            imageUrl: images[index],
                            fit: BoxFit.cover,
                          ),
                          if (!isSelected && !isHovered)
                            Container(
                              color: Colors.black.withAlpha(40),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
