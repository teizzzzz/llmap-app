/// 拍摄位置の手動微調整（自動GPS後の任意修正）。
/// 中心固定ピン方式：地図をパンし、中心が選択位置。確定で (lat,lng) を返す。
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../capture.dart';
import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import '../widgets/ll/ll.dart';
import '../widgets/map/ll_map_view.dart' show LLMapLayer;

class SelectLocationScreen extends StatefulWidget {
  /// 自動GPS等の初期位置（無ければ既定中心から開始）。
  final ({double? lat, double? lng})? initial;
  const SelectLocationScreen({super.key, this.initial});

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  final _map = MapController();
  LLMapLayer _layer = LLMapLayer.map;
  late LatLng _center;
  late final LatLng _auto; // 「恢复自动定位」用の初期位置
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final lat = widget.initial?.lat;
    final lng = widget.initial?.lng;
    _auto = (lat != null && lng != null)
        ? LatLng(lat, lng)
        : const LatLng(35.6021, 139.7011); // 既定: 渋谷
    _center = _auto;
  }

  Future<void> _relocate() async {
    setState(() => _locating = true);
    final gps = await currentGps();
    if (!mounted) return;
    setState(() => _locating = false);
    if (gps != null) {
      _map.move(LatLng(gps.lat, gps.lng), 17);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).gpsUnavailable)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.selectLocTitle)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _auto,
              initialZoom: 17,
              onPositionChanged: (camera, _) =>
                  setState(() => _center = camera.center),
            ),
            children: [
              if (_layer == LLMapLayer.satellite)
                TileLayer(
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                  maxZoom: 19,
                  keepBuffer: 5,
                  panBuffer: 2,
                  userAgentPackageName: 'com.llmap.llmap_app',
                )
              else
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  maxZoom: 19,
                  keepBuffer: 5,
                  panBuffer: 2,
                  retinaMode: RetinaMode.isHighDensity(context),
                  userAgentPackageName: 'com.llmap.llmap_app',
                ),
            ],
          ),

          // 中心固定ピン（チップが中心を指す）
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 44),
              child: Icon(Icons.location_on,
                  size: 48, color: AppColors.accentTerracotta),
            ),
          ),

          // 上部: 説明＋座標
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.md,
            child: LLCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.selectLocBody1, style: AppText.body()),
                  const SizedBox(height: 2),
                  Text(t.selectLocBody2, style: AppText.caption()),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    t.coords(_center.latitude.toStringAsFixed(5),
                        _center.longitude.toStringAsFixed(5)),
                    style: AppText.caption().copyWith(
                        color: AppColors.accentBlue,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),

          // 右上: Map/卫星
          Positioned(
            top: 120,
            right: AppSpacing.lg,
            child: LLSegmentedControl<LLMapLayer>(
              segments: [
                LLSegment(LLMapLayer.map, t.layerMap),
                LLSegment(LLMapLayer.satellite, t.layerSatellite),
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

          // 右側: 重新定位
          Positioned(
            top: 180,
            right: AppSpacing.lg,
            child: LLIconButton(
              icon: _locating ? Icons.hourglass_empty : Icons.my_location,
              tooltip: t.relocate,
              onPressed: _locating ? null : _relocate,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LLPrimaryButton(
                label: t.useThisLocation,
                icon: Icons.check,
                onPressed: () => Navigator.pop(
                    context, (lat: _center.latitude, lng: _center.longitude)),
              ),
              const SizedBox(height: AppSpacing.sm),
              LLSecondaryButton(
                label: t.restoreAuto,
                icon: Icons.gps_fixed,
                onPressed: () => _map.move(_auto, 17),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
