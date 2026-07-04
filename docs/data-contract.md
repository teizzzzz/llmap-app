# LLMap データ契約（Data Contract）

アプリ v1.5.1 / SchemaVersion **1.5**（採集字段定義表 三語重構版 v3 ＋ A区域ID刷新）

手机端（LLMap Mobile）が生成・导出するデータの正準定義。
PC 端（LLMap Research Console / Backend）はこの契約を前提に取り込む。

## 1. ID 体系（v1.5.0〜）

一意性の中心は **CaptureID**（1回の撮影イベント）。採集者ID とミリ秒時刻を含むため、
複数人が同日・同地区で採集してもファイル名 / SignID が衝突しない。

```text
CaptureID       = AREA-COLLECTORID-YYMMDDHHMMSSmmm
SignID          = CaptureID-<suffix>
写真ファイル名     = CaptureID-<suffix>.jpg      (裁切図。框选なしは suffix=a で全体)
元写真ファイル名   = CaptureID-source.jpg        (原始完整写真。pano とは呼ばない)
DisplayID       = AREA-YYYYMMDD-LOCALSEQ-<suffix>   (表示専用・主キー禁止)
UI short label  = AREA #LOCALSEQ-<suffix>           (例 OOK #008-a)
```

例（CollectorID = `7Kx9Qp2A`）:

```text
CaptureID:       OOK-7Kx9Qp2A-260701143512482
SignID:          OOK-7Kx9Qp2A-260701143512482-a
写真ファイル名:     OOK-7Kx9Qp2A-260701143512482-a.jpg
元写真ファイル名:   OOK-7Kx9Qp2A-260701143512482-source.jpg
DisplayID:       OOK-20260701-008-a
short label:     OOK #008-a
```

- **CollectorID**: Settings の既存機構（NanoID 風 8桁・`Random.secure()`・
  易混字 `0/O/1/l/I` 除外・未設定時は自動生成）。人工短码（T01/TEI 等）は既定にしない。
- **タイムスタンプ**: 端末ローカル時刻 `YYMMDDHHMMSSmmm`（15桁・ミリ秒）。
- **LocalSeq**: 端末内の連番（`_nextSeq`）。表示・整理用で、一意性は担わない。
- 1枚の元写真から複数 sign を裁切した場合、全 sign が同一 CaptureID・
  同一 元写真ファイル名 を共有し、SignID / 写真ファイル名 は suffix で分かれる。

## 2. CSV 列（A 識別情報）

| 列 | 新規/旧 | 新規レコードでの値 | 旧レコード互換 |
|---|---|---|---|
| SignID | 旧(意味更新) | `CaptureID-suffix` | 旧形式のまま保持 |
| _status | 旧 | pending/ai/human-reviewed/final | 同じ |
| CaptureID | **新** | 上記規則 | 空 → 読取時 写真ID にフォールバック |
| DisplayID | **新** | `AREA-YYYYMMDD-SEQ-suffix` | 空 → SignID にフォールバック |
| 採集者ID | **新** | Settings の CollectorID | 空（unknown 扱い） |
| 地区コード | **新** | AREA（大文字） | 空 |
| LocalSeq | **新** | 端末連番（整数） | 空 |
| CropSuffix | **新** | a/b/c… | 空 → SignID 末尾から推定 |
| CropRect | **新** | JSON `{"x":0.12,"y":0.34,"w":0.45,"h":0.20}`。框选なしは `{"x":0,"y":0,"w":1,"h":1}` | 空 |
| 写真ID | 旧 | **= CaptureID**（互換値） | 旧形式のまま |
| 写真ファイル名 | 旧 | `CaptureID-<suffix>.jpg` | 旧形式のまま |
| 元写真ファイル名 | **新** | `CaptureID-source.jpg` | 空 → 全景写真ファイル名 にフォールバック |
| 全景写真ファイル名 | 旧 | **= 元写真ファイル名**（互換値） | 旧形式のまま |
| 緯度 / 経度 / 採集日時 | 旧 | 同じ（採集日時は秒精度のまま） | 同じ |
| EntryMode | **新** | `standard`（現行採集フロー） | 空 |
| DataStatus | **新** | _status の対応値（下表） | 空 → 導出時に _status から導出 |
| SchemaVersion | **新** | `1.5`（本契約） | 空 |
| AppVersion | **新** | 採集時のアプリ版（例 `v1.5.1`） | 空 |

**DataStatus 対応表**（端末は `_status` が正。DataStatus は Research Console
審核フロー互換の派生値で、`Sign.setStatus()` が常に同時更新する）:

| _status（端末） | DataStatus（Console） |
|---|---|
| pending | raw |
| ai | ai_drafted |
| human-reviewed | reviewed |
| final | verified |

B〜D 区（言語・物質・解読字段）は三語重構版 v3 から変更なし。

## 3. 旧データ互換ルール

- 旧レコードは**変換しない**（フィールドは疎な Map のまま保持）。読取側がフォールバックする:
  - CaptureID なし → 写真ID
  - DisplayID なし → SignID
  - 元写真ファイル名 なし → 全景写真ファイル名
  - CropSuffix なし → SignID の末尾セグメント
  - 採集者ID なし → 空表示
- 旧データの閲覧・編集・导出は従来どおり動作する。
- 导出時は §6 の**導出時規範化**により、旧レコードも新契約形式で CSV/ZIP に出る
  （本地データは無変換のまま）。

## 4. 写真保存の衝突保護

`LocalStore.savePhoto` は同名ファイルを静黙上書きしない:

- 同名・同内容 → 書き込みスキップ（冪等）。
- 同名・異内容 → `名前~2.jpg` `名前~3.jpg` … の衝突回避名で保存し、
  実際に使った名前を呼び出し側（レコード）に返す。

## 5. 导出パッケージ（現行）

```text
llmap_export.zip
  data.csv        # utf-8-sig・上記表頭（規範化済みの行）
  photos/         # data.csv の 写真ファイル名/元写真ファイル名 と**完全一致**する JPEG
  MANIFEST.txt    # 件数・同梱/欠落写真・source_missing の一覧
```

標準 Dataset Package（機械可読 manifest.json、source_photos/ 分離等）は
次段（Step 2）で定義する。

## 6. 導出時規範化（export-time normalization）

旧レコードは**本地では原様のまま**、导出の瞬間だけ新契約へ変換する
（`app/lib/export_normalizer.dart`）。本地 project.json・旧写真ファイルは書き換えない。

- CaptureID を持つレコード → そのまま导出（DataStatus のみ欠けていれば _status から補完）。
- CaptureID の無い旧レコード → 以下の規則で生成:

```text
CaptureID = AREA-COLLECTOR_OR_LEGACY-YYMMDDHHMMSS000
  AREA      : 地区コード → SignID/写真ID の先頭セグメント → UNK
  COLLECTOR : 採集者ID → "legacy"（端末の現IDは入れない＝来源を捏造しない）
  時刻      : 採集日時（秒精度）＋ミリ秒 000。欠落時は全ゼロ
SignID      = CaptureID-suffix（CropSuffix → 旧SignID末尾 → a）
DisplayID   = 既存値 → 旧SignID → AREA-日付-連番-suffix
CropRect    = 既存値 → {"x":0,"y":0,"w":1,"h":1}
写真ID      = 旧値のまま（本地ファイルへの追跡用）
```

- **グループ共有**: 同一 写真ID の裁切群は同じ CaptureID・同じ 元写真 を共有する。
- **衝突回避**: 同秒の別撮影イベントで CaptureID が重なる場合は `-002` `-003` …を
  追加。导出包内で同名上書きは発生しない（CSV と zip 内の名前は常に一致）。
- **写真**: 旧ファイルを导出包内で新名（`CaptureID-<suffix>.jpg` / `-source.jpg`）に
  複製。旧・整図採集など元写真が特定できない場合、元写真ファイル名 は空とし、
  MANIFEST.txt の `source_missing:` に SignID を列挙する。
