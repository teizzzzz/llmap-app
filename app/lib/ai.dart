/// 端末から直接 Claude/Gemini を叩く AI 判定（backend/app/ai.py を移植）。
/// API キーは設定画面で端末内に保存し、ここから各社 API へ直接送る（後端不要）。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'schema_defaults.dart';

const String _systemPrompt =
    'あなたは言語景観研究の専門家です。都市の公共空間の看板・サイン・貼り紙の'
    '写真を分析します。必ずJSON形式のみで回答してください。';

const Map<String, String> _fieldGuide = {
  '名称': '看板の内容を簡潔に',
  '主要言語': '日本語 or 中文 or 韓国語 or 英語 or その他',
  '補助言語': '日本語 or 中文 or 韓国語 or 英語 or その他 or —',
  '装飾的言語': '英語(ブランド名) or 英語(装飾) or その他 or —',
  '設置主体': '行政/公共機関 or 商業 or 個人/非正式 or 不明',
  '担体類型':
      '建物固定(看板) or 建物固定(壁画) or 建物固定(門牌) or 移動物体(停車中) or 貼付物(ポスター) or 貼付物(ステッカー) or 路面固定 or デジタル表示(LED) or その他',
  '来源類型': 'top-down(標準化) or bottom-up(ローカル自作) or 不明',
  '多言語関係': '平行型 or 補完型 or 象徴型 or 単言語型',
  '備考': '特記事項があれば簡潔に',
};

String _buildPrompt(List<String> fields) {
  final use = fields.isEmpty ? kAiFields : fields;
  final body = use
      .map((f) => '  "$f": "${_fieldGuide[f] ?? '判定結果'}"')
      .join(',\n');
  return 'この写真の看板・サイン・貼り紙を分析してください。\n'
      '以下のJSON形式のみで回答してください。前置き・説明・マークダウンは不要です：\n\n'
      '{\n$body\n}';
}

/// §9 のAI推奨: 最大辺1024 / quality75 に圧縮して base64 化（別アイソレート）。
String _toBase64Entry(Uint8List src) {
  final image = img.decodeImage(src);
  if (image == null) return base64Encode(src);
  var out = image;
  final longSide = image.width > image.height ? image.width : image.height;
  if (longSide > 1024) {
    out = (image.width >= image.height)
        ? img.copyResize(image, width: 1024)
        : img.copyResize(image, height: 1024);
  }
  return base64Encode(img.encodeJpg(out, quality: 75));
}

Future<String> _imageToBase64(Uint8List src) =>
    compute(_toBase64Entry, src);

/// モデル出力から最初の JSON オブジェクトを取り出す。
Map<String, dynamic> _stripJson(String text) {
  final m = RegExp(r'\{.*\}', dotAll: true).firstMatch(text.trim());
  if (m == null) return {};
  try {
    return Map<String, dynamic>.from(jsonDecode(m.group(0)!));
  } catch (_) {
    return {};
  }
}

/// 写真バイト列を判定し字段 dict を返す。provider: 'claude' | 'gemini'。
Future<Map<String, dynamic>> judge({
  required Uint8List photoBytes,
  required String provider,
  required List<String> fields,
  required String apiKey,
}) async {
  if (apiKey.isEmpty) {
    throw Exception('API キーが未設定です（設定画面で入力してください）');
  }
  final b64 = await _imageToBase64(photoBytes);
  return provider == 'gemini'
      ? _judgeGemini(b64, fields, apiKey)
      : _judgeClaude(b64, fields, apiKey);
}

Future<Map<String, dynamic>> _judgeClaude(
    String b64, List<String> fields, String key) async {
  final r = await http.post(
    Uri.parse('https://api.anthropic.com/v1/messages'),
    headers: {
      'x-api-key': key,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: jsonEncode({
      'model': 'claude-haiku-4-5-20251001',
      'max_tokens': 1000,
      'system': _systemPrompt,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': 'image/jpeg',
                'data': b64,
              },
            },
            {'type': 'text', 'text': _buildPrompt(fields)},
          ],
        },
      ],
    }),
  );
  if (r.statusCode != 200) {
    throw Exception('Claude API ${r.statusCode}: ${utf8.decode(r.bodyBytes)}');
  }
  final j = jsonDecode(utf8.decode(r.bodyBytes));
  // content はブロック配列。type=="text" の最初のブロックを拾う
  // (将来 thinking ブロックが先頭に来ても壊れないように)。
  final blocks = (j['content'] as List).cast<Map<String, dynamic>>();
  final textBlock = blocks.firstWhere(
    (b) => b['type'] == 'text',
    orElse: () => {'text': ''},
  );
  return _stripJson((textBlock['text'] ?? '').toString());
}

Future<Map<String, dynamic>> _judgeGemini(
    String b64, List<String> fields, String key) async {
  final r = await http.post(
    Uri.parse('https://generativelanguage.googleapis.com/v1beta/'
        'models/gemini-2.5-flash:generateContent?key=$key'),
    headers: {'content-type': 'application/json'},
    body: jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': '$_systemPrompt\n\n${_buildPrompt(fields)}'},
            {
              'inline_data': {'mime_type': 'image/jpeg', 'data': b64},
            },
          ],
        },
      ],
    }),
  );
  if (r.statusCode != 200) {
    throw Exception('Gemini API ${r.statusCode}: ${utf8.decode(r.bodyBytes)}');
  }
  final j = jsonDecode(utf8.decode(r.bodyBytes));
  final text =
      j['candidates'][0]['content']['parts'][0]['text'] as String;
  return _stripJson(text);
}
