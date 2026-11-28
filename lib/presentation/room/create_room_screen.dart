import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/room_service.dart';
import '../../data/notification_service.dart';
import '../../domain/models/room.dart';
import '../widgets/app_button_style.dart';
import 'widgets/create_room_images_section.dart';

class CreateRoomScreen extends StatefulWidget {
  final Room? roomToEdit;
  const CreateRoomScreen({super.key, this.roomToEdit});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final RoomService _roomService = RoomService();

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
    super.dispose();
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
              CreateRoomSectionCard(
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
              CreateRoomSectionCard(
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
              CreateRoomSectionCard(
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
              CreateRoomSectionCard(
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
              CreateRoomImagesSection(
                images: _images,
                onAddImage: (img) => setState(() => _images.add(img)),
                onRemoveImage: (index) => setState(() => _images.removeAt(index)),
                onPickingStateChanged: (loading) => setState(() => _isSubmitting = loading),
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
