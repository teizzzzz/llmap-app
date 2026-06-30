/// 地図ピンの詳情カード（言語色ヘッダ＋主要字段）。MapScreen / Home で共用。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models.dart';
import '../../theme.dart' show statusBadge;
import '../../theme/tokens.dart';

class LLMapDetailCard extends StatelessWidget {
  final Sign sign;
  final AppSchema schema;
  final VoidCallback onClose;
  const LLMapDetailCard({
    super.key,
    required this.sign,
    required this.schema,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final color =
        parseHexColor(schema.languageColors[sign.mainLangPrimary] ?? '#888888');
    final suffix = sign.id.split('-').last;
    String v(String k) => sign.get(k).isEmpty ? '—' : sign.get(k);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceIvory,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.floating,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: color,
            padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white,
                  child: Text(suffix,
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sign.name.isEmpty ? t.untitled : sign.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: Colors.white),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(sign.id, style: AppText.caption()),
                    ),
                    statusBadge(sign.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _kv(t.mainLanguage, v('主要言語')),
                    _kv(t.subLanguage, v('補助言語')),
                    _kv(t.operator, v('設置主体')),
                    _kv(t.carrier, v('担体類型')),
                    _kv(t.sourceType, v('ディスコース類型')),
                    _kv(t.multilingual, v('多言語関係')),
                  ],
                ),
                if (sign.get('備考').isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(t.noteLabel(sign.get('備考')), style: AppText.caption()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String val) => SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: AppText.caption().copyWith(fontSize: 10)),
            Text(val,
                style: AppText.body()
                    .copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
