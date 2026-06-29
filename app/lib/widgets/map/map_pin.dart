/// 地図ピン（白縁＋淡い影の円ドット）。選択時は拡大し suffix を表示。
/// mapv2.0/index.html と同じ見た目。MapScreen / 地図主体Home で共用。
library;

import 'package:flutter/material.dart';

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
    final size = selected ? 24.0 : 16.0;
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
              color: selected ? const Color(0xFF2F3032) : Colors.white,
              width: 2),
          boxShadow: const [
            BoxShadow(
                color: Color(0x402F3032), blurRadius: 7, offset: Offset(0, 2)),
          ],
        ),
        child: selected
            ? Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold))
            : null,
      ),
    );
  }
}
