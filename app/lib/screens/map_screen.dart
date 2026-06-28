import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models.dart';

/// 地図预览（⑤⑦）。保存済み sign を言語別色で点表示し、タップで詳情。
class MapScreen extends StatefulWidget {
  final List<Sign> signs;
  final AppSchema schema;
  const MapScreen({super.key, required this.signs, required this.schema});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Sign? _selected;

  List<Sign> get _located =>
      widget.signs.where((s) => s.lat != null && s.lng != null).toList();

  LatLng get _center {
    final pts = _located;
    if (pts.isEmpty) return const LatLng(35.6021, 139.7011); // 既定: 東京近辺
    final lat = pts.map((s) => s.lat!).reduce((a, b) => a + b) / pts.length;
    final lng = pts.map((s) => s.lng!).reduce((a, b) => a + b) / pts.length;
    return LatLng(lat, lng);
  }

  Color _langColor(String lang) {
    final hex = widget.schema.languageColors[lang] ?? '#888888';
    return parseHexColor(hex);
  }

  @override
  Widget build(BuildContext context) {
    final located = _located;
    final skipped = widget.signs.length - located.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('地図预览'),
        bottom: skipped > 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Container(
                  width: double.infinity,
                  color: Colors.amber.shade100,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: Text('座標なし $skipped 件は地図に表示されません',
                      style: const TextStyle(fontSize: 12)),
                ),
              )
            : null,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _center,
              initialZoom: located.isEmpty ? 12 : 16,
              onTap: (_, _) => setState(() => _selected = null),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.llmap.app',
              ),
              MarkerLayer(
                markers: [
                  for (final s in located)
                    Marker(
                      point: LatLng(s.lat!, s.lng!),
                      width: 34,
                      height: 34,
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = s),
                        child: Icon(
                          Icons.location_on,
                          color: _langColor(s.mainLang),
                          size: _selected == s ? 40 : 34,
                          shadows: const [
                            Shadow(blurRadius: 2, color: Colors.black54),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: _LegendCard(schema: widget.schema, hex: parseHexColor),
          ),
          if (_selected != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: _DetailCard(
                sign: _selected!,
                color: _langColor(_selected!.mainLang),
                onClose: () => setState(() => _selected = null),
              ),
            ),
        ],
      ),
    );
  }
}

Color parseHexColor(String h) {
  h = h.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

class _LegendCard extends StatelessWidget {
  final AppSchema schema;
  final Color Function(String) hex;
  const _LegendCard({required this.schema, required this.hex});

  @override
  Widget build(BuildContext context) {
    final entries = schema.languageColors.entries.toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Card(
      color: Colors.white.withValues(alpha: 0.9),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in entries)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 12, color: hex(e.value)),
                  const SizedBox(width: 4),
                  Text(e.key, style: const TextStyle(fontSize: 11)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final Sign sign;
  final Color color;
  final VoidCallback onClose;
  const _DetailCard({
    required this.sign,
    required this.color,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    String v(String k) => sign.get(k).isEmpty ? '—' : sign.get(k);
    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    sign.name.isEmpty ? sign.id : sign.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(sign.id,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _kv('主要言語', v('主要言語')),
                _kv('補助言語', v('補助言語')),
                _kv('設置主体', v('設置主体')),
                _kv('担体類型', v('担体類型')),
                _kv('来源類型', v('来源類型')),
                _kv('多言語関係', v('多言語関係')),
              ],
            ),
            if (sign.get('備考').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('備考: ${sign.get('備考')}',
                  style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String val) => RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          children: [
            TextSpan(
                text: '$k: ',
                style: const TextStyle(color: Colors.grey)),
            TextSpan(text: val),
          ],
        ),
      );
}
