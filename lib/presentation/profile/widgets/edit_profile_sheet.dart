import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../widgets/app_button_style.dart';
import '../../widgets/app_image.dart';

/// Bottom sheet allowing the signed-in user to update profile details and avatar.
class EditProfileSheet extends StatefulWidget {
  final String initialFullName;
  final String initialPhone;
  final String initialAvatarUrl;
  final String userEmail;
  final Future<void> Function(String fullName, String phone, String avatarUrl) onSave;

  const EditProfileSheet({
    super.key,
    required this.initialFullName,
    required this.initialPhone,
    required this.initialAvatarUrl,
    required this.userEmail,
    required this.onSave,
  });

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _avatarCtrl;
  String _previewAvatar = '';
  bool _isSaving = false;
  bool _isPickingImage = false;

  final List<Map<String, String>> _sampleAvatars = [
    {
      'label': 'Sinh viên nam',
      'url': 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=250',
    },
    {
      'label': 'Sinh viên nữ',
      'url': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=250',
    },
    {
      'label': 'Công sở nam',
      'url': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=250',
    },
    {
      'label': 'Công sở nữ',
      'url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=250',
    },
    {
      'label': 'Năng động',
      'url': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=250',
    },
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialFullName);
    _phoneCtrl = TextEditingController(text: widget.initialPhone);
    _avatarCtrl = TextEditingController(text: widget.initialAvatarUrl);
    _previewAvatar = widget.initialAvatarUrl;

    _avatarCtrl.addListener(() {
      if (_avatarCtrl.text != _previewAvatar) {
        setState(() {
          _previewAvatar = _avatarCtrl.text.trim();
        });
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      setState(() => _isPickingImage = true);
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
      );

      if (file == null) {
        if (mounted) setState(() => _isPickingImage = false);
        return;
      }

      final rawBytes = await file.readAsBytes();
      if (rawBytes.isEmpty) {
        if (mounted) setState(() => _isPickingImage = false);
        return;
      }

      // Nén ảnh về kích thước nhỏ (~240px) để lưu vào Firestore an toàn (< 25KB)
      final compressed = await AppImage.compressImage(
        rawBytes,
        targetWidth: 240,
      );
      final base64Str = base64Encode(compressed);
      final ext = file.name.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final dataUri = 'data:$mimeType;base64,$base64Str';

      if (mounted) {
        setState(() {
          _previewAvatar = dataUri;
          _avatarCtrl.text = dataUri;
          _isPickingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Đã chọn ảnh hồ sơ! Bấm "LƯU THAY ĐỔI" để áp dụng.'),
            backgroundColor: Color(0xFF00897B),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPickingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải ảnh: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Chọn nguồn ảnh hồ sơ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF00897B)),
                title: const Text('Chọn từ thư viện ảnh'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF00897B)),
                title: const Text('Chụp ảnh từ Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar(ImageSource.camera);
                },
              ),
              if (_previewAvatar.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: const Text(
                    'Xóa ảnh đại diện hiện tại',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _previewAvatar = '';
                      _avatarCtrl.clear();
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '👤 Chỉnh sửa hồ sơ cá nhân',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Tài khoản: ${widget.userEmail}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: _showImageSourceDialog,
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF00897B).withAlpha(20),
                              border: Border.all(
                                color: const Color(0xFF00897B),
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _previewAvatar.isNotEmpty
                                  ? AppImage(
                                      imageUrl: _previewAvatar,
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.cover,
                                      errorWidget: const Icon(
                                        Icons.person_rounded,
                                        size: 52,
                                        color: Color(0xFF00897B),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_rounded,
                                      size: 52,
                                      color: Color(0xFF00897B),
                                    ),
                            ),
                          ),
                        ),
                        if (_isPickingImage)
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black38,
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _showImageSourceDialog,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00897B),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _showImageSourceDialog,
                          icon: const Icon(Icons.add_a_photo_outlined, size: 15),
                          label: const Text('Tải ảnh lên / Chụp ảnh'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00897B),
                            side: const BorderSide(color: Color(0xFF00897B)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (_previewAvatar.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _previewAvatar = '';
                                _avatarCtrl.clear();
                              });
                            },
                            icon: const Icon(Icons.delete_outline, size: 15, color: Colors.redAccent),
                            label: const Text(
                              'Xóa ảnh',
                              style: TextStyle(color: Colors.redAccent, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Hoặc chọn nhanh ảnh đại diện mẫu:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _sampleAvatars.length,
                  separatorBuilder: (ctx, i) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = _sampleAvatars[index];
                    final isSelected = _previewAvatar == item['url'];

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _previewAvatar = item['url']!;
                          _avatarCtrl.text = item['url']!;
                        });
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? const Color(0xFF00897B) : Colors.grey.shade300,
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF00897B).withAlpha(80),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                        child: ClipOval(
                          child: AppImage(
                            imageUrl: item['url']!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Họ và tên *',
                  hintText: 'VD: Nguyễn Văn A',
                  prefixIcon: const Icon(
                    Icons.badge_outlined,
                    color: Color(0xFF00897B),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF00897B),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Số điện thoại',
                  hintText: 'VD: 0912345678',
                  prefixIcon: const Icon(
                    Icons.phone_rounded,
                    color: Color(0xFF00897B),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF00897B),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _avatarCtrl,
                decoration: InputDecoration(
                  labelText: 'Hoặc dán link ảnh trực tiếp (URL)',
                  hintText: 'https://...',
                  prefixIcon: const Icon(
                    Icons.link_rounded,
                    color: Color(0xFF00897B),
                  ),
                  suffixIcon: _avatarCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _avatarCtrl.clear();
                              _previewAvatar = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF00897B),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          setState(() => _isSaving = true);
                          final nav = Navigator.of(context);
                          await widget.onSave(
                            _nameCtrl.text.trim(),
                            _phoneCtrl.text.trim(),
                            _previewAvatar.trim(),
                          );
                          if (mounted) {
                            setState(() => _isSaving = false);
                            nav.pop();
                          }
                        },
                  style: AppButtonStyle.primary(hoverElevation: 3),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'LƯU THAY ĐỔI',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
