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

## v1.14.2 (2026-10-27) — 仪表盘の網点写真を削除（ユーザーフィードバック）

- 仪表盘右上の「駐輪禁止」網点写真と、その衬底（灰色块・荧光の帯・虚線円・補助線・
  十字裁切線）を削除。見出しは記録数＋「条街道上的文字」だけの単欄に。
- console 0.12.2 / desktop 1.14.2（backend 0.6.12 のまま）。

## v1.14.1 (2026-10-27) — アプリアイコン刷新・ナビの番号を削除（ユーザーフィードバック）

- **アプリアイコンを視覚規範に合わせて描き直し**: 紙色の角丸地に太い「LL」、
  荧光の帯を重ね刷り（乗算）、網点の灰色块・虚線の円・補助線・十字裁切線。
  48px 以下は細線が潰れるため「LL」＋荧光の帯だけの簡略版を使い分ける。
  生成スクリプト `desktop/src-tauri/icons/make_icon.py`（ico / icns / png を一括出力）。
  インストーラ（NSIS）の画面アイコンも同じものに（従来は NSIS 既定）。
- **侧栏の 01–07 の番号を削除**（メニュー名だけに）。
- console 0.12.1 / desktop 1.14.1（backend 0.6.12 のまま）。

## v1.14.0 (2026-10-27) — Research Console の UI 刷新（Figma「Console UI 改稿」準拠）

- **視覚規範を一新**: 紙（#EDECE7）・墨・荧光 1 色（#C8F03C）。直角・影なし、
  1px 墨線で区切り、行は点線。数字は Archivo、ID・時間は IBM Plex Mono
  （同梱・オフライン可）、和文/中文はシステムフォント。荧光は「当前 / 要対応」
  （現在ページ・待審核・選択中の形式・需复核）にだけ使う。
- **言語色を UV 印刷板と同じ CMY 体系に統一**（ja=M, en=C, zh=Y, ko=C+M,
  vi=C+Y, ne=M+Y）。表格・队列・地図・相册・仪表盘の言語表示が色方块＋コード
  （JA / EN …）になった。言語色はデータの印にだけ使う。
- **説明文の小字を削除**: 各ページの副題・英語副ラベル・注記を外し、
  侧栏は LLMAP 字标＋番号ナビ＋接続状態だけ、顶栏は検索だけ（Enter で
  数据库へ、関键词を引き継ぐ）。版本・URL は接続状態の tooltip に残す。
- **仪表盘**: 記録数の大見出し＋網点写真の扉、指標 6 項目の行、主要言語構成
  （積み上げ帯＋比率）、データ状態・採集モード・採集者・欠損ファイル。
- **筛选栏**: 11 個の select を、検索＋常用 4 項目（語言・状態・地区・日期）＋
  「更多筛选」に再構成。適用中の条件は chip で一覧・個別解除。数据库（表格・
  相册）と导出で**筛选条件を共有**（数据库で絞って「导出当前筛选」へ）。
- **数据库の相册を瀑布流に**: データセット単位の相册を、筛选結果の写真を
  原比例で並べる瀑布流に置き換え。無限スクロール・Ctrl/Alt+ホイールの
  列幅ズーム・悬停で ID / 原図の复制（排版用）は継続。`?view=album` で直接開ける。
- **审核**: 队列・大きな写真・字段の 3 列。主操作「已审核，下一条」を 1 つに
  絞り、快捷键 1 已审核 / 2 已确认 / 3 需复核 / X 拒绝 / Ctrl+S 保存 /
  J・K 前後（入力中は無効）。言語選択 chip に色方块。
- **地图**: タイルを Esri 街路図に変更（tile.openstreetmap.org はアプリからの
  利用を 403 で遮断するため）、灰色化して点を目立たせる。凡例は言語ごとの
  表示切替ボタン、下に**言語ごとの分布小図**（クリックでその言語だけ表示）。
  F で全画面。
- **导出**: 01 範囲 → 02 形式 → 03 オプション → 04 出力 の 4 段に整理し、
  形式を選んで 1 つのボタンで実行。
- console 0.12.0 / desktop 1.14.0（backend 0.6.12 のまま）。データ契約不変。

## v1.13.13 (2026-09-25) — 相册の性能改善と連続ズーム（ユーザーフィードバック）

- **本物の縮略図配信を追加**（卡顿の根治）: これまで一覧・相册は
  原図（数 MB/枚）をそのまま読み込んでおり、読込が遅く最大化・リサイズで
  卡顿していた。新端点 `/records/{id}/thumb`・`/thumbs/{filename}` が
  長辺 512px の JPEG を生成して `thumbs/` にキャッシュし、
  **表格・審核队列・相册・相册封面がすべて縮略図に**。原図が必要な場面
  （ビューア・画像复制）は従来どおり原寸。壊れた JPEG は原図配信へ
  フォールバック。写真配信に Cache-Control も付与（再取得を抑止）。
- **画面外セルの描画スキップ**（content-visibility）: 大量セルでも
  最大化・リサイズ時の再描画が視界内だけになり卡顿しない。
- **縮略図サイズを連続ズームに**（小/中/大ボタン廃止）:
  **Ctrl / Alt + ホイール**で Pinterest / Apple 写真の感覚で拡縮
  （80–400px、スライダー併設、前回値を記憶）。ビューア表示中は
  ビューア自身のズームを優先。
- backend 0.6.12 / console 0.11.12 / desktop 1.13.13。データ契約不変。

## v1.13.12 (2026-09-25) — 相册を無限スクロールに（ユーザーフィードバック）

- 相册の「加载更多」ボタンを廃止し、**下へスクロールするだけで自動的に
  次の写真を読み込む**（末尾 600px 手前で先読み — 途切れず閲覧できる）。
  読込中は末尾に小さくインジケータのみ表示。
- console 0.11.11 / desktop 1.13.12（backend 0.6.11 のまま）。

## v1.13.11 (2026-09-25) — 相册の排版支援（ユーザー要望: 書籍レイアウト作業）

- **相册グリッドに悬停操作を追加**: 各サムネイルにマウスを乗せると
  「⧉ 画像コピー」「ID コピー」ボタン。画像は PNG に変換して剪贴板へ —
  **InDesign / Illustrator にそのまま粘贴できる**。ライトボックスの
  ツールバーにも「画像をコピー」を追加（ズーム表示中の裁剪/元写真を复制）。
- **相册内の快速筛选**: 写真グリッドの上に Database と同じ筛选栏
  （検索・語言・状態・期間・字段筛选 15 字段…）を追加。データセットは
  相册で固定のため非表示。筛选結果の件数も表示。
- **縮略図サイズ切替（小/中/大）**: 俯瞰 ⇄ 内容確認を行き来しやすく。
- console 0.11.10 / desktop 1.13.11（backend 0.6.11 のまま）。データ契約不変。

## v1.13.10 (2026-09-25) — 分包の「その他」桶を修正（ユーザーフィードバック）

- **字段別分包の other 語義を修正**: これまで「その他」zip は字面の
  「その他」だけに一致し、実データでは補助言語等に具体的な小語種
  （タイ語・ヒンディー語・不明・自由追加値…）が入っているため
  `sub_other.zip` がほぼ生成されなかった。分包をトークン単位の判定に変更し、
  **枚挙に無い値はすべて その他/其他 の桶に集める**（other = 主要枚挙以外の
  すべて、という研究上の期待語義に一致）。
- 副次修正: 分包の値判定が LIKE 部分一致 → トークン完全一致になり、
  部分文字列の誤マッチの可能性も解消。
- backend 0.6.11 / console 0.11.9 のまま / desktop 1.13.10。データ契約不変。

## v1.13.9 (2026-09-25) — 写真 ZIP の字段別分包（ユーザー要望）

- **写真 ZIP に「字段で分割」を追加**: 枚挙字段を 1 つ選ぶと、その字段の
  値ごとに zip を分けて生成する（例: 主要言語 → `main_jp.zip` /
  `main_en.zip` / `main_other.zip`…）。手作業で「値ごとに筛选 → 導出 →
  改名」を繰り返す必要がなくなる。
  - 命名は `<字段slug>_<値slug>.zip` 固定（言語は jp/kr/cn/ve/ne/en/other、
    他の字段も全値に英語 slug を定義）。再実行で同名を上書き。
  - 値の判定は既存の字段筛选と同一規則（複数選択字段は含有判定 —
    日本語/英語 の記録は main_jp と main_en の両方に入る）。
  - 現在の筛选条件・内容（裁剪/元写真）・命名規則・導出先（今回のみ）と
    すべて組み合わせ可能。値が 0 件の zip は作らない。
  - 分包ジョブは複数ファイルのため単一下载リンクは出さず、生成先目录と
    zip 本数を表示（新 API `POST /export/photos/split`）。
- backend 0.6.10 / console 0.11.9 / desktop 1.13.9。データ契約不変。

## v1.13.8 (2026-09-25) — 導出の論理改善 3 件（ユーザーフィードバック）

- **空字段の自動非表示**: 実データに値が 1 件も無い研究字段（例: v6 で廃止された
  空間階層）は字段筛选に出さない。新 API `GET /stats/fields`（字段ごとの
  非空記録数）に基づき判定。筛选中の字段は隠さない（解除不能を防ぐ）。
- **写真 ZIP の事前集計を表示**: 「筛选したのに全部の写真が出ている？」の
  誤解を解消。写真 ZIP カードに「{records} 記録の {total} ファイル =
  裁剪 {crop} + 元写真 {source}・欠落 {missing}」を筛选・内容選択に追従して
  常時表示（新 API `POST /export/photos/preview`）。件数が記録数より
  大きく見えるのは 裁剪+元写真 の合計のため — 内訳で確認できる。
  ※導出自体は従来から筛选に従っている（ジョブは筛选済み記録のみ処理）。
- **導出先の一時指定**: 導出页に「導出先（今回のみ）」入力を追加。
  Dataset Package / 写真 ZIP がその目录へ直接生成される（空欄 = 設定の
  既定目录。設定値は変更しない）。検証は設定ページと同一規則
  （絶対パス・作成/書き込み可能・開始前に 400）。
- backend 0.6.9 / console 0.11.8 / desktop 1.13.8。データ契約不変。

## v1.13.7 (2026-09-24) — 字段筛选を全字段に拡張・導出画面の筛选可視化

- **字段筛选を字段表の枚挙字段 15 個すべてに拡張**: v1.13.6 の 11 字段に
  主要言語・補助言語・装飾の言語・文字体系を追加。これで「補助言語=英語」
  「韓国語が装飾でのみ現れる記録」のような**言語の役割別**の絞り込み・導出が
  できる（複数選択字段は含有判定 — backend は変更なしで対応済み）。
- 字段筛选区を定義表のグループ（B 言語·文字 / C 物質·状態 / D 社会·機能）で
  3 行に整理し、行頭にグループ名を表示。
- **導出页に「適用中の筛选条件」chip 列を追加**: いま何を筛选して導出するのかを
  導出ボタンの直前に全条件一覧で確認できる。chip クリックでその条件だけ解除
  （語言/地区/採集者/模式/状態/データセット/GPS/写真/原図/期間/字段条件/検索語）。
- backend 0.6.8 のまま / console 0.11.7 / desktop 1.13.7。データ契約不変。

## v1.13.6 (2026-09-24) — 筛选に字段表の研究字段を追加（導出・数据库）

- **筛选栏に折りたたみ式の「字段筛选」区を追加**（導出页・数据库页共通）:
  字段定義表の枚挙字段（文字性・多言語関係・担体類型・放置位置・空間階層・
  時間性・可読性・重ね書き・設置主体・ディスコース類型・製作品質）で
  記録を絞り込める。条件あり時はボタンに件数を表示し自動展開。
- 筛选は件数集計と **CSV / GeoJSON / Dataset Package / 写真 ZIP /
  バッチ AI の全対象選択に共通で効く**（`apply_filters` に `fields`=JSON を
  追加し、`data_json` の `json_extract` で照合。複数選択字段は含有判定・
  同一字段の複数値は OR）。未知字段・壊れた JSON は 400 —— 黙って条件が
  落ちて「筛选したつもりで全件導出」になる事故を防ぐ。
- Dataset Package の manifest `filters` にも字段条件が記録される（導出来歴）。
- backend 0.6.8 / console 0.11.6。データ契約・DB スキーマは不変。

## v1.13.5 (2026-09-03) — 保存・審核ボタンを右側の字段列へ（ユーザーフィードバック）

- 保存・審核アクション（保存/已審核/已確認/需複核/拒絶/DB で開く）を
  ビューア下から**右側・研究字段列の最上部**へ移動。sticky で字段を
  スクロールしても常時見える。ビューア下は縮略切替バーと折りたたみ元情報のみに。
- console 0.11.5（表示のみ・データ不変）。

## v1.13.4 (2026-09-03) — 審核ビューアを左側へ（ユーザーフィードバック)

- 大画面写真ビューアを**左**、研究字段を**右**に入れ替え（v1.13.3 の逆配置）。
  視覚順のみ row-reverse で反転し、DOM/Tab 順は字段優先のまま。
- console 0.11.4（表示のみ・データ不変）。

## v1.13.3 (2026-09-03) — 審核画面のレイアウト刷新（大画面ビューア）

- **審核工作区を「左=研究字段 / 右=大画面写真ビューア」の 2 列に再構成**
  （ユーザー要望）: これまで写真は 220px の小さなサムネイル 2 枚で、
  中央〜右に大きな空白が余っていた。写真を残り全幅で大きく表示し、
  **原寸表示を開く回数を減らして標注効率を上げる**。
- 一般的な画像ギャラリー式の操作: 大画像の下に裁切図/元写真の**縮略切替バー**。
  クリックで従来どおり原寸ライトボックスも開ける。片方しか写真が無い記録は
  自動で他方を表示。
- **元情報（只読）は既定で折りたたみ**（必要な時だけ開く）。
  保存・審核アクションはビューア下に横並びで常時見える位置に。
  ビューアは sticky — 字段を下へスクロールしても写真が視界から消えない。
- 表示のみの変更（データ・API 不変）。backend 0.6.7 のまま / console 0.11.3。

## v1.13.2 (2026-09-03) — 全データ削除（初期化）機能

- **設定 → ストレージに「全データ削除（初期化）」を追加**: 記録データベースの
  全行・写真（裁切図/元写真）・導入遺留・保管パッケージ・既定フォルダ内の
  導出物を一括削除し、SQLite を VACUUM で収縮する。これまで手動でファイルを
  消すしかなかった操作を UI 化。
- **残すもの**: settings.json（AI キー・導出先設定）とログ。設定済みの
  **外部**導出フォルダには一切触れない（ユーザー選択の場所で他ファイルが
  同居し得るため、既定の data_dir/exports のみ対象）。
- **誤操作防止の二重ガード**: UI は「DELETE」の打鍵確認までボタン無効、
  backend も `confirm="DELETE"` が無い要求を 400 で拒否する。
  実行後は削除件数と解放容量を表示。
- backend 0.6.7（POST /storage/reset）/ console 0.11.2。テスト 43 件パス
  （confirm 拒否・全消し・settings 保持を検証）。

## v1.13.1 (2026-09-03) — 多言語関係を 2 段入力に（互补型を追加・v6.1 追補）

- **多言語関係の入力を「①是否多语言 → ②類型」の 2 段に変更**（Console）:
  「単一言語」を選べば 单语型、「多言語」を選ぶと Reh (2004) の 4 類
  （复制型 Duplicating / 重复型 Overlapping / 部分翻译型 Fragmentary /
  **互补型 Complementary**）から選ぶ。
- **互补型を新設**: Reh の原分類で唯一欠けていた「各言語の内容が完全に別々で
  重複なし」。従来は該当標識の受け皿が無かった。
- **保存形式は不変**: 従来どおり 1 字段 1 値（单语型 or 4 類）。「是否多语言」
  は値から導出できるため**新列は作らない**（冗長列は不整合の温床）。
  旧データ 4 値はそのまま有効。
- AI 提示詞に 互补型 と判定順を追記（backend ai_engine.py / app ai.dart 同文）。
  アプリ側は schema_defaults.dart の選択肢も同期（**モバイルのビルドは無し** —
  ソース同期のみ、次回モバイル更新時に反映）。
- backend 0.6.6（/schema の選択肢 5 値化）/ console 0.11.1。テスト 42 件パス。

## v1.13.0 (2026-09-03) — B 言語 3 字段の新入力器（検索追加・不明・無の状態モデル）

Console の 主要言語/補助言語/装飾の言語 に専用の LanguageRoleSelector を導入。
**データ契約は不変** — 保存形式は従来どおり日本語名の「/」区切り（無は「—」）、
ISO 码は UI 内部キーのみ。地図・筛选・CSV・旧データへの影響なし（着手前に
PATCH 検証・LIKE 筛选・統計の拆分計数・その他の旧値互換を確認済み）。

- **予設 chip ＋「＋その他の言語」検索追加**: 予設は v6 の 6 言語（その他は
  今後 UI から産出しない。旧データの その他・自由値は削除可能 chip で表示）。
  検索は内蔵言語表（56 言語、ja/zh/en/本族語名/ISO 码のどれでも部分一致）から
  選択し、正準日本語名で保存 — 表記ゆれ（半角ぺ等）を根絶。訳の無い言語名は
  言語表を第2辞書として表示訳（enumLabel フォールバック）。
- **「不明」を新設（v6.1 追補）**: 語種判別不能の専用値。従来「その他」に
  混在していた用法を分離。具体言語と**併存可**（"日本語/不明" — 採集從寬）、
  「無（—）」とだけ互斥。統計は既存の拆分計数でそのまま集計され、筛选下拉
  にも 不明 を追加（後端は含有 LIKE のため変更不要）。地図色は fallback 灰。
- **「無（—）」は字段級の状態 chip**（補助言語・装飾の言語のみ。主要言語は
  文字があれば必ず存在するため無し）。具体言語と互斥、自動クリアは読み上げ
  （aria-live）でも通知。
- **文字性との連動**: 文字性を 記号/対象外 に変えると B 言語 3 字段は自動で
  「—」になり編集禁用（無文字は図片級属性 — 言語字段内の状態ではない）。
  「文字」へ戻しても自動復元はしない。
- 無障害: chip は role=checkbox + aria-checked、選中は 背景＋辺框＋✓ の三重
  表現。検索框は ARIA combobox（listbox/矢印キー/Enter/Esc、IME 組立中の
  Enter 誤確定ガード付き）。
- モバイル App は変更なし（同じ状態モデルでの追随は今後の課題）。
  backend 変更なし（0.6.5 のまま）/ console 0.11.0。

## v1.12.6 (2026-09-02) — Console 選択肢値の表示翻訳（enum i18n）

- **字段の選択肢値も UI 言語で表示**: これまで UI 言語を切り替えても翻訳されるのは
  字段名・状態値のみで、選択肢値（担体類型の「无媒介」等の v6 中文正準値、
  言語名の日本語値）は原文のままだった。詳情・審核の編集器（下拉・チップ）、
  記録表格・審核队列・地図 popup/凡例、筛选栏の言語選択、ダッシュボードの
  主要言語別分布のすべてで、表示ラベルを ja / zh / en に翻訳する。
- **データ層は不変**（従来方針どおり）: 保存値・CSV・API・筛选キーは正準値のまま。
  翻訳キーは `enum.<正準値>`（console/src/lib/enumLabels.ts）。自由追加値や
  訳の無い値は原文のまま表示。fallbackLng=ja のため 3 locale とも完全対照表を持つ。
- 側栏 footer の console 版号が v0.9.0 に固定されていたのを修正
  （package.json から取得）。
- モバイル App は変更なし。backend 0.6.5 のまま / console 0.10.6。

## v1.12.5 (2026-08-19) — 導出のデータセット多选

- Console の筛选栏「数据集」を单选下拉から**チェックボックス式の多选**に変更。
  複数データセットをまとめて CSV / GeoJSON / Dataset Package / 写真 ZIP に導出できる。
  （筛选栏は数据库页と共用のため、表格の筛选でも多选が使える）
- backend: `datasetIds` パラメータを追加（GET はカンマ区切り "1,3"、POST は JSON 配列）。
  /records・/map/records・/export/csv・/export/geojson・導出ジョブ・AI 筛选で共通対応。
  従来の単値 `datasetId` は後方互換で維持。
- 相册视图の「在表格中打开」も datasetIds 経由に統一。
- backend 0.6.5 / console 0.10.5。テスト: 多选筛选・導出・後方互換の検証を追加（42 件全通過）。

## v1.12.4 (2026-07-25) — 字段表示の微調整（ユーザーフィードバック）

- 字段ラベル横の「AI」印を削除（AI 起草対象の目印だったが紛らわしいため）。
- 区分見出しから B/C/D の字母を削除（「语言 / 物质·状态 / 社会·功能」のみ表示）。
- backend 0.6.4 / console 0.10.4（機能変更なし・表示のみ）。

## v1.12.3 (2026-07-25) — Console の研究字段を v6 定義表へ完全整合

記録詳情・審核の編集器が v6 以前の「第一版 7 字段」白名单のままで、
AI が起草した維度の大半（文字性・放置位置・時間性・可読性・重ね書き・
ディスコース類型・製作品質・装飾の言語）が**表示されなかった**問題への対応。

- **字段清単のハードコードを廃止**: /schema に system_fields を追加し、
  研究字段 = CSV 表頭 − 系統字段 で派生（console/src/lib/researchFields.ts）。
  将来列が増えても UI が自動追従（今回の漏れの再発防止）。
- **v6 定義表と同じ区分・順序で表示**: B 言語 → C 物質・状態 → D 社会・機能。
  AI 起草対象の字段には小さな「AI」印。詳情・審核の両画面が同一派生を共用。
- **状態を 1 つに統合**: 編集は「状態」（v6 定義表どおり pending/ai/
  human-reviewed/final の 4 値）のみ。DataStatus は編集器から外し、
  識別情報欄に「審査状態（自動）」として只読表示（保存時に backend が自動同期）。
- **v6 定義表に無い旧 4 字段（名称/文字体系/空間階層/設置主体）を UI から非表示**
  （ユーザー決定）。CSV 列と既存データは互換のため保持 — 完全削除は
  SchemaVersion 1.7 の課題として保留。
- backend 0.6.3 / console 0.10.3。テスト 41 件パス。

## v1.12.2 (2026-07-25) — バッチ AI の実時ログ

- **AI 処理ページに「運行日志」パネルを追加**: レコード 1 件ごとに
  ✓ 起草（字段数）/ – 変更なし / ⏭ スキップ（写真なし）/ ✗ エラー（原因）を
  実時表示。エラーは赤字で即座に分かる — 全件終了を待たずに異常へ気付ける。
- backend はジョブに構造化ログ（seq 単調増加・上限5000行）を持ち、
  `GET /ai/jobs/{id}?afterSeq=N` で増分取得（0.7秒ポーリングでも転送は差分のみ）。
  文言はログに埋めず Console 側で i18n（ja/zh/en）。
- 開始（モデル・件数）/ 完了サマリ / 取消 / 中止も 1 行ずつ記録。
- backend 0.6.2 / console 0.10.2。テスト 40 件パス（ログ順序・増分取得を検証）。

## v1.12.1 (2026-07-25) — バッチ AI のモデル選択

- **設定 → AI にモデル選択を追加**: Claude は Haiku 4.5（既定・最安）/
  Sonnet 5（品質/価格の推奨）/ Opus 4.8（最高品質）、Gemini は 2.5 Flash（既定）/
  2.5 Pro。選択は settings.json に保存され、実行確認ダイアログ・ジョブ結果にも
  選択モデルが表示される。既定は従来どおり Haiku（モバイルと同一・後方互換）。
- Sonnet 5 は thinking 既定 ON のため分類バッチでは明示無効化
  （思考トークンが max_tokens を食って JSON が切れるのを防ぐ）。
  API タイムアウトを 60→120 秒へ（上位モデルは1枚が遅くなり得る）。
- backend 0.6.1 / console 0.10.1。テスト 39 件パス（モデル設定往復・
  不正値 400・ジョブが選択モデルで走ることを検証）。

## v1.12.0 (2026-07-25) — 桌面端バッチ AI（Console から一括起草）

これまで AI 判定はモバイル端のみだった。Console の「AI 処理」ページを scaffold
から実機能にし、導入済み記録に対して一括で v6 の 13 維度を起草できるようにした。

- **バッチ実行**: 筛选（状態/モード/言語/地区/データセット/写真有無）に一致する
  記録の裁切写真を Claude / Gemini で判定し、下書きを併合。進捗表示・取消・
  レコード別エラー一覧つき。実行前に件数とモデル名を出して確認（API 課金対策）。
- **モバイル版と同一の判定・併合**: v6 プロンプト・判定順・口訣を ai.dart から、
  併合規則（備考は追記のみ・複数選択は和集合・単一字段は空欄のみ・不確実は
  書かない・pending→ai の昇格のみ）を record_ops.mergeAiDraft から忠実移植
  （backend/app/ai_engine.py。単体テストで規則を固定）。
- **安全設計**: 記録ごとに独立コミット（取消/中断でも完了分は残り、再実行は
  冪等 — 二重追記なし）。連続 3 件失敗で自動中止（無効キーで全件空振りしない）。
- **設定 → AI**: プロバイダ選択と Claude/Gemini API キー（settings.json 保存）。
  キーは読み出し API で返さない（CORS 全開のため GET には有無とヒントのみ）。
- **事前プレビュー**: AI を呼ばずに対象件数（写真有無・状態内訳）だけ集計。
- 新 API: /ai/status（実状態）・/ai/preview・/ai/jobs（開始/進捗/取消）。
  依存に httpx / pillow（最大辺1024・quality75 縮小はアプリ §9 と同一）。
- backend 0.6.0 / console 0.10.0。テスト 38 件パス（併合規則・キー設定・
  モックジョブ・連続失敗中止・昇格/非降格）。

## v1.11.1 (2026-07-25) — 導出先フォルダを設定可能に（C 盘固定の解消）

導出/下载が常にソフトの数据目录（桌面版では C 盘の `%APPDATA%\LLMap\exports`）へ
zip を生成していた問題への対応。

- **設定 → 導出目录**（Console）: 任意の絶対パス（別ドライブ可）を指定でき、
  以後の導出ジョブ（Dataset Package・写真 ZIP）はそこへ直接生成される。
  空欄保存/「既定に戻す」で従来の `data_dir/exports` へ復帰。
- backend に `settings.json`（data_dir 直下・原子的保存）と `GET/PUT /config` を新設。
  指定パスは保存時に 絶対パス・作成可・書き込み可 を検証（不可なら 400 で理由表示）。
  実行時に到達不能（ドライブ取り外し等）なら既定へ静かにフォールバックし導出は止めない。
- 導出完了表示に**生成先フルパス**を追加（ジョブ状態 API に `path` を追加）。
  桌面版では再ダウンロード不要でそのまま開ける。
- backend 0.5.1 / console 0.9.1。テスト: 設定往復・カスタム目录への生成・
  相対パス/未知キー 400 を追加（backend 32 件パス）。

## v1.11.0 (2026-07-24) — 字段定義表 v6 対応（AI 判定の 13 維度化・SchemaVersion 1.6）

「言語景観_採集字段定義表 v6（2026-07-24）」に全層で追従。

- **新字段 `放置位置`**（建筑物上/柱子/公告板/屏幕/道路/市政设施设备/半可移动物体/其他）
  を 担体類型 の後ろに追加。CSV は 36→**37 列**、SchemaVersion **1.6**。
- **選択肢を v6 の中文正準値に更新**: 担体類型（无媒介/产品/贴纸/旗帜/海报/宣传册/
  夹心板/车辆/便签/其他）・時間性・可読性・重ね書き・多言語関係・製作品質。
  文字性は 文字/記号/**対象外**（定義表の例示に合わせユーザー確定）。
  ディスコース類型は 规约性话语/基础设施话语/商业话语/交际性话语/判读不能/其他
  （判定順が参照する規約類を含む 6 値・ユーザー確定）。
  **言語名のみ既存の日本語値を維持**（地図色・筛选・既存データとの連続性のため）。
- **AI 判定対象を v6 の 13 維度に整理**: 名称/文字体系/空間階層/設置主体 は AI 対象外
  （表単では引き続き人力入力可・CSV/旧データも保持）。
- **AI 併合規則を新設** `record_ops.mergeAiDraft`（テスト付き）:
  ①既存内容は絶対に削除・上書きしない — 備考は「既存 新規」で**追記**、複数選択字段は
  和集合、単一字段は空欄のみ埋める。②AI が不確実（空値）を返した字段は書かない。
  ③状態は pending→ai の昇格のみ（human-reviewed/final を AI 再実行で降格させない）。
- AI プロンプトを v6 の判定順・口訣に全面書き換え（不確実は空欄・備考は新規観察のみ・
  【判断】/【数量】接頭辞）。max_tokens 1000→1500。
- backend schema.py も同期（0.5.0）。Console は 37 列表記と 放置位置 ラベルを追加。

## v1.10.2 (2026-07-07) — 並行開発の合流（選択性導出 × 安全強化）

ローカル線（v1.10.0/1.10.1: 選択性導出）と远端線（v1.9.2/1.9.3:
カメラ/写真権限拒否時の案内・iOS Ad Hoc 打包脚本・Step 14 データ安全強化・
字段表示ラベルの本地化 field_labels.dart・Windows 一括ビルド脚本
scripts/build-windows-app.ps1・backend モジュール整理）をマージ。
l10n は両側の追加キーを全部保持し gen-l10n で再生成。versionCode は
両側が +27 を使っていたため +28 に採番し直し。
`flutter analyze` **0 issues** / `flutter test` 65 件 PASS。

## v1.10.1 (2026-07-07) — 導出範囲に「アルバムから選ぶ」を追加（Step 14 完善）

導出シートに **任意の相册を選んで導出** する範囲を追加（`ExportScope.album`）。
いま開いている相册でなくても、二段目シートで相册（件数つき）を選べる。
Home / Gallery 両方の導出シートに追加（相册ゼロのときは非表示）。
抽出規則は currentAlbum と同一で、削除済み recordId は無視。
l10n 1 キー × ja/zh/en。`flutter test` **65 件 PASS**（単体1・widget 1 追加）。

## v1.10.0 (2026-07-07) — 選択性導出 / Selective Export（Step 14）

Dataset Package の導出前に**範囲を選べる**ようにした。従来の
「常に全件」から、整理フローの成果だけを書き出せる形へ。

- **導出範囲**（`ExportScope`）: 全部 / 現在の表示（相册視図・归納状態・
  筛选・排序を反映した表示リストそのもの）/ 選択中の記録 / 現在のアルバム /
  未分類 / 分類済み。
- **入口**: Home メニューの導出 → 範囲シート（全部・未分類・分類済み）。
  Gallery 通常モードの共有アイコン → 範囲シート（現在の表示・現在の
  アルバム・全部、件数つき）。選択モードの共有アイコン → 選択中を導出
  （0 件時は無効）。いずれも件数つき確認ダイアログ → 共通フロー
  （export_flow.dart に home の導出処理を抽出）で実行。
- **写真の収束は従来ロジックのまま**: buildBundle は渡された記録が参照する
  crop / 元写真だけを同梱し、共有元写真は 1 回だけ（zipName 一意）。
  欠図は従来どおり manifest の missingFiles。導出は非破壊で、選択状態も
  保持する（続けて相册追加・削除に使える）。
- **Dataset Package v1 の構造・CSV header・schema・ID・写真名は不変**。
  albums.json は導出包に入れない。metadata への exportScope 記録も
  第一版では見送り（backend 依存を作らないため）。
- 相册に削除済み recordId が残っていても解決不能分は自然に無視（崩れない）。
- l10n 9 キー × ja/zh/en 追加。`flutter analyze` 追加警告 0 /
  `flutter test` **63 件 PASS**（範囲選択の単体 6・共有元写真の部分集合
  導出 1・widget 1 を追加）。
- backend / Console / Desktop は不変。

## v1.9.1 (2026-07-06) — Gallery 相册归納状態視図（Step 12.1）

Gallery 主視図に「未分類 / すべて / 分類済み」の切替（segmented）を追加。
既定は**未分類**（どの相册にも属さない記録のみ）で、採集後の整理待ち
インボックスとして使える。

- 記録を相册に加えると未分類から**即時に消え**、「すべて / 分類済み /
  該当相册」から見られる。全相册から外れる・相册削除で他の相册に
  属さなくなった記録は未分類へ戻る。
- 具体的な相册を開いている間は归納状態を適用しない（segmented も非表示）。
- 既存の筛选・排序とそのまま叠加（表示のみ・記録本体は不変）。
  複数相册に所属する記録も「分類済み」に 1 回だけ表示。
- 純ロジックは record_ops.dart の `AlbumStatusFilter` / `isFiled` /
  `applyAlbumStatusFilter`。空状態文言も状態別に用意し、筛选起因の空は
  従来の noMatch を優先。l10n 6 キー × ja/zh/en 追加。
- `flutter analyze` 追加警告 0 / `flutter test` **55 件 PASS**
  （単体 7 件＋widget 1 件を追加）。
- backend / Console / Desktop / Dataset Package / 字段 schema は不変。

## v1.9.0 (2026-07-06) — Gallery 批量管理と本地相册（Step 12）

（クラウド作業分の記載補填）Gallery を「相册 / 档案管理器」に増強。

- **批量選択**: iPhone 相册式（長押しで選択モード・タップで多選・
  全選/解除・「N 件選択中」表示・確認つき批量削除）。
- **写真の安全削除**: `orphanedPhotos()` が「残る記録から参照されない
  ファイルだけ」を計算。共有元写真（1图多sign）を誤削除しない。
  批量/編集画面/首页スワイプの全削除経路を `_deleteSigns()` に統一し、
  従来の**孤児写真リーク（記録だけ消え写真が残る）を解消**。
- **筛选**: 言語/設置主体/EntryMode/DataStatus/地区/採集者/GPS/写真/元写真
  （表示のみ）。**排序**: 採集日時 新旧 / DisplayID 昇降（欠損日時は末尾）。
- **本地相册**: `albums.json`（SignID 参照のみ・複数所属可）。相册は
  CSV / Dataset Package に**入らない**。相册削除は記録を消さない。
- l10n 36 キー × ja/zh/en。`flutter test` 47 件 PASS（本 Step からクラウド
  環境でも Flutter SDK を取得して analyze/test を実行検証）。

## console (2026-07-06) — Console 多言語 UI ja/zh/en（Step 11）

（クラウド作業分の記載補填）Research Console を i18next + react-i18next で
3 言語対応（**既定 ja-JP** → localStorage → ブラウザ言語の順で決定）。
Settings に言語切替（即時反映・端末に保存・Tauri Desktop でも持続）。
**データ字段キー・CSV ヘッダー・backend API・内部状態値は不変**
（UI 表示層のみ翻訳。select の option も value は内部値のまま）。
Playwright E2E 19 項目 PASS。設計は docs/console-i18n.md。
Desktop 起動オーバーレイの i18n は先送り（main.rs に TODO 記載）。

## desktop (2026-07-06) — macOS installable app prototype（Step 10E・実機検証済み）

macOS（Apple Silicon / macOS 26.5）実機で `LLMap.app` と
`LLMap_0.1.0_aarch64.dmg` を構築し、起動〜E2E〜終了まで検証した
（docs/macos-desktop-build.md。署名・公証は正式配布時の課題として残す）。

- **backend は one-dir に切替（macOS のみ・実測駆動）**: one-file は起動の
  たびに展開した dylib 群へ macOS の署名検証が走り /health ready まで
  **毎回 15〜25 秒**（M4 Pro）。one-dir は初回 25 秒（検証は cdhash 単位で
  キャッシュ）・**以後 0.6 秒**。spec に `LLMAP_PYI_ONEDIR=1` スイッチを追加し
  `build-backend-binary.sh` が Darwin で自動有効化（Linux/Windows は
  one-file のまま不変）。
- **sidecar 同梱は bundle.resources 方式**: one-dir は単一ファイルでないため
  externalBin 不可。`tauri.macos.conf.json`（macOS でのみ自動マージ）で
  `binaries/llmap-backend-onedir/` → `Resources/llmap-backend/` に同梱
  （実行権限の保持を実機確認）。`prepare-tauri-sidecar.sh` に Darwin 分岐追加。
  main.rs の探索に one-dir 形（`llmap-backend/llmap-backend`）を追加
  （exe 隣 / resource dir / repo dist の各所で 3 形を試す）。
- **起動オーバーレイの待機を 15s → 60s に延長**: 初回起動は OS 検証で
  数十秒かかり得るため（10 秒経過で「first launch can take up to a
  minute」に文言切替）。
- **icon.icns 新設**: 既存 128px pin を 1024px で再描画（tangent 計算で
  尾翼を滑らかに）→ iconutil で icns 生成。icon-1024.png も保存。
- **scripts/make-macos-dmg.sh 新設**: Tauri 標準 dmg バンドラは Finder への
  AppleScript 権限が必要でヘッドレス不可（実機で確認）。hdiutil のみで
  App + /Applications リンク入り UDZO dmg を生成する。
- **実機検証（チェックリストは docs §10）**: pytest 17件 / E2E 9項目
  （import zip → datasets → records → photo → map → review PATCH →
  export CSV → stats）を実 App の backend に対して PASS /
  `~/Library/Application Support/LLMap` 生成と再起動後のデータ保持 /
  正常終了で backend 残留 0 / 8000 占用時に 8001 へ自動移行 /
  sidecar 欠落時はエラー表示（白屏・クラッシュなし）/ dmg マウント内容確認。

## desktop (2026-07-05) — Windows installable app prototype 準備（Step 10F）

Windows 向けの sidecar/バンドル設定・脚本・文書を整備。Linux で検証可能な部分
（sidecar 探索・データ目录・回収）は実測済み。**exe/NSIS の生成と実機検証は
Windows 待ち**（チェックリストを docs/windows-desktop-build.md §10 に用意）。

- **externalBin 対応（Tauri v2 規則）**: `tauri.windows.conf.json`（Windows での
  み自動マージ）に `bundle.externalBin: ["binaries/llmap-backend"]`・NSIS
  （currentUser 導入）・`icon.ico`（多サイズ生成済み）・WebView2
  downloadBootstrapper を設定。実体は
  `scripts/prepare-tauri-sidecar.ps1 / .sh` が
  `binaries/llmap-backend-<target triple>[.exe]` に配置（triple は rustc から
  自動取得）。
- **sidecar 探索の拡張（main.rs）**: LLMAP_BACKEND_BIN → **App exe と同じ目录**
  （素の名前 / triple 付き名。インストール後の配置先）→ resource dir →
  repo backend/dist。triple は build.rs が `LLMAP_TARGET_TRIPLE` として埋込。
- **データ目录を §5 の標準に統一**: identifier 由来の app_data_dir から
  `<OS data dir>/LLMap`（Windows: `%APPDATA%\LLMap`）へ変更。
  **developer launcher と同一パス**になり、launcher のデータをそのまま開ける
  （10D の TODO 解消）。
- **docs/windows-desktop-build.md 新設**: prerequisites / backend exe ビルド /
  sidecar 配置 / NSIS ビルド / WebView2 / 未署名実行・SmartScreen・Defender
  誤検知対応 / `%APPDATA%\LLMap` / Troubleshooting / 実機チェックリスト。
- **Linux 実測（安装版レイアウトの模擬）**: exe 隣の triple 名 sidecar が
  repo fallback より優先で発見され、データ目录 `~/.local/share/LLMap` に
  SQLite 生成、正常終了で backend プロセス残留 0。cargo build 通過。

## desktop v0.1.0 / console v0.8.2 (2026-07-05) — Tauri shell prototype（Step 10D）

`desktop/` に最小の Tauri 2 桌面壳を新設（職責は包装のみ。console/・backend/
の職責は不変）。Linux 実機（Xvfb）で起動〜終了まで検証済み。

- **desktop/src-tauri/src/main.rs**: 用户数据目录（`app_data_dir()`、取得不能時
  `.llmap-desktop-data/` fallback・TODO 明記）→ 空き端口探索（8000〜）→
  llmap-backend sidecar 起動（LLMAP_BACKEND_BIN → resource dir →
  backend/dist の順で探索。LLMAP_DATA_DIR/HOST/PORT 注入・logs/backend.log）→
  注入スクリプトで起動オーバーレイ（Starting…/原因つき失敗表示・白屏なし）と
  `window.__LLMAP_API_BASE_URL__` 設定 → 終了時回収。
- **プロセスグループ回収（実測で発見・修正）**: PyInstaller onefile は
  親子2プロセスのため `Child::kill()` では server が残留する。unix は
  `process_group(0)`＋グループ SIGTERM/SIGKILL、Windows は `taskkill /T /F`。
  CloseRequested 時点でも先に回収。`LLMAP_AUTOEXIT_MS` 開発フックで
  正常終了経路をヘッドレス検証可能に。
- **console v0.8.2**: API 地址の運行時注入対応
  （`window.__LLMAP_API_BASE_URL__` → `VITE_API_BASE_URL` → localhost:8000）。
  Web dev / 既存デプロイの動作は不変（Playwright で注入あり/なし両方を検証）。
- **docs/tauri-desktop-prototype.md 新設**: prerequisites・実行手順・実装要点・
  実測で判明した注意点・制限・三平台の後続計画。desktop-offline-design §14 更新。
- 検証（Linux/Xvfb）: cargo check/build 通過、shell 起動 → sidecar 起動 →
  標準データ目录に SQLite 生成 → /health ready → 正常終了で backend
  プロセス 0 残留・端口解放。tauri.conf は bundle 無効（インストーラは 10E–10G）。

## backend (2026-07-05) — PyInstaller backend binary（Step 10C）

Python 未導入の環境でも動く `llmap-backend` binary の再現可能なビルド手順を整備
（将来の Tauri 桌面 shell が子プロセスとして起動する）。

- **backend/run_backend.py**: binary 用エントリポイント。既定 127.0.0.1:8000、
  `--host/--port/--data-dir`（環境変数 LLMAP_HOST/LLMAP_PORT/LLMAP_DATA_DIR
  より優先）、非 localhost 待受時は警告。開発の uvicorn 起動は不変。
- **backend/llmap-backend.spec**: one-file 採用（Tauri sidecar は単一パスの
  実行ファイルが最重要）。hidden imports（uvicorn 全 submodule /
  python-multipart / Pillow JPEG / pydantic_core）を明示。AI SDK
  （anthropic/google-genai）は遅延 import のため**除外**（binary では /ai
  無効・体積節約）。tkinter/pytest/numpy 除外。UPX 不使用（杀毒误报対策）。
  backend/data・テスト・仮想環境は同梱しない。
- **scripts/build-backend-binary.sh / .ps1**: 依存導入込みの再現ビルド。
  生成物（backend/build・dist）は .gitignore。
- **docs/backend-binary-build.md 新設**: 三平台の構築手順（クロスビルド不可の
  明記）、spec 設計判断、実測値、杀毒误报/Gatekeeper（署名は 10E）等の注意点。
- **Linux 実機で検証済み**: 体積 約30MB / 起動→health 約1.5秒 / /health /schema /
  multipart 導入 / SQLite・写真の LLMAP_DATA_DIR 書込 / 目录穿越拒否 /
  CSV 導出 36 列 / Console（Dashboard・Database）から通常どおり利用可。
  pytest 17 件通過（backend API 変更なし）。
- Windows exe / macOS binary は実機ビルド待ち（手順は文書化済み）。

## docs / scripts (2026-07-05) — Installable Offline Desktop 計画と developer launcher（Step 10A/10B）

- **docs/desktop-offline-design.md 新設**: LLMap Desktop（local-first の離線
  桌面研究ツール）の設計文書。产品定位（手机=採集 / 桌面=研究管理 /
  云端=将来可選）、Flutter Desktop を書き直さない理由、技術路線比較
  （**Tauri + PyInstaller backend binary を推奨**、Electron は代替）、
  三平台の包構造、**標準ユーザーデータ目录**（macOS `~/Library/Application
  Support/LLMap` / Windows `%APPDATA%\LLMap` / Linux `~/.local/share/LLMap`、
  LLMAP_DATA_DIR で backend に注入・程序と用户データの分離）、起動フロー
  （空き端口探索 → backend 子プロセス → /health 輪詢 → Console 読込 →
  終了時回収、異常系5種）、離線能力（OSM 底図のみオンライン。瓦片キャッシュ/
  MBTiles/無底図視図の将来方案）、opt-in 聯網三層（Backup/Sync/Publish）と
  **发布隐私規則**（既定 verified のみ・CollectorID/CaptureID 隠蔽・GPS 丸め・
  source photo 不上传）、MVP 範囲、Step 10C–10H 路線。
- **scripts/ 新設（developer launcher・最終製品ではない）**:
  `start-llmap-local.sh`（macOS/Linux: 依存チェック→標準データ目录→端口
  チェック→backend 起動→/health 待機→console 起動→ブラウザ→Ctrl+C で
  プロセス樹ごと回収）、`.command`（macOS 双击）、`.ps1`（Windows 同等機能）、
  `.bat`（ps1 の双击入口）。LLMAP_BACKEND_PORT/LLMAP_CONSOLE_PORT/
  LLMAP_DATA_DIR/LLMAP_NO_BROWSER で調整可。
- 検証: Linux 実機で launcher の起動→health→console 応答→SIGINT で両プロセス
  回収→端口占用の即時エラーを確認（vite 孫プロセス残留を kill_tree で修正）。
  ps1/bat は本環境に PowerShell が無いため静的検査のみ（Windows 実機確認待ち）。
- backend / console のコードは不変。

## console v0.8.1 / backend v0.3.1 (2026-07-04) — Stabilization Pass（全流程験収）

Mobile 导出 → Console 導入 → Database → Map → Review → Dashboard → Export の
端到端験収を実施し、発見した 2 件を修正（新機能追加なし）。

### 修正
- **fix(backend/セキュリティ)**: `/records/{id}/photo`・`/source-photo` が DB 内の
  ファイル名（導入 CSV 由来＝信頼できない）をそのままパス結合しており、
  `../` を含む名前で任意ファイルを読める目录穿越が可能だった（再現確認済）。
  `_serve` で名前を一律検証するよう修正し、テスト追加（17件全通過）。
- **fix(console/審核)**: 確定済み記録（_status=human-reviewed/final）に
  Needs review / Reject を適用すると「final なのに needs_review」という
  モバイル/Console 間の矛盾状態になっていた。`actionPayload()`（reviewStatus.ts）
  で該当時のみ _status を pending に降格。pending/ai の記録は従来どおり保持。

### 験収結果（実 backend＋Playwright）
- 空DB: 7ページすべて空状態表示・JSエラー0・导出ボタン0件で無効。
- 一致性: 全字段入りの Dataset Package を導入し、CaptureID/SignID/DisplayID/
  写真・元写真ファイル名/EntryMode/DataStatus/SchemaVersion/AppVersion/
  採集者ID/地区コード/LocalSeq/CropSuffix/CropRect の14字段が
  data.csv → DB/detail → Database 識別情報 → Review 元情報 → Export CSV で
  逐字段一致（緯度経度は数値同値）。写真名は storage/配信と一致。
- 状態遷移: submitted→verified→needs_review(降格)→reviewed→rejected(降格)→
  needs_review(pending保持) の全系列を検証。
- 回帰: 7ページ（有データ/空/offline）・console build・backend 17テスト全通過。

## console v0.8.0 / backend v0.3.0 (2026-07-04) — AI Processing 骨架（Step 8C）

AI 批処理の**安全な scaffold**（実 AI 呼び出しは一切行わない・API キーは
リポジトリに置かない）。

- **AI Processing ページ**: ① Batch selection（Status/Mode/Language/Area/
  Dataset/Photo/GPS 筛选＋`/records?pageSize=1` の該当件数）→
  ② Task type カード6種（Language identification / OCR / Field suggestion /
  Translation / Duplicate detection / Privacy risk detection — すべて
  Coming soon・Requires AI backend configuration）→ ③ Preview/Run
  （Dry run / Run batch は**無効**、理由 = /ai/status の message）。
- **Safety rules を常時表示**: AI 提案は下書き・human-reviewed を上書きしない・
  審核を経て研究データになる / backend 設定まで実行されない / キーは環境変数 /
  提案は人間確定字段と分離保存（将来案: `_ai.主要言語` `_ai.文字体系`
  `_ai.confidence` `_ai.provider` `_ai.updatedAt`）・結果は `ai_drafted` として
  Review 队列に入る。
- **backend v0.3.0**: `GET /ai/status` を追加（常に
  `{enabled:false, providers:[], message:"AI backend is not configured."}`。
  実呼び出しなし・テスト追加、16件全通過）。client に `getAiStatus()`。
- 検証: npm run build 通過。実 backend＋Playwright で件数連動・カード6枚・
  Run/Dry run 無効と理由表示・安全説明・offline エラーを確認。

## console v0.7.0 (2026-07-04) — Dashboard 看板増強（Step 8B）

Dashboard を統計カードの羅列から研究データ総覧ページへ。

- **Overview cards（8）**: Total records / Datasets / Records with GPS /
  Waiting for review / Reviewed / Verified (research-ready) / Photos /
  Source photos。主要カードはクリックで該当ページへ。
- **分布**: DataStatus / EntryMode / 主要言語 / 地区 / 採集者 を純CSSの
  横棒バーで表示（図表ライブラリ不使用）。
- **Data quality**: Missing photos / Missing source photos / Records without
  GPS・photo・source photo / Unknown EntryMode / Unknown DataStatus。
- **Shortcuts**: Open Database / Review Queue / Map / Export Data /
  Import Dataset（Database の既存導入 UI へ）。
- 実装は backend 変更なし: 待審核数は dataStatusCounts の合算、GPS/写真件数は
  既存 `/records?hasX=true&pageSize=1` の total から導出。
- 検証: npm run build 通過。実 backend＋Playwright でカード値と API の一致・
  分布バー本数・品質区・快捷遷移を確認（offline エラーは従来どおり）。

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
