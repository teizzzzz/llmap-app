# LLMap 网页试用版 · NAS 部署说明

这是手机 App 的网页试用版：在浏览器里体验拍照、框选、保存，并在地图和「探索」里预览。
它是一个纯静态网站，NAS 上不需要数据库，也不需要后台程序。

## 这个文件夹里有什么

| 文件 | 用途 |
|---|---|
| `web/` | 网站本体（App、示例照片 `web/explore-data/`） |
| `docker-compose.yml`、`nginx.conf` | 可选：没有 nginx 时用 Docker 启动 |

## 部署：已有 nginx 的话，两步

1. 把 `web/` 整个文件夹复制到 NAS，例如 `/volume1/web/llmap/`。
2. 在 nginx 配置里加一段（端口和路径按你的情况改），然后重新加载 nginx：

```nginx
server {
  listen 8088;
  root /volume1/web/llmap;
  index index.html;
}
```

浏览器打开 `http://<NAS 的 IP>:8088/` 即可。它只是一个静态网站，不需要其他服务。

必须放在域名或端口的根路径。要放在子路径（例如 `http://nas/llmap/`）需要重新构建，见最后一节。

没有 nginx 时，也可以用包里的 `docker-compose.yml`（`docker compose up -d`），效果相同。

## 定位需要 HTTPS

浏览器只在 HTTPS（或本机 localhost）下允许网页读取位置。
用 `http://192.168.x.x:8088` 这样的内网地址打开时：

- 浏览地图、探索示例照片、拍照（手机上会调起系统相机或相册）都可以用；
- 定位不可用，保存前需要在地图上手动指定位置。

要让定位可用，任选一种：

- **Tailscale**（只给自己和身边的人用，最省事）：NAS 和手机都装 Tailscale，
  在 NAS 上执行 `tailscale serve --bg 8088`，会得到一个带 HTTPS 的地址。
- **Cloudflare Tunnel**（给不特定的人用）：需要一个域名，不用开端口。
- **NAS 自带的反向代理 + 证书**：已有域名和公网 IP 时使用，把 HTTPS 的域名转发到 `http://127.0.0.1:8088`。

## 访客的数据在哪里

访客拍的照片和填写的记录只保存在他自己设备的浏览器里，不会上传到 NAS，其他人也看不到。
在 App 的「探索 → 右上角齿轮 → 试用版 → 重置试用」可以清空自己拍的内容。
iPhone 的 Safari 长时间不打开网页会自动清掉这些数据，所以它只适合试用，不能当正式采集工具。

## 示例照片

`web/explore-data/` 里是约 300 张示例照片（缩小到 512 像素）和它们的记录。
**对外公开前请先看一遍 `web/explore-data/thumbs/`**：街景照片里可能有行人、店名、车牌，
不想公开的照片可以排除后重新生成（见下一节）。

## 需要联网的部分

以下内容是打开网页的设备从互联网加载的，NAS 本身不需要联网，但访客的设备需要：

- 地图底图（瓦片）；
- 中文和日文字体（首次打开时下载）。

AI 识别默认关闭。访客如果自己在设置里填了密钥，密钥只保存在他自己的浏览器里；
浏览器直接调用 AI 服务可能被对方的跨域限制拦住，试用版里不保证可用。

## 重新构建（开发者）

在项目根目录（Windows，PowerShell）：

```powershell
.\scripts\build-web-trial.ps1                      # 部署在根路径
.\scripts\build-web-trial.ps1 -BaseHref /llmap/    # 部署在子路径
```

脚本会编译网页版、放入示例资料，并在 `dist/llmap-trial-nas/` 生成这个文件夹，同时打包成 `dist/llmap-trial-nas.zip`。
重新生成示例照片：先启动本地后端，再运行 `python scripts/make_trial_explore_data.py <输出目录>`（可用 `--exclude` 排除记录）。
