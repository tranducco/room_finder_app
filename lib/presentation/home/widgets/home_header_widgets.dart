import 'package:flutter/material.dart';

import '../../widgets/app_button_style.dart';

/// Circular header action button with optional notification badge.
class HomeNotificationBellButton extends StatelessWidget {
  final int notificationCount;
  final VoidCallback onTap;

  const HomeNotificationBellButton({
    super.key,
    required this.notificationCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Thông báo',
      child: HoverWidget(
        onTap: onTap,
        builder: (context, isHovered) {
          final isDesk = MediaQuery.of(context).size.width >= 1024;
          final btnSize = isDesk ? 40.0 : 36.0;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: btnSize,
            height: btnSize,
            transform: Matrix4.translationValues(0, isHovered ? -2 : 0, 0),
            decoration: BoxDecoration(
              color: isHovered
                  ? Colors.white.withAlpha(55)
                  : Colors.white.withAlpha(25),
              shape: BoxShape.circle,
              border: Border.all(
                color: isHovered ? Colors.white : Colors.white.withAlpha(70),
                width: isHovered ? 1.5 : 1.0,
              ),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.notifications_outlined, color: Colors.white, size: isDesk ? 20 : 18),
                if (notificationCount > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '$notificationCount',
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Circular header icon button shared across mobile & desktop home headers.
class HomeHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const HomeHeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: HoverWidget(
        onTap: onTap,
        builder: (context, isHovered) {
          final isDesk = MediaQuery.of(context).size.width >= 1024;
          final btnSize = isDesk ? 40.0 : 36.0;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: btnSize,
            height: btnSize,
            transform: Matrix4.translationValues(0, isHovered ? -2 : 0, 0),
            decoration: BoxDecoration(
              color: isHovered
                  ? Colors.white.withAlpha(55)
                  : Colors.white.withAlpha(25),
              shape: BoxShape.circle,
              border: Border.all(
                color: isHovered ? Colors.white : Colors.white.withAlpha(70),
                width: isHovered ? 1.5 : 1.0,
              ),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Icon(icon, color: Colors.white, size: isDesk ? 20 : 18),
          );
        },
      ),
    );
  }
}

/// Translucent summary pill shown inside the home hero header.
class HomeStatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const HomeStatChip(
    this.icon,
    this.label, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Removable active filter tag chip shown above the room list.
class HomeActiveFilterTag extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const HomeActiveFilterTag(
    this.label,
    this.onRemove, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF00897B))),
      deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFF00897B)),
      onDeleted: onRemove,
      backgroundColor: const Color(0xFF00897B).withAlpha(20),
      side: BorderSide(color: const Color(0xFF00897B).withAlpha(60)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
