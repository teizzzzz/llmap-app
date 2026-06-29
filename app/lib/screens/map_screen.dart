import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models.dart';
import '../theme.dart';

/// 地図预览（⑤⑦）。保存済み sign を言語別色のピンで表示し、タップで詳情。
class MapScreen extends StatefulWidget {
  final List<Sign> signs;
  final AppSchema schema;
  const MapScreen({super.key, required this.signs, required this.schema});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _map = MapController();
  Sign? _selected;

  List<Sign> get _located =>
      widget.signs.where((s) => s.lat != null && s.lng != null).toList();

  LatLng get _center {
    final pts = _located;
    if (pts.isEmpty) return const LatLng(35.6021, 139.7011);
    final lat = pts.map((s) => s.lat!).reduce((a, b) => a + b) / pts.length;
    final lng = pts.map((s) => s.lng!).reduce((a, b) => a + b) / pts.length;
    return LatLng(lat, lng);
  }

  Color _langColor(String lang) =>
      parseHexColor(widget.schema.languageColors[lang] ?? '#888888');

  String _suffixOf(Sign s) => s.id.split('-').last;

  void _recenter() {
    final pts = _located;
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      _map.move(LatLng(pts.first.lat!, pts.first.lng!), 17);
      return;
    }
    var minLa = pts.first.lat!, maxLa = pts.first.lat!;
    var minLn = pts.first.lng!, maxLn = pts.first.lng!;
    for (final s in pts) {
      minLa = s.lat! < minLa ? s.lat! : minLa;
      maxLa = s.lat! > maxLa ? s.lat! : maxLa;
      minLn = s.lng! < minLn ? s.lng! : minLn;
      maxLn = s.lng! > maxLn ? s.lng! : maxLn;
    }
    _map.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds(LatLng(minLa, minLn), LatLng(maxLa, maxLn)),
      padding: const EdgeInsets.all(60),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final located = _located;
    final skipped = widget.signs.length - located.length;
    return Scaffold(
      appBar: AppBar(title: const Text('地図预览')),
      floatingActionButton: located.isEmpty
          ? null
          : FloatingActionButton.small(
              onPressed: _recenter,
              tooltip: '全体表示',
              child: const Icon(Icons.center_focus_strong),
            ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: located.isEmpty ? 12 : 16,
              onTap: (_, _) => setState(() => _selected = null),
            ),
            children: [
              TileLayer(
                // CARTO Positron(light_all): mapv2.0 と同じ淡色クリーンタイル
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                maxZoom: 19,
                retinaMode: RetinaMode.isHighDensity(context),
                userAgentPackageName: 'com.llmap.llmap_app',
              ),
              MarkerLayer(
                markers: [
                  for (final s in located)
                    Marker(
                      point: LatLng(s.lat!, s.lng!),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selected = s);
                          _map.move(LatLng(s.lat!, s.lng!), _map.camera.zoom);
                        },
                        child: MapPin(
                          color: _langColor(s.mainLang),
                          label: _suffixOf(s),
                          selected: identical(_selected, s),
                        ),
                      ),
                    ),
                ],
              ),
              const _Attribution(),
            ],
          ),
          if (skipped > 0)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: _InfoBanner(text: '座標なし $skipped 件は地図に表示されません'),
            ),
          Positioned(
            left: 12,
            bottom: 12,
            child: _LegendCard(schema: widget.schema),
          ),
          if (_selected != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _DetailCard(
                sign: _selected!,
                color: _langColor(_selected!.mainLang),
                suffix: _suffixOf(_selected!),
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

/// mapv2.0/index.html と同じ、白縁＋淡い影のクリーンな円ドット。
/// 同一写真の複数 sign は座標が重なるため、中央に suffix(a,b,c…) を小さく表示。
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
              color: selected ? const Color(0xFF111827) : Colors.white,
              width: 2),
          boxShadow: const [
            BoxShadow(
                color: Color(0x52111827), blurRadius: 7, offset: Offset(0, 2)),
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

class _Attribution extends StatelessWidget {
  const _Attribution();
  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.only(right: 4, bottom: 2),
        child: Text('© OpenStreetMap · © CARTO',
            style: TextStyle(fontSize: 9, color: Colors.black54)),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner({required this.text});
  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      color: Colors.amber.shade100,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 16, color: Colors.brown),
            const SizedBox(width: 6),
            Flexible(child: Text(text, style: const TextStyle(fontSize: 12))),
          ],
        ),
      ),
    );
  }
}

class _LegendCard extends StatelessWidget {
  final AppSchema schema;
  const _LegendCard({required this.schema});

  @override
  Widget build(BuildContext context) {
    final entries = schema.languageColors.entries.toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      color: Colors.white.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: parseHexColor(e.value),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(e.key, style: const TextStyle(fontSize: 11)),
                  ],
                ),
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
  final String suffix;
  final VoidCallback onClose;
  const _DetailCard({
    required this.sign,
    required this.color,
    required this.suffix,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    String v(String k) => sign.get(k).isEmpty ? '—' : sign.get(k);
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 言語色のヘッダ
          Container(
            color: color,
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white,
                  child: Text(suffix,
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sign.name.isEmpty ? '(名称未入力)' : sign.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: Colors.white),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(sign.id,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                    const Spacer(),
                    statusBadge(sign.status),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
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
                  const SizedBox(height: 8),
                  Text('備考: ${sign.get('備考')}',
                      style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String val) => SizedBox(
        width: 150,
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            children: [
              TextSpan(text: '$k\n', style: const TextStyle(color: Colors.grey, fontSize: 10)),
              TextSpan(text: val, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
}

