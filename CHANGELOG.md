# 更新履歴 (CHANGELOG)

バージョンは **MAJOR.MINOR.PATCH**（例 `v1.2.6`）。
- PATCH（末尾）= 小さな修正・調整
- MINOR = 目立つ新機能のまとまり
- MAJOR = 大きな節目／方向転換

APK 成果物のファイル名もこれに合わせる（例 `dist/LLMap-v1.2.6-release.apk`）。
Android の versionCode（`+N`）は番号表記に関わらず単調増加させる。

> 採番方針の変更（2026-06-30）: 初期は小変更ごとに MINOR を上げて v1.9 まで進んだため、
> 3 つの節目（MVP / ローカル化+AI / Lingscape UI 刷新）に整理し直した。過去の見出しは
> 新スキームで振り直している。

## console v0.6.0 (2026-07-04) — Export CSV ページ（Step 8A）

- Export ページを実装: 筛选（Database と同じ RecordsFilters を再利用・
  q/言語/地区/採集者/モード/状態/日付/GPS/写真/dataset）＋快速プリセット
  （All / Reviewed only / Verified only / With GPS / With photos）。
- 导出摘要: `/records?pageSize=1` で筛选後の件数を表示、0件は導出不可。
- **Export CSV**: `/export/csv` を現在の筛选条件付きで取得し
  `llmap_export_YYYYMMDD_HHMMSS.csv` としてブラウザ下載
  （client に `exportRecordsCsv(params)` 追加）。進行中/成功/失敗/offline を表示。
- フォーマット区: CSV=available、Dataset Package / GeoJSON / Photos ZIP は
  Coming soon（無効カード）。写真は CSV に含まれない旨をページに明記。
- 検証: npm run build 通過。実 backend＋Playwright で件数摘要→reviewed 筛选→
  実ダウンロード（36列 header・行数・筛选反映を検査）→Coming soon 無効→
  offline エラーまで確認。backend 変更なし。

## console v0.5.0 / backend v0.2.1 (2026-07-04) — Review 審核工作流（Step 7）

Review ページを審核队列として実装（「どの記録がまだ人の確認を要するか」に答える。
Database は閲覧・編集、Review は状態を前に進める場所）。

- **队列**: 既定は待審核（raw / submitted / ai_drafted / needs_review）。快速タブ
  （All pending / Raw / Submitted / AI drafted / Needs review / Reviewed /
  Verified / Rejected）＋ Mode/Language/Area/Dataset 筛选＋件数＋Skip/Next。
  カードに缩略图・DisplayID・言語・地区・日時・badge。
- **工作区**（3列）: 写真（crop/source、クリックで原寸を新タブ表示・欠図
  placeholder）/ 研究字段編集（Database の FieldEditor 再利用: 言語・文字体系
  チップ、担体類型等下拉、備考）/ 只読元情報16項目（CropRect はテキスト表示、
  可視化 overlay は TODO）＋アクション。
- **審核アクション**（状態対応は `reviewStatus.ts` に一元定義）:
  Save changes（状態不変）/ Mark as reviewed（_status=human-reviewed・
  DataStatus=reviewed）/ Mark as verified（final・verified）/
  Needs review（DataStatus のみ。_status 保持＝モバイル互換）/
  Reject（DataStatus のみ）/ Open in Database（?record= 連動）。
  アクションは未保存の字段変更も一緒に保存する。
- **队列規則**: 成功後に队列再取得＋自動で次の記録へ。空になったら
  「No records waiting for review.」。未保存変更がある間の記録/タブ切替は
  confirm で保護。
- **backend v0.2.1**: `/records` の dataStatus 筛选がカンマ区切りの複数値を
  許容（待審核队列が raw,submitted,ai_drafted を1リクエストで分页取得する
  ため。単値の既存動作は不変・テスト追加、15件全通過）。
- 検証: npm run build 通過。実 backend＋Playwright で 队列3件→タブ/筛选→
  保存→reviewed/verified/needs_review/rejected の状態遷移と队列移除・
  自動前進→空状態→dirty ガード→offline まで確認。

## v1.8.1 (2026-07-04) — ビルド修正（設定画面の第二経路）

- **fix**: v1.7.0 で `SettingsScreen` に必須パラメータ `captureMode` を追加した際、
  設定画面を開く**もう一つの経路**（`main.dart` の `_Boot._editUrl()`＝起動失敗
  画面の「設定」ボタン）が追随しておらずコンパイルエラーになっていた。
  `loadCaptureMode()` の読込・受け渡し・戻り値型・`saveCaptureMode()` を補完。
  実機ビルドで発見された問題（flutter analyze クリーン・リリースビルド成功を確認済）。
- 既知の注意: Android release 署名はデバッグキーのまま
  （`build.gradle.kts` の release ブロック）。ストア配布時は本番 keystore が必要。

## console v0.4.0 (2026-07-04) — Map ページ（Step 6）

Web 地図预览を実装（Leaflet + react-leaflet v4・OpenStreetMap tiles・
attribution 付き。有料 token 不要）。

- **GET /map/records** を接続（`getMapRecords(params)`＋`MapRecord`/`MapQuery` 型）。
  GPS を持つ記録のみ表示（その旨をページに明記）。経緯度異常値は除外。
- **marker**: 主要言語の先頭言語で着色（/schema の language_colors =
  モバイル地図と同一配色。未知言語は灰）。CircleMarker（画像アセット不要）。
  表示中の言語だけの凡例を左下に表示。記録群が変わると fitBounds。
- **筛选**: mainLanguage / areaCode / entryMode / dataStatus / datasetId
  （Database と同じ命名・同じ選択肢ソース = useFilterOptions hook に共通化）。
  Clear filters / Refresh / 「N mapped records」。
- **popup**: 開いた時に /records/{id} を遅延取得し、缩略图（欠図 placeholder）・
  DisplayID・主要/補助言語・地区コード・採集日時・EntryMode/DataStatus badge を
  表示。**Open in Database** で Database ページへ遷移し該当記録を自動選択
  （?record=<id> 連動を DatabasePage に追加）。
- 空状態（GPS 記録なし / 筛选後 0 件）・offline エラーを白屏なしで処理。
- 検証: npm run build 通過。実 backend＋Playwright で marker 2件・言語/モード/
  状態筛选・空状態・popup 遅延詳情＋写真・Database 遷移選択・offline を確認。
- backend 変更なし。

## console v0.3.0 (2026-07-04) — Dataset Package 導入 UI（Step 5C）

Database ページから直接 Dataset Package をアップロードできるようにした
（curl 不要に）。

- ヘッダに「⇪ Import Dataset Package」ボタン → モーダル
  （`components/database/ImportDatasetDialog.tsx`）。
- フロー: zip 選択（非 zip は即時拒否・ファイル名/サイズ表示）→ Upload
  （進行中表示）→ **導入レポート**（Dataset ID / Records / Imported / Skipped /
  Photos / Source photos / Missing 2種）＋ duplicateSignIds・warnings は
  黄色の警告ボックスに列挙（20件で省略表示）。
- 成功後: records 表格・datasets/筛选肢を自動再取得。「View records」で閉じる /
  「Import another」で連続導入。空状態の文言も導入ボタン誘導に更新。
- API client: `importDatasetPackage(file)`（FormData。multipart の boundary の
  ため Content-Type はブラウザに委譲するよう request() を調整）＋
  `ImportDatasetResult` 型。
- エラー処理: 未選択 / 非zip / 失敗（backend の detail 表示）/ offline すべて
  モーダル内で表示（白屏なし）。
- 検証: npm run build 通過。実 backend＋Playwright で 非zip拒否 → 導入成功
  レポート → 表格 3→4 件刷新 → 同一包再導入で duplicate 表示 → offline
  エラーまで確認。backend 変更なし。

## console v0.2.0 (2026-07-04) — Database ページ MVP（Step 5B）

Database ページを実用化: 一覧・検索・筛选・分页・詳情・編集・保存。

- **表格**: 缩略图 / DisplayID(→SignID fallback) / 主要・補助言語 / 地区 /
  採集日時 / EntryMode・DataStatus badge / 採集者 / GPS有無。選択行ハイライト、
  写真欠落は placeholder。
- **筛选**: q 検索（400ms デバウンス）＋ mainLanguage / areaCode / collectorId /
  entryMode / dataStatus / datasetId / hasGps / hasPhoto / hasSourcePhoto /
  dateFrom / dateTo。選択肢は /schema（言語 enum）・/stats/summary（実在の
  地区/採集者）・/datasets から動的取得。変更で page 1 に戻る。
  Clear filters / Refresh / 件数表示。
- **分页**: Prev/Next・pageSize 25/50/100・「1–50 of 123」表示。
- **詳情面板**: 裁切図＋元写真（欠落 placeholder）、識別情報14字段は只読、
  編集は 主要言語/補助言語/文字体系(チップ多選)・担体類型/設置主体/多言語関係
  (下拉)・備考(textarea)・_status/DataStatus(下拉)。dirty 表示・Save(PATCH)・
  Cancel・保存後に表格再取得・失敗はエラー表示。
- 新規コンポーネント: components/database/{RecordsTable, RecordsFilters,
  RecordDetailPanel, FieldEditor, StatusBadge, PhotoThumb}。
- API client に getSchema()（/schema の enums・multi_fields で表単型を決定）。
- 検証: npm run build（tsc strict）通過。実 backend＋Playwright で
  表格/検索/3筛选/詳情/写真表示・placeholder/編集保存の永続化/識別情報只読を確認。
- backend 変更なし。

## console v0.1.0 (2026-07-04) — Research Console 基礎フレーム（Step 5A）

リポジトリ根に `console/` を新設（React + Vite + TypeScript + React Router、
UI フレームワーク無しの軽量構成・桌面工具型レイアウト）。

- 左ナビ（Dashboard / Database / Map / Review / AI Processing / Export /
  Settings）＋顶部栏＋内容区。顶部栏に backend 接続状態チップ（/health）。
- **Dashboard は実装済み**: `/stats/summary` を読み、件数タイル＋言語/状態/
  モード/地区/採集者の分布を表示。backend 未起動時は白屏でなく友好なエラー
  ボックス（起動コマンドと設定方法を案内）。
- API client（`src/api/client.ts` + `types.ts`）: getStatsSummary /
  getRecords / getRecord / updateRecord / getDatasets / getHealth。
  base URL は `VITE_API_BASE_URL`（既定 http://localhost:8000、`.env.example`）。
- Database/Map/Review/AI/Export は占位ページ（実装予定 Step を明記）。
- 検証: `npm run build`（tsc strict）通過。実 backend＋Playwright で
  Dashboard 表示・全ページ遷移・オフライン時エラー表示を確認。
- アプリ・backend は不変（backend テスト 14 件通過のまま）。

## backend v0.2.0 (2026-07-04) — Research Console 用ローカルDBサービス（Step 4）

backend を SQLite ベースのローカルデータベースサービスに拡張（アプリは不変）。
既存の採集補助エンドポイント（/health /schema /extract /ai /export*）は維持。

### 新規モジュール
- `database.py`（SQLite・LLMAP_DATA_DIR で保存先切替可）/ `db_models.py`
  （Dataset / SignRecord / Photo。核心列＋全字段 data_json）
- `import_dataset.py`: **POST /datasets/import** — Dataset Package zip を
  data/imports に展開、JSON/CSV 検証、manifest と実ファイル照合、SQLite 取込、
  写真を data/photos・data/source_photos へ複製、導入レポート返却。
  SignID 重複は skip して duplicateSignIds に報告（静黙上書きなし）。
  写真欠落は warnings（導入は失敗しない）。zip slip 拒否。
- `records_api.py`: **GET /records**（分页・q検索・言語/地区/採集者/モード/
  状態/日付/GPS/写真有無/dataset 筛选）、**GET/PATCH /records/{id}**
  （研究字段と _status/DataStatus のみ編集可・系統字段はロック・_status 変更で
  DataStatus 自動同期）、**GET /records/{id}/photo・/source-photo・
  /photos/{filename}**（目录穿越拒否）、**GET /map/records**（GPS有のみ軽量）。
- `stats_api.py`: **GET /stats/summary**（件数・写真・EntryMode/DataStatus/
  言語(併記展開)/地区/採集者分布）。
- `export_api.py`: **GET /export/csv**（筛选条件付き・標準36列・utf-8-sig）。

### 互換
- DataStatus 欠落は _status から補完（DATA_STATUS_MAP）。旧データは package 側で
  規範化済みのため再規範化しない。字段欠落は空で取込（落ちない）。
- テスト `backend/tests/test_console_api.py`（14件: 導入/重複/分页/筛选/詳細/
  編集/ロック/写真/地図/統計/導出/壊れた包の拒否）全通過。

## v1.8.0 (2026-07-04) — Dataset Package v1 完成（Step 3）

v1.6.0 で導入した Dataset Package を Step 3 仕様どおりに完成させた
（包構造・manifest.json・規範化は v1.6.0 から不変。formatVersion 1.0 のまま追加のみ）。

- **metadata.json**: `entryModeCounts` / `dataStatusCounts` の分布を追加
  （規範化後の rows で集計。旧データ等の空値は `unknown`、合計=件数）。
- **schema.json**: `standardDefaultFields` / `standardMoreFields` を追加
  （Console が採集モード別の簡易/展開字段を解釈できる）。
- 導出成功時に「Dataset Package を書き出しました」を表示（三語対応）。
- テスト: dataset_package_test に分布・schema 追加字段・JSON 往返の検証を追加。

## v1.7.1 (2026-07-04) — 採集モードの験収と補漏（Step 2.6）

- **UI ラベルと data キーの分離**: 標準モード表単のラベルを本地化文言に
  （mainLanguage/subLanguage/operator/carrier/multilingual を再利用、
  fieldScript/fieldNote を新設）。data キーは従来どおり schema 正準キーのまま。
- **字段キーの契約を定数化**: `kStandardDefaultFields` / `kStandardMoreFields`
  （schema_defaults）を標準モード表単の駆動に使い、全キーが kCsvHeader に
  含まれ・システム字段でないことをテストで保証。
- **capture_mode.dart を純ロジック化**（l10n 依存を settings.dart の
  CaptureModeLabels 拡張へ分離）→ 単体テスト可能に。
- テスト追加: `test/capture_mode_test.dart`（既定値/フォールバック・
  EntryMode/DataStatus 初期値・DataStatus 対応表・字段キー契約）、
  normalizer テストに EntryMode/DataStatus の直通/補完ケースを追加。
- 験収結果: 状態は採番時に _status＋DataStatus を成対で書き、以後の遷移は
  すべて `Sign.setStatus()` 経由（不同期なし）。CaptureID/ファイル命名は
  3モード共通で不変。旧データの閲覧・導出も不変。

## v1.7.0 (2026-07-04) — 3つの採集モード（quick / standard / research）

同一の Sign データ構造・同一の地図首页のまま、**框选後のフロー**だけを
採集モードで切り替えられるようにした（3套の首页・3套のモデルは作らない）。

### モード（`capture_mode.dart` 新設）
- **クイック**: 拍照→框选→即保存。表単なし。EntryMode=quick / DataStatus=raw /
  _status=pending。字段は後で Gallery/編集から補完（保存時にその旨を案内）。
- **標準（既定）**: 拍照→框选→簡易言語選択（Lingscape 相当）。
  EntryMode=standard / DataStatus=submitted / _status=pending。
- **研究**: 拍照→框选→完全な研究字段表単（既存 FieldsScreen・AI下書可）。
  EntryMode=research / DataStatus=submitted、校閲保存で
  `setStatus('human-reviewed')` → DataStatus=reviewed。

### 標準モードの簡易表単（`standard_fields_screen.dart` 新設）
- 裁切プレビュー＋「標識に現れる言語」の複数選択チップ
  （日本語/韓国語/中国語/ベトナム語/ネパール語/英語/その他＋**不明**）
  ＋補助言語＋任意の備考。
- 「＋ 添加更多信息」で少数の官方字段（文字体系/担体類型/設置主体/多言語関係）
  を展開。完全表単は研究モードのみ。

### 設定・首页
- 設定に**採集モード**セクション（radio・説明付き、既定 standard）。研究モード
  選択時は**字段方案**入口（官方字段＝現行 / 自定义字段＝開発中 TODO）を表示。
- 首页の記録パネルに現在モードのタグを表示（タップで設定へ）。地図・大ボタン・
  Gallery 等の首页構造は3モード共通で不変。
- 保存成功メッセージをモード別に（保存済・後で補完可 / 提交済 / 研究記録保存）。
- 文言は三語対応（arb＋生成 l10n に 16 キー追加）。

### 互換
- モードは本機のアプリ設定（SharedPreferences）。権限/アカウント機構ではない。
- CaptureID/SignID/ファイル命名・導出規範化は3モード共通で不変。
  旧データ（EntryMode/DataStatus なし）もそのまま閲覧・編集・導出可。

## v1.6.0 (2026-07-04) — LLMap Dataset Package v1.0（標準导出包 / Step 2）

导出を標準 Dataset Package に刷新（`dataset_package.dart` 新設・`store.buildBundle` 改修）。
将来の Research Console はこの包をそのまま取り込む。

### 包構造（`llmap_dataset_YYYYMMDD_HHMMSS.zip`）
- `data.csv`（規範化済み・36列）/ `photos/`（裁切図）/ `source_photos/`（元写真、
  CaptureID 毎に1枚・複数 sign 共有時も重複同梱しない）
- `metadata.json`（導出日時・件数・app/schema/format 版・欠落数）
- `schema.json`（headers / systemFields / fieldGroups(A〜D) / enums /
  statusValues / dataStatusMap / multiFields — Console が字段構成を解釈できる）
- `manifest.json`（**機械可読の主フォーマット**: files に path/type/signId/
  captureId/sizeBytes/localName、missingFiles・sourceMissing・
  normalizedLegacyRecords を記録）＋ `MANIFEST.txt`（人向け補助）＋ `README.md`
- 写真欠落・元写真なしでも导出は失敗せず manifest.json に記録。包内同名上書きなし。

### 互換に関する注記
- **导出入口は従来どおり1つ**（メニュー→データ导出）。导出フォーマットは旧
  `llmap_export.zip`（data.csv＋photos/＋MANIFEST.txt）から Dataset Package に
  **置き換え**（旧簡易形式は廃止。CSV 列は上位互換、写真が photos/ と
  source_photos/ に分かれる点のみ構造変更）。
- 旧データの導出時規範化（v1.5.1）はそのまま適用。本地データは不変。
- 規範化・包生成は純ロジック（export_normalizer / dataset_package）に分離し、
  単体テスト `test/dataset_package_test.dart` を追加。

## v1.5.1 (2026-07-04) — データ契約の験収と補完（Step 1.5）

### 溯源字段の追加（`models.dart` / `schema_defaults.dart` / 後端 `schema.py`）
- 新CSV列: `EntryMode`（採集方式、現行フローは `standard`）/ `DataStatus`
  （Console 審核状態: raw/ai_drafted/reviewed/verified、`_status` と対応）/
  `SchemaVersion`（データ契約版 `1.5`）/ `AppVersion`（採集時のアプリ版）。
- `Sign.setStatus()` を新設し、`_status` の全遷移箇所（AI下書・校閲・編集）で
  DataStatus を同時更新。旧レコードは空のままでよい（導出時に補完）。

### 導出時規範化（`export_normalizer.dart` 新設 / `store.buildBundle`）
- 旧レコードも导出の瞬間に新契約形式へ変換（**本地の project.json・旧写真は不変**）:
  `CaptureID = AREA-legacy-YYMMDDHHMMSS000`（採集者ID 無しは `legacy` 固定、
  端末の現IDは入れない）。同一 写真ID の裁切群は CaptureID・元写真を共有。
- 旧写真は导出包内でのみ新名（`CaptureID-<suffix>.jpg` / `-source.jpg`）に複製し、
  CSV の 写真ファイル名/元写真ファイル名 と zip 内容を完全一致させる。
- 同秒衝突は `-002` 序号で回避（导出包内の同名上書きなし）。旧・整図採集など
  元写真が無いレコードは 元写真ファイル名 空＋MANIFEST の `source_missing:` に明示。
- 単体テスト `test/export_normalizer_test.dart` を追加（旧単体/裁切群/同秒衝突/
  整図/壊れた記録/新旧混在/setStatus 同期）。

## v1.5.0 (2026-07-04) — A区域ID刷新（CaptureID / 多人採集で衝突しない命名）

多人採集・データ合并・将来の PC Console 取り込みに向けて、識別字段と写真命名を
「地区＋日付＋連番」依存から **CaptureID 中心**に刷新（詳細は `docs/data-contract.md`）。

### 新ID契約（`imaging.dart` / `crop_screen.dart` / 後端 `schema.py`）
- **CaptureID** `AREA-COLLECTORID-YYMMDDHHMMSSmmm` を新設（1回の撮影イベントの一意ID）。
  Settings の既存ランダム CollectorID（NanoID 8桁）＋ミリ秒時刻を含むため、
  複数人が同日同地区で採集しても写真ファイル名 / SignID が衝突しない。
- **SignID** = `CaptureID-suffix`、**写真ファイル名** = `CaptureID-<suffix>.jpg`、
  **元写真ファイル名** = `CaptureID-source.jpg`（原始完整写真。pano 呼称は廃止）。
- **DisplayID** `AREA-YYYYMMDD-SEQ-suffix` は表示専用（主キーにしない）。
  一覧/画廊/地図は短いラベル `OOK #008-a` を表示し、長い CaptureID を出さない。
- 新CSV列: `CaptureID / DisplayID / 採集者ID / 地区コード / LocalSeq / CropSuffix /
  CropRect / 元写真ファイル名`。**CropRect** は框选矩形を JSON（相対座標）で保存
  — 框选なしは `{"x":0,"y":0,"w":1,"h":1}`。PC 端の再裁切の土台。
- 旧列 `写真ID / 全景写真ファイル名` は保持（新規レコードでは 写真ID=CaptureID、
  全景写真ファイル名=元写真ファイル名 の互換値を書き込む）。

### 旧データ互換
- 旧レコードは無変換のまま閲覧・編集・导出可。読取側フォールバック:
  CaptureID→写真ID / DisplayID→SignID / 元写真→全景写真 / CropSuffix→SignID末尾。

### 写真保存の衝突保護（`store.dart`）
- `savePhoto` が実際に保存した名前を返すように。同名同内容はスキップ、
  同名異内容は `名前~2.jpg` の衝突回避名で保存（静黙上書きを廃止）。
- 导出 ZIP の写真収集に `元写真ファイル名` を追加。

### UI
- 編集画面に**識別情報カード**（展開で SignID/CaptureID/DisplayID/写真・元写真
  ファイル名/採集者ID/地区コード/採集日時/緯度/経度 を全表示・コピー可）。

## v1.4.0 (2026-06-30) — 採集字段の刷新（三語重構版 v3 / Scollon・Reh 準拠）

採集字段定義表を「三語重構版 v3」へ全面刷新。**採集從寬・分析從嚴**の方針で、
現場で客観判定しやすい字段に整理し直した（純減 6 字段・新規 4 字段）。

### CSV 構造（`schema_defaults.dart` / 後端 `schema.py`）
- **削除（6）**: `来源類型`・`視認等級`・`位置描述`・`想定受容者`（読心/重複/不可検証）と、
  旧 `装飾的言語`→`装飾の言語` へ改称。`判定来源`は `_status` に統合。
- **新規（4）**: `文字性`（含文字/純記号/対象外の第一軸）・`文字体系/Script`（書記体系を言語と分離）・
  `空間階層`（低位/中位/高位＝権力·可及性軸）・`重ね書き/Layering`（時間的上書き痕跡）。
- **更新**: `設置主体`を細分（行政·公共機関/商業·チェーン/商業·個人店/個人/団体/不明）、
  `ディスコース類型`を新設（規約/基礎設施/商業/越境/判読不能/その他＝Scollon 2003、判定順あり）、
  `多言語関係`を Reh(2004) 類型へ（単言語/複製/重複/部分翻訳）、`可読性`を物理的明瞭度のみに収窄。
- **言語値**を拡張（日本語/韓国語/中国語/ベトナム語/ネパール語/英語/その他）。地図色も追従。
- **ステータス**: `pending / ai / human-reviewed / final`（旧 `modified/reviewed` を改め、判定来源を内包）。

### AI プロンプト（`ai.dart` / 後端 `ai.py`）
- システムプロンプトを刷新（言語景観研究者として「採集從寬」で**下書き**、推測は備考に根拠、
  読めない言語でも文字体系は判定、内容判定字段は「判読不能」出口）。
- 字段ガイドを全 16 字段に作り直し、各字段の選択肢＋境界判定ルール
  （支配性の優先順位／ディスコースの判定順／補助 vs 装飾の区別口訣 等）を埋め込み。
  AI は全編集字段（名称含む）を下書きし、人が校閲して `human-reviewed/final` へ。

### 複数選択 ＋ 自由追加
- `主要言語`・`補助言語`・`装飾の言語`・`文字体系` を**複数選択**化（チップ式 multi-select）。
  選択肢に無い値は入力欄から**自由追加**できる。値は「/」区切りで保存（例「日本語/韓国語」）。
- `文字体系` の選択肢を更新: 漢字/平仮名/片仮名/ローマ字/ハングル/**デーヴァナーガリー/ビルマ文字/タイ文字/ベンガル文字**/アラビア/キリル/その他/無。
- 地図ピン色・画廊タグ・言語フィルタを併記値（"/"）対応に（代表言語で配色、フィルタは含有判定）。

### 採集者ID（多人協作）
- 設定に**採集者ID**を追加。SignID を「地点-採集者-序号」（例 `HAS-K7m9Qp4t-S001-a`）にし、
  多人で同時採集しても採番が衝突しない。
- 既定で**自動生成**（NanoID 8桁、視認・手抄・スキャンで紛れやすい `0/O/1/l/I` を除外）。
  設定で自由に変更・再生成できる（`SharedPreferences` に保存）。

### UI 追従
- 画廊の二次フィルタを `来源類型`→`設置主体` に、地図詳情の項目を `来源類型`→`ディスコース類型` に差替え。
  ラベルは三言語（设置/設置/Agent・话语类型/ディスコース類型/Discourse type）を更新。
- 編集で status を `human-reviewed` に昇格するよう分層ロジックを更新。
- 編集画面に**写真プレビュー**（タップで全画面ズーム）、采集記録カードに**サムネイル**（番号バッジ付）を追加。
- 既定の地点コードを `OOK`（新大久保 Shin-Ōkubo）に変更。

> データ移行: 旧スキーマで保存済みの記録は Map 構造のため起動・表示は壊れないが、
> 削除字段は CSV 書き出し対象外、新字段は空欄になる。再AI識別または手動で補完する。

## v1.3.1 (2026-06-30) — 導出の固まり修正（実機）

- 実機（Xiaomi）で「导出を押すと一瞬固まり、進捗ダイアログが点滅／フリーズして
  そのまま共有画面へ」だった不具合を修正。
- 原因: ZIP 圧縮（deflate）がメインスレッドで動き UI をブロックしていた。
- 対応: `LocalStore.buildBundle` の圧縮を **別アイソレート**へ移し、進捗を
  `ReceivePort` で受信。UI スレッドが空くため進捗バーが滑らかに動く。
  大量画像でも UI が固まらない。

## v1.3.0 (2026-06-30) — 多言語対応（简体中文 / 日本語 / English）

- Flutter 公式の `flutter_localizations` + ARB（gen-l10n）で国際化。
  `lib/l10n/app_{en,zh,ja}.arb` に全UI文言を集約、`AppLocalizations` を生成。
- **言語切替**: 既定はシステム言語に追従。設定画面に言語ピッカー
  （跟随系统 / 简体中文 / 日本語 / English）を追加し、`SharedPreferences` に保存。
  `localeNotifier` を `MaterialApp` が購読し即時切替。
- 全画面・全部品の表示文言をローカライズ（起動/撮影/ホーム/框选/字段/編集/設定/
  画廊/Select Location/地図/各ダイアログ/進捗）。
- **据え置き（データ層は不変）**: CSV 標準の字段名・分類値（主要言語/日本語 等）は
  研究用の正準キーのため未翻訳。状態コード（pending/ai/…）も据え置き。必要なら次段で
  表示ラベルのマップを追加可能。

## v1.2.7 (2026-06-30) — 導出進捗の視認性改善

- 少量（数枚）でも進捗ダイアログが見えるよう、**最低表示時間 ~0.9 秒**を確保。
  以前は5枚程度だと一瞬で閉じて進捗バーが見えなかった。
- 完了時に**「✓ 完成 · 共 N 张照片」**と緑のバーを表示してから閉じるように。

## v1.2.6 (2026-06-30) — 采集档案（筛选型画廊）

- 新規 `lib/screens/gallery_screen.dart`: 缩略图カード网格で採集記録を閲覧する
  全屏「采集档案」ページ。
  - 各カード: 裁切写真の缩略图＋状態バッジ＋名称＋SignID＋言語タグ（言語別色）＋来源タグ。
  - **筛选**: 言語 × 来源（横スクロールのチップ）。响应式网格（`SliverGridDelegate`、
    最大列幅220）、`GridView.builder` で遅延読込（大量でも軽量）。
  - タップで `EditSignScreen` 編集。
- 地図主体ホームの「采集记录」パネルヘッダに**画廊入口**（grid アイコン）を追加。
  底部抽屉の快速列表はそのまま保持。
- **状態オーナーは HomeScreen のまま**。画廊の編集/削除は callback で委譲し、
  `_signs`/`LocalStore` のデータフローは不変。

## v1.2.5 (2026-06-29) — 導出の進捗表示

- **導出進捗ダイアログ**を追加。写真1枚ごとに「X / N 张照片」を表示（新規 `LLProgressDialog`）。
- `LocalStore.buildBundle` を **`ZipFileEncoder` のストリーミング書き込み**に変更
  （全画像をメモリに抱えず、写真ごとに進捗 `onProgress(done,total)` を通知）。

## v1.2.4 (2026-06-29) — 地図の体感改善（実機フィードバック）

- **ズーム時の灰白点滅を軽減**: タイルの `keepBuffer`/`panBuffer` を増やし、
  未読込領域の下地を暖色(`muted`)へ。
- **起動時に現在地をプレビュー**: 起動と同時にGPS取得、地図準備完了時に現在地へ
  センタリング（取得不可なら記録範囲）。`LLMapView` に `onMapReady` を追加。

## v1.2.3 (2026-06-29) — 仕上げ（Phase 6）

- 起動画面をブランド化＋中文化。撮影シートを中文＋LL化（`LLBottomSheetScaffold`）。
- 衛星/暗色地図での出典表記を半透明チップ化。残存日本語のユーザー可視文言を中文へ。

## v1.2.2 (2026-06-29) — Select Location 手動微調整（Phase 5）

- 新規 `lib/screens/select_location_screen.dart`: 中心固定ピン方式の位置選択
  （地图/卫星切替・重新定位・恢复自动定位・座標表示）。
- `CropScreen`: GPS状態行に手動調整入口。`_manualGps` を優先適用
  （`gps = _manualGps ?? await _gpsFuture`）。採集ロジックは不変。

## v1.2.1 (2026-06-29) — 既存画面の視覚移行（Phase 4）

- `CropScreen`/`FieldsScreen`/`EditSignScreen`/`SettingsScreen` を LL コンポーネント＋
  tokens に移行、中文文案へ統一。`SignForm` 補助文字を tokens に。
- `box_selector.dart`: ハードコード色を `AppColors` に置換。
- **業務ロジック・データ構造は不変。**

## v1.2.0 (2026-06-29) — Lingscape UI 全面刷新 ＋ 地図主体ホーム（Phase 1–3）

Figma「Lingscape」を参照し、エディトリアル調＋map-first へ全面刷新。中核データフロー
（`_signs`/`LocalStore`/`Sign`/`AppSchema`）は不変。中文文案へ統一。

### デザインシステム
- `lib/theme/tokens.dart`: `AppColors`/`AppSpacing`/`AppRadius`/`AppShadows`/`AppText`
  （Fraunces/Nunito）/`parseHexColor`。`theme.dart` は tokens 参照に再編（`llXxx` は互換維持）。
- 共通部品 `lib/widgets/ll/`: `LLPrimaryButton`/`LLSecondaryButton`/`LLIconButton`/`LLCard`/
  `LLTagChip`/`LLSegmentedControl`/`LLAppHeader`/`LLBottomSheet`/`LLDialog`/`LLFormField`。

### 地図主体ホーム
- 地図部品を抽出・再利用化 `lib/widgets/map/`: `LLMapView`（CARTO/Esri 衛星切替）・
  `LLMapDetailCard`・`LLMapLegend`・`MapPin`。`MapScreen` も同部品へ置換。
- `HomeScreen` を地図主体に再構成（上部ヘッダ＋Map/卫星＋现在位置＋「新增采集」＋
  採集記録の常駐ドラッグ抽屉）。本地保存成功 Dialog、Info メニューを追加。

### アプリアイコン
- Lingscape のアプリマークに刷新（Pillow で SVG 描画、`flutter_launcher_icons` で展開）。

### 依存追加
- `google_fonts` / `flutter_launcher_icons`(dev)

## v1.1.0 (2026-06-29) — ローカル完結化（計画C-1）＋ AI端末化

「家のPCを切ったまま外でスマホ単体で採集・閲覧・書き出し・AI判定まで完結」を実現。

- **データ永続化**: 採集記録と写真を端末に保存、再起動後も復元（`lib/store.dart`）。
- **オフライン起動**: 端末内既定スキーマ（`lib/schema_defaults.dart`）。
- **ローカル採集/書き出し**: クロップ・SignID採番・CSV/ZIP を端末内で（`lib/imaging.dart`）。
- **AI端末化**: Claude/Gemini を端末から直接HTTP（`lib/ai.dart`）。APIキーは端末内保存。
- ビルド: ASCII パス化で直接ビルド可、`kotlin.incremental=false` でキャッシュ失敗回避。

## v1.0.0 — 初期リリース

- Phase 0〜3: FastAPI後端（EXIF/GPS・AI判定・CSV）、Flutter採集MVP、地図预览、AI填字段。
- 実機カメラ撮影・実時GPS、編集/削除、CSV+写真の一括エクスポート。後端依存の構成。
