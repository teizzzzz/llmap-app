import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models.dart';
import '../theme/tokens.dart';
import '../widgets/ll/ll.dart';
import '../widgets/map/ll_map_detail_card.dart';
import '../widgets/map/ll_map_legend.dart';
import '../widgets/map/ll_map_view.dart';

/// 地図预览。保存済み sign を言語別色のピンで表示し、タップで詳情。
/// 再利用部品 LLMapView / LLMapLegend / LLMapDetailCard を用いる。
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
  LLMapLayer _layer = LLMapLayer.map;

  List<Sign> get _located =>
      widget.signs.where((s) => s.lat != null && s.lng != null).toList();

  LatLng get _center {
    final pts = _located;
    if (pts.isEmpty) return const LatLng(35.6021, 139.7011);
    final lat = pts.map((s) => s.lat!).reduce((a, b) => a + b) / pts.length;
    final lng = pts.map((s) => s.lng!).reduce((a, b) => a + b) / pts.length;
    return LatLng(lat, lng);
  }

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
      appBar: AppBar(title: const Text('地图预览')),
      body: Stack(
        children: [
          LLMapView(
            controller: _map,
            signs: located,
            schema: widget.schema,
            layer: _layer,
            selected: _selected,
            initialCenter: _center,
            initialZoom: located.isEmpty ? 12 : 16,
            onMarkerTap: (s) {
              setState(() => _selected = s);
              _map.move(LatLng(s.lat!, s.lng!), _map.camera.zoom);
            },
            onMapTap: () => setState(() => _selected = null),
          ),
          // Map / Satellite 切替
          Positioned(
            top: AppSpacing.md,
            left: 0,
            right: 0,
            child: Center(
              child: LLSegmentedControl<LLMapLayer>(
                segments: const [
                  LLSegment(LLMapLayer.map, '地图'),
                  LLSegment(LLMapLayer.satellite, '卫星'),
                ],
                selected: _layer,
                activeColor: _layer == LLMapLayer.satellite
                    ? AppColors.accentViolet
                    : AppColors.accentMustard,
                activeTextColor: _layer == LLMapLayer.satellite
                    ? Colors.white
                    : AppColors.textPrimary,
                onChanged: (v) => setState(() => _layer = v),
              ),
            ),
          ),
          if (located.isNotEmpty)
            Positioned(
              top: 64,
              right: AppSpacing.md,
              child: LLIconButton(
                icon: Icons.center_focus_strong,
                tooltip: '全体表示',
                onPressed: _recenter,
              ),
            ),
          if (skipped > 0)
            Positioned(
              top: 64,
              left: AppSpacing.md,
              child: LLTagChip(
                  label: '无坐标 $skipped 条未显示',
                  color: AppColors.warning,
                  icon: Icons.info_outline),
            ),
          Positioned(
            left: AppSpacing.md,
            bottom: AppSpacing.md,
            child: LLMapLegend(schema: widget.schema),
          ),
          if (_selected != null)
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: LLMapDetailCard(
                sign: _selected!,
                schema: widget.schema,
                onClose: () => setState(() => _selected = null),
              ),
            ),
        ],
      ),
    );
  }
}
