import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

import '../../data/room_service.dart';
import '../../data/notification_service.dart';
import '../../domain/models/room.dart';
import '../widgets/app_image.dart';
import '../widgets/app_button_style.dart';

class CreateRoomScreen extends StatefulWidget {
  final Room? roomToEdit;
  const CreateRoomScreen({super.key, this.roomToEdit});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final RoomService _roomService = RoomService();
  final ImagePicker _picker = ImagePicker();

  bool _initialized = false;
  Room? _roomToEdit;

  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _areaController = TextEditingController();
  final _depositController = TextEditingController();
  final _electricityController = TextEditingController();
  final _waterController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _urlController = TextEditingController();

  String _selectedDistrict = 'Cầu Giấy';
  String _selectedRoomType = 'Phòng trọ khép kín';
  bool _isSubmitting = false;

  // Mỗi ảnh có thể là: URL string hoặc base64 data URI
  final List<String> _images = [];

  final List<String> _districts = [
    'Cầu Giấy',
    'Đống Đa',
    'Thanh Xuân',
    'Nam Từ Liêm',
    'Bắc Từ Liêm',
    'Ba Đình',
    'Hai Bà Trưng',
    'Hoàng Mai',
    'Hà Đông',
    'Tây Hồ',
  ];

  final List<String> _roomTypes = [
    'Phòng trọ khép kín',
    'Chung cư mini',
    'Ở ghép',
    'Nhà nguyên căn',
  ];

  final List<String> _availableAmenities = [
    'Điều hòa',
    'Nóng lạnh',
    'Wifi',
    'Máy giặt',
    'Tủ lạnh',
    'Chỗ để xe',
    'Ban công',
    'Thang máy',
    'Giờ giấc tự do',
    'Camera an ninh',
  ];

  final Set<String> _selectedAmenities = {'Điều hòa', 'Nóng lạnh', 'Wifi'};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _roomToEdit = widget.roomToEdit ??
          (ModalRoute.of(context)?.settings.arguments is Room
              ? ModalRoute.of(context)!.settings.arguments as Room
              : null);
      if (_roomToEdit != null) {
        final r = _roomToEdit!;
        _titleController.text = r.title;
        _priceController.text = r.price.toStringAsFixed(0);
        _areaController.text = r.area.toStringAsFixed(0);
        if (r.deposit > 0) _depositController.text = r.deposit.toStringAsFixed(0);
        if (r.electricityPrice > 0) _electricityController.text = r.electricityPrice.toStringAsFixed(0);
        if (r.waterPrice > 0) _waterController.text = r.waterPrice.toStringAsFixed(0);
        _addressController.text = r.address
            .replaceAll(', ${r.district}, Hà Nội', '')
            .replaceAll(', Hà Nội', '');
        _descriptionController.text = r.description;
        if (_districts.contains(r.district)) {
          _selectedDistrict = r.district;
        }
        if (_roomTypes.contains(r.roomType)) {
          _selectedRoomType = r.roomType;
        }
        _selectedAmenities
          ..clear()
          ..addAll(r.amenities);
        _images
          ..clear()
          ..addAll(r.images);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _areaController.dispose();
    _depositController.dispose();
    _electricityController.dispose();
    _waterController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  // Gợi ý ảnh mẫu thực tế để thử nghiệm nhanh
  final List<Map<String, String>> _sampleImages = [
    {
      'name': 'Phòng ngủ',
      'url':
          'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800',
    },
    {
      'name': 'Phòng khách',
      'url':
          'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800',
    },
    {
      'name': 'Studio khép kín',
      'url':
          'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800',
    },
    {
      'name': 'Căn hộ mini',
      'url':
          'https://images.unsplash.com/photo-1484154218962-a197022b5858?w=800',
    },
  ];

  // ===== 1. Chọn ảnh từ thiết bị (Hỗ trợ cả Web & Mobile) =====
  Future<void> _pickFromDevice() async {
    setState(() => _isSubmitting = true);
    try {
      List<XFile> picked = [];
      try {
        // KHÔNG truyền imageQuality vì Web sẽ quăng UnsupportedError
        picked = await _picker.pickMultiImage();
      } catch (e) {
        // Fallback chọn từng ảnh nếu trình duyệt không hỗ trợ multi
        try {
          final single = await _picker.pickImage(source: ImageSource.gallery);
          if (single != null) picked = [single];
        } catch (_) {}
      }

      if (picked.isEmpty) {
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }

      int addedCount = 0;
      for (final xfile in picked) {
        final rawBytes = await xfile.readAsBytes();
        if (rawBytes.isEmpty) continue;

        // Tự động thu nhỏ ảnh về kích thước chuẩn để lưu vào Firestore an toàn (< 100KB)
        final compressed = await AppImage.compressImage(
          rawBytes,
          targetWidth: 700,
        );
        final base64Str = base64Encode(compressed);
        final ext = xfile.name.split('.').last.toLowerCase();
        final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
        final dataUri = 'data:$mimeType;base64,$base64Str';

        if (mounted) {
          setState(() {
            _images.add(dataUri);
          });
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ===== 2. Dán link trực tiếp từ Clipboard =====
  Future<void> _pasteDirectlyToField() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isNotEmpty) {
        _urlController.text = text;
        // Nếu là URL hợp lệ thì thêm ngay vào danh sách
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

  // ===== 3. Thêm URL thủ công hoặc từ clipboard =====
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

    // Tách các URL nếu người dùng dán nhiều link cách nhau bởi xuống dòng, dấu phẩy
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
        if (!_images.contains(u)) {
          setState(() => _images.add(u));
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

  Future<void> _submitForm() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để đăng tin phòng trọ!'),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng thêm ít nhất 1 ảnh phòng trọ!'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    try {
      final double price = double.tryParse(_priceController.text.trim()) ?? 0;
      final double area = double.tryParse(_areaController.text.trim()) ?? 0;
      final double deposit = double.tryParse(_depositController.text.trim()) ?? 0;
      final double electricityPrice = double.tryParse(_electricityController.text.trim()) ?? 0;
      final double waterPrice = double.tryParse(_waterController.text.trim()) ?? 0;

      if (_roomToEdit != null) {
        final updatedRoom = Room(
          roomId: _roomToEdit!.roomId,
          ownerId: _roomToEdit!.ownerId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          price: price,
          area: area,
          deposit: deposit,
          electricityPrice: electricityPrice,
          waterPrice: waterPrice,
          averageRating: _roomToEdit!.averageRating,
          totalReviews: _roomToEdit!.totalReviews,
          ward: _roomToEdit!.ward,
          street: _roomToEdit!.street,
          district: _selectedDistrict,
          address:
              '${_addressController.text.trim()}, $_selectedDistrict, Hà Nội',
          images: _images,
          amenities: _selectedAmenities.toList(),
          roomType: _selectedRoomType,
          status: _roomToEdit!.status == 'rejected'
              ? 'pending_approval'
              : _roomToEdit!.status,
          rejectionReason: _roomToEdit!.status == 'rejected'
              ? null
              : _roomToEdit!.rejectionReason,
          createdAt: _roomToEdit!.createdAt,
          expiredAt: _roomToEdit!.expiredAt,
          vipType: _roomToEdit!.vipType,
        );

        await _roomService.updateRoom(updatedRoom);

        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('🎉 Cập nhật phòng thành công!'),
            backgroundColor: Color(0xFF00897B),
            behavior: SnackBarBehavior.floating,
          ),
        );
        nav.pop(true);
      } else {
        final newRoom = Room(
          roomId: '',
          ownerId: user.uid,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          price: price,
          area: area,
          deposit: deposit,
          electricityPrice: electricityPrice,
          waterPrice: waterPrice,
          averageRating: 0.0,
          totalReviews: 0,
          district: _selectedDistrict,
          address:
              '${_addressController.text.trim()}, $_selectedDistrict, Hà Nội',
          images: _images,
          amenities: _selectedAmenities.toList(),
          roomType: _selectedRoomType,
          status: 'pending_approval',
          createdAt: DateTime.now(),
          expiredAt: DateTime.now().add(const Duration(days: 10)),
          vipType: 'normal',
        );

        await _roomService.createRoom(newRoom);

        await NotificationService().sendUserNotification(
          userId: user.uid,
          title: 'Tin đăng đang chờ phê duyệt ⏳',
          body:
              'Tin đăng "${newRoom.title}" của bạn đã được gửi thành công và đang chờ Ban quản trị kiểm duyệt.',
          type: 'system',
        );

        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              '🎉 Đăng tin thành công! Tin đăng đang chờ Ban quản trị duyệt trước khi hiển thị công khai.',
            ),
            backgroundColor: Color(0xFF00897B),
            behavior: SnackBarBehavior.floating,
          ),
        );
        nav.pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _roomToEdit != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(isEditing ? 'Chỉnh sửa phòng trọ' : 'Đăng phòng cho thuê'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ======= THÔNG TIN CƠ BẢN =======
              _sectionCard(
                title: '📋 Thông tin cơ bản',
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: _inputDecoration(
                      label: 'Tiêu đề bài đăng *',
                      hint: 'VD: Phòng trọ khép kín full đồ Cầu Giấy',
                      icon: Icons.title_rounded,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng nhập tiêu đề';
                      }
                      if (val.trim().length < 10) {
                        return 'Tiêu đề tối thiểu 10 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  if (MediaQuery.of(context).size.width < 540) ...[
                    TextFormField(
                      controller: _priceController,
                      decoration: _inputDecoration(
                        label: 'Giá thuê (VNĐ) *',
                        hint: '3500000',
                        icon: Icons.payments_outlined,
                        suffix: 'đ',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Nhập giá thuê';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _areaController,
                      decoration: _inputDecoration(
                        label: 'Diện tích (m²) *',
                        hint: '25',
                        icon: Icons.square_foot_rounded,
                        suffix: 'm²',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Nhập diện tích';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _depositController,
                      decoration: _inputDecoration(
                        label: 'Tiền cọc (VNĐ)',
                        hint: 'VD: 3500000',
                        icon: Icons.security_rounded,
                        suffix: 'đ',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _electricityController,
                      decoration: _inputDecoration(
                        label: 'Giá điện (VNĐ/kWh)',
                        hint: 'VD: 3800',
                        icon: Icons.electric_bolt_rounded,
                        suffix: 'đ',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            decoration: _inputDecoration(
                              label: 'Giá thuê (VNĐ) *',
                              hint: '3500000',
                              icon: Icons.payments_outlined,
                              suffix: 'đ',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Nhập giá thuê';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _areaController,
                            decoration: _inputDecoration(
                              label: 'Diện tích (m²) *',
                              hint: '25',
                              icon: Icons.square_foot_rounded,
                              suffix: 'm²',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Nhập diện tích';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Tiền cọc & Chi phí điện nước
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _depositController,
                            decoration: _inputDecoration(
                              label: 'Tiền cọc (VNĐ)',
                              hint: 'VD: 3500000',
                              icon: Icons.security_rounded,
                              suffix: 'đ',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _electricityController,
                            decoration: _inputDecoration(
                              label: 'Giá điện (VNĐ/kWh)',
                              hint: 'VD: 3800',
                              icon: Icons.electric_bolt_rounded,
                              suffix: 'đ',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _waterController,
                    decoration: _inputDecoration(
                      label: 'Giá nước (VNĐ/m³ hoặc người)',
                      hint: 'VD: 30000 hoặc 100000',
                      icon: Icons.water_drop_rounded,
                      suffix: 'đ',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRoomType,
                    decoration: _inputDecoration(
                      label: 'Loại phòng *',
                      icon: Icons.meeting_room_outlined,
                    ),
                    items: _roomTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedRoomType = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ======= ĐỊA CHỈ =======
              _sectionCard(
                title: '📍 Địa chỉ phòng',
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedDistrict,
                    decoration: _inputDecoration(
                      label: 'Quận/Huyện *',
                      icon: Icons.location_city_rounded,
                    ),
                    items: _districts
                        .map(
                          (d) => DropdownMenuItem(value: d, child: Text(d)),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedDistrict = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _addressController,
                    decoration: _inputDecoration(
                      label: 'Số nhà, ngõ, tên đường *',
                      hint: 'Số 15 ngõ 122 Trần Duy Hưng',
                      icon: Icons.signpost_outlined,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng nhập địa chỉ chi tiết';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ======= TIỆN ÍCH =======
              _sectionCard(
                title: '✨ Tiện ích có sẵn',
                children: [
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 6.0,
                    children: _availableAmenities.map((amenity) {
                      final isSelected = _selectedAmenities.contains(amenity);
                      return FilterChip(
                        label: Text(amenity),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedAmenities.add(amenity);
                            } else {
                              _selectedAmenities.remove(amenity);
                            }
                          });
                        },
                        selectedColor: const Color(0xFF00897B).withAlpha(40),
                        checkmarkColor: const Color(0xFF00897B),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? const Color(0xFF00897B)
                              : Colors.grey.shade700,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF00897B)
                              : Colors.grey.shade300,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ======= MÔ TẢ =======
              _sectionCard(
                title: '📝 Mô tả chi tiết',
                children: [
                  TextFormField(
                    controller: _descriptionController,
                    decoration: _inputDecoration(
                      label: 'Mô tả thêm về phòng trọ',
                      hint:
                          'Giờ giấc tự do, không chung chủ, điện nước giá dân...',
                      icon: Icons.description_outlined,
                    ),
                    maxLines: 4,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ======= HÌNH ẢNH =======
              _sectionCard(
                title: '🖼️ Hình ảnh phòng trọ (${_images.length})',
                children: [
                  // Action buttons row
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

                  // URL input with Paste & Clear suffix buttons
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
                                    onPressed: () =>
                                        setState(() => _urlController.clear()),
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
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
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

                  // Quick sample photos suggestion row
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
                                  backgroundColor: const Color(
                                    0xFF00897B,
                                  ).withAlpha(15),
                                  side: BorderSide(
                                    color: const Color(0xFF00897B).withAlpha(60),
                                  ),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    final u = s['url']!;
                                    if (!_images.contains(u)) {
                                      setState(() => _images.add(u));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Đã thêm ảnh ${s['name']}'),
                                          backgroundColor: const Color(
                                            0xFF00897B,
                                          ),
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

                  // Image preview grid
                  if (_images.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.0,
                          ),
                      itemCount: _images.length,
                      itemBuilder: (context, index) {
                        final img = _images[index];
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildImagePreview(img),
                            ),
                            // Delete button
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _images.removeAt(index)),
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
                            // Main image badge
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
              ),

              const SizedBox(height: 24),

              // ======= SUBMIT BUTTON =======
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: AppButtonStyle.primary(hoverElevation: 4),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          _roomToEdit != null
                              ? 'LƯU THAY ĐỔI'
                              : 'ĐĂNG PHÒNG LÊN HỆ THỐNG',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(String img) {
    return AppImage(
      imageUrl: img,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
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

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
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

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    required IconData icon,
    String? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
      suffixText: suffix,
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }
}
