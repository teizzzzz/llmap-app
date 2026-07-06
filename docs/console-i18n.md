# Console 多言語 UI（Step 11）

PC Console / Desktop の UI を **ja-JP（既定）/ zh-CN / en-US** の 3 言語に対応させた。
実装は i18next + react-i18next。

```text
console/src/i18n/index.ts            # 初期化・言語検出・setLanguage()
console/src/i18n/locales/ja-JP.json  # 日本語（既定）
console/src/i18n/locales/zh-CN.json  # 简体中文
console/src/i18n/locales/en-US.json  # English
```

## 紅線（翻訳しないもの）

**翻訳するのは UI 表示層のみ。** 以下は一切変更しない:

- **データの字段キー**: `主要言語`・`補助言語`・`SignID`・`CaptureID` 等は
  データスキーマそのもの。UI ラベル表示だけ `fields.*` キーで翻訳し、
  PATCH / CSV / Dataset Package には従来どおり原キーが載る。
- **CSV ヘッダー**: backend の導出はそのまま（backend は本 Step で無変更）。
- **backend API**: エンドポイント・パラメータ・レスポンスとも無変更。
- **内部状態値**: `quick/standard/research`、`raw/submitted/ai_drafted/
  needs_review/reviewed/verified/rejected`、legacy `_status`
  （`pending/ai/human-reviewed/final`）は内部値のまま。表示ラベルだけ
  `status.*` キーで翻訳する（例: verified → 確定済み / 已确认 / Verified）。
  `<select>` の option も **value は内部値・表示だけ翻訳**。

## 言語の決定と切替

1. `localStorage['llmap.console.language']`（ユーザー設定）
2. ブラウザ言語（`zh*` → zh-CN、`en*` → en-US）
3. 既定 **ja-JP**（日本の大学での運用が主のため）

切替は Settings ページのボタン（日本語 / 简体中文 / English）。
`setLanguage()` が即時切替＋localStorage 保存＋`<html lang>` 更新を行う。
Tauri Desktop でも WebView の localStorage に保存されるため再起動後も持続する。

## 実装規約

- コンポーネントは `useTranslation()` の `t()` を使う。動的キー
  （状態値・字段名）は `t(`status.${v}`, { defaultValue: v })` のように
  **defaultValue に原文**を入れ、未知値でもキー文字列が漏れないようにする。
- 定数配列にラベルを持たせる場合は文字列でなく **i18n キー**（`labelKey`）を
  持たせ、描画時に `t()` する（`reviewStatus.ts` の QUEUE_TABS /
  REVIEW_ACTIONS、Sidebar の NAV、ExportPage の FORMATS 等）。
- 件数は `{{n}}` の interpolation（`common.records` 等）。
- 3 つの locale JSON は**同一のキー集合**を保つ（fallback は ja-JP）。

## TODO（先送り）

- **Desktop native loading/error overlay i18n is deferred** —
  `desktop/src-tauri/src/main.rs` の起動オーバーレイ
  （"Starting LLMap local backend…" / "Failed to start LLMap backend."）は
  Console 読み込み前の注入スクリプトのため i18next に乗れない。当面英語のまま。
  対応する場合は localStorage の言語設定を読んで出し分ける（main.rs に TODO 記載）。
- Mobile（Flutter）側の i18n は対象外（本 Step は Console / Desktop のみ）。

## 検証（実施済み）

- `npm run build`（tsc strict + vite）通過。
- Playwright E2E 19 項目: en/zh/fr ブラウザ言語での初期言語、Settings での
  即時切替、reload 後の持続、全 7 ページの翻訳表示、`<select>` option の
  value が内部値のままであること、`ai_drafted` 等の内部値リテラルの保持。
