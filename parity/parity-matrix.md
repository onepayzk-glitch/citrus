# Tangerine 功能对照矩阵（100% 匹配口径）

审计对象：`/Applications/Tangerine.app` v2.0.2（`com.th.Tangerine`，LEAP STUDIO，Mac App Store 版）
开源基线：`Open-Tangerine` v0.1.10（GPL-3.0，本地 `tangerine-oss/`，本仓库已在其上补齐）
对照日期：2026-10-28

## 0. 结论速览

| 维度 | Tangerine 官方 | 本仓库现状 | 匹配度 |
|---|---|---|---|
| 转换路由（格式对） | 275 | 275（`ConversionMatrix.totalConversions == 275`，测试断言） | **275/275 声明一致** |
| 可执行引擎覆盖 | 275 | **275/275**（267 条无外部依赖；8 条 →PAGES 走本机 Pages.app + Automation 授权，见 §3.3） | 100%（含依赖说明） |
| 文件工具 | 26（+ 读 QR，2.0.2 新增） | 29 = 26/26 + QR + Resize + Rotate 两个额外工具 | **26/26 全覆盖**（超集） |
| 文件动作 | 6（AirDrop/Float/Copy/Move/Copy Path/Terminal） | 6/6 + 3 个额外动作（Reveal/Duplicate/SHA-256） | **6/6 全覆盖** |
| 拖拽交互 | ⇧ 格式轮盘 / ⌘ 工具轮盘 / ⌃ 动作轮盘，松键后轮盘保持到 drop | 同，且三键可重映射；轮盘支持 Esc/Enter/方向键 | 一致 |
| 设置项（5 tab） | General / Formats / Compatibility / Folders / About | 5 tab 对齐；General 含修饰键重映射与 Terminal 选择，Compatibility 为矩阵表格；Folders 不适用（开源版不沙盒） | 核心项已对齐 |
| 付费墙 | 免费 20 个文件后一次性买断 | 无付费墙、无用量计数 | 有意的开源差异（§8） |
| 输出命名 | `Compressed`/`Edited`/`Annotated.png`/`Speed 2x`/`Clips`/`Pages` 等后缀 | 采用同族命名（§5） | 语义一致 |

**判定口径**：「功能 100% 匹配」= Tangerine 对外可见的每一个操作入口都能在开源版找到等价入口并产出对应结果文件。品牌、付费墙、Apple 私有资源不复制；无法等价实现的引擎项单独列出，不静默降级。

## 1. 证据来源

| 证据 | 位置 |
|---|---|
| App Store 描述（9 图片 / 6 视频 / 8 音频 / 文档字幕压缩包 / 工具清单） | `parity/static/bundle-inventory.txt`、App Store 页面抓取 |
| 官方站点完整矩阵（275 conversions / 26 tools / 6 actions 的可执行数据） | `parity/site-spec/tang_home.js`（`z()` 转换矩阵、`et()` 工具映射、`M` 动作表） |
| 站点规格机器可读版 | `parity/spec/conversions.json`（275 条，逐对）、`parity/spec/tools-actions.json` |
| 静态 REA（FFmpeg 8.0.3 构建配置、ExifTool 13.59、Java 21+POI、付费墙字符串） | `parity/tangerine-static-evidence.md`、`parity/static/` |
| 运行时观察（菜单栏 10 项、设置 5 tab、⇧/⌘/⌃ 修饰键、20/20 免费额度） | `parity/tangerine-runtime-evidence.md`、`parity/runtime/`（19 张截图 + AX 转储） |
| 基线审计（175 路由 / 25 工具 / 5 动作） | `parity/oss-capability-matrix.md` |
| 构建与测试 | `parity/verification.md` |

## 2. 格式族（46 个 `FileFormat` case）

| 类别 | Tangerine 输入 | 现在是否可输入 | 可输出目标 |
|---|---|---|---|
| 图片 | jpg png webp heic tiff svg avif bmp | ✅ 全部 | jpg png webp heic tiff avif bmp pdf |
| 音频 | mp3 m4a wav flac ogg opus aiff wma | ✅ 全部 | 8 种互转 |
| 视频 | mp4 mov mkv webm avi wmv（+ gif 输入） | ✅ 全部 | 6 种互转 + gif + mp3 |
| PDF | pdf | ✅ | docx pages pptx xlsx jpg png epub txt md |
| 文档 | docx pages md rtf rtfd textclipping html | ✅ 全部（html 仅输入） | docx pages pdf txt md html epub png jpg |
| 电子表格 | xlsx xls ods csv tsv | ✅ 全部 | xlsx xls ods csv tsv pdf |
| 演示文稿 | ppt pptx | ✅ 全部 | pdf jpg png |
| 字幕 | srt vtt | ✅ | srt vtt txt |
| 压缩包 | zip tar gz rar | ✅ 全部 | zip tar gz |

## 3. 转换矩阵（275 条）

### 3.1 每条目的计数与官方一致

| 输入 | 目标数 | 输入 | 目标数 | 输入 | 目标数 |
|---|---|---|---|---|---|
| jpg/png/webp/heic/tiff/avif/bmp | 各 7 | mp4/mov/mkv/webm/avi/wmv | 各 7 | docx/pages/md | 各 8 |
| svg | 8 | gif | 6 | rtf/rtfd/textclipping | 各 9 |
| mp3/m4a/wav/flac/ogg/opus/aiff/wma | 各 7 | pdf | 9 | epub | 6 |
| ppt/pptx | 各 3 | xlsx/xls/ods/csv/tsv | 4/5/4/4/4 | txt | 8 |
| srt/vtt | 各 2 | zip/tar/gz/rar | 2/2/2/3 | | |

合计 **275**，与官方「275 conversions」及站点兼容性矩阵数据逐对一致。

### 3.2 引擎归属（实现位置）

| 引擎 | 负责 | 文件 |
|---|---|---|
| `ImageEngine` | 图片互转、SVG 光栅化、PDF 输出 | `Engines/ImageEngine.swift` |
| `AudioEngine` | 8 种音频互转（原生 + FFmpeg 兜底） | `Engines/AudioEngine.swift` |
| `VideoEngine`/`AVExporter` | 6 种视频互转 + gif/mp3 输出 | `Engines/VideoEngine.swift`、`Engines/AVExporter.swift` |
| `DocumentEngine` | pdf→docx/jpg/png/txt；txt→pdf/jpg/png/srt/vtt | `Engines/DocumentEngine.swift` |
| `TextDocumentEngine`（新增） | docx/pages/md/html/rtf/rtfd/textclipping/epub/txt/csv/tsv/xlsx/xls/ods/ppt/pptx/pdf → txt/md/html/docx/epub/pdf/png/jpg/csv/tsv/xlsx/ods/srt/vtt | `Engines/TextDocumentEngine.swift` |
| `SubtitleEngine` | srt↔vtt、→txt | `Engines/SubtitleEngine.swift` |
| `ArchiveEngine`（已启用） | zip/tar/gz/rar → zip/tar/gz（含解压中间层） | `Engines/ArchiveEngine.swift` |

### 3.3 依赖与保真说明

| 路由组 | 依赖 | 说明 |
|---|---|---|
| 8 条 `→ PAGES`（docx/md/rtf/rtfd/textclipping/epub/txt/pdf） | 本机 `Pages.app` + 首次 macOS Automation 授权 | 通过 Pages 自动化保存为 `.pages`；PDF→PAGES 先渲染页面为图片 DOCX 再交给 Pages。Tangerine 内置 iWork 写入引擎、无需授权——这是与官方的已知运行差异 |
| `pdf → pptx` | 无 | 自研纯 OOXML PPTX 写入器：每页 PDF 渲染为图片，一页一张幻灯片 |
| Office 类（DOCX/PPTX/XLSX/ODS/RTF/HTML/CSV） | 本机 LibreOffice（自动检测，L2） | 检测到 LibreOffice 时用其导出 PDF/PNG/JPG（保真接近官方）；未安装时回退内置文本/表格级重建。不捆绑、不下载 |
| EPUB | 无 | 文本级重建（LibreOffice 26.8 不支持 EPUB 导入，实测拒绝） |
| MP3/FLAC/OGG/Opus/WMA/MKV/WebM/AVI/WMV/GIF 部分编码 | 可选系统 `ffmpeg` | 缺失时图片/字幕/压缩包/文档仍可用，相关按钮会给出提示 |

## 4. 文件工具（Tangerine 26 项 → 26/26 + 3 额外）

| # | Tangerine 工具 | ToolID | 状态 | 备注 |
|---|---|---|---|---|
| 1 | Compress（含精确目标大小） | `compress` | ✅（已有） | 目标体积二分搜索：`Operations/Compressor.swift` |
| 2 | Edit metadata / remove | `editMetadata` | ✅（已有） | `Operations/MetadataOps.swift`（含 PDF 敏感字段剥离） |
| 3 | Edit photos | `editImage` | ✅（已有） | 17 项调整 |
| 4 | Annotate photos | `annotateImage` | ✅（新增） | 框/箭头/高亮/文字/编号；`Operations/ImageAnnotation.swift`、`Tools/ExtraToolViews.swift` |
| 5 | Add BG（相框） | `frameImage` | ✅（已有） | |
| 6 | Crop images | `cropImage` | ✅（已有） | |
| 7 | Redact photos | `redactImage` | ✅（已有） | solid/blur/pixelate |
| 8 | Create a PDF | `createPDF` | ✅（已有） | |
| 9 | Create collage | `createCollage` | ✅（已有） | |
| 10 | Trim video | `trimVideo` | ✅（已有） | |
| 11 | Crop video | `cropVideo` | ✅（已有） | |
| 12 | Change video speed | `changeVideoSpeed` | ✅（已有） | 0.25×–4×，保留音调 |
| 13 | Join videos | `joinVideos` | ✅（已有） | |
| 14 | Save video frames | `videoSnapshots` | ✅（已有） | |
| 15 | Split video | `splitVideo` | ✅（已有） | |
| 16 | Redact video | `redactVideo` | ✅（已有） | |
| 17 | Normalize volume | `normalizeAudio` | ✅（已有） | EBU R128（需 FFmpeg） |
| 18 | Audio visualizer | `audioToVideo` | ✅（已有） | |
| 19 | Trim audio | `trimAudio` | ✅（已有） | |
| 20 | Audio channels | `audioChannels` | ✅（已有） | |
| 21 | Bleep audio | `redactAudio` | ✅（已有） | |
| 22 | Remove audio（Mute video） | `muteVideo` | ✅（新增） | `Operations/VideoExtraOps.swift` |
| 23 | Split PDF | `splitPDF` | ✅（已有） | |
| 24 | Organize PDF pages | `organizePDF` | ✅（已有） | |
| 25 | Merge PDFs | `mergePDF` | ✅（已有） | |
| 26 | Extract archive | `extractArchive` | ✅（新增） | `ArchiveEngine.extract` + `Tools/ExtraToolViews.swift` |
| + | 读 QR codes（2.0.2） | `readQRCode` | ✅（新增） | CoreImage CIDetector，本地识别 |
| + | Resize images | `resizeImage` | ✅（额外） | 长边/百分比/精确尺寸 |
| + | Rotate & flip | `rotateImage` | ✅（额外） | |

单文件/多文件可用性由 `ToolID.applies(to:)` 与官方规则对齐（多图才出现 Create PDF/Collage、多 PDF 才出现 Merge、多视频才出现 Join）。

## 5. 文件动作（6/6）

| 官方动作 | 实现 | 语义 |
|---|---|---|
| AirDrop | `FileAction.airDrop` | 系统 AirDrop 分享面板 |
| Float | `FileAction.float` + `UI/FloatingShelf.swift` | 置顶浮窗，可把文件拖到其它 App |
| Copy | `FileAction.copy` | 文件 URL 写入剪贴板，可在 Finder 粘贴 |
| Move | `FileAction.move` | 选择目标文件夹并移动原文件 |
| Copy Path | `FileAction.paths` | 每行一个完整路径 |
| Terminal | `FileAction.openTerminal` | 在 Terminal 打开所在文件夹 |

额外保留：Reveal / Duplicate / SHA-256（开源基线已有，不冲突）。官方强调「文件动作不消耗转换额度」——开源版本来就没有额度。

**输出命名词表**（与官方站点模拟一致，见 `parity/spec/tools-actions.json`）：`Compressed.*`、`No Metadata.*`、`Edited.*`、`Annotated.png`、`Background.*`、`Cropped.*`、`Redacted.*`、`Normalized.*`、`Muted.*`、`Trimmed.*`、`Bleeped.*`、`Speed 2x.*`、`Snapshot.png`、`Clips/`、`Pages/`、`Organized.pdf`、`Extracted/`、`Visualizer.mp4`、`Mono.*`。

## 6. 交互

| 能力 | 状态 |
|---|---|
| ⇧ 拖拽 → 格式轮盘 | ✅ `Radial/DragMonitor.swift` + `RadialController` |
| ⌘ 拖拽 → 工具轮盘 | ✅（`advanced` 通道，工具列表来自 `ToolID.available`） |
| ⌃ 拖拽 → 动作轮盘 | ✅（`actions` 通道，动作来自 `FileAction`） |
| 先拖起、后按修饰键；松键后轮盘保持到 drop | ✅（轮询 + `didChangeModifiers`，拖拽结束才隐藏） |
| 多文件批量、目标取交集 | ✅（`ConversionMatrix.targets(for:)`，BatchTests 覆盖） |
| 每个任务独立进度窗 / 刘海进度 / 完成后 Finder 显示 | ✅（`Core/JobRunner.swift`、`UI/NotchCompanion.swift`） |
| 菜单栏常驻、菜单内入口 | ✅（菜单栏含 Convert/Open Tool/File Actions/Settings/About/Updates/Logs/Quit） |
| 轮盘键盘操作（Esc 取消、Enter 确认、方向键切换） | ✅ `Radial/RadialView.swift` keyDown |
| 声音与触感反馈 | ✅ 任务成功播放系统音并触发触感（`UI/Feedback.swift`），设置里可关闭 |
| 修饰键可在设置内重映射（⇧/⌘/⌃/⌥ 任选，重复自动互换） | ✅ Settings → General → 三个下拉框（`AppSettings.convertModifier/toolsModifier/actionsModifier`） |

## 7. 设置与其它差异

| 官方设置 | 状态 | 说明 |
|---|---|---|
| General：Glass/Solid 外观 | ✅ | 刘海样式黑/玻璃 |
| General：Launch at login | ✅ | `SMAppService` |
| General：Sound and haptic feedback | ✅ | 开关 + 成功音/触感（`Feedback.swift`） |
| General：Drag Modifiers 重映射 | ✅ | 三行下拉框，重复键自动互换 |
| General：Float Behaviour | ✅ | Create a new Float / Add to the current Float（`AppSettings.floatBehaviour`） |
| General：Terminal app 选择（Terminal/iTerm2/系统默认） | ✅ | `AppSettings.terminalApplication` |
| Formats：源格式面板 + Preserve metadata + 压缩预设 | ✅ | 「Format settings」面板：全部可转换源格式按钮网格、所选格式的输出清单、按类别的质量/压缩/元数据控件、Restore Defaults / Restore Compression Defaults |
| Compatibility：源×目标矩阵 UI | ✅ | Settings → Compatibility：逐源格式列出全部目标与总数（275） |
| Folders：安全作用域书签 | ❌ | 开源版不沙盒，无需书签 |
| About：版本/免费额度/Restore Purchase | ⚠️ | 有 About；无付费墙故无额度/恢复购买 |
| 首启引导 6 页 | ✅ | `App/OnboardingView.swift`：欢迎 → ⇧ 转换 → ⌘ 工具 → ⌃ 动作 → 隐私 → 完成设置；菜单「Getting Started…」可重开 |

> PAGES 输出依赖本机 Pages.app 与 Automation 授权；其余 267 条路由不依赖任何外部应用（音视频部分格式可选依赖系统 ffmpeg）。

## 8. 付费墙（有意差异）

官方：免费 20 个文件，之后一次性买断（RevenueCat，一次性 IAP，无订阅）。
开源版：**无付费墙、无计数器、无网络请求**。这是「开源版本」的前提，不作为缺口处理。
官方唯一联网用途是 IAP（`PrivacyInfo.xcprivacy` 仅声明 PurchaseHistory）；开源版移除了该链路。

## 9. 引擎与依赖差异

| 项 | Tangerine | 本仓库 |
|---|---|---|
| FFmpeg | 内置 22 MB（8.0.3，LGPL，VideoToolbox + libmp3lame + libwebp，无 x264/x265/VPx/AV1 编码器） | 使用系统 `ffmpeg`（可选依赖，Homebrew 已装）；缺失时原生路径仍可完成大部分图片/视频/音频 |
| WebP 编码 | 内置 `cwebp` | 原生/FFmpeg，缺失时内置 VP8L 无损兜底 |
| 元数据 | 内置 ExifTool 13.59 + 两个自研 Perl 桥 | 原生 MetadataOps（读写删），未内嵌 ExifTool |
| Office | Java 21 jlink + POI 5.5.1/PDFBox 3.0.6 + 自研 jar（1–1000 页限制） | 检测本机 LibreOffice 作为可选高保真引擎（`Engines/OfficeEngine.swift`，L2，不捆绑）；无 LibreOffice 时用纯原生文本/表格重建（无 Java 依赖） |
| iWork | JavaScriptCore + iWork 模板 | 只读 `.pages` 的 QuickLook 预览 PDF；不做 iWork 写入 |

> 保真度说明：官方对 Office 的转换同样是重建（Java/POI + JS 渲染），不是像素级回放。开源实现按「可打开、内容不丢、版式近似」交付；PDF→DOCX/PNG/JPG 继承基线（含 300 DPI 渲染、扫描页图片回填）。

## 10. 未完成项清单（均为非核心项）

1. Settings → Formats 的「按格式细分设置」面板未做（质量/压缩/长边/Preserve metadata/Office 引擎已集中提供）。
2. Office 转换的版式级保真：已改走本机 LibreOffice（L2，检测复用，0 捆绑）；未安装 LibreOffice 的机器回退文本级重建，保真度低于官方自研渲染器。
2. FFmpeg 未内置：官方内置 22 MB LGPL 版；本仓库使用系统可选 ffmpeg，缺失时部分音视频编码不可用（会明确提示）。
3. PAGES 输出依赖本机 Pages.app 与首次 Automation 授权（Tangerine 内置引擎无此依赖）。

核心功能（275 条转换路由、26 个工具 + QR、6 个文件动作、⇧/⌘/⌃ 轮盘、批量/进度/输出位置）已全部对齐。
