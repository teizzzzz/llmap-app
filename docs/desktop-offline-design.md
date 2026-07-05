# LLMap Installable Offline Desktop Design

> Step 10A 設計文書（実装計画を含む。10C 以降は本文書の計画のみで未実装）

**LLMap Desktop は local-first の離線桌面研究ツールである。**
macOS / Windows / Linux にインストールでき、既定で遠隔サーバ・アカウント・
データアップロードを一切必要としない。起動時にユーザーの PC 内で backend
（FastAPI + SQLite）を立ち上げ、桌面ウィンドウに Research Console（React）を
読み込む。データベース・写真・導入包・導出結果はすべて既定でユーザー本機に
保存される。将来、聯網同步 / 上传 / 发布を **opt-in** で有効化できるが、
それは既定要件ではない。

---

## 1. 产品定位

```text
手机端（LLMap Mobile）    … 現場採集（拍照・框选・GPS・三採集モード）
桌面端（LLMap Desktop）   … 研究管理（導入・閲覧・審核・統計・導出）
云端 / Public Map         … 将来の可選拡張（既定では存在しない）
```

桌面端は **local-first research management app** である。

桌面端が「ではない」もの:

- 云后台ではない（サーバ運用を前提にしない）
- 公众平台ではない（投稿・共有機能を内蔵しない）
- 強制登录工具ではない（アカウントなしで全機能が使える）

## 2. なぜ Flutter Desktop を書き直さないか

- 既存 React Console は Database / Import / Map / Review / Dashboard / Export /
  AI scaffold まで**完成済み**で、E2E 検証も済んでいる。
- PC 端の性質は「研究管理后台」であり、表格・Web 地図（Leaflet）・Dashboard は
  React + Web 技術の方が適している。
- Flutter Desktop で書き直すと上記のほぼ全てを二重実装することになる。
- 将来の Public Map も Web 技術を必要とするため、Web 資産は無駄にならない。

**結論: 現段階で Flutter Desktop の再実装は推奨しない。
Tauri（推奨）または Electron で既存 React Console を包み、
本地 backend を子プロセスとして起動する。**

## 3. 推奨技術路線の比較

### A. Tauri + backend binary（推奨）

- Tauri が桌面ウィンドウと本地プロセス管理を担当。
- React Console（`console/dist`）を前端 UI としてバンドル。
- FastAPI backend は **PyInstaller** で単体バイナリ化（`llmap-backend`）。
- Tauri が backend binary を起動し、`http://127.0.0.1:<port>` に接続。

| 観点 | 評価 |
|---|---|
| 体積 | ◎ 小さい（WebView は OS 同梱を利用） |
| 桌面体験 | ◎ ネイティブメニュー・ウィンドウ |
| 跨平台 | ◎ macOS / Windows / Linux |
| 長期製品化 | ◎ 適する |

難点（計画時に織り込む）:

- backend binary は**三平台それぞれで**ビルドが必要（クロスビルド不可）。
- 起動・終了・端口占用・ログの管理を shell 側で実装する必要がある。
- 配布には macOS 署名/公証、Windows インストーラ（MSI/NSIS）、
  Linux AppImage の各設定が要る。

### B. Electron + backend binary

- 利点: 生態が成熟、プロセス管理が容易、資料が多い。
- 欠点: 配布物が大きい（>100MB）、メモリ占用が高い。
- 位置づけ: Tauri で問題が出た場合の代替。設計（§4–6）は両者共通。

### C. Flutter Desktop 重写（非推奨）

- Console 全機能の再実装＋Web 地図/表格の Flutter 化コストが大きい。
- 毕业設計の期間内に完成しないリスクが高く、既存 E2E 資産も捨てることになる。

### 最終推奨

```text
短期  … 現行 Web Console + backend（開発者はブラウザで使う）＋ developer launcher（10B）
中期  … PyInstaller backend binary（10C）
中期  … Tauri shell prototype（10D）
長期  … Tauri installable desktop app（10E–10G: mac/.app → Windows installer → AppImage）
```

## 4. 桌面 App 内部結構

程序ファイル（読み取り専用・升級で置換される）と用户データ（永続・升級で
保持される）を**必ず分離**する。

macOS app bundle:

```text
LLMap.app/Contents/
  MacOS/llmap-desktop          # Tauri shell
  Resources/
    console/                   # React Console assets (console/dist)
    llmap-backend              # PyInstaller binary
```

Windows:

```text
C:\Program Files\LLMap\
  LLMap.exe                    # Tauri shell
  llmap-backend.exe
  resources\console\
```

Linux:

```text
LLMap.AppImage                 # 内部に shell + llmap-backend + console assets
```

## 5. 用户数据目录設計

三平台の標準ユーザーデータ目録を使う（**インストール目録には置かない**。
升級してもユーザーデータは上書きされない）:

```text
macOS   : ~/Library/Application Support/LLMap/
Windows : %APPDATA%\LLMap\
Linux   : ~/.local/share/LLMap/   (XDG_DATA_HOME 準拠)
```

目录構造（backend の data_dir と同一レイアウト）:

```text
LLMap/
  llmap.sqlite3      # 記録データベース
  photos/            # 裁切写真
  source_photos/     # 元写真
  imports/           # 導入した Dataset Package（zip＋展開）
  exports/           # 導出結果（将来: Desktop 経由の保存先）
  logs/              # backend / shell のログ
  config.json        # 桌面設定（端口・言語など。API キーは置かない）
```

接続規約:

- backend は既存の環境変数 **`LLMAP_DATA_DIR`** で保存先を切り替えられる
  （backend v0.2.0 で実装済み。追加改修不要）。
- **桌面 shell が LLMAP_DATA_DIR を設定して backend を起動する**。
- developer launcher（10B）も同じ目録規約に従う → 将来 Tauri 版に移行しても
  ユーザーデータはそのまま引き継がれる。

## 6. 起動フロー

```text
 1. ユーザーが LLMap Desktop を起動
 2. shell が用户数据目录を確認、無ければ作成（logs/ ほか）
 3. 空き localhost 端口を選択（既定 8000。占用時は 8001… と探索）
 4. LLMAP_DATA_DIR を設定
 5. llmap-backend binary を子プロセスとして起動（stdout/stderr → logs/）
 6. GET /health を輪詢（例: 200ms 間隔 × 最大 15 秒）で ready を待つ
 7. React Console をウィンドウに読み込む
 8. Console は運行時 config（window.__LLMAP_API__ 注入 or /config.json）
    または VITE_API_BASE_URL で backend に接続
 9. ユーザーが App を終了
10. shell が backend 子プロセスを確実に終了させる（graceful → kill）
```

異常系（shell が必ず処理する）:

| 異常 | 対応 |
|---|---|
| 端口占用 | 次の空き端口を探索。全滅なら明確なエラーダイアログ |
| backend 起動失敗 | logs/ のパスを示して失敗ダイアログ。UI は白屏にしない |
| DB 迁移失敗 | 起動中断＋バックアップ案内（DB ファイルはコピーで退避可能） |
| 写真目录不可写 | 権限エラーを明示（どのパスかを表示） |
| 異常終了の残留プロセス | 起動時に前回の PID/端口を確認し、自分が起動した backend のみ回収 |

## 7. 離線能力

**ネットワークなしで以下がすべて動く**（現行実装で既に成立している）:

- Dataset Package 導入 / Database 閲覧・編集 / 本地写真表示
- Map ページの GPS marker 表示と筛选
- Review 審核 / Dashboard 統計
- CSV 導出（将来: Dataset Package / GeoJSON 導出も本地で完結）

既知の制約: **地図底図（OpenStreetMap tiles）はオンライン取得**のため、
断網時は底図が表示されない。ただし marker・popup・筛选・Database 連動は
データが本地にあるため引き続き機能する。

底図の将来方案（優先順）:

1. **瓦片キャッシュ**: 表示済み tile を本地キャッシュし再訪時に利用
2. **離線 MBTiles**: 調査地域の tile を MBTiles で同梱/導入
3. **無底図座標視図**: 底図なしで相対座標系に marker を描画する fallback

## 8. 可選聯網（設計のみ・実装しない）

将来の聯網能力は三層に分ける。**すべて opt-in。既定は完全オフラインで、
一切アップロードしない。実行前に必ず対象データのプレビューと確認を挟む。**

- **A. Backup** — 本地 DB＋写真をユーザー自身のクラウド/サーバへ丸ごと退避。
  最も単純で、アカウント不要（保存先はユーザーが用意）。
- **B. Sync** — 複数設備間で Dataset / Records を同期。SignID の一意性は
  既に保証されているが、**衝突解決とアカウント系が必要**になるため最後発。
- **C. Publish** — 審核済みデータのみを Public Map に発布（§9 の規則に従う）。

## 9. 上传 / 发布の隐私規則

**既定でアップロードしてはならない DataStatus**:

```text
raw / submitted / ai_drafted / needs_review / rejected
```

**既定で発布を許可するのは `verified` のみ**。`reviewed` はオプションで許可
できるが、有効化時に「人手確認が final でない」旨のリスク提示を必須とする。

上传 / 发布前の匿名化処理（発布パイプラインの必須ステップ）:

- **CollectorID を隠す**（採集者の行動履歴が復元できるため）
- **CaptureID を隠す**（CollectorID＋ミリ秒時刻を内包するため。公開側は
  別途発番した公開 ID を使う）
- **GPS 精度を落とす**（例: 小数 3 位≒100m へ丸め、または区画単位）
- **人脸・車牌・私人住宅の検査**（AI Processing の Privacy risk detection と接続）
- **crop photo のみ**を対象にし、**source photo は上传しない**
  （元写真は周辺環境・人物が写り込みやすい）

## 10. MVP 範囲

**LLMap Desktop MVP がやること**: 可安装 App / 本地 backend 自動起動 /
本地数据目录（§5）/ Dataset Package 導入 / Database / Map / Review /
Dashboard / Export / 完全離線動作。

**MVP がやらないこと**: 账号 / 云同步 / 自動上传 / Public Map 发布 /
真実 AI 呼び出し / 自動更新 / 多人協作 / 権限系統。

## 11. 開発路線

```text
Step 10B  Developer launcher scripts（本 PR で実装済み。§12）
Step 10C  PyInstaller backend binary（計画のみ。§13）
Step 10D  Tauri shell prototype（ウィンドウ＋backend 子プロセス＋health 待機）
Step 10E  macOS installable app（.app / .dmg、署名・公証）
Step 10F  Windows installer prototype（MSI or NSIS）
Step 10G  Linux AppImage prototype
Step 10H  Optional upload / sync design（§8-9 の詳細設計）
```

## 12. Step 10B — Developer launcher（実装済み）

> **これらは最終製品ではない。** 開発者/研究者が Python + Node の入った環境で
> 一発起動するための **developer launcher** であり、最終製品は Tauri/Electron が
> 打包した `LLMap.app` / `LLMap.exe` / `LLMap.AppImage` である。

```text
scripts/start-llmap-local.sh        # macOS / Linux（メイン実装）
scripts/start-llmap-local.command   # macOS 双击入口（要 chmod +x）
scripts/start-llmap-local.ps1       # Windows（メイン実装）
scripts/start-llmap-local.bat       # Windows 双击入口（ps1 を呼ぶだけ）
```

共通挙動（§5/§6 の規約に先行準拠）:

1. python3 / node / npm の存在確認（無ければ導入方法を表示して終了）
2. backend 依存の確認（不足時は `pip install -r requirements.txt` を案内/実行）
3. `LLMAP_DATA_DIR` を三平台標準目录に設定（環境変数で上書き可）
4. backend 起動 → `/health` 輪詢で ready 待ち
5. console（Vite dev server）起動 → ブラウザを開く
6. Ctrl+C / 終了時に両プロセスを回収

環境変数: `LLMAP_BACKEND_PORT`（既定 8000）/ `LLMAP_CONSOLE_PORT`（既定 5173）/
`LLMAP_DATA_DIR`（既定 §5 の標準目录）/ `LLMAP_NO_BROWSER=1`（CI・headless 用）。

## 13. Step 10C — PyInstaller backend binary（**実装済み**）

詳細は **docs/backend-binary-build.md** 参照。

```text
backend/run_backend.py           # binary 用エントリポイント
                                 #   --host/--port/--data-dir（環境変数 LLMAP_HOST/
                                 #   LLMAP_PORT/LLMAP_DATA_DIR より優先）
backend/llmap-backend.spec       # PyInstaller spec（one-file・AI SDK 除外・UPX 無し）
scripts/build-backend-binary.sh  # macOS / Linux ビルド
scripts/build-backend-binary.ps1 # Windows ビルド
→ backend/dist/llmap-backend(.exe)
```

- Linux 実機で構築・検証済み: 体積 約30MB、起動→/health 約1.5秒、
  multipart 導入・SQLite/写真の LLMAP_DATA_DIR 書込・目录穿越拒否・
  Console からの利用まで通常起動と同一動作。
- 既定 127.0.0.1 のみ待受（非 localhost 指定時は警告）。
- クロスビルド不可のため Windows/macOS binary は各実機で要構築。
- binary では /ai エンドポイントは無効（AI SDK を除外して体積節約。
  桌面 MVP では未使用）。
