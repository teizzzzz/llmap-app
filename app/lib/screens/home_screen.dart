import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../capture.dart';
import '../models.dart';
import '../settings.dart';
import '../store.dart';
import '../theme.dart';
import '../version.dart';
import 'crop_screen.dart';
import 'edit_sign_screen.dart';
import 'map_screen.dart';

/// 採集ホーム：地区コード・連番を管理し、採集済み sign を一覧／CSV导出。
class HomeScreen extends StatefulWidget {
  final BackendApi api;
  final AppSchema schema;
  const HomeScreen({super.key, required this.api, required this.schema});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  final List<Sign> _signs = [];
  String _area = 'HAS';
  int _nextSeq = 1;
  bool _busy = false;
  bool _opening = false; // 二重起動防止
  AiConfig _ai = AiConfig();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadAiConfig().then((c) {
      if (mounted) setState(() => _ai = c);
    });
    // 端末内に保存した採集記録を復元（アプリ再起動後もデータが残る）。
    _loadSaved();
    // カメラ起動中に Android が Activity を破棄して写真が失われる事象の復旧。
    _recoverLostData();
  }

  /// 端末内の保存データを読み込み、一覧・地区・連番を復元する。
  Future<void> _loadSaved() async {
    final p = await LocalStore.instance.loadProject();
    if (p == null || !mounted) return;
    setState(() {
      _signs
        ..clear()
        ..addAll(p.signs);
      _area = p.area;
      _nextSeq = p.nextSeq;
    });
  }

  /// 現在の採集記録とセッション（地区/連番）を端末に保存する。
  void _persist() {
    LocalStore.instance.saveProject(_signs, _area, _nextSeq);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recoverLostData();
  }

  /// 撮影直後に Activity 再生成で失われた写真を image_picker から復旧。
  Future<void> _recoverLostData() async {
    if (!isMobile) return;
    final lost = await ImagePicker().retrieveLostData();
    if (lost.isEmpty || lost.file == null) return;
    final x = lost.file!;
    final bytes = await x.readAsBytes();
    if (!mounted) return;
    _openCrop(bytes, x.name);
  }

  Future<void> _startCapture() async {
    if (_opening) return;
    // モバイル: カメラ/ギャラリー選択。デスクトップ: ファイル取り込み。
    final shot = await capturePhoto(context);
    if (shot == null || !mounted) return;
    _openCrop(shot.bytes, shot.fileName);
  }

  /// 框选画面へ。GPS は CropScreen 側で非ブロッキング取得する。
  Future<void> _openCrop(Uint8List bytes, String fileName) async {
    if (_opening) return;
    _opening = true;
    try {
      final result = await Navigator.push<List<Sign>>(
        context,
        MaterialPageRoute(
          builder: (_) => CropScreen(
            api: widget.api,
            schema: widget.schema,
            imageBytes: bytes,
            fileName: fileName,
            area: _area,
            seq: _nextSeq,
            aiConfig: _ai,
          ),
        ),
      );
      if (result != null && result.isNotEmpty && mounted) {
        setState(() {
          _signs.addAll(result);
          _nextSeq++;
        });
        _persist();
      }
    } finally {
      _opening = false;
    }
  }

  /// CSV＋写真を ZIP で一括エクスポート。モバイルは共有シート、
  /// デスクトップは Downloads に保存。
  Future<void> _export() async {
    if (_signs.isEmpty) return;
    setState(() => _busy = true);
    try {
      // 端末内の写真と記録から ZIP を生成（後端不要／PC off 可）。
      final zipPath =
          await LocalStore.instance.buildBundle(_signs, widget.schema.csvHeader);
      if (!mounted) return;
      if (isMobile) {
        await Share.shareXFiles(
          [XFile(zipPath)],
          text: 'LLMap export (${_signs.length} 件)',
        );
      } else {
        final dir = Platform.environment['USERPROFILE'] ??
            Directory.systemTemp.path;
        final dest = File('$dir/Downloads/llmap_export.zip');
        await dest.parent.create(recursive: true);
        await File(zipPath).copy(dest.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('一括エクスポート: ${dest.path}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push<({String baseUrl, AiConfig ai})>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(baseUrl: widget.api.baseUrl, ai: _ai),
      ),
    );
    if (result == null) return;
    await saveBaseUrl(result.baseUrl);
    await saveAiConfig(result.ai);
    widget.api.baseUrl = result.baseUrl;
    if (mounted) {
      setState(() => _ai = result.ai);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を保存しました（URL変更は次回起動から有効）')),
      );
    }
  }

  Future<void> _editSign(int i) async {
    final r = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditSignScreen(sign: _signs[i], schema: widget.schema),
      ),
    );
    if (!mounted) return;
    if (r == 'deleted') {
      setState(() => _signs.removeAt(i));
      _persist();
    } else if (r == 'saved') {
      setState(() {});
      _persist();
    }
  }

  Future<void> _editArea() async {
    final ctrl = TextEditingController(text: _area);
    final v = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('地区コード (3文字)'),
        content: TextField(
          controller: ctrl,
          maxLength: 3,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'HAS / YKH / SKO ...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.toUpperCase()),
              child: const Text('OK')),
        ],
      ),
    );
    if (v != null && v.trim().isNotEmpty) {
      setState(() => _area = v.trim());
      _persist();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('LLMap 採集'),
            Text(kAppVersion,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                )),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _editArea,
            icon: const Icon(Icons.place_outlined),
            label: Text('$_area  #$_nextSeq'),
          ),
          IconButton(
            onPressed: _signs.isEmpty
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MapScreen(
                            signs: _signs, schema: widget.schema),
                      ),
                    ),
            icon: const Icon(Icons.map_outlined),
            tooltip: '地図预览',
          ),
          IconButton(
            onPressed: _signs.isEmpty || _busy ? null : _export,
            icon: const Icon(Icons.download),
            tooltip: 'CSV导出',
          ),
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
            tooltip: '設定',
          ),
        ],
      ),
      body: _signs.isEmpty
          ? _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: _signs.length,
              itemBuilder: (_, i) {
                final s = _signs[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Dismissible(
                    key: ValueKey('${s.id}-$i'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      decoration: BoxDecoration(
                        color: llDestructive,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      child: const Icon(Icons.delete_outline,
                          color: Colors.white),
                    ),
                    confirmDismiss: (_) async => await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('削除確認'),
                        content: Text('${s.id} を削除しますか？'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('取消')),
                          FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: llDestructive),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('削除'),
                          ),
                        ],
                      ),
                    ),
                    onDismissed: (_) {
                      setState(() => _signs.removeAt(i));
                      _persist();
                    },
                    child: _SignCard(
                      sign: s,
                      index: i,
                      onTap: () => _editSign(i),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _startCapture,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('採集'),
      ),
    );
  }
}

/// 採集一覧の1枚カード（エディトリアル調）。
class _SignCard extends StatelessWidget {
  final Sign sign;
  final int index;
  final VoidCallback onTap;
  const _SignCard(
      {required this.sign, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasGps = sign.lat != null && sign.lng != null;
    return Material(
      color: llCard,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: llMuted,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('${index + 1}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: llForeground)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sign.name.isEmpty ? '(名称未入力)' : sign.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(hasGps ? Icons.place : Icons.location_off,
                            size: 13, color: llMutedFg),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '${sign.id}'
                            '${sign.mainLang.isEmpty ? '' : ' · ${sign.mainLang}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: llMutedFg),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              statusBadge(sign.status),
            ],
          ),
        ),
      ),
    );
  }
}

/// 採集ゼロ件のときの空状態。
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: llCard,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(Icons.add_a_photo_outlined,
                size: 38, color: llPrimary),
          ),
          const SizedBox(height: 20),
          Text('採集をはじめる',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              '「採集」から写真を撮影・取り込み、看板を框选して記録します。',
              textAlign: TextAlign.center,
              style: TextStyle(color: llMutedFg, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
