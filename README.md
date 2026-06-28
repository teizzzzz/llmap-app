# LLMap App

言語景観（Linguistic Landscape）採集アプリ。LingScape / LinguaSnapp に対応する。
`mapv2.0`（桌面ツールキット）の後継として、採集〜地図表示を端末1つで完結させる。

## 採集フロー

```
拍照 → 框选景观(1图多个sign) → 读取GPS → 字段处理 → 上传地图 → AI/手动填字段 → 预览
```

## 構成

```
llmap-app/
  app/        Flutter モバイルアプリ（採集・框选・地図预览・字段表单）
  backend/    Python FastAPI 轻后端（EXIF/GPS抽出・字段规整・AI判定・CSV互換）
```

- **単人本地**で開始し、データ構造は将来の**多人共享**（クラウド同期）を予約。
- CSV標準字段（`mapv2.0/PROJECT_STANDARD.md` §6/§7）を踏襲し、CSV import/export を維持。

## ロードマップ

- [x] Phase 0 — 后端化（FastAPI: `/health` `/extract` `/ai` `/export`）
- [ ] Phase 1 — 採集MVP（拍照→框选→GPS→保存）
- [ ] Phase 2 — 地図预览（flutter_map・言語別色分け）
- [ ] Phase 3 — AI填字段（承認フロー `_status`: ai→reviewed）
- [ ] Phase 4 — 多人予約（同期API・アカウント）

## backend 起動

```bash
cd backend
python -m venv .venv && .venv/Scripts/activate   # Windows
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
# http://localhost:8000/docs
```

AI判定を使う場合は環境変数で API key を渡す（CSV/コードに書かない）：

```bash
export ANTHROPIC_API_KEY=sk-...
export GEMINI_API_KEY=...
```
