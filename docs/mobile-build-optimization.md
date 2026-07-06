# Mobile 构建与打包速度优化（Step 13）

测量环境：macOS 26.5（arm64，32GB RAM）· Flutter 3.44.2 stable / Dart 3.12.2 ·
Xcode 26.5 · CocoaPods 1.16.2（本项目未使用）· Gradle wrapper 9.1.0 ·
AGP 9.0.1 · Kotlin 2.3.20 · JDK：Temurin 需 sudo 改用 **openjdk@21**（Homebrew keg）。
app 版本 v1.9.1+25（55 个测试）。

> 本机原本**没有 Android SDK / JDK 17+**（系统 java 是 OpenJDK 11）——这是最大的
> "构建慢点"：Android 根本无法构建。本 Step 通过 Homebrew 安装了
> `openjdk@21` + `android-commandlinetools`，并用 sdkmanager 装了
> platform-tools / platforms;android-36 / build-tools;36.0.0，
> `flutter config --android-sdk … --jdk-dir …` 指向（用户级配置，不入 repo）。

## 一、Baseline 实测

通用（clean 后）：

| 项目 | 耗时 |
|---|---|
| flutter pub get | 2s |
| flutter analyze | 14s（1 条既有 info：imaging.dart doc 注释） |
| flutter test | 16s（55/55 通过） |

Android（`flutter build apk --release`）：

| 场景 | 耗时 | 产物 |
|---|---|---|
| 首次构建（含 Gradle 发行版+依赖下载，一次性） | 319s | app-release.apk 57MB |
| clean 构建 · build cache **关**（原配置） | **57s** | 同上 |
| clean 构建 · build cache **开**（本次优化后） | **44s** | 同上 |
| 增量构建（无改动重跑） | **8s** | 同上 |
| split-per-abi（3 个 APK） | 21s | arm64 20MB / v7a 18MB / x86_64 21MB |
| appbundle（AAB，增量态） | 8s | app-release.aab 55MB |
| fast 脚本（仅 arm64） | 40s（近 clean 态） | app-arm64-v8a-release.apk **20MB** |

iOS（`flutter build ios --release --no-codesign`）：

| 场景 | 耗时 | 产物 |
|---|---|---|
| clean 构建 | **60s**（Xcode 53.4s） | Runner.app 20.1MB |
| 增量构建 | **11s**（Xcode 5.7s） | 同上 |

iOS 结论：本项目插件走 **Swift Package Manager**（无 Podfile / 无 Pods），
不存在 pod install / pod repo update 环节，60s clean 已经很快，无明显慢点。
签名未配置（release 使用 debug signingConfig / iOS 未设 Team），
日常用 `--no-codesign` 完整验证编译；`build ipa` 需在 Xcode 配置 Team 后可用。

## 二、已做的安全优化

1. **`app/android/gradle.properties`**（低风险，均属任务清单允许项）：
   - `org.gradle.daemon=true`、`org.gradle.parallel=true` 显式开启；
   - `org.gradle.caching=false → true`：clean 构建 57s → 44s（-23%）。
     该项原先与 `kotlin.incremental=false` 一起被关（Windows 文件锁问题），
     但锁问题出在 Kotlin 增量侧，与 Gradle build cache 无关，故恢复。
     **如 Windows 上重新出现缓存 close 失败，把它改回 false 即可**；
   - jvmargs 追加 `-Dfile.encoding=UTF-8`（项目路径含非 ASCII 字符）。
     `-Xmx8G` 在 32GB 机器上合理，未改动。
   - `org.gradle.configureondemand` **未加**：incubating 特性，对
     Flutter 这种小模块图收益≈0，还可能与 AGP 产生怪问题。
   - `kotlin.incremental=false` **保留不动**（有注释的 Windows 工作区规避）。
2. **四个构建脚本**（repo 根 `scripts/`，可从根目录直接运行，输出耗时+产物，
   绝不偷跑 `flutter clean`，不上传商店）：
   - `build-mobile-android-fast.sh` — 日常：`--split-per-abi --target-platform android-arm64`，
     只做一次 AOT，产物 20MB（fat 包 57MB 的 1/3）；
   - `build-mobile-android-release.sh [--apk|--aab|--split]` — 发布：默认 fat APK（侧载），
     `--aab` 出 Play 用 App Bundle；
   - `build-mobile-ios-fast.sh` — 日常：`--no-codesign`；非 macOS 明确报 unsupported；
     设 `COCOAPODS_DISABLE_STATS=true`（现在无 Pods，防未来）；
   - `build-mobile-ios-release.sh` — `flutter build ipa`；签名未配置时给出
     明确的 Xcode 配置指引而非静默失败。

## 三、推荐命令

| 用途 | 命令 |
|---|---|
| Android 日常测试 | `./scripts/build-mobile-android-fast.sh`（arm64 APK，真机侧载） |
| Android 正式发布（侧载/dist） | `./scripts/build-mobile-android-release.sh`（fat APK） |
| Android 上架 Google Play | `./scripts/build-mobile-android-release.sh --aab` |
| iOS 日常验证 | `./scripts/build-mobile-ios-fast.sh`（无需签名） |
| iOS 正式打包 | `./scripts/build-mobile-ios-release.sh`（需 Xcode 配置 Team） |

APK / AAB / IPA 的区别：**APK** 可直接安装（侧载、dist 分发、测试）；
**AAB** 只用于 Google Play 上架（Play 按设备拆分下发，用户下载量≈单 ABI）；
**IPA** 是 iOS 安装包（需签名，经 TestFlight/App Store 或 Ad Hoc 分发）。

## 四、缓存策略（避免"每次都慢"）

- **不要频繁 `flutter clean`**。增量构建 Android 8s / iOS 11s，clean 后翻 5 倍。
  只在以下情况 clean：切分支后产物异常、插件原生代码升级后报错、l10n/生成物错乱。
- iOS：不要清 DerivedData，除非 Xcode 缓存明确出错；本项目无 Pods，
  不存在 `pod deintegrate` / Pods 缓存问题。
- 首次构建慢是一次性网络成本（Gradle 发行版 + Maven 依赖，约 4~5 分钟），
  之后 clean 构建 44s。
- CI 若未来需要（**本 Step 未新增 CI**），建议缓存：
  `~/.pub-cache`、`app/.dart_tool`、`app/build`、`app/android/.gradle`、
  `~/.gradle/caches`、`~/Library/Developer/Xcode/DerivedData`（macOS runner）、
  `~/Library/Caches/CocoaPods`（如未来引入 Pods）。

## 五、依赖与 assets 检查结果

- assets 仅 96KB（应用图标），无大文件。
- 依赖全部有引用，唯一例外 **`cupertino_icons`（0 处引用）**——Flutter 模板
  标配、体积极小（图标字体按需 tree-shake，本次构建 MaterialIcons 已从
  1.6MB 摇树到 7KB），删除收益≈0，**保留、仅报告**。
- `google_fonts` 在**运行时**联网取字体（Nunito/Fraunces），不影响构建速度；
  离线首启会回退系统字体。想彻底离线可把字体打进 assets（另行任务）。
- dev_dependencies 无错放；R8/minify/shrinkResources 均未开启（Flutter 默认），
  release 目前用 debug 签名（TODO 已在 build.gradle.kts 注释中）。

## 六、未做的中风险优化（建议与理由）

| 项 | 现状 | 建议 |
|---|---|---|
| `kotlin.incremental=false` | Windows 文件锁工作区规避 | mac 构建可提速增量编译；建议改为只在 Windows 机器的 `%USERPROFILE%\.gradle\gradle.properties` 里放 false，repo 恢复默认。需在 Windows 实机验证后再动 |
| R8 / shrinkResources | 未开启 | 可减 APK 体积但**增加**构建时间且需过混淆规则测试，与本 Step 目标（速度）相反，不做 |
| release 签名 | debug 签名 | 发布 Play 前需配置正式 keystore（功能性 TODO，非速度） |
| 升级 Flutter/AGP/Gradle/Kotlin | 3.44.2 / 9.0.1 / 9.1.0 / 2.3.20 | 已是新版，无升级必要 |
| minSdk/targetSdk、iOS target 13.0 | Flutter 默认 | 正常，不动 |
