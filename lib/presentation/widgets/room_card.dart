import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/room.dart';
import 'app_image.dart';

class RoomCard extends StatefulWidget {
  final Room room;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const RoomCard({
    super.key,
    required this.room,
    required this.onTap,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  State<RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends State<RoomCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _isHovered ? -6 : 0, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered
                  ? const Color(0xFF00897B).withAlpha(120)
                  : (widget.room.isPromotedActive && widget.room.effectivePriority == 3
                      ? const Color(0xFFFFA000).withAlpha(140)
                      : Colors.grey.shade200),
              width: _isHovered ? 1.4 : (widget.room.isPromotedActive && widget.room.effectivePriority == 3 ? 1.3 : 1.0),
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF00897B).withAlpha(45),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image section
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.32,
                    child: ClipRect(
                      child: AnimatedScale(
                        scale: _isHovered ? 1.06 : 1.0,
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        child: AppImage(
                          imageUrl: widget.room.images.isNotEmpty
                              ? widget.room.images.first
                              : '',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  // Room type & VIP Package Badges
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.room.isPromotedActive) ...[
                          _buildVipBadge(widget.room),
                          const SizedBox(width: 5),
                        ],
                        if (widget.room.roomType.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF004D40).withAlpha(200),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.room.roomType,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Favorite button
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.onFavoriteToggle,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(235),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: widget.isFavorite
                                ? Colors.red
                                : Colors.grey.shade600,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Info section
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: _isHovered
                            ? const Color(0xFF00897B)
                            : const Color(0xFF1A1A2E),
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      child: Text(widget.room.title),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${currencyFormatter.format(widget.room.price)}/tháng',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF00897B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.square_foot_rounded,
                          size: 13.0,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${widget.room.area} m²',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.location_on_rounded,
                          size: 13.0,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            widget.room.district,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11.0,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVipBadge(Room room) {
    Color startColor;
    Color endColor;
    String label;
    IconData icon;

    final prio = room.effectivePriority;
    final type = room.packageType.toLowerCase();

    if (prio == 3 || type == 'gold') {
      startColor = const Color(0xFFFFB300);
      endColor = const Color(0xFFFFA000);
      label = 'VÀNG';
      icon = Icons.workspace_premium_rounded;
    } else if (prio == 2 || type == 'silver') {
      startColor = const Color(0xFF90A4AE);
      endColor = const Color(0xFF78909C);
      label = 'BẠC';
      icon = Icons.shield_rounded;
    } else {
      startColor = const Color(0xFFD7CCC8);
      endColor = const Color(0xFFCD7F32);
      label = 'ĐỒNG';
      icon = Icons.military_tech_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [startColor, endColor]),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: endColor.withAlpha(120),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
