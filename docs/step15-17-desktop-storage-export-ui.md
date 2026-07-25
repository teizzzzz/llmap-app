# Step 15–17: 桌面端 存储・導出・UI 増強

「待解决桌面端」リスト（2026-07）への対応。backend 0.4.0 / console 0.9.0。

## Step 15 — 存储モデル（一.1 基礎 / 一.5）

**導入フローの臨時化**（`import_dataset.py` 全面改修）
- zip は `data/tmp/` へ**ストリーミング**受信（メモリ全載せ廃止）
- 展開・検証 → 写真は正式目录へ **rename 移動**（同一 FS・複製ゼロ）
- commit 後に zip・展開目录を**即削除**。「原始包を保管」は任意（`archives/`、既定オフ）
- 旧フローは zip＋展開＋正式コピーの 2〜3 倍占用だった

**二層去重**
- 整包 SHA-256（`dataset.package_hash`）: 同一 zip の再導入は
  `status=duplicate` を返し、Console が「閉じる / 欠落写真だけ補充」を提示
  （SignID 全体一意のため「新データセットとして再導入」は成立しない）
- 写真内容去重: 同名同内容は再保存せず共用、同名別内容は `stem~2.ext` に
  改名し、その導入分の記録参照も追随（既存データは無傷）

**最小マイグレーション層**（`database.py`）
- `PRAGMA user_version` ＋ 版数別 ALTER。create_all は新テーブルしか作らない
  ため、**既存テーブルへの列追加は必ずここに書く**（v2: package_hash）

**存储の可視化と清掃**
- `GET /storage/summary`: データ目录パス・分類別使用量・ディスク残量・回収可能量
- `POST /storage/cleanup {dryRun}`: 旧 imports/（zip＋展開）と tmp/ 遺留を削除。
  正式写真庫に欠落があるうちは**削除拒否**（imports が唯一の復旧源かもしれない）。
  photos/・source_photos/・SQLite・archives/ には一切触れない
- Console Settings に「ストレージ」カード（内訳・残量・回収可能量・一鍵清掃）

**データ目录の変更（一.1 基礎）**
- shell が `<OS config dir>/LLMap/config.json` の `{"dataDir": "D:\\LLMapData"}`
  を読む（Windows: `%APPDATA%\LLMap\config.json`）。再起動で反映、
  実効パスは Settings > ストレージ で確認できる
- UI からの変更＋既存データ移行ウィザード（停止→複製→検証→切替→旧削除確認）
  は別 Step（工程が重く、清掃実装で C 盘圧力は先に解消するため）

## Step 16 — 導出（一.2 / 一.3 / 一.4）

**導出ジョブ基盤**（`export_jobs.py`）: バックグラウンド構築・進捗 done/total・
取消・完了後ダウンロード。zip は `data/exports/` に逐次書き（メモリに組まない）。

- **Dataset Package**（`POST /export/package`）: data.csv（正準36列）＋
  photos/ ＋ source_photos/ ＋ metadata/schema/manifest（各ファイル
  sha256/size）＋ MANIFEST.txt ＋ README。欠落は `missingFiles` に明示。
  **往返互換をテストで保証**（導出→導入が全行 SignID 認識）
- **GeoJSON**（`GET /export/geojson`）: RFC 7946・座標 [経度,緯度]・WGS84。
  GPS 無し記録は含めず件数を foreign member `llmap.skippedNoGps` に記録。
  properties は 精簡 / 全字段 の 2 択
- **写真 ZIP**（`POST /export/photos`）: 内容（裁切/元写真/両方）×命名
  （原名 / SignID / DisplayID、衝突は ~2 連番）。`photo_mapping.csv`
  （SignID,DisplayID,CaptureID,照片文件,原图文件）同梱。
  **内容ハッシュ去重**で同一写真は 1 回だけ。欠落は MISSING.txt

Console の Export 頁: 3 形式とも実装（ジョブ式は進捗バー・取消・下載付き）。

## Step 17 — UI（二.1〜二.4）

- **統一写真ビューア PhotoLightbox**: ズーム（ホイール/±）・fit/1:1・
  ドラッグ平移・回転・裁切↔元写真切替・←→前後・ピクセル寸法・下載・Esc。
  Database 詳情（二.2）と Review（二.3 の「点击无效果」修理）と相册グリッドが共用
- **地図（二.1）**: marker clustering（leaflet.markercluster、spiderfy 付き）で
  2000+ 点の密集を解消。全画面モード（⛶ / Esc）・筛选バー折りたたみ。
  言語色は divIcon 丸マーカーで維持。视口 bbox 查询は 2 万点超で導入予定
- **Dataset 相册（二.4）**: Database 頁に「テーブル / データセット相册」切替。
  封面・件数・写真容量・導入日のカード → 写真グリッド（分页ロード）→
  ビューア。「テーブルで表示」でそのデータセット筛选の表格へ。
  手機端ユーザー相册の跨端同期は Dataset Package formatVersion 1.1
  （albums.json 追加）として別 Step

## 検証

- backend: pytest **31/31**（去重・清掃・GeoJSON・包往返・写真ZIP去重 等 12 件追加）
- console: `npm run build`（tsc strict）通過
- Playwright E2E **22/22**: 実 JPEG 包の導入 → 重複検出対話 → 詳情/審核/相册の
  Lightbox → 地図 marker/全画面/Esc → GeoJSON 下載 → Package ジョブ完了+下載 →
  存储カード表示・清掃対象なし
- desktop: `cargo check` 通過（config.json 読み取り）
