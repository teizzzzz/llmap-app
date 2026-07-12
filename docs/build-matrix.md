# LLMap Build Matrix

回答一个问题：**"我要在哪台机器上构建哪个产物、用什么命令、产物在哪里？"**
适用于 macOS / Windows / Linux 三平台分工。实测数字见
[mobile-build-optimization.md](mobile-build-optimization.md)（Mobile）、
[backend-binary-build.md](backend-binary-build.md)（backend 二进制）、
[macos-desktop-build.md](macos-desktop-build.md) /
[windows-desktop-build.md](windows-desktop-build.md)（Desktop）。

## 一、总览表

| Target | Recommended build OS | Required tools | Build command | Output path | Status | Notes |
|---|---|---|---|---|---|---|
| Android APK (arm64, 日常) | macOS / Windows / Linux 任一 | Flutter, JDK 17+, Android SDK | `./scripts/build-mobile-android-fast.sh` | `app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` | ✅ 已在 macOS 实测 | 20MB，日常真机测试用 |
| Android APK (fat, 发布/dist) | 同上 | 同上 | `./scripts/build-mobile-android-release.sh` | `app/build/app/outputs/flutter-apk/app-release.apk` | ✅ 已在 macOS 实测 | 57MB，侧载分发用 |
| Android AAB (Google Play) | 同上 | 同上 | `./scripts/build-mobile-android-release.sh --aab` | `app/build/app/outputs/bundle/release/app-release.aab` | ✅ 已在 macOS 实测 | 55MB，仅上架用 |
| iOS app（无签名验证） | **仅 macOS** | Flutter, Xcode | `./scripts/build-mobile-ios-fast.sh` | `app/build/ios/iphoneos/Runner.app` | ✅ 已实测 | SPM 插件，无 CocoaPods |
| iOS IPA（App Store/TestFlight） | **仅 macOS** | + Apple Developer Team/签名 | `./scripts/build-mobile-ios-release.sh` | `app/build/ios/ipa/*.ipa` | ⏳ 未验证 | 上架用 |
| iOS IPA（Ad Hoc，蒲公英分发） | **仅 macOS** | 付费 Developer 账号 + 注册设备 UDID | `./scripts/build-mobile-ios-adhoc.sh` | `dist/LLMap-v<ver>-adhoc.ipa` | ✅ 已实测 | profile 有效期约 1 年；仅注册设备可装 |
| macOS Desktop .app / .dmg | **仅 macOS** | Rust, Node, Tauri CLI, Python/PyInstaller | 见 §五 macOS 流程 | `desktop/src-tauri/target/release/bundle/macos/LLMap.app`、`bundle/dmg/*.dmg` | ✅ 已实机验证 (Step 10E) | 未签名会被 Gatekeeper 拦 |
| Windows Desktop .exe / NSIS installer | **仅 Windows** | Rust MSVC, Node, Tauri CLI, Python/PyInstaller, WebView2 | 见 §五 Windows 流程 | `desktop\src-tauri\target\release\bundle\nsis\`、`...\release\LLMap.exe` | 🔜 脚本就绪，待 Windows 实机 (Step 10F) | SmartScreen/Defender 注意 |
| Linux Desktop AppImage | **仅 Linux**（建议旧发行版） | Rust, Node, Tauri, webkit2gtk/gtk, Python/PyInstaller | 见 §五 Linux 流程 | `desktop/src-tauri/target/release/bundle/appimage/`、`bundle/deb/` | ❌ 未开始 (10G) | glibc 兼容性取决于构建机 |
| Backend binary | **各目标平台各自构建** | Python 3.11+, PyInstaller | `./scripts/build-backend-binary.sh`（Win: `.ps1`） | `backend/dist/llmap-backend`（Win: `.exe`） | ✅ macOS / 🔜 Windows / ❌ Linux | PyInstaller 不能交叉编译 |
| React Console static build | 任意平台 | Node 18+ | `cd console && npm install && npm run build` | `console/dist/` | ✅ 已实测 | Desktop shell 与 Web 部署共用 |

## 二、平台分工原则

```text
Windows 机器负责:
- Android build（可选，任何平台都行）
- Windows Desktop build（必须）
- Windows installer / SmartScreen / Defender 实机验证（必须）

macOS 机器负责:
- iOS build（必须 — 只有 macOS 能构建 iOS）
- macOS Desktop .app/.dmg build（必须）
- Android build（可选，Step 13 已在此机配好工具链）

Linux 机器负责:
- Linux Desktop AppImage build（强烈建议）
- backend binary 的 Linux 版
- CI / smoke testing（未来）
```

硬性规则：

- **iOS 必须在 macOS 上构建**（Xcode 依赖，无例外）。
- **macOS .app/.dmg 必须在 macOS 上构建**。
- **Windows .exe/installer 必须在 Windows 上构建**（Rust MSVC + NSIS）。
- **Linux AppImage 建议在 Linux 上构建**（glibc 向后兼容：在较旧发行版上构建，产物适配面更广）。
- **Android 可在三平台任意构建**（只需 Flutter + JDK 17+ + Android SDK）。
- **React Console 可在任意平台构建**（纯 Node）。
- **Backend binary 必须在各目标平台分别构建**——PyInstaller 通常不能跨平台交叉编译。

## 三、Mobile 构建

### Android

日常快速构建（真机测试）：

```bash
./scripts/build-mobile-android-fast.sh
```

- 只编 arm64（`--split-per-abi --target-platform android-arm64`），一次 AOT，速度最快、产物 20MB。

正式发布：

```bash
./scripts/build-mobile-android-release.sh          # fat APK（侧载 / dist 分发）
./scripts/build-mobile-android-release.sh --aab    # AAB（Google Play 上架）
./scripts/build-mobile-android-release.sh --split  # 按 ABI 拆 3 个 APK
```

- **APK**：直接安装测试 / 侧载分发；**AAB**：只用于 Google Play（商店按设备拆分下发）。
- 版本号在 `app/pubspec.yaml`（`version: x.y.z+build`）；dist 产物命名带上它（如 `LLMap-v1.9.1-release.apk`）。

### iOS

日常快速构建（无需签名）：

```bash
./scripts/build-mobile-ios-fast.sh
```

- `flutter build ios --release --no-codesign`，完整编译验证，适合日常。

正式发布：

```bash
./scripts/build-mobile-ios-release.sh
```

- 需要 Xcode Team / Signing / Provisioning Profile（Runner → Signing & Capabilities）。
- 用于 App Store / TestFlight / IPA 分发。签名未配置时脚本会给出配置指引。

## 四、Backend binary 构建

产物：`backend/dist/llmap-backend`（macOS/Linux）、`backend\dist\llmap-backend.exe`（Windows）。

```bash
# macOS / Linux
./scripts/build-backend-binary.sh
```

```powershell
# Windows
.\scripts\build-backend-binary.ps1
```

要点：

- **必须在目标平台构建**（不能在 macOS 上出 Windows exe）。
- macOS 用 **one-dir** 模式（one-file 首启动会被签名验证拖慢 15–25s）；Windows 用 one-file。
- **用户数据不打进 binary**，运行时用 `LLMAP_DATA_DIR` 指定数据目录。

冒烟测试：

```bash
# macOS / Linux
LLMAP_DATA_DIR=/tmp/llmap-test ./backend/dist/llmap-backend --port 8010
curl http://127.0.0.1:8010/health
curl http://127.0.0.1:8010/schema
```

```powershell
# Windows
$env:LLMAP_DATA_DIR = "$env:TEMP\llmap-test"
.\backend\dist\llmap-backend.exe --port 8010
Invoke-RestMethod http://127.0.0.1:8010/health
Invoke-RestMethod http://127.0.0.1:8010/schema
```

## 五、Desktop 构建（Tauri shell + backend sidecar）

三平台流程同构：**① console 静态资源 → ② backend binary → ③ 复制为 sidecar → ④ tauri build**。
`desktop/package.json` 里有对应的 npm scripts（`build:console` / `build:backend` /
`prepare:sidecar` / `make:dmg`）。

### macOS（目标：LLMap.app / LLMap.dmg）

需要：Rust（`~/.cargo/bin`）、Node、Tauri CLI、Python + PyInstaller、Xcode Command Line Tools。

```bash
cd console && npm run build && cd ..
./scripts/build-backend-binary.sh
./scripts/prepare-tauri-sidecar.sh
cd desktop && npm install && npm run build
# 可选: 出 dmg
./scripts/make-macos-dmg.sh
```

输出：

```text
desktop/src-tauri/target/release/bundle/macos/LLMap.app
desktop/src-tauri/target/release/bundle/dmg/*.dmg
```

注意：未签名 app 会被 Gatekeeper 拦（右键打开或 `xattr -dr com.apple.quarantine`）；
正式发布需要 Apple Developer ID 签名 + 公证（notarization）。

### Windows（目标：LLMap.exe / NSIS installer）

需要：Rust MSVC toolchain、Node、Tauri CLI、Python + PyInstaller、WebView2 Runtime。

```powershell
cd console; npm run build; cd ..
.\scripts\build-backend-binary.ps1
.\scripts\prepare-tauri-sidecar.ps1
cd desktop; npm install; npm run build
```

输出：

```text
desktop\src-tauri\target\release\bundle\nsis\   # 安装包
desktop\src-tauri\target\release\LLMap.exe      # 裸 exe
```

注意：未签名会触发 SmartScreen；PyInstaller exe 可能被 Defender 误报；
正式发布需要代码签名证书。

### Linux（目标：AppImage，deb/tar.gz 可选）——未开始

需要：Rust、Node、Tauri 的 Linux 依赖（webkit2gtk、gtk 等）、Python + PyInstaller。

```bash
cd console && npm run build && cd ..
./scripts/build-backend-binary.sh
./scripts/prepare-tauri-sidecar.sh
cd desktop && npm install && npm run build
```

输出：

```text
desktop/src-tauri/target/release/bundle/appimage/
desktop/src-tauri/target/release/bundle/deb/
```

注意：AppImage 的 glibc 兼容性取决于构建机——**在较旧的发行版上构建**适配面更广。

## 六、本地数据目录（三平台统一规范）

| 平台 | 用户数据目录 |
|---|---|
| macOS | `~/Library/Application Support/LLMap` |
| Windows | `%APPDATA%\LLMap` |
| Linux | `~/.local/share/LLMap` |

内部结构：

```text
LLMap/
  llmap.sqlite3      # 研究数据库
  photos/            # 裁切照片
  source_photos/     # 原始照片
  imports/           # 导入的 Dataset Package 存档
  exports/           # 导出产物
  logs/              # backend.log 等
  config.json        # 端口等本地配置
```

原则：**程序文件和用户数据分离**——升级/重装 App 不覆盖用户数据；
launcher（`scripts/start-llmap-local.*`）、Tauri desktop、backend binary
共用这套目录规范（`LLMAP_DATA_DIR` 环境变量可覆盖，测试时常用）。

## 七、常用检查命令

```bash
cd app && flutter analyze && flutter test        # Mobile（55 tests）
cd backend && python -m pytest tests/ -q         # backend（17 tests）
cd console && npm run build                      # Console（tsc strict + vite）
cd desktop && cargo check                        # Desktop shell
```

backend 进程残留检查（desktop/launcher 异常退出后）：

```bash
# macOS / Linux
pgrep -fl llmap-backend
lsof -i :8000
```

```powershell
# Windows
Get-Process llmap-backend -ErrorAction SilentlyContinue
netstat -ano | findstr :8000
```

## 八、Recommended daily workflow

```text
日常 Flutter 修改:
  cd app && flutter analyze && flutter test
  Android 真机 → ./scripts/build-mobile-android-fast.sh
  iOS 验证   → ./scripts/build-mobile-ios-fast.sh

日常 Console 修改:
  cd console && npm run build（含 tsc 严格检查）

Backend 修改:
  cd backend && python -m pytest tests/ -q
  backend binary 只在 desktop sidecar 需要更新时才重建

Desktop 修改:
  先保证 console/dist 和 sidecar 是新的，再 cd desktop && cargo check / npm run build
```

- **不要频繁 `flutter clean`**（增量 Android 8s / iOS 11s，clean 后 ×5 起）。
- **不要每次都重建 PyInstaller binary**——只有 backend 代码变了才需要。
- 版本发布日（多产物同出）建议顺序：console → backend binary → desktop → mobile，
  各平台产物按 §一 总览表分机器执行。

## 九、CI / 未来自动化建议（仅建议，未实现）

```text
GitHub Actions macOS runner:
  - iOS --no-codesign build（编译回归）
  - macOS Desktop build（不签名、不公证）

GitHub Actions Windows runner:
  - Android build（可选）
  - Windows Desktop NSIS build

GitHub Actions Linux runner:
  - backend pytest + console build（最便宜的全量回归）
  - Linux AppImage build
```

缓存建议：`~/.pub-cache`、`app/.dart_tool`、`app/build`、`app/android/.gradle`、
`~/.gradle/caches`、`~/.cargo`、`desktop/src-tauri/target`、`console/node_modules`。

**签名类 secrets（iOS release signing / macOS notarization / Windows code signing）
现在不要进 CI**——等发布流程定型后再加。
