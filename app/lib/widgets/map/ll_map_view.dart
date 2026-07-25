/// 再利用可能な地図ビュー（タイル＋言語別ピン＋出典）。
/// MapScreen と 地図主体HomeScreen の双方が利用する。業務ロジックは持たない。
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models.dart';
import '../../theme/tokens.dart';
import 'map_pin.dart';

enum LLMapLayer { map, satellite }

class LLMapView extends StatelessWidget {
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
  });

  Color _langColor(String lang) =>
      parseHexColor(schema.languageColors[lang] ?? '#888888');

  String _suffixOf(Sign s) => s.cropSuffix;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // タイル未読込領域の下地（灰白の代わりに暖色）。
      color: AppColors.muted,
      child: FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        onTap: (_, _) => onMapTap?.call(),
        onMapReady: onMapReady,
      ),
      children: [
        if (layer == LLMapLayer.satellite)
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
          TileLayer(
            // CARTO Positron(light_all): 淡色クリーンタイル。
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            maxZoom: 19,
            keepBuffer: 5,
            panBuffer: 2,
            retinaMode: RetinaMode.isHighDensity(context),
            userAgentPackageName: 'com.llmap.llmap_app',
          ),
        MarkerLayer(
          markers: [
            for (final s in signs)
              Marker(
                point: LatLng(s.lat!, s.lng!),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () => onMarkerTap(s),
                  child: MapPin(
                    color: _langColor(s.mainLangPrimary),
                    label: _suffixOf(s),
                    selected: identical(selected, s),
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
            color: AppColors.surfaceIvory.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('© OpenStreetMap · CARTO · Esri',
              style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
        ),
      ),
    );
  }
}
