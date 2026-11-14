/// 再利用可能な地図ビュー（タイル＋単色のピン/点＋出典）。
/// MapScreen と 地図主体HomeScreen の双方が利用する。業務ロジックは持たない。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models.dart';
import '../../theme/tokens.dart';
import 'map_pin.dart';

enum LLMapLayer { map, satellite }

/// 通常の底図：Esri World Street Map（API キー不要。web-viewer と同じ提供元）を
/// ほぼ無彩色に落とし、写真の点が主役になる淡い地図にする。
/// ※ CARTO の無料タイルは API キー必須になり「API KEY REQUIRED」と描かれるため使わない。
Widget quietStreetTiles() => ColorFiltered(
      colorFilter: const ColorFilter.matrix(_kQuietMap),
      child: TileLayer(
        urlTemplate:
            'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
        maxZoom: 19,
        keepBuffer: 5,
        panBuffer: 2,
        userAgentPackageName: 'com.llmap.llmap_app',
      ),
    );

/// 底図を淡く（彩度 15%・コントラスト控えめ・少し明るく）する色行列。
const List<double> _kQuietMap = [
  0.40, 0.51, 0.06, 0, 30, //
  0.18, 0.73, 0.06, 0, 30, //
  0.18, 0.51, 0.28, 0, 30, //
  0, 0, 0, 1, 0, //
];

/// 共有写真（探索データ）を描く軽量な点。数千件でも重くならないよう
/// Marker ウィジェットではなく CircleLayer で描く。点は指より小さいので、
/// タップは「画面上で最も近い点（22px 以内）」を拾う。
class LLMapDot<T extends Object> {
  final LatLng point;
  final Color color;
  final T value;
  const LLMapDot(this.point, this.color, this.value);
}

class LLMapView<T extends Object> extends StatefulWidget {
  final MapController controller;
  final List<Sign> signs; // lat/lng を持つ sign のみ渡す想定
  final AppSchema schema;
  final LLMapLayer layer;
  final Sign? selected;
  final void Function(Sign sign) onMarkerTap;
  final VoidCallback? onMapTap;
  final VoidCallback? onMapReady;
  final LatLng initialCenter;
  final double initialZoom;

  /// 共有写真の点（任意）。
  final List<LLMapDot<T>> dots;
  final void Function(T value)? onDotTap;

  /// 選択中の地点を強調するリング（任意）。
  final LatLng? highlight;

  /// 地図の移動・拡縮が落ち着いたとき（抽屉の「範囲内」一覧の更新用）。
  final void Function(MapCamera camera)? onCameraIdle;

  const LLMapView({
    super.key,
    required this.controller,
    required this.signs,
    required this.schema,
    required this.onMarkerTap,
    this.layer = LLMapLayer.map,
    this.selected,
    this.onMapTap,
    this.onMapReady,
    required this.initialCenter,
    this.initialZoom = 16,
    this.dots = const [],
    this.onDotTap,
    this.highlight,
    this.onCameraIdle,
  });

  @override
  State<LLMapView<T>> createState() => _LLMapViewState<T>();
}

class _LLMapViewState<T extends Object> extends State<LLMapView<T>> {
  Timer? _idle;

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

  /// タップ位置に最も近い点（画面距離 22px 以内）。無ければ null。
  T? _nearestDot(Offset tap) {
    final cam = widget.controller.camera;
    T? best;
    var bestD = 22.0 * 22.0;
    for (final d in widget.dots) {
      final p = cam.latLngToScreenPoint(d.point);
      final dx = p.x - tap.dx, dy = p.y - tap.dy;
      final dist = dx * dx + dy * dy;
      if (dist < bestD) {
        bestD = dist;
        best = d.value;
      }
    }
    return best;
  }

  void _onPosition(MapCamera camera, bool _) {
    if (widget.onCameraIdle == null) return;
    _idle?.cancel();
    _idle = Timer(const Duration(milliseconds: 260),
        () => widget.onCameraIdle?.call(camera));
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return ColoredBox(
      // タイル未読込領域の下地（灰白の代わりに暖色）。
      color: AppColors.muted,
      child: FlutterMap(
        mapController: w.controller,
        options: MapOptions(
          initialCenter: w.initialCenter,
          initialZoom: w.initialZoom,
          onTap: (pos, _) {
            final rel = pos.relative;
            final hit = (w.dots.isEmpty || rel == null) ? null : _nearestDot(rel);
            if (hit != null) {
              w.onDotTap?.call(hit);
            } else {
              w.onMapTap?.call();
            }
          },
          onMapReady: () {
            w.onMapReady?.call();
            if (w.onCameraIdle != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) w.onCameraIdle!(w.controller.camera);
              });
            }
          },
          onPositionChanged: _onPosition,
        ),
        children: [
          if (w.layer == LLMapLayer.satellite)
            TileLayer(
              // Esri World Imagery（衛星）。subdomain/retina パラメータ無し。
              urlTemplate:
                  'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
              maxZoom: 19,
              // ズーム/パン中にタイルを保持し、灰白の点滅を抑える。
              keepBuffer: 5,
              panBuffer: 2,
              userAgentPackageName: 'com.llmap.llmap_app',
            )
          else
            quietStreetTiles(),
          if (w.dots.isNotEmpty)
            CircleLayer(
              circles: [
                for (final d in w.dots)
                  CircleMarker(
                    point: d.point,
                    radius: 4.5,
                    color: d.color,
                    borderColor: Colors.white,
                    borderStrokeWidth: 1.5,
                  ),
              ],
            ),
          MarkerLayer(
            markers: [
              for (final s in w.signs)
                Marker(
                  point: LatLng(s.lat!, s.lng!),
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => w.onMarkerTap(s),
                    child: MapPin(
                      // 地図の点は単色（言語の色分けはしない）。自分の記録は黒。
                      color: AppColors.textPrimary,
                      label: s.cropSuffix,
                      selected: identical(w.selected, s),
                    ),
                  ),
                ),
              if (w.highlight != null)
                Marker(
                  point: w.highlight!,
                  width: 34,
                  height: 34,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.textPrimary, width: 3),
                        boxShadow: AppShadows.card,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const _Attribution(),
        ],
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution();
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('© Esri · OpenStreetMap',
              style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
        ),
      ),
    );
  }
}
