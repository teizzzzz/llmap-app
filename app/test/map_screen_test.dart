import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llmap_app/models.dart';
import 'package:llmap_app/screens/map_screen.dart';
import 'package:llmap_app/theme/tokens.dart';
import 'package:llmap_app/widgets/map/map_pin.dart';

AppSchema _schema() => AppSchema(
      csvHeader: const ['SignID', '名称', '主要言語'],
      statusValues: const ['pending', 'reviewed'],
      enums: const {},
      aiFields: const [],
      languageColors: const {'日本語': '#2e6fdb', '中文': '#e07b1a'},
    );

void main() {
  testWidgets('located signs render markers; tap shows detail',
      (tester) async {
    final signs = [
      Sign({
        'SignID': 'HAS-S001-a',
        '名称': '理髪店',
        '主要言語': '日本語',
        '緯度': 35.60210,
        '経度': 139.70110,
      }),
      Sign({
        'SignID': 'HAS-S002-a',
        '名称': '中華料理',
        '主要言語': '中文',
        '緯度': 35.60214,
        '経度': 139.70114,
      }),
      // 座標なし → 地図に出ない
      Sign({'SignID': 'HAS-S003-a', '名称': '無座標', '主要言語': '英語'}),
    ];

    await tester.pumpWidget(
      MaterialApp(home: MapScreen(signs: signs, schema: _schema())),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // 2件の座標ありマーカー
    expect(find.byType(MapPin), findsNWidgets(2));
    // 座標なし警告
    expect(find.textContaining('无坐标 1 条'), findsOneWidget);

    // マーカータップで詳情カード
    await tester.tap(find.byType(MapPin).first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('HAS-S00'), findsWidgets);
  });

  test('hex color parses 6-digit with alpha', () {
    expect(parseHexColor('#2e6fdb').toARGB32(), 0xFF2E6FDB);
  });
}
