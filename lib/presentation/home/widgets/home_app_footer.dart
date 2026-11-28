import 'package:flutter/material.dart';

import '../../widgets/app_logo.dart';

class HomeAppFooter extends StatelessWidget {
  const HomeAppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Main footer content ----
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Wrap(
              spacing: 32,
              runSpacing: 28,
              children: [
                // Cột 1: App info
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            padding: const EdgeInsets.all(4),
                            clipBehavior: Clip.antiAlias,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const AppLogo(size: 30),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Trọ Tốt',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ứng dụng tìm phòng trọ uy tín, an toàn và nhanh chóng tại Hà Nội.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: 14),
                      // App store badges
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          const _StoreBadge(
                            icon: Icons.apple,
                            label: 'App Store',
                            sublabel: 'Download on the',
                          ),
                          const _StoreBadge(
                            icon: Icons.android,
                            label: 'Google Play',
                            sublabel: 'Get it on',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Cột 2: Về chúng tôi
                const SizedBox(
                  width: 160,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Về Trọ Tốt',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      SizedBox(height: 14),
                      _FooterLink('Về chúng tôi'),
                      _FooterLink('Quy chế hoạt động'),
                      _FooterLink('Chính sách bảo mật'),
                      _FooterLink('Giải quyết tranh chấp'),
                      _FooterLink('Điều khoản sử dụng'),
                    ],
                  ),
                ),

                // Cột 3: Liên hệ & mạng xã hội
                const SizedBox(
                  width: 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Liên kết',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      SizedBox(height: 14),
                      // Social icons
                      Row(
                        children: [
                          _SocialBtn(icon: Icons.business, color: Color(0xFF0A66C2), tooltip: 'LinkedIn'),
                          SizedBox(width: 8),
                          _SocialBtn(icon: Icons.play_circle_fill, color: Color(0xFFFF0000), tooltip: 'YouTube'),
                          SizedBox(width: 8),
                          _SocialBtn(icon: Icons.facebook, color: Color(0xFF1877F2), tooltip: 'Facebook'),
                        ],
                      ),
                      SizedBox(height: 14),
                      _FooterInfoRow(Icons.email_outlined, 'trotot@gmail.com'),
                      SizedBox(height: 6),
                      _FooterInfoRow(Icons.support_agent_rounded, 'CSKH: 1900 1234 (1.000đ/phút)'),
                      SizedBox(height: 6),
                      _FooterInfoRow(
                        Icons.location_on_outlined,
                        'Tầng 5, Tòa nhà ABC,\n175 Tây Sơn, Đống Đa,\nHà Nội, Việt Nam',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ---- Bottom bar ----
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E).withAlpha(8),
              border: Border(
                top: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  '© 2025 Trọ Tốt. Đồ án tốt nghiệp - Đại học Thủy lợi.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, color: Color(0xFF00897B), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Đã đăng ký BCTT',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreBadge extends StatefulWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  const _StoreBadge({required this.icon, required this.label, required this.sublabel});
  @override
  State<_StoreBadge> createState() => _StoreBadgeState();
}

class _StoreBadgeState extends State<_StoreBadge> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _hovered ? const Color(0xFF1A1A2E).withAlpha(230) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(8),
          boxShadow: _hovered
              ? [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.sublabel, style: const TextStyle(color: Colors.white70, fontSize: 9)),
                Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterLink extends StatefulWidget {
  final String label;
  const _FooterLink(this.label);
  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: TextStyle(
            fontSize: 13,
            color: _hovered ? const Color(0xFF00897B) : Colors.grey.shade600,
            fontWeight: _hovered ? FontWeight.w500 : FontWeight.normal,
            decoration: _hovered ? TextDecoration.underline : TextDecoration.none,
            decorationColor: const Color(0xFF00897B),
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

class _SocialBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  const _SocialBtn({required this.icon, required this.color, required this.tooltip});
  @override
  State<_SocialBtn> createState() => _SocialBtnState();
}

class _SocialBtnState extends State<_SocialBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 36,
          height: 36,
          transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: _hovered ? widget.color : widget.color.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: widget.color.withAlpha(_hovered ? 0 : 60)),
            boxShadow: _hovered
                ? [BoxShadow(color: widget.color.withAlpha(60), blurRadius: 8, offset: const Offset(0, 3))]
                : [],
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: _hovered ? Colors.white : widget.color,
          ),
        ),
      ),
    );
  }
}

class _FooterInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FooterInfoRow(this.icon, this.text);
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF00897B)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, height: 1.4),
          ),
        ),
      ],
    );
  }
}
