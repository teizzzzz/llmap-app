import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../capture.dart';
import '../capture_mode.dart';
import '../imaging.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../record_ops.dart';
import '../schema_defaults.dart';
import '../settings.dart';
import '../store.dart';
import '../version.dart';
import '../theme/tokens.dart';
import '../widgets/box_selector.dart';
import '../widgets/ll/ll.dart';
import 'fields_screen.dart';
import 'quick_lang_screen.dart';
import 'select_location_screen.dart';
import 'standard_fields_screen.dart';

/// 撮影後の框选画面：1枚の写真から複数 sign を矩形で切り出す（框选しなければ
/// 写真全体が 1 sign）。次の画面は採集モードで分岐する:
/// - デフォルトモード: 標識ごとに「出现了哪些语言」を任意で選んで保存（QuickLangScreen）。
/// - エキスパートモード: 完全な研究字段表単（FieldsScreen）。
class CropScreen extends StatefulWidget {
  final AppSchema schema;
  final Uint8List imageBytes;
  final String fileName;
  final String area;
  final int seq;
  final String collector;
  final AiConfig aiConfig;
  final CaptureMode mode;

  const CropScreen({
    super.key,
    required this.schema,
    required this.imageBytes,
    required this.fileName,
    required this.area,
    required this.seq,
    required this.collector,
    required this.aiConfig,
    this.mode = CaptureMode.quick,
  });

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  List<CropRegion> _regions = [];
  bool _busy = false;
  // 撮影時GPSを画面表示中に非ブロッキングで取得（EXIF無し時の fallback）。
  Future<({double lat, double lng})?>? _gpsFuture;
  // 手動微調整した位置（あれば自動GPSより優先）。
  ({double lat, double lng})? _manualGps;
  bool get _isQuick => widget.mode == CaptureMode.quick;

  @override
  void initState() {
    super.initState();
    // 写真に撮影位置（EXIF）があればそれを、無ければ現在地を使う。
    final fromPhoto = exifGps(widget.imageBytes);
    _gpsFuture = fromPhoto != null ? Future.value(fromPhoto) : currentGps();
    _warnIfNoGps();
  }

  /// 位置が取れなかったら（権限なし・時間切れ）、黙って進めずに知らせる。
  /// 「地図で指定」か「もう一度試す」を選べる。
  Future<void> _warnIfNoGps() async {
    final gps = await _gpsFuture;
    if (gps != null || !mounted || _manualGps != null) return;
    final lang = Localizations.localeOf(context).languageCode;
    const m = {
      'zh': {
        'title': '没有获取到位置',
        'body': '请允许浏览器使用位置信息后再试一次，或者在地图上手动指定。\n\n'
            'iPhone：设置 → 隐私与安全性 → 定位服务 → Safari 网站 → 选择「使用 App 期间」，然后回到这里点「再试一次」。',
        'manual': '在地图上指定',
        'retry': '再试一次',
      },
      'ja': {
        'title': '位置情報を取得できませんでした',
        'body': 'ブラウザに位置情報の利用を許可してからもう一度試すか、地図で場所を指定してください。\n\n'
            'iPhone：設定 → プライバシーとセキュリティ → 位置情報サービス → Safari の Web サイト →「この App の使用中」を選び、ここに戻って「もう一度試す」。',
        'manual': '地図で指定する',
        'retry': 'もう一度試す',
      },
      'en': {
        'title': 'Could not get your location',
        'body': 'Allow location access for this browser and try again, or pick the place on the map.\n\n'
            'iPhone: Settings → Privacy & Security → Location Services → Safari Websites → “While Using the App”, then come back and tap “Try again”.',
        'manual': 'Pick on map',
        'retry': 'Try again',
      },
    };
    final tx = m[lang] ?? m['en']!;
    await showLLDialog(
      context,
      icon: Icons.gps_off,
      iconColor: AppColors.warning,
      title: tx['title']!,
      message: tx['body']!,
      primaryLabel: tx['manual']!,
      onPrimary: () {
        Navigator.pop(context);
        _adjustLocation();
      },
      secondaryLabel: tx['retry']!,
      onSecondary: () {
        Navigator.pop(context);
        setState(() => _gpsFuture = currentGps());
        _warnIfNoGps();
      },
    );
  }

  Future<void> _next() async {
    setState(() => _busy = true);
    try {
      // 手動調整があれば優先、無ければ自動GPS。
      final gps = _manualGps ?? await _gpsFuture;
      // 端末内で sign 群を生成し、写真を端末に保存する（後端非依存／PC off 可）。
      final signs = await _extractLocal(gps);
      if (!mounted) return;

      // 採集モードで框选後のフローを分岐する（データ構造は共通）。
      final result = await Navigator.push<List<Sign>>(
        context,
        MaterialPageRoute(
          builder: (_) => _isQuick
              // デフォルト: 標識ごとに言語を任意で選ぶだけ。
              ? QuickLangScreen(
                  schema: widget.schema,
                  imageBytes: widget.imageBytes,
                  signs: signs,
                  regions: _regions,
                )
              : widget.mode == CaptureMode.research
              // research: 完全な研究字段表単（AI下書も可）。
              ? FieldsScreen(
                  schema: widget.schema,
                  imageBytes: widget.imageBytes,
                  signs: signs,
                  regions: _regions,
                  aiConfig: widget.aiConfig,
                )
              // standard: 簡易言語選択（既定モード）。
              : StandardFieldsScreen(
                  schema: widget.schema,
                  imageBytes: widget.imageBytes,
                  signs: signs,
                  regions: _regions,
                ),
        ),
      );
      if (result != null && mounted) {
        Navigator.pop(context, result);
      } else if (result == null) {
        // 表単を放棄した: _extractLocal が保存した写真を削除する（孤児化防止）。
        // CaptureID はミリ秒一意のため、既存記録のファイルと重なることはない。
        await LocalStore.instance.deletePhotos({
          for (final s in signs) ...photoRefsOf(s),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).processFailed('$e'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 後端 /extract のローカル版：元写真を端末保存し sign 群を組み立てる。
  /// ID は新契約で採番する: CaptureID = AREA-COLLECTORID-YYMMDDHHMMSSmmm。
  /// 採集者ID＋ミリ秒時刻を含むため多人採集でもファイル名/SignID が衝突しない。
  Future<List<Sign>> _extractLocal(({double lat, double lng})? gps) async {
    final capturedAt = DateTime.now();
    final captured = formatCaptured(capturedAt);
    final captureId = makeCaptureId(widget.area, widget.collector, capturedAt);

    // 元写真（原始完整写真）。衝突時は store が別名を割り当てるため戻り値を使う。
    final sourceName = await LocalStore.instance
        .savePhoto(sourcePhotoName(captureId), widget.imageBytes);

    // 框选が無ければ元写真全体を1 sign として扱う（CropRect は 0,0,1,1）。
    final regions = _regions.isEmpty
        ? [CropRegion(suffix: 'a', x: 0, y: 0, w: 1, h: 1)]
        : _regions;

    final signs = <Sign>[];
    for (final r in regions) {
      final isFull = r.w >= 0.999 && r.h >= 0.999;
      final bytes = isFull
          ? widget.imageBytes
          : await cropJpegAsync(widget.imageBytes, r.x, r.y, r.w, r.h);
      final fname = await LocalStore.instance
          .savePhoto(cropPhotoName(captureId, r.suffix), bytes);
      signs.add(Sign({
        'SignID': makeSignId(captureId, r.suffix),
        '_status': 'pending',
        'CaptureID': captureId,
        'DisplayID':
            makeDisplayId(widget.area, capturedAt, widget.seq, r.suffix),
        '採集者ID': widget.collector,
        '地区コード': widget.area.toUpperCase(),
        'LocalSeq': widget.seq,
        'CropSuffix': r.suffix,
        'CropRect': jsonEncode({'x': r.x, 'y': r.y, 'w': r.w, 'h': r.h}),
        // 旧字段互換: 写真ID は CaptureID と同値、全景写真ファイル名 は 元写真 と同値。
        '写真ID': captureId,
        '写真ファイル名': fname,
        '元写真ファイル名': sourceName,
        '全景写真ファイル名': sourceName,
        '緯度': gps?.lat,
        '経度': gps?.lng,
        '採集日時': captured,
        // 溯源字段: 採集方式・審核状態(Console対応値)・契約/アプリ版。
        // DataStatus 初期値: quick=raw / standard=submitted / research=submitted
        // （research は校閲保存で setStatus により reviewed へ昇格）。
        'EntryMode': widget.mode.entryMode,
        'DataStatus': widget.mode.initialDataStatus,
        'SchemaVersion': kSchemaVersion,
        'AppVersion': kAppVersion,
      }));
    }
    return signs;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.cropTitle(_regions.length)),
        actions: [
          if (_regions.isNotEmpty)
            IconButton(
              tooltip: t.undoLastBox,
              onPressed: () => setState(() => _regions.removeLast()),
              icon: const Icon(Icons.undo),
            ),
          if (_regions.isNotEmpty)
            IconButton(
              tooltip: t.clearAll,
              onPressed: () => setState(() => _regions = []),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Column(
        children: [
          // 操作ヒント＋GPS状態
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
            child: LLCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.crop_free,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _regions.isEmpty
                          ? t.cropHintEmpty
                          : t.cropHintBoxed(
                              _regions.map((r) => r.suffix).join(', ')),
                      style: AppText.caption(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _gpsStatus(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: BoxSelector(
                imageBytes: widget.imageBytes,
                regions: _regions,
                onChanged: (r) => setState(() => _regions = r),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: LLPrimaryButton(
            label: _regions.isEmpty
                ? t.nextWholeImage
                : (_isQuick ? t.nextChooseLangs : t.nextFillFields),
            icon: Icons.arrow_forward,
            busy: _busy,
            onPressed: _busy ? null : _next,
          ),
        ),
      ),
    );
  }

  /// GPS 状態＋手動調整入口（自動GPS後の任意修正）。
  Widget _gpsStatus() {
    final t = AppLocalizations.of(context);
    Widget row(IconData icon, String text, Color color, String action) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.sm, 0),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(text, style: AppText.caption().copyWith(color: color)),
            const Spacer(),
            TextButton(
              onPressed: _adjustLocation,
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Text(action, style: AppText.caption()
                  .copyWith(color: AppColors.link)),
            ),
          ],
        ),
      );
    }

    if (_manualGps != null) {
      return row(Icons.edit_location_alt, t.gpsAdjusted,
          AppColors.link, t.gpsReadjust);
    }
    return FutureBuilder<({double lat, double lng})?>(
      future: _gpsFuture,
      builder: (context, snap) {
        final waiting = snap.connectionState == ConnectionState.waiting;
        final (icon, text, color) = waiting
            ? (Icons.gps_not_fixed, t.gpsLocating, AppColors.textSecondary)
            : snap.data != null
                ? (Icons.gps_fixed, t.gpsGot, AppColors.success)
                : (Icons.gps_off, t.gpsFailed, AppColors.warning);
        return row(icon, text, color,
            snap.data != null ? t.gpsAdjust : t.gpsManual);
      },
    );
  }

  /// Select Location 画面で位置を手動微調整し、結果を _manualGps に反映。
  Future<void> _adjustLocation() async {
    final base = _manualGps ?? await _gpsFuture;
    if (!mounted) return;
    final r = await Navigator.push<({double lat, double lng})>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectLocationScreen(
          initial: base == null ? null : (lat: base.lat, lng: base.lng),
        ),
      ),
    );
    if (r != null && mounted) setState(() => _manualGps = r);
  }
}
