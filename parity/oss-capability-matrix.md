# Open-Tangerine v0.1.10 能力矩阵与 Tangerine 官方差距

- 审计对象：`tangerine-oss/`（Open-Tangerine v0.1.10，GPLv3，SwiftUI 原生菜单栏 App + Python Desktop 版，基于 MIT 的 Satsuma）
- 对照对象：`/Applications/Tangerine.app` v2.0.2（LEAP STUDIO，Mac App Store）官方宣称 275 conversions / 26 tools / 6 file actions / 免费 20 文件后买断
- 审计方式：代码级静态阅读（未改源码）+ 构建与测试实跑；证据格式为 `文件:行号`
- 审计日期：2026-10-28

## 0. 规模对比

| 维度 | Tangerine 官方 | Open-Tangerine 代码 | 覆盖率 |
|---|---|---|---|
| 转换路由 | 275 | **175**（`ConversionMatrix.swift:4-43` 逐条计数；`README.md:127` 自述 176，差 1 未解释） | 约 64% |
| 工具 | 26 | **25**（`ToolID.swift:9-34`） | 96%（口径未核实，见下） |
| 文件动作 | 6（AirDrop/Float/Copy/Move/Copy Path/Terminal） | **5**（Reveal / Copy Files / Copy Paths / Duplicate / SHA-256，`FileAction.swift:4-5`） | 与官方交集仅 Copy、Copy Path 两项 |
| 付费限制 | 免费 20 文件后一次性购买 | 无付费代码、无文件数计数 | 无付费墙（反超官方，但官方额度本身未独立核实，`docs/PRD.md:23`） |
| 引擎依赖 | 未披露 | Apple 框架 + **可选外部 FFmpeg** | 开箱即用度低于官方 |

175 的计数明细（便于复核）：jpg/png 各 9-1=8（16）；webp/heic/tiff/svg/avif/bmp 各 8-1=7（42）；音频 8 种各 8-1=7（56）；视频 6 种各 8-1=7（42）；gif→视频 6；pdf 4；txt 5；srt/vtt 各 2（4）。合计 16+42+56+42+6+4+5+4 = **175**。

> 注意：以上是「矩阵声明的可转目标」，不等于端到端已验证。音频/视频多数路由实际依赖外部 FFmpeg（见第 6 节）。

## 1. 格式支持

来源：`FileFormat.swift:35-50`（枚举与分类）、`93-128`（UTType）、`78-91`（别名）。

| 类别 | 输入 | 输出目标 | 与官方格式族对比 |
|---|---|---|---|
| 图片 | jpg, png, webp, heic, tiff, svg, avif, bmp（gif 归入视频类） | jpg, png, webp, heic, tiff, avif, bmp, pdf | 官方所列 JPEG/PNG/HEIC/WebP/TIFF/BMP/SVG/GIF/PDF 全部有对应 case；但 **SVG 只入不出**（`imageTargets` 不含 svg，`FileFormat.swift:46`），GIF 只入不出图片侧 |
| 音频 | mp3, m4a, wav, flac, ogg, opus, aiff, wma | 同上 8 种互转 | 官方 7 种全覆盖，额外多 **WMA**（官方未列） |
| 视频 | mp4, mov, mkv, webm, avi, wmv | 视频 6 种互转 + gif + mp3 | 官方 6 种全覆盖；GIF 作为视频输入可转 6 种视频 |
| 文档 | pdf, docx, txt | pdf→docx/jpg/png/txt；txt→pdf/jpg/png/srt/vtt | **DOCX 只出不入**（`ConversionMatrix.swift:25-26`）；官方列为「文档」双向，这里是单向 |
| 字幕 | srt, vtt | srt↔vtt、各→txt | 官方 SRT/VTT 覆盖，且多出 txt |
| 压缩包 | zip, tar, gz, rar | **无**（路由被显式禁用） | 官方 ZIP/TAR/GZIP/RAR 覆盖，这里全部缺失 |

补充：gif 的归类在视频（`FileFormat.swift:55`）；`.tar.gz`/`.tgz` 归一为 gz（`FileFormat.swift:132`、`71-76`）；额外支持官方未列的 AVIF、WMA。

## 2. 转换路由明细（输入 → 输出）

来源：`ConversionMatrix.swift:4-29`（`list.filter { $0 != source }`，见 `:28`）。

| 输入 | 输出目标 | 条数 |
|---|---|---|
| jpg, png | 图片目标 8 种 + docx（不含自身） | 各 8 |
| webp, heic, tiff, svg, avif, bmp | 图片目标 8 种（不含自身） | 各 7 |
| mp3, m4a, wav, flac, ogg, opus, aiff, wma | 全部 8 种（不含自身） | 各 7 |
| mp4, mov, mkv, webm, avi, wmv | 视频 6 种 + gif + mp3（不含自身） | 各 7 |
| gif | 视频 6 种 | 6 |
| pdf | docx, jpg, png, txt | 4 |
| txt | pdf, jpg, png, srt, vtt | 5 |
| srt / vtt | 互为对方 + txt | 各 2 |
| zip, tar, gz, rar | **空**（`ConversionMatrix.swift:24`：「Archive engine is disabled」） | 0 |
| docx | **空**（`ConversionMatrix.swift:25-26`） | 0 |

多文件批量时取各输入目标集合的交集（`ConversionMatrix.swift:31-39`）；输出重名自动加序号（`:45-55`）。

## 3. 工具清单（25 项，`ToolID.swift:9-34`）

| # | ToolID | 界面标题 | 适用类别 | 多文件 | 对应官方能力 | 状态 |
|---|---|---|---|---|---|---|
| 1 | compress | Compress | 图/视/音/文档 | 任意 | 压缩（图/视频/音频/PDF） | 部分覆盖：有质量预设/长边/码率，未见「精确目标文件大小」输入 |
| 2 | editMetadata | Edit metadata | 图/视/音/文档 | 任意 | 元数据读取/编辑/删除 | 已覆盖（含 PDF 敏感字段剥离，测试 PASS） |
| 3 | editImage | Edit photo | 图片 | 单 | 照片调色 | 已覆盖（`docs/BUILD-STATUS.md:36` 记 17 项调整） |
| 4 | frameImage | Add a background | 图片 | 单 | 官方工具清单未明列 | OSS 额外能力 |
| 5 | cropImage | Crop image | 图片 | 单 | 照片裁剪 | 已覆盖 |
| 6 | redactImage | Redact photo | 图片 | 单 | 照片涂黑 | 已覆盖（solid/blur/pixelate 三模式） |
| 7 | resizeImage | Resize images | 图片 | 任意 | 官方未明列 | OSS 额外能力 |
| 8 | rotateImage | Rotate & flip | 图片 | 任意 | 官方未明列 | OSS 额外能力 |
| 9 | createPDF | Create a PDF | 图片 | 任意 | 由图片建 PDF | 已覆盖 |
| 10 | createCollage | Create a collage | 图片 | 多 | 拼贴 | 已覆盖 |
| 11 | trimVideo | Trim video | 视频 | 单 | 视频裁剪 | 已覆盖 |
| 12 | cropVideo | Crop video | 视频 | 单 | 视频裁剪 | 已覆盖 |
| 13 | changeVideoSpeed | Change video speed | 视频 | 单 | 视频变速 | 已覆盖 |
| 14 | joinVideos | Join videos | 视频 | 多 | 视频合并 | 已覆盖 |
| 15 | videoSnapshots | Save video frames | 视频 | 单 | 视频抽帧 | 已覆盖 |
| 16 | splitVideo | Split video | 视频 | 单 | 视频分割 | 已覆盖 |
| 17 | redactVideo | Redact video | 视频 | 单 | 官方工具清单未明列 | OSS 额外能力 |
| 18 | normalizeAudio | Normalize volume | 音频 | 单 | 音频归一化 | 已覆盖（EBU R128 需 FFmpeg；否则降级峰值归一化，`AudioToolViews.swift:112-114`） |
| 19 | audioToVideo | Audio visualizer | 音频 | 单 | 官方未明列 | OSS 额外能力，需 FFmpeg |
| 20 | trimAudio | Trim audio | 音频 | 单 | 音频裁剪 | 已覆盖 |
| 21 | audioChannels | Audio channels | 音频 | 单 | 变声道 | 已覆盖（stereo/mono/左/右/交换），需 FFmpeg |
| 22 | redactAudio | Bleep audio | 音频 | 单 | 哔声 | 已覆盖，需 FFmpeg |
| 23 | mergePDF | Merge PDFs | 文档(pdf) | 多 | PDF 合并 | 已覆盖 |
| 24 | organizePDF | Organize PDF pages | 文档(pdf) | 单 | PDF 重组 | 已覆盖（重排/旋转） |
| 25 | splitPDF | Split PDF | 文档(pdf) | 单 | PDF 拆分 | 已覆盖（多模式） |

官方 26 项逐条清单**未公开核实**（`docs/PRD.md:19` 只给分类与宣称数量，`:23` 明确「full 26-tool inventory … not independently verified」）。按 App Store 分类映射，缺口为**照片标注（annotate）**与**读 QR**；官方声音类「归一化/裁剪/哔声/变声道」与「PDF 合并/拆分/重组/建 PDF/拼贴」在本基线均可一一对上。

## 4. 文件动作（官方 6 项）

来源：`FileAction.swift:4-5`（枚举穷举 5 项）、`38-69`（实现）、`AppDelegate.swift:52`（菜单入口）、`RadialController.swift:158-159`（轮盘入口）。

| 官方动作 | OSS 状态 | 证据 |
|---|---|---|
| AirDrop | 缺失（枚举无此动作；未见 `NSSharingService` 调用） | `FileAction.swift:4-5` |
| Float（悬浮架） | 缺失 | 同上 |
| Copy | 部分覆盖：`Copy Files` 把文件 URL 写入剪贴板（`:42-43`），不是复制到目标文件夹 | `FileAction.swift:42-43` |
| Move | 缺失：全仓无移动文件实现 | `FileAction.swift:4-69` |
| Copy Path | 已覆盖（路径文本写入剪贴板，`:44-46`） | `FileAction.swift:44-46` |
| Terminal | 缺失：无终端唤起实现 | `FileAction.swift:4-69` |
| （OSS 额外）Reveal | 已覆盖（`activateFileViewerSelecting`，`:40`） | `FileAction.swift:40` |
| （OSS 额外）Duplicate | 已覆盖（`:16-22,47-50`） | `FileAction.swift:16-22` |
| （OSS 额外）SHA-256 | 已覆盖（流式哈希，`:24-37,51-67`） | `FileAction.swift:24-37` |

结论：6 项官方动作里只实现 2 项（Copy 还是剪贴板语义），并且没有 Move / AirDrop / Float / Terminal。

## 5. 交互

| 能力 | 状态 | 证据 |
|---|---|---|
| 全局拖拽检测 | 已覆盖：全局事件监视 + 轮询兜底（按住后位移阈值） | `DragMonitor.swift:121-141` |
| 拖拽时按 Shift 弹格式轮盘 | 已覆盖 | `DragMonitor.swift:183-188`、`RadialController.swift:172` |
| Command 弹工具轮盘 | 部分覆盖：OSS 把 `shift‖command‖control` 都当作「弹轮盘」，`command‖option` 当作 advanced（工具）。语义与官方「Command=工具、Control=动作」不同 | `DragMonitor.swift:102-104`、`RadialController.swift:44-54` |
| Option+Shift 弹工具轮盘 | 已覆盖（文档明确第二入口） | `README.md:109` |
| Control 弹动作轮盘 | 已覆盖：`actions = NSEvent.modifierFlags.contains(.control)` | `RadialController.swift:40,48`、`:158-159` |
| 松开按键后轮盘保持 | 部分覆盖/未验证：`didChangeModifiers` 在 `!shift` 时直接 `return`，未见显式 dismiss 逻辑；官方称松键后轮盘仍在 | `RadialController.swift:44-46` |
| 多文件批量 | 已覆盖（目标取交集 + BatchTests 通过） | `ConversionMatrix.swift:31-39`、`docs/BUILD-STATUS.md:30` |
| 每任务小进度窗 | 已覆盖（JobRunner + 进度样式设置） | `Core/JobRunner.swift:38-39`、`AppSettings.swift:117` |
| Notch 进度 | 已覆盖（黑/胶囊两种刘海样式、NotchJobRow） | `UI/NotchCompanion.swift:76`、`SettingsView.swift:235` |
| 完成后 Finder 显示 | 已覆盖（可设置开关） | `AppSettings.swift:109`、`JobRunner.swift:113-114,647`、`SettingsView.swift:163` |
| 输出位置 | 已覆盖（源旁 / 下载 / 桌面） | `AppSettings.swift:105`、`SettingsView.swift:159-163`、`README.md:112` |
| 菜单栏常驻 | 已覆盖（NSStatusItem + 菜单 + LSUIElement） | `AppDelegate.swift:6,43-73`；构建产物 `LSUIElement=true` |
| 菜单栏作为拖放目标 | 未验证（状态栏项挂的是菜单，未见 NSDraggingDestination 证据） | `AppDelegate.swift:43-73` |
| 设置项 | 部分覆盖：输出位置/登录启动/主题/进度样式/刘海样式/图片质量与长边/FFmpeg 路径/排除应用；「Drag Modifiers」只有说明文本，未见可重映射控件 | `SettingsView.swift:159-292`、`183-185`、`AppSettings.swift:93-151` |
| 付费限制 | 无：未见订阅/试用计数/购买校验代码；About 写 "Free to use"，GPL-3.0 | `SettingsView.swift:308,314,327`、`README.md:10` |

## 6. 引擎与外部依赖

| 能力 | 实现 | 外部依赖 |
|---|---|---|
| 图片编解码 | ImageIO / CoreGraphics（`Engines/ImageEngine.swift`） | 无 |
| SVG 输入 | 光栅化 `rasterizeSVG`（`ImageEngine.swift:26,61`），只入不出 | 无 |
| HEIC | ImageIO 原生（`FileFormat.swift:98`）；受限环境编码受限（`docs/BUILD-STATUS.md:40`） | 无 |
| WebP 编码 | 原生/FFmpeg，缺 libwebp 时用内置 VP8L 无损兜底 | 可选 FFmpeg |
| AVIF | 原生/FFmpeg（libaom-av1 / libsvtav1） | 可选 FFmpeg |
| 视频 | AVFoundation 导出（`Engines/AVExporter.swift`、`VideoEngine.swift`） | 部分编码需 FFmpeg |
| 音频 | AVFoundation + FFmpeg 兜底（`AudioOps.swift`） | MP3/FLAC/OGG/Opus/WMA 需 FFmpeg |
| **FFmpeg** | **外部可选 CLI**：自动探测 Homebrew/MacPorts/`/usr/local/bin`，设置里可手动指定路径，带健康检查；缺失时抛 `ffmpegMissing` 并禁用相关按钮 | 用户自装（本机 `/opt/homebrew/bin/ffmpeg` 已存在）`Shell.swift:87-91`、`SettingsView.swift:278-292`、`SatsumaError.swift:7,20-21`、`AudioToolViews.swift:112-114,194,212,273,365` |
| PDF | PDFKit（`PDFOps.swift:3`、`MetadataOps.swift:4`、`DocumentEngine.swift:4`、`PDFToolViews.swift:2`） | 无 |
| DOCX 输出 | 自写 OOXML + `/usr/bin/zip` + `ditto`（`Engines/DocxWriter.swift:7-20`）；无版式保真、无 OCR（`docs/BUILD-STATUS.md:42`） | 系统自带 |
| 字幕 | SubtitleEngine（SRT/VTT/TXT，时间戳修复见 `BUILD-STATUS.md:15`） | 无 |
| 压缩包 | ArchiveEngine 存在（`/usr/bin/tar`、`/bin/sh gunzip`，`ArchiveEngine.swift:17-59`），但矩阵路由禁用 | 系统自带（引擎未接入 UI） |
| 元数据 | MetadataOps（读写删，含 PDF 敏感字段剥离） | 无 |
| **读 QR** | **无**：全仓 `QR`/`CIDetector`/`VNDetectBarcodes` 零命中 | — |
| OCR | 无（`docs/BUILD-STATUS.md:42`） | — |

## 7. 缺口矩阵（对照官方能力清单）

状态定义：**已覆盖** = 代码与测试均有；**部分覆盖** = 有实现但参数/范围/语义不全；**缺失** = 代码中无；**未验证** = 有线索但本次未跑到确证。

| # | 官方能力 | 状态 | 证据 | 影响 |
|---|---|---|---|---|
| 1 | 275 conversions | 部分覆盖（175） | `ConversionMatrix.swift:4-43`、`README.md:127` | 约差 100 条路由 |
| 2 | 压缩包 ZIP/TAR/GZIP/RAR | 缺失（显式禁用） | `ConversionMatrix.swift:23-24`、`README.md:133` | 官方 4 种格式完全不可转 |
| 3 | DOCX 作为输入 | 缺失 | `ConversionMatrix.swift:25-26` | 只能输出 DOCX，不能读 Word |
| 4 | SVG 作为输出 | 缺失（只入不出） | `FileFormat.swift:46` | 官方图片族里的 SVG 只做输入 |
| 5 | 压缩到精确目标文件大小 | 未验证（疑似缺失） | `CompressToolView.swift:103`、`AppSettings.swift:97-102` | 只有质量/长边/码率，没有「目标大小」参数 |
| 6 | 照片标注（文字/箭头） | 缺失（25 工具穷举无此项） | `ToolID.swift:9-34` | 官方分类里的 annotate 无对应 |
| 7 | 照片调色 | 已覆盖 | `ToolID.swift:12`、`docs/BUILD-STATUS.md:36` | — |
| 8 | 照片裁剪 / 涂黑 | 已覆盖 | `ToolID.swift:14,16`、`BUILD-STATUS.md:31` | — |
| 9 | 视频裁剪/变速/分割/合并/抽帧 | 已覆盖 | `ToolID.swift:20-25`、`BUILD-STATUS.md:32` | 部分编码需 FFmpeg |
| 10 | 音频归一化/裁剪/哔声/变声道 | 已覆盖 | `ToolID.swift:27-31`、`BUILD-STATUS.md:32` | 实际信号质量依赖 FFmpeg |
| 11 | 元数据读取/编辑/删除 | 已覆盖 | `Operations/MetadataOps.swift`、`BUILD-STATUS.md:15` | — |
| 12 | PDF 合并/拆分/重组/由图片建 PDF/拼贴 | 已覆盖 | `ToolID.swift:18-19,32-34`、`BUILD-STATUS.md:29` | PDF→DOCX 是重建，非精确往返 |
| 13 | 读 QR | 缺失 | 无 QR/Vision 命中 | 官方工具卡片直接无对应 |
| 14 | 6 个文件动作 | 部分覆盖（交集 2/6，语义还不同） | `FileAction.swift:4-5`、`42-43` | Copy 只是剪贴板；Move 不存在 |
| 15 | AirDrop / Float / Move / Terminal | 缺失 | `FileAction.swift:4-69` | 4 项交互完全没有 |
| 16 | Shift 格式轮盘 | 已覆盖 | `DragMonitor.swift:183-188` | — |
| 17 | Command/Control 修饰键分工 | 部分覆盖 | `DragMonitor.swift:102-104`、`RadialController.swift:40,48` | OSS 用 Option 承担 advanced，与官方肌肉记忆不一致 |
| 18 | 多文件批量 | 已覆盖 | `ConversionMatrix.swift:31-39`、`BatchTests` 通过 | — |
| 19 | 每任务小进度窗 | 已覆盖 | `JobRunner.swift:38-39`、`AppSettings.swift:117` | — |
| 20 | 完成后 Finder 显示 | 已覆盖 | `JobRunner.swift:113-114,647` | — |
| 21 | 菜单栏常驻 | 已覆盖 | `AppDelegate.swift:6,43-73` | — |
| 22 | 免费 20 文件 + 买断 | 无此限制（无付费代码） | `SettingsView.swift:314`、`README.md:10` | 比官方更宽松；官方额度本身未核实 |
| 23 | 免外部依赖开箱即用 | 部分覆盖 | `SettingsView.swift:292`、`SatsumaError.swift:20-21` | 多种音视频格式要求用户自装 FFmpeg |
| 24 | 26 tools 逐项对应 | 未验证 | `docs/PRD.md:19,23` | 官方清单未公开逐条，只能按分类映射 |

## 8. 缺口 Top 10（按优先级）

1. **压缩包四格式（ZIP/TAR/GZIP/RAR）完全禁用**，官方明确列出的整族能力缺失（`ConversionMatrix.swift:23-24`）。
2. **文件动作只有 2/6**：无 AirDrop、Float、Move、Terminal；Copy 只写剪贴板（`FileAction.swift:4-69`）。
3. **转换路由 175 vs 官方 275**，差距约 100 条（`ConversionMatrix.swift:4-43`）。
4. **读 QR 缺失**，官方工具卡片的一项直接无对应。
5. **照片标注（annotate）缺失**，25 工具里没有任何标注/涂鸦/箭头能力（`ToolID.swift:9-34`）。
6. **精确目标文件大小的压缩未实现/未验证**，只有质量与尺寸参数（`CompressToolView.swift:103`）。
7. **DOCX 只能出不能入**，Word 输入转换不存在（`ConversionMatrix.swift:25-26`）。
8. **FFmpeg 外部依赖**：MP3/FLAC/OGG/Opus/WMA/MKV/WebM/AVI/WMV/GIF 与旧系统 WebP/AVIF 编码都要用户自装，缺失时按钮直接禁用（`SettingsView.swift:292`、`AudioToolViews.swift:112-114`）。
9. **修饰键语义不一致**：官方 Shift=转换、Command=工具、Control=动作；OSS 用 `shift‖command‖control` 弹轮盘、`command‖option` 进工具（`DragMonitor.swift:102-104`），迁移用户肌肉记忆会错位。
10. **设置项可重映射缺失**：「Drag Modifiers」只有提示文字，官方称修饰键可重映射（`SettingsView.swift:183-185`、`docs/PRD.md:21`）。

## 9. 未验证清单（不要当成结论）

- 官方 275/26/6 的**完整逐项含义**：`docs/PRD.md:19` 记厂商宣称，`:23` 明确「26-tool inventory / 20-item limit / price 未独立核实」。
- 菜单栏图标是否接受文件拖放（未见 NSDraggingDestination 证据）。
- 精确目标大小压缩是否藏在未读的视图里（本次只做了定向 grep）。
- 松开修饰键后轮盘是否保持（代码阅读有疑点，未做真机交互验证）。
- 真实 Finder 拖拽 UX：`docs/BUILD-STATUS.md:41` 自述只做了自动化测试，未做 live Finder 拖拽验证。
- HEIC 编码、物理刘海动画：`docs/BUILD-STATUS.md:17,40`。
- 官方「免费 20 文件」额度与价格：`docs/PRD.md:23` 明确未核实。

## 10. 复现命令

```
cd tangerine-oss
grep -n 'case ' NativeApp/Sources/Formats/FileFormat.swift | head -30        # 格式枚举
sed -n '4,29p' NativeApp/Sources/Formats/ConversionMatrix.swift              # 路由矩阵
grep -c '^    case ' NativeApp/Sources/Tools/ToolID.swift                    # 工具数
sed -n '4,5p' NativeApp/Sources/Tools/FileAction.swift                       # 文件动作
grep -rn 'QR\|CIDetector\|VNDetectBarcodes' NativeApp/Sources                 # 读 QR 检索（零命中）
```
