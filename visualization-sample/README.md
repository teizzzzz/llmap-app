# 新大久保语言景观可视化样本

双击 `index.html` 即可使用，无需安装依赖或联网。HTML 已内嵌数据和匹配照片，可以单独复制给他人。

- `index.html`：可直接打开的样本。
- `support/`：HTML 模板、生成与检查脚本，以及桌面和窄屏预览图。仅修改、重建样本时需要。
- `svg-layers/`：Illustrator 用矢量分层导出（`support/export_svg_layers.py` 生成）。
  所有文件同一画板（550×175 mm）、同一坐标框架，叠放自动对齐：图框 / 底图 /
  六种语言层 / 语言数量 / 用途 / 多语言关系 / 图例，另有 combined.svg 合并版。
  数据口径与 index.html 默认视图一致（已审核文字记录 1,933 条）。
  `05-basemap.svg` 是新大久保站周边的街道底图（道路/铁路/建筑，
  `support/fetch_basemap.py` 从 OpenStreetMap 取得并按同一投影绘制；
  数据 © OpenStreetMap contributors，图内已含归属标注，对外发布须保留。
  原始数据缓存在 `support/osm-cache.json`，重跑无需联网）。

当前版本的数据来源是 `E:\1_LLmap\data.csv`。打开 HTML 不需要访问该路径；重建时才读取源 CSV 和对应照片。

本目录内集中存放本次可视化相关文件，源 CSV 和原应用文件保持原位。
