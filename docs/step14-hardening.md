# Step 14: データ安全・堅牢化（コードレビュー指摘の修復）

全層コードレビュー（2026-07）で見つかった問題の修復。機能追加なし・
データ契約/CSV/Dataset Package/ID 体系は不変。

## P0（データ安全）

1. **project.json の原子的書き込み**（`app/lib/store.dart`）
   `.tmp` へ書き切ってから `.bak` 退避→置換。読み込みは
   project.json → .tmp → .bak の順で復旧を試み、壊れたファイルは消さない。
   従来は直接上書きで、書き込み中断＝全記録消失があり得た。
2. **編集画面の draft 化**（`edit_sign_screen.dart`）
   編集は副本に対して行い「保存」時のみ元記録へ反映。未保存で戻る時は
   破棄確認（PopScope）。従来は就地編集のため「キャンセル」しても
   メモリ上の記録が書き換わり、次の永続化で保存されていた。
3. **採集ウィザードの中途放棄**（`crop_screen.dart` / 両表単画面）
   表単からの返回は確認ダイアログを通し、放棄時は今回保存した写真
   （source＋crops）を削除する。従来は無確認で全入力が消え、写真だけが
   孤児として永久に残っていた。

## P1

- **ネットワークタイムアウト**: AI 呼び出し 60s（`ai.dart`）、/schema 8s
  （`api.dart`）。従来は無限待ちで UI が固まり得た。
- **PATCH /records の状態値検証**（`records_api.py`）: `_status` /
  `DataStatus` を既知枚挙に限定（未知値は審核队列・統計から静黙に漏れるため）。
- **首页記録抽屉の遅延構築**（`home_screen.dart`）: ListView.builder 化＋
  表示を新しい順に（Gallery の既定と一致。番号は採集順を保持）。
- **EXIF 方向の一致**（`imaging.dart`）: 切り出し前に `bakeOrientation` で
  向きをピクセルへ焼き込み、Flutter の表示（EXIF 適用）と座標系を一致させた。
  ※縦位置・EXIF 付き実機写真での確認を推奨。
- **設定画面の離脱確認**（`settings.dart`）: 未保存変更ありで戻る時に破棄確認
  （言語は従来どおり即時適用・対象外）。
- **框选 suffix の拡張**（`box_selector.dart`）: a–z の次は aa–zz
  （27 個目以降が全部 'x' になり SignID が重複し得た）。

## P2

- **旧 Phase 0 エンドポイントの削除**: backend の /extract・/ai・/export・
  /export_bundle と app 側クライアント（api.dart の対応メソッド）を削除
  （どこからも呼ばれておらず、未認証の書き込み/中継入口だった）。
  `ai.py` / `storage.py` / `exif.py` / `csv_io.py` を削除、requirements から
  Pillow / piexif / anthropic / google-genai を除去（binary も小さくなる）。
  /health・/schema・/ai/status は不変。backend 0.3.2。
- **Gemini API key をヘッダ送信に変更**（URL クエリはログに残るため）。
- **i18n 漏れの解消**: crop の失敗 snackbar・自定义追加ヒント/tooltip を l10n 化。
  研究/編集表単の字段ラベルと _status バッジを本地化
  （`field_labels.dart` 新設。**データのキー・値は正準のまま**）。
- **Console**: 桌面版（Tauri）では「uvicorn を起動して」系の開発者向け案内を
  非表示に（`IS_DESKTOP`）。エラーメッセージからも uvicorn 記述を除去。

## やらなかったこと（理由つき）

- **API key の secure storage 化**: flutter_secure_storage は minSdk 23 を
  要求し、minSdk 変更は別途判断が必要（現状 flutter 既定）。次 Step 候補。
- **google_fonts のオフライン同梱**: フォントファイル選定を伴うため保留。
- **框选の個別削除/リサイズ、批量删除の回收站**: 機能追加のため対象外。
- **DB マイグレーション機構**: 現段階は「モデル変更＝再導入」で運用
  （db_models 変更時は要注意）。

## Windows ビルド（Win11 向け配布物）

**Windows の exe/インストーラは Windows 実機でのみビルド可能**
（PyInstaller・Tauri ともクロスコンパイル不可）。一括スクリプトを追加:

```powershell
git clone https://github.com/teizzzzz/llmap-app && cd llmap-app
git checkout claude/program-major-revision-ezzpwh
powershell -ExecutionPolicy Bypass -File scripts\build-windows-app.ps1
# → desktop\src-tauri\target\release\bundle\nsis\LLMap_*_x64-setup.exe
```

前提・検証チェックリストは docs/windows-desktop-build.md。

## 検証

- app: `flutter analyze` 0 issues / `flutter test` 47/47（v1.9.1+25）
- backend: pytest **19/19**（PATCH 検証・旧端点削除確認の 2 テスト追加）
- console: `npm run build`（tsc strict）通過（v0.8.3）
