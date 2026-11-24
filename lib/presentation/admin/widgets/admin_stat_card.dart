import 'package:flutter/material.dart';

class AdminStatCard extends StatefulWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const AdminStatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  State<AdminStatCard> createState() => _AdminStatCardState();
}

class _AdminStatCardState extends State<AdminStatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 720;

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
          padding: EdgeInsets.all(isSmall ? 12 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? widget.color.withAlpha(120) : Colors.grey.shade200,
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered ? widget.color.withAlpha(35) : Colors.black.withAlpha(8),
                blurRadius: _isHovered ? 16 : 10,
                offset: Offset(0, _isHovered ? 6 : 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: isSmall ? 11 : 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                        letterSpacing: isSmall ? 0.1 : 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: EdgeInsets.all(isSmall ? 6 : 10),
                    decoration: BoxDecoration(
                      color: widget.color.withAlpha(25),
                      borderRadius: BorderRadius.circular(isSmall ? 8 : 12),
                    ),
                    child: Icon(
                      widget.icon,
                      size: isSmall ? 16 : 22,
                      color: widget.color,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isSmall ? 6 : 14),
              Text(
                widget.value,
                style: TextStyle(
                  fontSize: isSmall ? 22 : 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              if (widget.subtitle != null) ...[
                SizedBox(height: isSmall ? 2 : 6),
                Text(
                  widget.subtitle!,
                  style: TextStyle(
                    fontSize: isSmall ? 10.5 : 12,
                    fontWeight: FontWeight.w500,
                    color: widget.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

