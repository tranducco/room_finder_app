import 'package:flutter/material.dart';

import '../../widgets/app_button_style.dart';

class RoomFilterSheet extends StatefulWidget {
  final RangeValues initialPriceRange;
  final RangeValues initialAreaRange;
  final String initialRoomType;
  final Set<String> initialAmenities;
  final Function(RangeValues, RangeValues, String, Set<String>) onApply;

  const RoomFilterSheet({
    super.key,
    required this.initialPriceRange,
    required this.initialAreaRange,
    required this.initialRoomType,
    required this.initialAmenities,
    required this.onApply,
  });

  @override
  State<RoomFilterSheet> createState() => _RoomFilterSheetState();
}

class _RoomFilterSheetState extends State<RoomFilterSheet> {
  late RangeValues _price;
  late RangeValues _area;
  late String _roomType;
  late Set<String> _amenities;

  final List<String> _roomTypes = [
    'Tất cả',
    'Phòng trọ khép kín',
    'Chung cư mini',
    'Ở ghép',
    'Nhà nguyên căn',
  ];

  final List<String> _allAmenities = [
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

  @override
  void initState() {
    super.initState();
    _price = widget.initialPriceRange;
    _area = widget.initialAreaRange;
    _roomType = widget.initialRoomType;
    _amenities = Set.from(widget.initialAmenities);
  }

  void _reset() {
    setState(() {
      _price = const RangeValues(1, 15);
      _area = const RangeValues(15, 80);
      _roomType = 'Tất cả';
      _amenities.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '🎛️ Bộ lọc nâng cao',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _reset,
                      child: const Text('Đặt lại', style: TextStyle(color: Colors.red)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content scrollable
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ====== 1. KHOẢNG GIÁ ======
                _sectionHeader(
                  'Khoảng giá (triệu/tháng)',
                  '${_price.start.toStringAsFixed(1)} - ${_price.end >= 15 ? '15+ tr' : '${_price.end.toStringAsFixed(1)} tr'}',
                ),
                RangeSlider(
                  values: _price,
                  min: 1.0,
                  max: 15.0,
                  divisions: 28,
                  activeColor: const Color(0xFF00897B),
                  inactiveColor: Colors.grey.shade200,
                  labels: RangeLabels(
                    '${_price.start.toStringAsFixed(1)} tr',
                    _price.end >= 15 ? '15+ tr' : '${_price.end.toStringAsFixed(1)} tr',
                  ),
                  onChanged: (vals) => setState(() => _price = vals),
                ),
                const SizedBox(height: 20),

                // ====== 2. DIỆN TÍCH ======
                _sectionHeader(
                  'Diện tích (m²)',
                  '${_area.start.toStringAsFixed(0)} m² - ${_area.end >= 80 ? '80+ m²' : '${_area.end.toStringAsFixed(0)} m²'}',
                ),
                RangeSlider(
                  values: _area,
                  min: 15.0,
                  max: 80.0,
                  divisions: 13,
                  activeColor: const Color(0xFF00897B),
                  inactiveColor: Colors.grey.shade200,
                  labels: RangeLabels(
                    '${_area.start.toStringAsFixed(0)} m²',
                    _area.end >= 80 ? '80+ m²' : '${_area.end.toStringAsFixed(0)} m²',
                  ),
                  onChanged: (vals) => setState(() => _area = vals),
                ),
                const SizedBox(height: 20),

                // ====== 3. LOẠI PHÒNG ======
                const Text(
                  'Loại phòng',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _roomTypes.map((type) {
                    final selected = _roomType == type;
                    return ChoiceChip(
                      label: Text(type),
                      selected: selected,
                      selectedColor: const Color(0xFF00897B),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.grey.shade800,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      onSelected: (_) => setState(() => _roomType = type),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // ====== 4. TIỆN ÍCH BẮT BUỘC ======
                const Text(
                  'Tiện ích bắt buộc phải có',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Chỉ hiển thị phòng có ĐỦ các tiện ích được tích chọn',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allAmenities.map((amenity) {
                    final isChecked = _amenities.contains(amenity);
                    return FilterChip(
                      label: Text(amenity),
                      selected: isChecked,
                      selectedColor: const Color(0xFF00897B).withAlpha(40),
                      checkmarkColor: const Color(0xFF00897B),
                      labelStyle: TextStyle(
                        color: isChecked ? const Color(0xFF00897B) : Colors.grey.shade800,
                        fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      side: BorderSide(
                        color: isChecked ? const Color(0xFF00897B) : Colors.grey.shade300,
                      ),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _amenities.add(amenity);
                          } else {
                            _amenities.remove(amenity);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Bottom sticky apply button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_price, _area, _roomType, _amenities);
                    Navigator.pop(context);
                  },
                  style: AppButtonStyle.primary(),
                  child: const Text(
                    'ÁP DỤNG BỘ LỌC',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String value) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2F1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF00796B),
            ),
          ),
        ),
      ],
    );
  }
}
