import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/sign_form.dart';

/// 既存 sign の編集（②の追加要望）。フォームはウィザードと共用。
/// 戻り値: 'saved' 保存 / 'deleted' 削除 / null キャンセル。
class EditSignScreen extends StatefulWidget {
  final Sign sign;
  final AppSchema schema;
  const EditSignScreen({super.key, required this.sign, required this.schema});

  @override
  State<EditSignScreen> createState() => _EditSignScreenState();
}

class _EditSignScreenState extends State<EditSignScreen> {
  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('${widget.sign.id} を削除しますか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.pop(context, 'deleted');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('編集'),
        actions: [
          IconButton(
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline),
            tooltip: '削除',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SignForm(
            sign: widget.sign,
            schema: widget.schema,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: () => Navigator.pop(context, 'saved'),
            icon: const Icon(Icons.check),
            label: const Text('保存'),
          ),
        ),
      ),
    );
  }
}
