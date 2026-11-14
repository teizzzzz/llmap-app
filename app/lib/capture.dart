/// 撮影/取り込みと実時GPSの抽象化。
/// モバイル: カメラ直撮り or ギャラリー。デスクトップ: ファイル取り込み。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'l10n/app_localizations.dart';
import 'platform/geo.dart';
import 'theme/tokens.dart';
import 'widgets/ll/ll.dart';

class CaptureResult {
  final Uint8List bytes;
  final String fileName;
  CaptureResult(this.bytes, this.fileName);
}

/// 端末アプリ（iOS / Android）として動いているか。Web 試用版は含めない。
bool get isMobile =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// 「撮影／アルバムから」を選ばせるか。Web 試用版でも選べる
/// （スマホのブラウザではカメラが開き、PC ではファイル選択になる）。
bool get offersCameraChoice => isMobile || kIsWeb;

/// 写真を取得。モバイルでは撮影/ギャラリーを選ばせる。取消は null。
Future<CaptureResult?> capturePhoto(BuildContext context) async {
  final picker = ImagePicker();
  ImageSource source = ImageSource.gallery;

  if (offersCameraChoice) {
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
  // Web 試用版: ブラウザの位置情報を直接読む（高精度 → 低精度の順に試す）。
  if (kIsWeb) return browserGps();
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

/// 写真の EXIF に入っている撮影位置（無ければ null）。アルバムから選んだ写真は、
/// いまいる場所ではなく撮った場所を使いたいので、現在地より先にこれを見る。
({double lat, double lng})? exifGps(Uint8List bytes) {
  try {
    final gps = img.decodeJpgExif(bytes)?.gpsIfd;
    if (gps == null) return null;
    double? dms(img.IfdValue? v) {
      if (v == null || v.length < 3) return null;
      return v.toDouble(0) + v.toDouble(1) / 60 + v.toDouble(2) / 3600;
    }

    var lat = dms(gps[0x0002]);
    var lng = dms(gps[0x0004]);
    if (lat == null || lng == null) return null;
    if ('${gps[0x0001]}'.toUpperCase().startsWith('S')) lat = -lat;
    if ('${gps[0x0003]}'.toUpperCase().startsWith('W')) lng = -lng;
    if (lat == 0 && lng == 0) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return (lat: lat, lng: lng);
  } catch (_) {
    return null;
  }
}
