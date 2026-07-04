# LLMap データ契約（Data Contract）

アプリ v1.5.0 / SchemaVersion: 採集字段定義表 三語重構版 v3 ＋ A区域ID刷新

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

B〜D 区（言語・物質・解読字段）は三語重構版 v3 から変更なし。

## 3. 旧データ互換ルール

- 旧レコードは**変換しない**（フィールドは疎な Map のまま保持）。読取側がフォールバックする:
  - CaptureID なし → 写真ID
  - DisplayID なし → SignID
  - 元写真ファイル名 なし → 全景写真ファイル名
  - CropSuffix なし → SignID の末尾セグメント
  - 採集者ID なし → 空表示
- 旧データの閲覧・編集・导出は従来どおり動作する。CSV は新表頭で出力され、
  旧レコードの新列は空欄になる（导出は失敗しない）。
- 旧写真ファイルのリネーム（migration / export-copy）は未実装。実装するまで
  旧ファイル名のまま导出する。

## 4. 写真保存の衝突保護

`LocalStore.savePhoto` は同名ファイルを静黙上書きしない:

- 同名・同内容 → 書き込みスキップ（冪等）。
- 同名・異内容 → `名前~2.jpg` `名前~3.jpg` … の衝突回避名で保存し、
  実際に使った名前を呼び出し側（レコード）に返す。

## 5. 导出パッケージ（現行）

```text
llmap_export.zip
  data.csv        # utf-8-sig・上記表頭
  photos/         # 写真ファイル名・元写真ファイル名（旧: 全景写真ファイル名）で参照される JPEG
  MANIFEST.txt    # 件数・同梱/欠落写真の一覧
```

標準 Dataset Package（機械可読 manifest.json 等）は次段（Step 2）で定義する。
