# 1.0 完整测试报告

日期：2026-11-01
仓库：`/Users/zhukun/Documents/HARNESS/dsh-mac/tangerine-oss`
版本：`1.0.0 (build 1)`，arm64，macOS 15+，ad-hoc 签名（暂无 Developer ID）
发布身份：`CFBundleIdentifier = com.onepayzk.opentangerine`（本 fork）；开发构建默认 `com.syntaxerror.opentangerine`

## 1. 环境

| 项 | 值 |
|---|---|
| macOS | 27.2 (26B123) |
| 芯片 / 架构 | Apple Silicon / arm64 |
| Xcode / Swift | 27.1 / 6.4 |
| LibreOffice | 26.8.1.1（检测可用） |
| FFmpeg | 9.0.2（Homebrew，`/opt/homebrew/bin/ffmpeg`） |
| Pages | 已安装（Automation 首次授权） |
| 签名身份 | `security find-identity -v -p codesigning` → **0 valid identities** |
| 公证凭据 | 未配置（`notarytool` 可用，无 keychain profile） |

## 2. 自动化测试（12 个套件，全部通过）

```bash
./scripts/test.sh   # exit 0
```

| 套件 | 结果 |
|---|---|
| SatsumaTests | 20/20 passed（矩阵=275、29 工具、命名/检测/匹配规则） |
| IntegrationTests | passed |
| InteractionTests | passed |
| ImageConversionTests | 45 passed（图片互转/HEIC/WebP/AVIF） |
| DocumentTests | 文档/PDF/Office 文本路由 + 外部解析器校验 |
| BatchTests | passed（批量输出命名、失败隔离） |
| ImageToolsTests | passed（裁剪/调整/拼贴等） |
| MediaIntegrationTests | 55 passed, 0 failed（音视频/FFmpeg） |
| OfficeEngineTests | LibreOffice 检测 + DOCX→PDF/PNG、XLSX→PDF、PPTX→PDF |
| DependencyTests | 按需依赖判断（Office/FFmpeg/Pages 提示边界） |
| AppInfoTests | 作者信息、mailto、诊断信息隐私（无路径/邮箱） |
| **MatrixCoverageTests** | **275/275 条路由均有引擎**（图片 57、音频 56、视频 48） |

外部解析器校验（DocumentTests 产物）：`python-pptx` / `python-docx` / `openpyxl` / `zipfile` 均可读取。

## 3. 构建

```bash
MARKETING_VERSION=1.0.0 BUILD_NUMBER=1 ./scripts/build-app.sh   # exit 0
```

```
Built dist/Citrus.app (arm64, macOS 15.0+, version 1.0.0 build 1)
dist/Citrus.app: valid on disk
dist/Citrus.app: satisfies its Designated Requirement
```

启动冒烟：启动 → 进程存活 → 正常退出，无残留。

## 4. 打包产物

```bash
MARKETING_VERSION=1.0.0 BUILD_NUMBER=1 ./scripts/package-release.sh   # exit 0
```

| 产物 | 大小 | SHA-256 |
|---|---|---|
| `dist/release/Citrus-1.0.0.zip` | 2.0 MB | `5a769499f3153adc0884cee952bf046dfa7b74664fe67bf702d5b2b1e38b5aa4` |
| `dist/release/Citrus-1.0.0.dmg` | 2.5 MB | `bb0e009ec4afb2bc13ff425caa3592f867d50fea4a2b22d3720fd7758c7dca49` |

DMG 验收：可挂载；内含 `Citrus.app` 与 `Applications` 软链；
`CFBundleShortVersionString=1.0.0`、`CFBundleVersion=1`、`CFBundleIdentifier=com.onepayzk.opentangerine`；
`OTGitHubRepo` 为空（未配置仓库时 App 内更新检查不联网）；签名类型为 ad-hoc；
`spctl --assess` 拒绝（**符合预期**：未公证的 ad-hoc 包不能对外分发）。

## 5. 签名与公证

- **当前无法完成对外签名/公证**：本机没有 Developer ID Application 证书（0 identities），也没有
  notarytool 凭据。代码与脚本已就绪：
  - `scripts/build-app.sh`：支持 `DEVELOPER_ID_APPLICATION`（hardened runtime + timestamp）；
  - `scripts/package-release.sh`：签名、ZIP/DMG、`notarytool submit --wait`、`stapler staple`、
    `spctl` 校验、SHA256；
  - 流程与前置条件见 [`release-1.0.md`](release-1.0.md)。
- 需要你完成的前置：Apple Developer Program、Developer ID Application 证书、Team ID、
  `xcrun notarytool store-credentials`（API Key 或 Apple ID 专用密码）。
- 之后一条命令即可产出对外包：

```bash
MARKETING_VERSION=1.0.0 BUILD_NUMBER=1 \
DEVELOPER_ID_APPLICATION="Developer ID Application: <Name> (TEAMID)" \
NOTARY_PROFILE="open-tangerine-notary" \
./scripts/package-release.sh
```

## 6. 未覆盖 / 待人工验证

1. **真人拖拽链路**（⇧/⌘/⌃ 轮盘、批量、依赖提示 UI、Pages 授权）——合成事件无法进入轮盘，
   清单见 [`manual-verification-checklist.md`](manual-verification-checklist.md)。
2. **公证后的 Gatekeeper 实测**（需要证书与 Apple 公证服务）。
3. Intel（x86_64）构建：当前默认 arm64；可用 `ARCHS=universal BUILD_UNIVERSAL=1` 构建后复测。
4. 长时间稳定性/大文件/超大 PDF 压测未做。
5. 多显示器、不同 macOS 版本的 UI 回归未做。

## 7. 结论

- 功能实现与依赖策略通过全部 12 个自动化套件，矩阵 275/275 有引擎；
- 构建、启动、ZIP/DMG 打包流程可重复执行；
- 对外分发只差**你的 Apple Developer 证书与公证凭据**；脚本与文档已准备好，拿到后跑一条命令并做 §4 验收即可。
