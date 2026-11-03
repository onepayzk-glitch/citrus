# Open-Tangerine v0.1.10 基线构建记录

- 审计日期：2026-10-28
- 审计员：oss-auditor（Team Lead 委派）
- 仓库路径：`/Users/zhukun/Documents/HARNESS/dsh-mac/tangerine-oss`
- 任务：task-2「基线审计：构建 Open-Tangerine 并输出能力矩阵」

## 0. 结论速览

| 项 | 结果 |
|---|---|
| 源码编译 | 成功（xcrun swiftc 全量编译 `NativeApp/Sources`，只有警告，无 error） |
| 打包脚本首次运行 | **失败**，exit 1，失败点在签名阶段 |
| 失败原因 | bundle 带 `com.apple.FinderInfo` 等扩展属性，codesign 拒绝 |
| 手动修复后签名 | 通过（`valid on disk` / `satisfies its Designated Requirement`） |
| App 启动 | 成功：进程存活，System Events 读到 1 个窗口、菜单栏 6 个元素；已确认退出、无残留 |
| 测试 `scripts/test.sh` | **通过**，exit 0，8 个套件全过（末尾 MediaIntegrationTests `55 passed, 0 failed`） |

## 1. 环境

- 宿主：macOS 27（按任务背景），目录位于文件提供程序同步路径下
- SDK：`MacOSX27.0.sdk`（编译诊断里的 framework 头文件路径可证）／Xcode 27.1
- 目标：`-swift-version 5 -O -parse-as-library -target arm64-apple-macosx15.0`
- 脚本默认 `MIN_MACOS=15.0`（`scripts/build-app.sh`，未设 `BUILD_UNIVERSAL`）
- 外部依赖现状：`which ffmpeg` → `/opt/homebrew/bin/ffmpeg`（已安装，但这是可选项，不是构建依赖）

## 2. 构建命令与结果

```
cd tangerine-oss && ./scripts/build-app.sh
```

结果：**exit 1**。编译阶段成功，日志尾部：

```
dist/Citrus.app: replacing existing signature
dist/Citrus.app: resource fork, Finder information, or similar detritus not allowed
BUILD_EXIT=1
```

之前有大量告警（均非 error），典型如：`onChange(of:perform:)` 在 macOS 14 弃用、`AVMutableVideoComposition(asset:)` 与 `AVAssetExportSession.export()` 在 macOS 15 弃用、`MediaPlayer` 的 MainActor 隔离告警、`AVAssetWriterInput` 非 Sendable 告警。它们不影响产物，只说明代码是按旧 API 写的、在当前 SDK 下会被弃用警告淹没。

## 3. 失败根因

- `xattr -lr "dist/Citrus.app"` 显示：bundle 根带 `com.apple.FinderInfo`、`com.apple.fileprovider.fpfs#P`，所有内容文件带 `com.apple.provenance`。
- 该工作目录落在文件提供程序（iCloud / CloudStorage 类）同步路径下；对已存在的 `dist/` 做增量重打包时，系统会把这些扩展属性写回 bundle。
- `codesign` 拒绝带 FinderInfo 的 bundle，`set -euo pipefail` 使脚本在该步直接终止，因此其后的 `codesign --verify --deep --strict`、`plutil -lint`、`test -x` 都没执行到。
- 失败后产物处于「二进制已就位、bundle 未签名」状态：`codesign -dv` 当时显示 `Identifier=Citrus-arm64`、`Signature=adhoc (linker-signed)`，即只有链接期签名，不是 `com.syntaxerror.opentangerine` 的 bundle 签名。

## 4. 修复（只动 dist/，未改源码与脚本）

```
xattr -cr "dist/Citrus.app"
codesign --force --sign - "dist/Citrus.app"
codesign --verify --deep --strict --verbose=2 "dist/Citrus.app"
plutil -lint "dist/Citrus.app/Contents/Info.plist"
```

结果：

```
dist/Citrus.app: valid on disk
dist/Citrus.app: satisfies its Designated Requirement
VERIFY_EXIT=0
Identifier=com.syntaxerror.opentangerine
Format=app bundle with Mach-O thin (arm64)
Signature=adhoc
Info.plist: OK
```

**给 Lead 的建议**（`scripts/` 不在本任务写权限内）：在 `build-app.sh` 的 `codesign` 之前加一行 `xattr -cr "$app"`，可让构建在此目录下幂等通过。否则每次重打包都可能在同一处失败。

## 5. 启动、存活与退出验证

```
open "dist/Citrus.app"; sleep 5
pgrep -fl Citrus
ps -o pid,etime,comm -p 42691
osascript -e 'tell application "System Events" to tell process "Citrus" to return (count windows) & " windows; UI elements: " & (count of UI elements of menu bar 1)'
```

结果：

- `PID 42691 …/dist/Citrus.app/Contents/MacOS/Citrus` 在 5 秒后仍存活
- System Events 返回 `1 个窗口`、菜单栏 `6` 个 UI 元素 → 窗口与常驻菜单栏均存在
- 同一时刻还看到 `/opt/homebrew/bin/ffprobe`、`ffmpeg` 在探测 `/tmp/Citrus-media-*/tone.wav`。该临时目录与 `tone.wav` 是**并行运行的 `scripts/test.sh`（MediaIntegrationTests）夹具**，不是 App 启动行为；两者同时运行，未做隔离验证，故不作归因。

退出：

```
osascript -e 'tell application "Citrus" to quit'
pkill -f 'Citrus.app'
```

结果：`pgrep -fl Citrus` 为空 → 干净退出，未留残留进程，不会与 Lead 的运行时观察抢屏幕。

## 6. 产物信息

- 路径：`dist/Citrus.app`
- 内容：`Contents/MacOS/Citrus`、`Resources/AppIcon.icns`、`GPL-3.0.txt`、`Satsuma-MIT.txt`、`THIRD_PARTY_NOTICES.md`
- `CFBundleIdentifier` = `com.syntaxerror.opentangerine`；`CFBundleShortVersionString` = `0.1.10`；`CFBundleVersion` = `11`；`LSMinimumSystemVersion` = `15.0`；`LSUIElement` = `true`（无 Dock 图标，纯菜单栏 App）
- 签名：ad-hoc（`codesign --force --sign -`），未 notarize，无 Developer ID
- 架构：单 arm64（未设 `BUILD_UNIVERSAL=1`；脚本支持该开关出 universal）

## 7. 测试

安全性预读：`scripts/test.sh` 只做两件事——编译（xcrun swiftc）与在 `.build/` 下逐个跑测试套件；不安装、不写系统目录、不 sudo。因此全量执行。

```
cd tangerine-oss && ./scripts/test.sh
```

结果：**exit 0**。8 个套件（顺序见 `scripts/test.sh`）：SatsumaTests、IntegrationTests、InteractionTests、ImageConversionTests、DocumentTests、BatchTests、ImageToolsTests、MediaIntegrationTests。

尾部证据：

```
Image tool failures: 0
MEDIA RESULT: 55 passed, 0 failed
TEST_EXIT=0
```

说明：脚本是逐套件串行 + `set -e`，任一失败即非 0；本次为 0，故 8 套件全通过。逐套件覆盖说明见 `docs/BUILD-STATUS.md:21-36`（那是 0.1.7 的历史记录，不是本次重启跑的逐条统计）。

## 8. 边界声明

未改 `NativeApp/` 源码、未改 `docs/`、未改 `scripts/`；只写 `parity/`，以及在 `dist/` 上做了 xattr 清理与重新签名。运行期深度观察（截图/AX 遍历/拖拽 UX）留给 runtime-observer，本任务只做存活确认并已退出 App。

## 9. 一行复现

```
cd tangerine-oss && ./scripts/build-app.sh || (xattr -cr "dist/Citrus.app" && codesign --force --sign - "dist/Citrus.app" && codesign --verify --deep --strict "dist/Citrus.app"); ./scripts/test.sh
```
