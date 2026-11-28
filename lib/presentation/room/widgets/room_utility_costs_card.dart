import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/room.dart';

class RoomUtilityCostsCard extends StatelessWidget {
  final Room room;
  final NumberFormat currencyFormatter;

  const RoomUtilityCostsCard({
    super.key,
    required this.room,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final hasCosts = room.deposit > 0 || room.electricityPrice > 0 || room.waterPrice > 0;
    if (!hasCosts) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💰 Chi phí & Tiền cọc',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _costItem(
                  icon: Icons.security_rounded,
                  label: 'Tiền đặt cọc',
                  value: room.deposit > 0
                      ? currencyFormatter.format(room.deposit)
                      : 'Không cọc',
                  color: Colors.deepPurple,
                ),
              ),
              Expanded(
                child: _costItem(
                  icon: Icons.electric_bolt_rounded,
                  label: 'Giá điện',
                  value: room.electricityPrice > 0
                      ? '${currencyFormatter.format(room.electricityPrice)}/kWh'
                      : 'Giá nhà nước',
                  color: Colors.amber.shade800,
                ),
              ),
              Expanded(
                child: _costItem(
                  icon: Icons.water_drop_rounded,
                  label: 'Giá nước',
                  value: room.waterPrice > 0
                      ? '${currencyFormatter.format(room.waterPrice)}/m³'
                      : 'Giá nhà nước',
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _costItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withAlpha(25),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
