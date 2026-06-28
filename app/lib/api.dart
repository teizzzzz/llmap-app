/// FastAPI 后端クライアント。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
    final r = await http.get(Uri.parse('$baseUrl/schema'));
    if (r.statusCode != 200) {
      throw Exception('schema 取得失敗: ${r.statusCode}');
    }
    return AppSchema.fromJson(jsonDecode(utf8.decode(r.bodyBytes)));
  }

  /// 写真＋框选から sign 群を生成（③④）。
  Future<List<Sign>> extract({
    required Uint8List photoBytes,
    required String fileName,
    required String area,
    required int seq,
    required List<CropRegion> crops,
    double? fallbackLat,
    double? fallbackLng,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/extract'))
      ..fields['area'] = area
      ..fields['seq'] = '$seq'
      ..fields['crops'] =
          jsonEncode(crops.map((c) => c.toJson()).toList())
      ..files.add(http.MultipartFile.fromBytes('photo', photoBytes,
          filename: fileName));
    if (fallbackLat != null) req.fields['fallback_lat'] = '$fallbackLat';
    if (fallbackLng != null) req.fields['fallback_lng'] = '$fallbackLng';

    final resp = await http.Response.fromStream(await req.send());
    if (resp.statusCode != 200) {
      throw Exception('extract 失敗: ${resp.statusCode} ${resp.body}');
    }
    final body = jsonDecode(utf8.decode(resp.bodyBytes));
    return (body['signs'] as List)
        .map((s) => Sign.fromJson(Map<String, dynamic>.from(s)))
        .toList();
  }

  /// AI判定（⑥のAI部分）。字段dictを返す。
  Future<Map<String, dynamic>> ai({
    required Uint8List photoBytes,
    required String fileName,
    String provider = 'claude',
    List<String> fields = const [],
    CropRegion? crop,
    String apiKey = '',
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/ai'))
      ..fields['provider'] = provider
      ..fields['fields'] = fields.join(',')
      ..files.add(http.MultipartFile.fromBytes('photo', photoBytes,
          filename: fileName));
    if (apiKey.isNotEmpty) req.fields['api_key'] = apiKey;
    if (crop != null) {
      req.fields['crop_x'] = '${crop.x}';
      req.fields['crop_y'] = '${crop.y}';
      req.fields['crop_w'] = '${crop.w}';
      req.fields['crop_h'] = '${crop.h}';
    }
    final resp = await http.Response.fromStream(await req.send());
    if (resp.statusCode != 200) {
      throw Exception('ai 失敗: ${resp.statusCode} ${resp.body}');
    }
    return Map<String, dynamic>.from(
        jsonDecode(utf8.decode(resp.bodyBytes))['fields']);
  }

  /// signs を CSV(utf-8-sig) でファイル保存し、保存先パスを返す（⑦）。
  Future<String> exportCsv(List<Sign> signs) async {
    final r = await http.post(
      Uri.parse('$baseUrl/export'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(signs.map((s) => s.toJson()).toList()),
    );
    if (r.statusCode != 200) {
      throw Exception('export 失敗: ${r.statusCode}');
    }
    final dir = Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    final out = File('$dir/Downloads/llmap_export.csv');
    await out.parent.create(recursive: true);
    await out.writeAsBytes(r.bodyBytes);
    return out.path;
  }
}
