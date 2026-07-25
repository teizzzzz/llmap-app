import 'package:flutter_test/flutter_test.dart';
import 'package:llmap_app/capture_mode.dart';
import 'package:llmap_app/models.dart';
import 'package:llmap_app/schema_defaults.dart';

void main() {
  test('captureModeFrom: 既定・未知値は standard に落ちる', () {
    expect(captureModeFrom(null), CaptureMode.standard);
    expect(captureModeFrom(''), CaptureMode.standard);
    expect(captureModeFrom('bogus'), CaptureMode.standard);
    expect(captureModeFrom('quick'), CaptureMode.quick);
    expect(captureModeFrom('standard'), CaptureMode.standard);
    expect(captureModeFrom('research'), CaptureMode.research);
  });

  test('EntryMode / DataStatus 初期値の契約', () {
    expect(CaptureMode.quick.entryMode, 'quick');
    expect(CaptureMode.standard.entryMode, 'standard');
    expect(CaptureMode.research.entryMode, 'research');
    expect(CaptureMode.quick.initialDataStatus, 'raw');
    expect(CaptureMode.standard.initialDataStatus, 'submitted');
    expect(CaptureMode.research.initialDataStatus, 'submitted');
  });

  test('DataStatus 対応表（_status 遷移時の派生値）', () {
    expect(dataStatusFor('pending'), 'raw');
    expect(dataStatusFor('ai'), 'ai_drafted');
    expect(dataStatusFor('human-reviewed'), 'reviewed');
    expect(dataStatusFor('final'), 'verified');
    expect(dataStatusFor('unknown-value'), 'raw');
  });

  test('標準モードの字段キーはすべて CSV 正準キー（新キーを作らない）', () {
    for (final f in [...kStandardDefaultFields, ...kStandardMoreFields]) {
      expect(kCsvHeader, contains(f), reason: '$f が kCsvHeader に無い');
      expect(AppSchema.systemFields, isNot(contains(f)),
          reason: '$f はシステム字段（表単に出してはいけない）');
    }
    // 展開字段は enums に選択肢を持つ（dropdown/チップが空にならない）。
    for (final f in kStandardMoreFields) {
      expect(kEnums[f], isNotEmpty, reason: '$f の選択肢が無い');
    }
  });
}
