/// 端末から直接 Claude/Gemini を叩く AI 判定（backend/app/ai.py を移植）。
/// API キーは設定画面で端末内に保存し、ここから各社 API へ直接送る（後端不要）。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'schema_defaults.dart';

// 採集字段定義表 v3 に準拠。AI は「下書き(ai)」を担い、人が校閲して確定する。
const String _systemPrompt =
    'あなたは言語景観（linguistic landscape）研究の専門家です。'
    '都市の公共空間にある看板・サイン・貼り紙・標識の写真を分析し、研究用の字段を下書きします。'
    '方針は「採集從寬・分析從嚴」: 客観的に観察できることを記し、推測が必要な場合は備考に根拠を書きます。'
    '各字段は与えられた選択肢から最も適切な値を選びます'
    '（「複数可」と示した言語・文字体系のみ、等価なものは「/」で併記してよい）。'
    '読めない言語でも文字体系は字形から判定でき、内容判定が要る字段は「判読不能」を選びます。'
    '必ず指定された JSON 形式のみで回答し、前置き・説明・マークダウン・コードフェンスは付けません。';

const Map<String, String> _fieldGuide = {
  '名称': '標識内容の短い名称（自由記述）',
  '文字性':
      '含文字 / 純記号 / 対象外。駐禁・矢印・トイレ図=純記号；装飾挿絵・図形のみのロゴ=対象外；記号+文字の混在→含文字',
  '主要言語':
      '視覚的に支配的な言語。優先順位 ①面積最大 > ②中心 > ③字号最大。'
      '日本語/韓国語/中国語/ベトナム語/ネパール語/英語/その他。等大の並行は「日本語/韓国語」のように併記',
  '補助言語':
      '次要だが情報を伝える言語（複数可、無は —）。外すと情報が欠ける→補助',
  '装飾の言語':
      '情報をほぼ伝えず装飾/ブランド/雰囲気のための言語（複数可、無は —）。例 英語(ブランド名)。見栄えだけ→装飾',
  '文字体系':
      '書記体系（言語とは別、複数可）。漢字/平仮名/片仮名/ローマ字/ハングル/デーヴァナーガリー/ビルマ文字/タイ文字/ベンガル文字/アラビア/キリル/その他/無。混在は「/」で併記',
  '多言語関係':
      '単言語型 / 複製型 / 重複型 / 部分翻訳型（Reh 2004）。単語なら単言語型',
  '担体類型':
      '路面固定 / 壁面 / 看板 / 移動物体(停車中) / ステッカー / 横断幕 / その他。キッチンカー・停車中トラック→移動物体(停車中)',
  '空間階層':
      '低位・接近可能層 / 中位・視線層 / 高位・天際層。環境の客観参照（部位・階・高度帯）で判定し採集者の身長に依らない',
  '時間性': '常設 / 臨時・季節的 / 一過性。選挙ポスター・季節販促→臨時・季節的',
  '可読性':
      '完全可読 / 部分可読 / 判読困難。物理的明瞭度のみ（言語が分かるかとは切り離す）。劣化・褪色・破損→部分可読/判読困難',
  '重ね書き':
      '無 / 有(新が旧を上書き) / 有(多層の堆積)。旧字を新字が覆う・ステッカー堆積→有',
  '設置主体':
      '行政・公共機関 / 商業・チェーン / 商業・個人店 / 個人 / 団体 / 不明。客観的に「誰が立てたか」',
  'ディスコース類型':
      '規約 / 基礎設施 / 商業 / 越境 / 判読不能 / その他（Scollon 2003）。'
      '判定順: 越境→規約→基礎設施→商業。読めない言語は判読不能',
  '製作品質': '専門印刷 / 半専門 / 手作り',
  '備考': '分類の迷い・例外・補足や境界判断の理由。採集/除外理由は「【判断】」を接頭辞に',
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

/// AI 呼び出しの上限時間。超過時は例外 → snackbar 表示（UI を永久に固めない）。
const _aiTimeout = Duration(seconds: 60);

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
  ).timeout(_aiTimeout);
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
        'models/gemini-2.5-flash:generateContent'),
    headers: {
      'content-type': 'application/json',
      // key は URL クエリでなくヘッダで送る（プロキシ/アクセスログに残さない）。
      'x-goog-api-key': key,
    },
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
  ).timeout(_aiTimeout);
  if (r.statusCode != 200) {
    throw Exception('Gemini API ${r.statusCode}: ${utf8.decode(r.bodyBytes)}');
  }
  final j = jsonDecode(utf8.decode(r.bodyBytes));
  final text =
      j['candidates'][0]['content']['parts'][0]['text'] as String;
  return _stripJson(text);
}
