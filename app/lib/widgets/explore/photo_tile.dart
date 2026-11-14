/// 瀑布流の 1 枚（写真が主役：角丸＋自然な縦横比、文字は最小限）。
/// 縦横比は画像の読込時に分かるので、分かるまでは下地色の仮比率で置き、
/// 分かった比率はキャッシュして再表示時にガタつかないようにする。
library;

import 'package:flutter/material.dart';

import '../../explore/photo_item.dart';
import '../../models.dart';
import '../../theme/tokens.dart';

class PhotoTile extends StatefulWidget {
  final PhotoItem item;
  final AppSchema schema;
  final VoidCallback onTap;

  /// 左上に重ねる小さな状態タグ（我的の「待补充」など）。
  /// 写真の上には色点などの印を置かない（写真そのものを見せる）。
  final String? badge;

  const PhotoTile({
    super.key,
    required this.item,
    required this.schema,
    required this.onTap,
    this.badge,
  });

  @override
  State<PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<PhotoTile> {
  static final Map<String, double> _ratios = {}; // key → 幅/高さ
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(
    _onImage,
    onError: (_, _) {},
  );

  /// 一覧用に縮小デコードする（端末の元写真は 4000px 級のため）。
  ImageProvider? get _provider {
    final img = widget.item.image;
    if (img == null) return null;
    return ResizeImage(img, width: 480, policy: ResizeImagePolicy.fit);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(PhotoTile old) {
    super.didUpdateWidget(old);
    if (old.item.key != widget.item.key) _resolve();
  }

  void _resolve() {
    if (_ratios.containsKey(widget.item.key)) return;
    final p = _provider;
    if (p == null) return;
    final next = p.resolve(createLocalImageConfiguration(context));
    if (next.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = next..addListener(_listener);
  }

  void _onImage(ImageInfo info, bool _) {
    final w = info.image.width, h = info.image.height;
    if (w > 0 && h > 0) {
      _ratios[widget.item.key] = (w / h).clamp(0.45, 2.2);
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final ratio = _ratios[item.key] ?? 0.78;
    final provider = _provider;
    return GestureDetector(
      onTap: widget.onTap,
      child: AspectRatio(
        aspectRatio: ratio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: item.placeholder.withValues(alpha: 0.55)),
              if (provider != null)
                Image(
                  image: provider,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  frameBuilder: (_, child, frame, sync) => sync
                      ? child
                      : AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: const Duration(milliseconds: 220),
                          child: child,
                        ),
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else
                const Center(
                  child: Icon(
                    Icons.image_outlined,
                    color: AppColors.textSecondary,
                  ),
                ),
              if (widget.badge != null)
                Positioned(left: 8, top: 8, child: _Badge(widget.badge!)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        style: AppText.caption().copyWith(color: Colors.white, fontSize: 10.5),
      ),
    );
  }
}

/// 言語コードの小チップ（色点＋名前）。详情・筛选で共用。
class LangChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool strong;
  const LangChip({
    super.key,
    required this.label,
    required this.color,
    this.strong = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: strong ? 0.16 : 0.07),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppText.caption().copyWith(
              color: AppColors.textPrimary,
              fontWeight: strong ? FontWeight.w600 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
