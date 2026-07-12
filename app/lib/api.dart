/// FastAPI 后端クライアント。
/// C 計画（本地完結化）以降、採集・AI・導出はすべて端末内で完結するため、
/// backend へは /health と /schema しか使わない
/// （旧 /extract・/ai・/export 系のクライアントは Step 14 で削除済み）。
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class BackendApi {
  /// Windows/デスクトップ既定。Android実機/エミュは設定画面で差し替える想定
  /// (emulator: 10.0.2.2 / 実機: PCのLAN IP)。
  String baseUrl;
  BackendApi({this.baseUrl = 'http://localhost:8000'});

  Future<bool> health() async {
    try {
      final r = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<AppSchema> schema() async {
    // 起動時に呼ばれるため必ずタイムアウトを付ける
    // （到達不能な URL 設定でも起動画面で固まらず既定スキーマへ落ちる）。
    final r = await http
        .get(Uri.parse('$baseUrl/schema'))
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) {
      throw Exception('schema 取得失敗: ${r.statusCode}');
    }
    return AppSchema.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }
}
