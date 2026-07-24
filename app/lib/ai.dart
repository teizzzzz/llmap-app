/// 端末から直接 Claude/Gemini を叩く AI 判定（backend/app/ai.py を移植）。
/// API キーは設定画面で端末内に保存し、ここから各社 API へ直接送る（後端不要）。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'schema_defaults.dart';

// 採集字段定義表 v6（2026-07-24）に準拠。AI は「下書き(ai)」を担い、人が校閲して確定する。
// v6 の 2 大規則:
//   1) 既存内容は消さない — 併合はアプリ側 record_ops.mergeAiDraft が行うため、
//      AI は備考に「新規観察のみ」を書く（既存の再掲・書き換えをしない）。
//   2) 不確実は空欄 — 自信を持てない字段は "" を返し、推測で埋めない。
const String _systemPrompt =
    'あなたは言語景観（linguistic landscape）研究の専門家です。'
    '都市の公共空間にある看板・サイン・貼り紙・標識の写真を分析し、研究用の字段を下書きします。'
    '方針は「採集從寬・分析從嚴」: 客観的に観察できることだけを記します。'
    '各字段は与えられた選択肢から最も適切な値を**そのままの表記**で選びます'
    '（「複数可」と示した言語のみ、等価なものは「/」で併記してよい。選択肢に無い言語名は直接記入してよい）。'
    '写真から判定できない・自信が持てない字段は、推測で埋めずに空文字列 "" を返します。'
    '内容を読む必要がある字段が読めない場合は「判读不能」を選びます。'
    '備考にはこの写真から新たに観察できたことだけを書き、判断理由は「【判断】」、'
    '同一載体上の同款重複数は「【数量】×N」の接頭辞を使います（既存データの再掲・書き換えはしない）。'
    '必ず指定された JSON 形式のみで回答し、前置き・説明・マークダウン・コードフェンスは付けません。';

// v6「人（AI 起草）」13 維度の判定ガイド（定義表の意思・例子列を圧縮）。
// 値は schema_defaults.kEnums の正準表記と一字一句一致させること。
const Map<String, String> _fieldGuide = {
  '文字性':
      '文字 / 記号 / 対象外。第一軸=言語として読める文字を含むか。'
      '駐禁・矢印・トイレ図标=記号；装飾挿絵・純図形logo=対象外；記号+文字の混在=文字',
  '主要言語':
      '視覚的に支配的な言語（code preference）。判定順 ①視覚面積最大 → ②位置最中心 → ③字号最大。'
      '日本語/韓国語/中国語/ベトナム語/ネパール語/英語、他の言語は名前を直接記入。'
      '三項等権重なら「日本語/韓国語」のように併記し無理に一つへ絞らない。判別不能のみ「その他」',
  '補助言語':
      '次要だが情報を伝える言語（複数可、無は —）。'
      '口訣: それを外すと情報が欠ける→補助；見栄えだけ→装飾の言語へ',
  '装飾の言語':
      'ほぼ情報を伝えず装飾・ブランド識別・雰囲気のための言語（複数可、無は —）。'
      '欧文の格調的使用・芸術字logo。logoがブランド識別のみ→ここに記し主要言語に数えない',
  '多言語関係':
      '单语型 / 复制型 / 重复型 / 部分翻译型（Reh 2004: Monolingual/Duplicating/Overlapping/Fragmentary）。'
      '各言語の内容が完全同一→复制型；完全情報が一言語のみで他言語は断片訳→部分翻译型；単一言語→单语型',
  '担体類型':
      '无媒介 / 产品 / 贴纸 / 旗帜 / 海报 / 宣传册 / 夹心板 / 车辆 / 便签 / 其他。'
      '无媒介=文字が固定位置/物体に直接ある；产品=衣服・鞄・新聞等；海报=臨時掲示でA4より大きい紙；'
      '夹心板=路上の自立式看板(gatupratare)；车辆=自転車・車・バス・トラック等；'
      '便签=簡易レイアウトの臨時貼紙でA4未満・テープ/画鋲どめ',
  '放置位置':
      '建筑物上 / 柱子 / 公告板 / 屏幕 / 道路 / 市政设施设备 / 半可移动物体 / 其他。'
      '建筑物上=壁・扉・窓；柱子=建物から独立した柱；屏幕=自立式(デジタル/アナログ)；'
      '道路=歩道・広場・駐車場を含む；市政设施设备=パーキングメーター・郵便ポスト・配電箱等；'
      '半可移动物体=ゴミ箱・ベンチ・テーブル・足場・工事フェンス・コンテナ等；其他=人など',
  '時間性':
      '常设 / 临时·季节性 / 一过性。判定順: ①明確な失効日付があれば日付に従う '
      '②固定方式を見る: 溶接・ボルト→常设／フック・掛け外し可→临时·季节性／テープ・画鋲・易剥離→一过性 '
      '③材質で曖昧なら内容で判断。区分線: 撤去したら終わり=一过性；来季また掛かる=临时·季节性',
  '可読性':
      '完全可读 / 部分可读 / 判读困难。文字の物理的明瞭度のみ（言語が分かるかとは切り離す）。'
      '劣化・褪色・破損→部分可读/判读困难。部分可读の場合は備考に理由（磨損か字体芸術化か）を必ず書く',
  '重ね書き':
      '无 / 有（新覆旧） / 有（多层堆叠）。物理的な叠写・覆盖・修改の痕跡。'
      '旧字を新字が覆う・ステッカーの層状堆積→有',
  'ディスコース類型':
      '规约性话语 / 基础设施话语 / 商业话语 / 交际性话语 / 判读不能 / 其他（Scollon & Scollon 2003）。'
      '判定順: ①交际性(Transgressive:涂鸦・未授権貼付・私的メモ) → ②规约性(行動を規制:禁止・警告・指示) '
      '→ ③基础设施(施設の身元表示:門牌・路牌・電柱番号・楼層指示) → ④商业(販売・広告・招徕)。'
      '内容が読めなければ判读不能',
  '製作品質':
      '专业印刷 / 半专门 / 手作。工芸水準のみを見る（内容は見ない）。'
      '专业印刷=アルミ看板・発光文字・チェーン統一店招；'
      '半专门=家庭用プリンタ印刷・通販簡易横断幕・AI生成ポスター（機械は介在するが専門デザイン/業者なし）；'
      '手作=手書き・手描き・自作紙',
  '備考':
      'この写真からの新規観察のみ（自由記述）。分類の迷い・例外・境界判断の理由は「【判断】」接頭辞、'
      '同一載体上の同款重複数は「【数量】×N」。書くことが無ければ空文字列',
};

String _buildPrompt(List<String> fields) {
  // v6 対象外の旧字段（名称/文字体系/空間階層/設置主体）が呼び出し側から
  // 渡されても AI には出さない（kAiFields = v6 の 13 維度が正）。
  final requested = fields.isEmpty ? kAiFields : fields;
  final use = requested.where(kAiFields.contains).toList();
  final body = (use.isEmpty ? kAiFields : use)
      .map((f) => '  "$f": "${_fieldGuide[f] ?? '判定結果（不確実なら \\"\\"）'}"')
      .join(',\n');
  return 'この写真の看板・サイン・貼り紙を分析してください。\n'
      '各値は説明文でなく判定結果そのもの。判定できない字段は空文字列 "" にしてください。\n'
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
      'max_tokens': 1500, // v6 は 13 字段＋備考の自由記述 — 1000 だと切れ得る
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
