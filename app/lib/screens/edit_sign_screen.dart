import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/tokens.dart';
import '../widgets/ll/ll.dart';
import '../widgets/sign_form.dart';

/// 既存 sign の編集／削除。フォームはウィザードと共用。
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
    final ok = await showLLDialog<bool>(
      context,
      icon: Icons.delete_outline,
      iconColor: AppColors.danger,
      title: '删除记录',
      message: '确定删除 ${widget.sign.id} 吗？此操作不可撤销。',
      primaryLabel: '删除',
      onPrimary: () => Navigator.pop(context, true),
      secondaryLabel: '取消',
      onSecondary: () => Navigator.pop(context, false),
    );
    if (ok == true && mounted) Navigator.pop(context, 'deleted');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑记录'),
        actions: [
          IconButton(
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline),
            color: AppColors.danger,
            tooltip: '删除',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
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
          padding: const EdgeInsets.all(AppSpacing.md),
          child: LLPrimaryButton(
            label: '保存修改',
            icon: Icons.check,
            onPressed: () => Navigator.pop(context, 'saved'),
          ),
        ),
      ),
    );
  }
}
