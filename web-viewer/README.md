# LLMap 查阅用轻量 Web（Lingscape 风格）

新大久保言语景观 1933 条已审核记录的**查阅站**：OSM 全图 + 照片 pin +
筛选 + 一览网格 + 详情面板。纯静态文件夹（Leaflet 已内置，无 CDN 依赖），
**双击 `index.html` 即可使用**，整个文件夹打包发给别人也能直接打开。
地图为 Esri 街道瓦片（可平移缩放到任何地方，浏览时需联网）；
右上图层开关里有「調査エリア底図」——印刷板同款自绘矢量层，离线时开它。

## 使用

- **地图**：滚轮缩放（指向光标）、拖拽平移、右下 ＋/−/⤢；点击 pin 看照片与字段，
  密集处一次点选多条 → 面板列表中再选。
- **筛选**：顶栏语言 chip（多选）+「絞り込み」展开九个字段下拉 + 文本搜索
  （ID/名称/備考），地图与一览实时联动。
- **一览**：照片网格，无限滚动；点击进详情。`index.html#list` 直达一览。
- 详情面板点照片可放大（仅缩略图分辨率——原图未打包，保持轻量）。

## 文件

| 文件 | 说明 | 入库 |
|---|---|---|
| `web-viewer.template.html` | 应用本体（改 UI 改这里，重建后生效） | ✔ |
| `build_web_viewer.py` | 构建脚本（读源 CSV/照片，不修改任何源） | ✔ |
| `index.html` | 模板的构建副本 | 生成物 |
| `data.js` / `basemap.js` | 记录数据 / 自绘底图 | 生成物 |
| `thumbs/` | 缩略图（长边 360px JPEG，约 28 MB） | 生成物 |

## 部署到 NAS

全部是相对路径的静态文件，怎么放都行：

1. **最简单（SMB 共享）**：把整个 `web-viewer` 文件夹复制到 NAS 共享目录，
   在资源管理器里双击 `index.html` 即可（file:// 打开也完全可用）。
2. **HTTP 服务（推荐，手机平板也能访问）**：
   - Synology：套件中心装 **Web Station** → 把文件夹放进 `web` 共享目录
     （如 `web/llmap`）→ 访问 `http://NAS地址/llmap/`；
   - QNAP：启用 **Web 服务器** → 放入 `Web` 目录，同理；
   - 支持 Docker 的 NAS 一行搞定：
     `docker run -d -p 8080:80 -v /volume1/你的路径/web-viewer:/usr/share/nginx/html:ro nginx:alpine`
     → 访问 `http://NAS地址:8080/`。
3. 更新数据：在电脑上重跑构建脚本后，把文件夹重新复制/同步（Synology Drive、
   robocopy 均可；`thumbs/` 增量生成，同步工具只会传新文件）。

注意：街道瓦片来自 Esri（`server.arcgisonline.com`，免 key、带归属标注即可使用），
**浏览的设备需要能上外网**。之所以不用 `tile.openstreetmap.org`：它会拦截无
Referer 的访问（file:// / NAS 内网打开就是这种情况，返回 403 "Access blocked"）；
CARTO 免费瓦片也已改为需要 API key。纯内网/离线环境请打开右上角
「調査エリア底図」叠加层（调查区域可完整显示）。

## 重建

```
python build_web_viewer.py
```

照片源：`E:\1_LLmap`（原始采集）优先，桌面版数据目录
（`%APPDATA%\llmap\photos`）补缺。数据口径与投影同 visualization-sample
（已审核文字记录 1933 条，全数据 bbox）。缩略图增量生成，重跑很快。

底图数据 © OpenStreetMap contributors（ODbL），分发须保留页内归属标注。
