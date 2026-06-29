/// 撮影/取り込みと実時GPSの抽象化。
/// モバイル: カメラ直撮り or ギャラリー。デスクトップ: ファイル取り込み。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'widgets/ll/ll.dart';

class CaptureResult {
  final Uint8List bytes;
  final String fileName;
  CaptureResult(this.bytes, this.fileName);
}

bool get isMobile => Platform.isAndroid || Platform.isIOS;

/// 写真を取得。モバイルでは撮影/ギャラリーを選ばせる。取消は null。
Future<CaptureResult?> capturePhoto(BuildContext context) async {
  final picker = ImagePicker();
  ImageSource source = ImageSource.gallery;

  if (isMobile) {
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => LLBottomSheetScaffold(
        title: '新增采集',
        children: [
          LLSheetTile(
            icon: Icons.camera_alt_outlined,
            label: '拍照',
            showChevron: false,
            onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
          ),
          LLSheetTile(
            icon: Icons.photo_library_outlined,
            label: '从相册选择',
            showChevron: false,
            onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
          ),
        ],
      ),
    );
    if (choice == null) return null;
    source = choice;
  }

  final x = await picker.pickImage(source: source, maxWidth: 4096);
  if (x == null) return null;
  return CaptureResult(await x.readAsBytes(), x.name);
}

/// 撮影時の現在地。権限拒否/未対応/タイムアウトは null（backend が EXIF を優先）。
Future<({double lat, double lng})?> currentGps() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return (lat: pos.latitude, lng: pos.longitude);
  } catch (_) {
    return null; // デスクトップ等 未対応プラットフォームを含む
  }
}
