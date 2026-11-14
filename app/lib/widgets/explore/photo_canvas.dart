/// 照片漫游画布：探索データの全写真を 1 枚の画布に並べ、ドラッグで移動・
/// 2 本指で拡縮して眺める（llmap-view の照片云/照片墙の手機版）。
/// 並べ方は 照片墙 / 分组 / 色轮 / 色相×明度。位置は llmap-view と同じ
/// （色轮・色相×明度は data.js の事前計算 wh / hl をそのまま使う）。
/// 写真は atlas（全写真を縮小して 1 枚に並べた画像）から drawAtlas で一度に
/// 描くので、2000 枚近くでも滑らかに動く。筛选外の写真は 照片墙/分组 では
/// 隠し、色轮/色相×明度 では位置を保ったまま薄く残す（web 版と同じ）。
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../explore/dataset.dart';
import '../../explore/photo_item.dart';
import '../../explore/themes.dart';
import '../../theme/tokens.dart';

enum CanvasLayout { wall, group, wheel, hueLight }

/// 分组の次元（llmap-view の DIMS と同じキー）。
const List<String> kCanvasGroupKeys = [
  'cn',
  'lang',
  'car',
  'q',
  'dis',
  'rel',
  'pos',
  'tmp',
];

/// 分组キーごとの値（先頭値でグループにする）。
String canvasGroupValue(LlvRecord r, String key) => switch (key) {
  'cn' => r.colorName,
  'lang' => r.main.isEmpty ? 'none' : r.main.first,
  _ => r.fields[key] ?? '',
};

class PhotoCanvas extends StatefulWidget {
  final ExploreDataset ds;
  final List<PhotoItem> items; // 探索データの写真（records と同じ並び）
  final Set<int>? active; // 筛选に合う index（null = 全部）
  final CanvasLayout layout;
  final String groupKey;
  final String Function(String key, String value) groupLabel;
  final void Function(PhotoItem item) onOpen;

  const PhotoCanvas({
    super.key,
    required this.ds,
    required this.items,
    required this.active,
    required this.layout,
    required this.groupKey,
    required this.groupLabel,
    required this.onOpen,
  });

  @override
  State<PhotoCanvas> createState() => _PhotoCanvasState();
}

class _Label {
  final double x, y; // ワールド座標（タイル単位）
  final String text;
  const _Label(this.x, this.y, this.text);
}

class _Cam {
  double k, x, y; // screen = world * k + (x, y)
  _Cam(this.k, this.x, this.y);
  _Cam copy() => _Cam(k, x, y);
}

class _PhotoCanvasState extends State<PhotoCanvas>
    with SingleTickerProviderStateMixin {
  static const _gap = 0.92; // タイルの描画サイズ（隙間を残す）
  static const _staggerMax = 0.35; // 位置移動の時差（全体に対する割合）

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  )..addListener(_tick);
  final _repaint = ValueNotifier<int>(0);

  ui.Image? _atlas;
  ImageStream? _atlasStream;
  late final ImageStreamListener _atlasListener = ImageStreamListener(
    _onAtlas,
    onError: (_, _) {},
  );

  // 位置・透明度（from → to を _anim で補間、cur が現在値）
  late int _n = widget.ds.records.length;
  late List<double> _fx = List.filled(_n, 0), _fy = List.filled(_n, 0);
  late List<double> _tx = List.filled(_n, 0), _ty = List.filled(_n, 0);
  late List<double> _fa = List.filled(_n, 0), _ta = List.filled(_n, 0);
  late List<double> _cx = List.filled(_n, 0), _cy = List.filled(_n, 0);
  late List<double> _ca = List.filled(_n, 0);
  late List<double> _delay = List.filled(_n, 0);
  List<_Label> _labels = const [];

  _Cam _cam = _Cam(1, 0, 0);
  _Cam _camFrom = _Cam(1, 0, 0), _camTo = _Cam(1, 0, 0);
  Size _viewport = Size.zero;
  bool _laidOut = false;

  // ジェスチャ
  late _Cam _gestureStart;
  late Offset _gestureWorld;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAtlas();
  }

  @override
  void didUpdateWidget(PhotoCanvas old) {
    super.didUpdateWidget(old);
    if (!identical(old.ds, widget.ds)) {
      _n = widget.ds.records.length;
      _fx = List.filled(_n, 0);
      _fy = List.filled(_n, 0);
      _tx = List.filled(_n, 0);
      _ty = List.filled(_n, 0);
      _fa = List.filled(_n, 0);
      _ta = List.filled(_n, 0);
      _cx = List.filled(_n, 0);
      _cy = List.filled(_n, 0);
      _ca = List.filled(_n, 0);
      _delay = List.filled(_n, 0);
      _laidOut = false;
      _loadAtlas();
    }
    final sameActive =
        old.active == widget.active ||
        (old.active != null &&
            widget.active != null &&
            old.active!.length == widget.active!.length &&
            old.active!.containsAll(widget.active!));
    if (!_laidOut ||
        old.layout != widget.layout ||
        old.groupKey != widget.groupKey ||
        !sameActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _relayout(animate: _laidOut);
      });
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _repaint.dispose();
    _atlasStream?.removeListener(_atlasListener);
    super.dispose();
  }

  void _loadAtlas() {
    final url = widget.ds.atlasUrl;
    if (url == null) return;
    final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
    if (stream.key == _atlasStream?.key) return;
    _atlasStream?.removeListener(_atlasListener);
    _atlasStream = stream..addListener(_atlasListener);
  }

  void _onAtlas(ImageInfo info, bool _) {
    if (!mounted) return;
    setState(() => _atlas = info.image);
    _repaint.value++;
  }

  bool _isActive(int i) => widget.active?.contains(i) ?? true;

  // ── 並べ方（ワールド座標＝タイル単位） ──

  void _relayout({required bool animate}) {
    if (_viewport.isEmpty) return;
    for (var i = 0; i < _n; i++) {
      _fx[i] = _cx[i];
      _fy[i] = _cy[i];
      _fa[i] = _ca[i];
    }
    final recs = widget.ds.records;
    final aspect = math.max(
      0.5,
      _viewport.width / math.max(1, _viewport.height),
    );
    final ids = [
      for (var i = 0; i < _n; i++)
        if (_isActive(i)) i,
    ];
    _labels = const [];

    void hideInactive() {
      for (var i = 0; i < _n; i++) {
        if (!_isActive(i)) {
          _tx[i] = _cx[i];
          _ty[i] = _cy[i];
          _ta[i] = 0;
          _delay[i] = 0;
        }
      }
    }

    switch (widget.layout) {
      case CanvasLayout.wall:
        ids.sort((a, b) => recs[a].spectrum.compareTo(recs[b].spectrum));
        final cols = math.max(3, (math.sqrt(ids.length * aspect)).ceil());
        for (var k = 0; k < ids.length; k++) {
          final i = ids[k];
          _tx[i] = (k % cols).toDouble();
          _ty[i] = (k ~/ cols).toDouble();
          _ta[i] = 1;
          _delay[i] = k / math.max(1, ids.length) * _staggerMax;
        }
        hideInactive();
      case CanvasLayout.group:
        _layoutGroups(ids, aspect);
        hideInactive();
      case CanvasLayout.wheel:
      case CanvasLayout.hueLight:
        for (var i = 0; i < _n; i++) {
          final p = widget.layout == CanvasLayout.wheel
              ? recs[i].wheelPos
              : recs[i].hueLightPos;
          if (p == null) {
            _tx[i] = _cx[i];
            _ty[i] = _cy[i];
            _ta[i] = 0;
            continue;
          }
          _tx[i] = p.x;
          _ty[i] = p.y;
          _ta[i] = _isActive(i) ? 1 : 0.07;
          _delay[i] = recs[i].spectrum / math.max(1, _n) * _staggerMax;
        }
    }

    if (!animate) {
      // 初回は動かさずにその場へ置く（散らばった状態から飛んでこない）。
      for (var i = 0; i < _n; i++) {
        _fx[i] = _cx[i] = _tx[i];
        _fy[i] = _cy[i] = _ty[i];
        _fa[i] = _ta[i];
        _ca[i] = _ta[i];
      }
    }
    _laidOut = true;
    _fitCamera(animate: animate);
  }

  /// 分组：グループごとに正方形に近いタイル塊を作り、棚詰めで並べる。
  void _layoutGroups(List<int> ids, double aspect) {
    final recs = widget.ds.records;
    final key = widget.groupKey;
    final groups = <String, List<int>>{};
    for (final i in ids) {
      (groups[canvasGroupValue(recs[i], key)] ??= []).add(i);
    }
    var keys = groups.keys.toList();
    if (key == 'cn') {
      keys = [
        ...kColorSwatch.keys.where(groups.containsKey),
        ...keys.where((k) => !kColorSwatch.containsKey(k)),
      ];
    } else {
      keys.sort((a, b) => groups[b]!.length.compareTo(groups[a]!.length));
    }
    final multi = keys.length > 1;
    final minW = multi ? 7 : 0;
    final blocks = [
      for (final v in keys)
        () {
          final items = groups[v]!
            ..sort((a, b) => recs[a].spectrum.compareTo(recs[b].spectrum));
          final cols = math.max(1, math.sqrt(items.length).ceil());
          final rows = (items.length / cols).ceil();
          return (
            v: v,
            items: items,
            cols: cols,
            w: math.max(cols, minW),
            h: rows,
          );
        }(),
    ];
    final gx = multi ? 3 : 0, gy = multi ? 4 : 0;
    final area = blocks.fold<double>(
      0,
      (s, b) => s + (b.w + gx) * (b.h + gy).toDouble(),
    );
    final rowW = math.max(
      blocks.isEmpty
          ? 10.0
          : blocks.map((b) => b.w).reduce(math.max).toDouble(),
      math.sqrt(area * aspect) * 1.05,
    );
    final shelves = <List<int>>[]; // blocks の index
    var shelf = <int>[];
    var shelfW = 0.0;
    for (var bi = 0; bi < blocks.length; bi++) {
      final b = blocks[bi];
      if (shelf.isNotEmpty && shelfW + b.w > rowW) {
        shelves.add(shelf);
        shelf = [];
        shelfW = 0;
      }
      shelf.add(bi);
      shelfW += b.w + gx;
    }
    if (shelf.isNotEmpty) shelves.add(shelf);

    final labels = <_Label>[];
    var y = 0.0;
    for (final sh in shelves) {
      final w = sh.fold<double>(0, (s, bi) => s + blocks[bi].w + gx) - gx;
      var x = ((rowW - w) / 2).roundToDouble();
      var h = 0;
      for (final bi in sh) {
        final b = blocks[bi];
        for (var k = 0; k < b.items.length; k++) {
          final i = b.items[k];
          _tx[i] = x + (k % b.cols);
          _ty[i] = y + (k ~/ b.cols);
          _ta[i] = 1;
          _delay[i] = k / b.items.length * _staggerMax;
        }
        if (multi) {
          labels.add(
            _Label(x, y, '${widget.groupLabel(key, b.v)}  ${b.items.length}'),
          );
        }
        x += b.w + gx;
        h = math.max(h, b.h);
      }
      y += h + gy;
    }
    _labels = labels;
  }

  /// 見えている写真がちょうど画面に収まるカメラ。
  void _fitCamera({required bool animate}) {
    var x0 = double.infinity, y0 = double.infinity;
    var x1 = -double.infinity, y1 = -double.infinity;
    for (var i = 0; i < _n; i++) {
      if (_ta[i] < 0.5) continue;
      x0 = math.min(x0, _tx[i]);
      y0 = math.min(y0, _ty[i]);
      x1 = math.max(x1, _tx[i] + 1);
      y1 = math.max(y1, _ty[i] + 1);
    }
    if (x0 == double.infinity) {
      _repaint.value++;
      return;
    }
    if (_labels.isNotEmpty) y0 -= 3;
    if (widget.layout == CanvasLayout.wheel) {
      x0 -= 3;
      x1 += 3;
      y0 -= 3;
      y1 += 3;
    }
    const pad = 16.0;
    final aw = _viewport.width - pad * 2, ah = _viewport.height - pad * 2;
    final k = math.min(math.min(aw / (x1 - x0), ah / (y1 - y0)), 140.0);
    final target = _Cam(
      k,
      pad + aw / 2 - (x0 + x1) / 2 * k,
      pad + ah / 2 - (y0 + y1) / 2 * k,
    );
    _camFrom = _cam.copy();
    _camTo = target;
    if (animate) {
      _anim.forward(from: 0);
    } else {
      _cam = target.copy();
      _anim.value = 1;
      _repaint.value++;
    }
  }

  // ── アニメーション ──

  void _tick() {
    final v = _anim.value;
    for (var i = 0; i < _n; i++) {
      final d = _delay[i];
      final local = ((v - d) / (1 - _staggerMax)).clamp(0.0, 1.0);
      final e = Curves.easeInOutCubic.transform(local);
      _cx[i] = _fx[i] + (_tx[i] - _fx[i]) * e;
      _cy[i] = _fy[i] + (_ty[i] - _fy[i]) * e;
      _ca[i] = _fa[i] + (_ta[i] - _fa[i]) * e;
    }
    final c = Curves.easeInOutCubic.transform(v);
    _cam = _Cam(
      _camFrom.k + (_camTo.k - _camFrom.k) * c,
      _camFrom.x + (_camTo.x - _camFrom.x) * c,
      _camFrom.y + (_camTo.y - _camFrom.y) * c,
    );
    _repaint.value++;
  }

  // ── ジェスチャ（ドラッグ＝移動、2 本指＝拡縮、ダブルタップ＝拡大） ──

  void _zoomAt(Offset focal, double factor) {
    final k = (_cam.k * factor).clamp(2.0, 400.0);
    final wx = (focal.dx - _cam.x) / _cam.k, wy = (focal.dy - _cam.y) / _cam.k;
    _cam = _Cam(k, focal.dx - wx * k, focal.dy - wy * k);
    _repaint.value++;
  }

  void _onScaleStart(ScaleStartDetails d) {
    _anim.stop();
    // 補間途中で止めたら、その時点の位置を確定させる。
    _gestureStart = _cam.copy();
    _gestureWorld = Offset(
      (d.localFocalPoint.dx - _cam.x) / _cam.k,
      (d.localFocalPoint.dy - _cam.y) / _cam.k,
    );
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final k = (_gestureStart.k * d.scale).clamp(2.0, 400.0);
    _cam = _Cam(
      k,
      d.localFocalPoint.dx - _gestureWorld.dx * k,
      d.localFocalPoint.dy - _gestureWorld.dy * k,
    );
    _repaint.value++;
  }

  void _onTapUp(TapUpDetails d) {
    final wx = (d.localPosition.dx - _cam.x) / _cam.k;
    final wy = (d.localPosition.dy - _cam.y) / _cam.k;
    // 手前（後に描いたもの）から探す。
    for (var i = _n - 1; i >= 0; i--) {
      if (_ca[i] < 0.5) continue;
      if (wx >= _cx[i] &&
          wx <= _cx[i] + _gap &&
          wy >= _cy[i] &&
          wy <= _cy[i] + _gap) {
        widget.onOpen(widget.items[i]);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        if (size != _viewport) {
          final first = _viewport.isEmpty;
          _viewport = size;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (first || !_laidOut) {
              _relayout(animate: false);
            } else {
              _fitCamera(animate: false);
            }
          });
        }
        return Listener(
          // 電脳（Windows 開発時）のホイールで拡縮。
          onPointerSignal: (e) {
            if (e is PointerScrollEvent) {
              _zoomAt(e.localPosition, e.scrollDelta.dy < 0 ? 1.15 : 1 / 1.15);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onTapUp: _onTapUp,
            onDoubleTapDown: (d) => _zoomAt(d.localPosition, 2.2),
            onDoubleTap: () {},
            child: ClipRect(
              child: CustomPaint(
                size: size,
                painter: _CanvasPainter(this, repaint: _repaint),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final _PhotoCanvasState s;
  _CanvasPainter(this.s, {required Listenable repaint})
    : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final cam = s._cam;
    final k = cam.k;
    final tileW = k * _PhotoCanvasState._gap;
    final atlas = s._atlas;
    final ds = s.widget.ds;
    final tile = ds.atlasTile.toDouble();
    final cols = ds.atlasCols;

    final transforms = <RSTransform>[];
    final rects = <Rect>[];
    final colors = <Color>[];
    final fallback = Paint();
    for (var i = 0; i < s._n; i++) {
      final a = s._ca[i];
      if (a < 0.01) continue;
      final x = s._cx[i] * k + cam.x, y = s._cy[i] * k + cam.y;
      if (x > size.width || y > size.height || x + tileW < 0 || y + tileW < 0) {
        continue;
      }
      if (atlas != null) {
        transforms.add(
          RSTransform.fromComponents(
            rotation: 0,
            scale: tileW / tile,
            anchorX: 0,
            anchorY: 0,
            translateX: x,
            translateY: y,
          ),
        );
        rects.add(
          Rect.fromLTWH((i % cols) * tile, (i ~/ cols) * tile, tile, tile),
        );
        colors.add(Color.fromRGBO(255, 255, 255, a));
      } else {
        // atlas 読込前は代表色の四角で場所だけ見せる。
        fallback.color = s.widget.items[i].placeholder.withValues(alpha: a);
        canvas.drawRect(Rect.fromLTWH(x, y, tileW, tileW), fallback);
      }
    }
    if (atlas != null && transforms.isNotEmpty) {
      canvas.drawAtlas(
        atlas,
        transforms,
        rects,
        colors,
        BlendMode.modulate,
        null,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    // 分组のラベル（画面上で一定の大きさ）。
    for (final l in s._labels) {
      final x = l.x * k + cam.x, y = l.y * k + cam.y;
      if (x > size.width || y > size.height || y < -40) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: l.text,
          style: AppText.caption().copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: 220);
      tp.paint(canvas, Offset(x, y - tp.height - 4));
    }
  }

  @override
  bool shouldRepaint(_CanvasPainter old) => true;
}
