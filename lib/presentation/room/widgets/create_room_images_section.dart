import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../widgets/app_button_style.dart';
import '../../widgets/app_image.dart';

/// Shared white rounded section container for Create / Edit Room form blocks.
class CreateRoomSectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const CreateRoomSectionCard({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// Image picker, URL importer, sample chips, and preview grid section for Create / Edit Room.
class CreateRoomImagesSection extends StatefulWidget {
  final List<String> images;
  final ValueChanged<String> onAddImage;
  final ValueChanged<int> onRemoveImage;
  final ValueChanged<bool> onPickingStateChanged;

  const CreateRoomImagesSection({
    super.key,
    required this.images,
    required this.onAddImage,
    required this.onRemoveImage,
    required this.onPickingStateChanged,
  });

  @override
  State<CreateRoomImagesSection> createState() => _CreateRoomImagesSectionState();
}

class _CreateRoomImagesSectionState extends State<CreateRoomImagesSection> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _urlController = TextEditingController();

  final List<Map<String, String>> _sampleImages = [
    {
      'name': 'Phòng ngủ',
      'url': 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800',
    },
    {
      'name': 'Phòng khách',
      'url': 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800',
    },
    {
      'name': 'Studio khép kín',
      'url': 'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800',
    },
    {
      'name': 'Căn hộ mini',
      'url': 'https://images.unsplash.com/photo-1484154218962-a197022b5858?w=800',
    },
  ];

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickFromDevice() async {
    widget.onPickingStateChanged(true);
    try {
      List<XFile> picked = [];
      try {
        // KHÔNG truyền imageQuality vì Web sẽ quăng UnsupportedError
        picked = await _picker.pickMultiImage();
      } catch (e) {
        try {
          final single = await _picker.pickImage(source: ImageSource.gallery);
          if (single != null) picked = [single];
        } catch (_) {}
      }

      if (picked.isEmpty) {
        if (mounted) widget.onPickingStateChanged(false);
        return;
      }

      int addedCount = 0;
      for (final xfile in picked) {
        final rawBytes = await xfile.readAsBytes();
        if (rawBytes.isEmpty) continue;

        final compressed = await AppImage.compressImage(
          rawBytes,
          targetWidth: 700,
        );
        final base64Str = base64Encode(compressed);
        final ext = xfile.name.split('.').last.toLowerCase();
        final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
        final dataUri = 'data:$mimeType;base64,$base64Str';

        if (mounted) {
          widget.onAddImage(dataUri);
        }
        addedCount++;
      }

      if (!mounted) return;
      if (addedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Đã thêm $addedCount ảnh từ thiết bị của bạn!'),
            backgroundColor: const Color(0xFF00897B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể chọn ảnh: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) widget.onPickingStateChanged(false);
    }
  }

  Future<void> _pasteDirectlyToField() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isNotEmpty) {
        _urlController.text = text;
        _addUrlManually(textOverride: text);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bộ nhớ đệm (Clipboard) đang trống!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể đọc clipboard: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _addUrlManually({String? textOverride}) {
    final rawText = (textOverride ?? _urlController.text).trim();
    if (rawText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập đường link ảnh hoặc dán URL!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final items = rawText
        .split(RegExp(r'[\n\r,]+'))
        .map((s) => s.trim().replaceAll('"', '').replaceAll("'", ''))
        .where((s) => s.isNotEmpty)
        .toList();

    int added = 0;
    for (final u in items) {
      if (u.startsWith('http://') ||
          u.startsWith('https://') ||
          u.startsWith('data:image')) {
        if (!widget.images.contains(u)) {
          widget.onAddImage(u);
          added++;
        }
      }
    }

    if (added > 0) {
      _urlController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Đã thêm $added ảnh thành công!'),
          backgroundColor: const Color(0xFF00897B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Link ảnh không hợp lệ (cần bắt đầu bằng http:// hoặc https://)',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _imgActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return HoverWidget(
      onTap: onTap,
      builder: (context, isHovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, isHovered ? -2 : 0, 0),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(isHovered ? 45 : 20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withAlpha(isHovered ? 180 : 80),
            width: isHovered ? 1.4 : 1.0,
          ),
          boxShadow: isHovered
              ? [
                  BoxShadow(
                    color: color.withAlpha(50),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CreateRoomSectionCard(
      title: '🖼️ Hình ảnh phòng trọ (${widget.images.length})',
      children: [
        Row(
          children: [
            Expanded(
              child: _imgActionBtn(
                icon: Icons.photo_library_rounded,
                label: 'Từ thiết bị',
                color: const Color(0xFF00897B),
                onTap: _pickFromDevice,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _imgActionBtn(
                icon: Icons.content_paste_rounded,
                label: 'Dán URL',
                color: Colors.orange.shade700,
                onTap: _pasteDirectlyToField,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  hintText: 'Nhập link ảnh (https://...) hoặc dán nhiều link',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.link_rounded,
                    color: Color(0xFF00897B),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_urlController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            Icons.clear,
                            size: 18,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() => _urlController.clear()),
                          tooltip: 'Xóa',
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.content_paste_rounded,
                          size: 20,
                          color: Color(0xFF00897B),
                        ),
                        onPressed: _pasteDirectlyToField,
                        tooltip: 'Dán trực tiếp từ clipboard',
                      ),
                    ],
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F7FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF00897B),
                      width: 1.5,
                    ),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _addUrlManually(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _addUrlManually,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm'),
                style: AppButtonStyle.primary(
                  borderRadius: 10,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(
              Icons.lightbulb_outline,
              size: 15,
              color: Colors.orange,
            ),
            const SizedBox(width: 4),
            Text(
              'Thử nhanh ảnh mẫu:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _sampleImages.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(
                          '+ ${s['name']}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF00897B),
                          ),
                        ),
                        backgroundColor: const Color(0xFF00897B).withAlpha(15),
                        side: BorderSide(
                          color: const Color(0xFF00897B).withAlpha(60),
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          final u = s['url']!;
                          if (!widget.images.contains(u)) {
                            widget.onAddImage(u);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Đã thêm ảnh ${s['name']}'),
                                backgroundColor: const Color(0xFF00897B),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        if (widget.images.isNotEmpty) ...[
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              final img = widget.images[index];
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AppImage(
                      imageUrl: img,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => widget.onRemoveImage(index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(160),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (index == 0)
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00897B),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Ảnh bìa',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ] else ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.grey.shade300,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 36,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 6),
                Text(
                  'Chưa có ảnh nào. Nhấn "Từ thiết bị" hoặc nhập link.',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
