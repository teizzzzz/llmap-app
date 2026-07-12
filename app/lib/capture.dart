/// 撮影/取り込みと実時GPSの抽象化。
/// モバイル: カメラ直撮り or ギャラリー。デスクトップ: ファイル取り込み。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'l10n/app_localizations.dart';
import 'theme/tokens.dart';
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
    final t = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => LLBottomSheetScaffold(
        title: t.newCollection,
        children: [
          LLSheetTile(
            icon: Icons.camera_alt_outlined,
            label: t.takePhoto,
            showChevron: false,
            onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
          ),
          LLSheetTile(
            icon: Icons.photo_library_outlined,
            label: t.chooseFromGallery,
            showChevron: false,
            onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
          ),
        ],
      ),
    );
    if (choice == null) return null;
    source = choice;
  }

  try {
    final x = await picker.pickImage(source: source, maxWidth: 4096);
    if (x == null) return null;
    return CaptureResult(await x.readAsBytes(), x.name);
  } on PlatformException catch (e) {
    // カメラ/写真の権限が拒否された場合、黙って失敗せず設定への導線を出す
    // （iOS で一度「許可しない」を選ぶと、設定でしか再有効化できないため）。
    final denied =
        e.code.contains('access_denied') || e.code.contains('denied');
    if (denied && context.mounted) {
      final t = AppLocalizations.of(context);
      final isCamera = source == ImageSource.camera;
      await showLLDialog(
        context,
        icon: Icons.lock_outline,
        iconColor: AppColors.danger,
        title: t.permissionDeniedTitle,
        message: isCamera ? t.cameraDeniedBody : t.photoDeniedBody,
        primaryLabel: t.openSettings,
        onPrimary: () {
          Navigator.pop(context);
          Geolocator.openAppSettings(); // アプリの設定ページを直接開く
        },
        secondaryLabel: t.cancel,
        onSecondary: () => Navigator.pop(context),
      );
    }
    return null;
  }
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
