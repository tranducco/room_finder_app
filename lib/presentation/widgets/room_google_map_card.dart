import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'room_map_embed_stub.dart'
    if (dart.library.js_interop) 'room_map_embed_web.dart' as map_embed;

/// Thẻ hiển thị Google Maps theo địa chỉ phòng trọ, kèm các nút Sao chép, Mở Google Maps và Chỉ đường.
class RoomGoogleMapCard extends StatelessWidget {
  final String address;
  final String ward;
  final String district;

  const RoomGoogleMapCard({
    super.key,
    required this.address,
    this.ward = '',
    this.district = '',
  });

  /// Ghép địa chỉ đầy đủ tại Hà Nội mà không bị lặp phân đoạn phường/quận/thành phố.
  static String buildFullAddress({
    required String address,
    String ward = '',
    String district = '',
  }) {
    final parts = <String>[];
    final seenSegments = <String>{};

    void addPart(String raw) {
      final cleaned = raw.trim();
      if (cleaned.isEmpty) return;

      final segments = cleaned
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();

      final lower = cleaned.toLowerCase();
      final alreadyExists = seenSegments.contains(lower) ||
          seenSegments.contains('phường $lower') ||
          seenSegments.contains('quận $lower') ||
          seenSegments.contains('huyện $lower') ||
          (segments.length == 1 &&
              seenSegments.any(
                (seg) =>
                    seg == lower ||
                    seg == 'phường $lower' ||
                    seg == 'quận $lower' ||
                    seg == 'huyện $lower',
              ));

      if (alreadyExists) return;
      parts.add(cleaned);
      seenSegments.addAll(segments);
    }

    addPart(address);
    addPart(ward);
    addPart(district);
    final hasHanoi = seenSegments.any(
      (seg) => seg.contains('hà nội') || seg.contains('ha noi'),
    );
    if (!hasHanoi) {
      parts.add('Hà Nội');
    }
    return parts.join(', ');
  }

  /// URL nhúng Google Maps iframe theo địa chỉ.
  static Uri buildEmbedUrl(String fullAddress) {
    final encoded = Uri.encodeComponent(fullAddress);
    return Uri.parse(
      'https://maps.google.com/maps?q=$encoded&t=&z=16&ie=UTF8&iwloc=&output=embed',
    );
  }

  /// URL mở Google Maps xem vị trí.
  static Uri buildSearchUrl(String fullAddress) {
    final encoded = Uri.encodeComponent(fullAddress);
    return Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
  }

  /// URL mở Google Maps chỉ đường đến phòng trọ.
  static Uri buildDirectionsUrl(String fullAddress) {
    final encoded = Uri.encodeComponent(fullAddress);
    return Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$encoded');
  }

  Future<void> _launchExternalMap(BuildContext context, Uri url) async {
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể mở Google Maps trên thiết bị này.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullAddress = buildFullAddress(
      address: address,
      ward: ward,
      district: district,
    );
    final embedUrl = buildEmbedUrl(fullAddress).toString();
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.map_rounded,
                  color: Color(0xFF00897B),
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Bản đồ vị trí',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const Spacer(),
              if (district.trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00897B).withAlpha(18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    district.trim(),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00695C),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            fullAddress,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: isDesktop ? 320 : 230,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: map_embed.buildRoomMapEmbed(
                embedUrl: embedUrl,
                fullAddress: fullAddress,
                district: district,
                onOpenMap: () => _launchExternalMap(context, buildSearchUrl(fullAddress)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: fullAddress));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã sao chép địa chỉ!'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Sao chép'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00695C),
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _launchExternalMap(context, buildSearchUrl(fullAddress)),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Mở Google Maps'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00897B),
                  side: const BorderSide(color: Color(0xFF00897B)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    _launchExternalMap(context, buildDirectionsUrl(fullAddress)),
                icon: const Icon(Icons.directions_rounded, size: 16),
                label: const Text('Chỉ đường'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
