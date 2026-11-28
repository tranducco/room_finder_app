import 'package:flutter/material.dart';

class HomePaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const HomePaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Tạo danh sách trang hiển thị (tối đa 7 nút, dùng dấu ... nếu nhiều)
    List<int?> pages = [];
    if (totalPages <= 7) {
      pages = List.generate(totalPages, (i) => i);
    } else {
      pages.add(0);
      if (currentPage > 2) pages.add(null);
      for (int i = (currentPage - 1).clamp(1, totalPages - 2);
          i <= (currentPage + 1).clamp(1, totalPages - 2);
          i++) {
        pages.add(i);
      }
      if (currentPage < totalPages - 3) pages.add(null);
      pages.add(totalPages - 1);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PageBtn(
              label: null,
              icon: Icons.chevron_left_rounded,
              isEnabled: currentPage > 0,
              isSelected: false,
              onTap: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
            ),
            const SizedBox(width: 4),
            ...pages.map((p) {
              if (p == null) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('...', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _PageBtn(
                  label: '${p + 1}',
                  icon: null,
                  isEnabled: true,
                  isSelected: p == currentPage,
                  onTap: () => onPageChanged(p),
                ),
              );
            }),
            const SizedBox(width: 4),
            _PageBtn(
              label: null,
              icon: Icons.chevron_right_rounded,
              isEnabled: currentPage < totalPages - 1,
              isSelected: false,
              onTap: currentPage < totalPages - 1 ? () => onPageChanged(currentPage + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PageBtn extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final bool isEnabled;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PageBtn({
    required this.label,
    required this.icon,
    required this.isEnabled,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_PageBtn> createState() => _PageBtnState();
}

class _PageBtnState extends State<_PageBtn> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected;
    final enabled = widget.isEnabled;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (enabled) setState(() => _isHovered = true);
      },
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 36,
          height: 36,
          transform: Matrix4.translationValues(0, _isHovered && !active ? -2 : 0, 0),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF00897B)
                : _isHovered
                    ? const Color(0xFFE0F2F1)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? const Color(0xFF00897B)
                  : _isHovered
                      ? const Color(0xFF00897B)
                      : Colors.grey.shade300,
            ),
            boxShadow: _isHovered && !active
                ? [BoxShadow(color: const Color(0xFF00897B).withAlpha(40), blurRadius: 6, offset: const Offset(0, 2))]
                : [],
          ),
          child: Center(
            child: widget.icon != null
                ? Icon(
                    widget.icon,
                    size: 18,
                    color: !enabled
                        ? Colors.grey.shade300
                        : active || _isHovered
                            ? const Color(0xFF00897B)
                            : Colors.grey.shade600,
                  )
                : Text(
                    widget.label!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.bold : FontWeight.w500,
                      color: active
                          ? Colors.white
                          : _isHovered
                              ? const Color(0xFF00897B)
                              : Colors.grey.shade700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
