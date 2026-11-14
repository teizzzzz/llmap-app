/// 地図ピン（白縁の小さな円ドット）。選択時は拡大し suffix を表示。
/// 共有写真の点（CircleLayer）より一回り大きく、自分の記録だと分かる大きさ。
/// MapScreen / 地図主体Home で共用。
library;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

class MapPin extends StatelessWidget {
  final Color color;
  final String label;
  final bool selected;
  const MapPin({
    super.key,
    required this.color,
    required this.label,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = selected ? 24.0 : 13.0;
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
              color: selected ? AppColors.textPrimary : Colors.white,
              width: selected ? 2.5 : 2),
          boxShadow: const [
            BoxShadow(
                color: Color(0x26000000), blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
        child: selected
            ? Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600))
            : null,
      ),
    );
  }
}
