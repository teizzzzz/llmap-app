import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../models.dart';
import 'crop_screen.dart';
import 'map_screen.dart';

/// 採集ホーム：地区コード・連番を管理し、採集済み sign を一覧／CSV导出。
class HomeScreen extends StatefulWidget {
  final BackendApi api;
  final AppSchema schema;
  const HomeScreen({super.key, required this.api, required this.schema});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Sign> _signs = [];
  String _area = 'HAS';
  int _nextSeq = 1;
  bool _busy = false;

  Future<void> _startCapture() async {
    final picker = ImagePicker();
    // Windows: ファイル選択ダイアログ。モバイルでは後で camera に差し替え。
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    final result = await Navigator.push<List<Sign>>(
      context,
      MaterialPageRoute(
        builder: (_) => CropScreen(
          api: widget.api,
          schema: widget.schema,
          imageBytes: bytes,
          fileName: picked.name,
          area: _area,
          seq: _nextSeq,
        ),
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        _signs.addAll(result);
        _nextSeq++;
      });
    }
  }

  Future<void> _export() async {
    if (_signs.isEmpty) return;
    setState(() => _busy = true);
    try {
      final path = await widget.api.exportCsv(_signs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV を保存しました: $path')),
        );
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
    if (v != null && v.trim().isNotEmpty) setState(() => _area = v.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LLMap 採集'),
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
        ],
      ),
      body: _signs.isEmpty
          ? const Center(
              child: Text('「＋」から写真を取り込み、框选して採集を始めます',
                  style: TextStyle(color: Colors.grey)),
            )
          : ListView.separated(
              itemCount: _signs.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = _signs[i];
                return ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(s.name.isEmpty ? '(名称未入力)' : s.name),
                  subtitle: Text(
                      '${s.id} · ${s.mainLang} · ${s.lat ?? '—'}, ${s.lng ?? '—'}'),
                  trailing: _StatusChip(status: s.status),
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

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = {
          'pending': Colors.grey,
          'ai': Colors.blue,
          'modified': Colors.orange,
          'reviewed': Colors.green,
        }[status] ??
        Colors.grey;
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color),
      visualDensity: VisualDensity.compact,
    );
  }
}
