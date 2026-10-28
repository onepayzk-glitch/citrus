# Tangerine.app 静态逆向证据基线

- 目标：`/Applications/Tangerine.app`（Mac App Store 版，`CFBundleShortVersionString=2.0.2`，`CFBundleVersion=9`，`CFBundleIdentifier=com.th.Tangerine`，TeamID `GTF45UH2VQ`）
- 用途：为「开源版 100% 功能匹配」提供**可复现的静态证据**，不作运行时行为断言
- 采集时间：2026-10-28；原始导出物全部位于 `tangerine-oss/parity/static/`
- 标注约定：**[观察]** = 命令/字符串直接可见；**[推断]** = 由多处证据合并得出；**[未知]** = 静态不可判定
- 铁律遵守：未读取任何 `rea ... --json` 全量输出（本次未调用 rea，全部用 `strings/plutil/otool/codesign/unzip` 完成，原因见 §7.1）

---

## ① 执行摘要

### 1.1 可确证的产品形态

| 项 | 值 | 证据 |
|---|---|---|
| 版本 / Build | 2.0.2 (9) | `Contents/Info.plist` → `CFBundleShortVersionString`, `CFBundleVersion` |
| 最低系统 | macOS 13.0 | `Info.plist` → `LSMinimumSystemVersion` |
| 形态 | 菜单栏 App（无 Dock 图标） | `Info.plist` → `LSUIElement=true`；字符串 `Find the Tangerine icon near the clock in your menu bar`、`Tangerine.MenuBarController`、`Tangerine is ready` / `Tangerine is working` |
| 分类 | Utilities | `LSApplicationCategoryType=public.app-category.utilities` |
| 沙盒 | 是 | `entitlements.plist`：`com.apple.security.app-sandbox`、`com.apple.security.files.user-selected.read-write`、`com.apple.security.files.bookmarks.app-scope`、`com.apple.security.network.client` |
| 内购 | RevenueCat + StoreKit 2 | `Info.plist` → `RevenueCatAPIKey=appl_czfAzzQZWlJqAfTAOgqikuKSisS`；类名 `RevenueCatPurchaseService`、`PurchasesStatusPoller`、`UnlockStore`、`PaywallPanel` |
| 构建链 | Xcode 27（`DTXcode=2700`, `DTSDKName=macosx27.0`） | `Info.plist` |

**[观察]** 主二进制 `/Applications/Tangerine.app/Contents/MacOS/Tangerine` 为 11.2 MB arm64 Mach-O（非 fat），链接 `Foundation / AppKit / AVFoundation / AVKit / CoreImage / CoreMedia / CoreVideo / ImageIO / PDFKit / Quartz / JavaScriptCore / CryptoKit / AdServices / Combine / IOKit / CoreText`（`otool -L`）。其中 `PDFKit`+`JavaScriptCore`+`AVFoundation` 的存在直接对应下文三条实现路线。

### 1.2 功能面（静态可确证的原子能力）

**[观察]** 主二进制内直接出现以下用户可见工具名/界面字符串（`main-binary.strings.txt`，行号为导出文件行号）：

| 类别 | 能力字符串 | 行号 |
|---|---|---|
| 图片 | `Annotate Photo`、`Crop`、`Crop width in pixels`、`Crop selection. Drag to reposition.`、`Collage`、`CollageStyle`/`CollageBackground`、`Add BG`（`Change image background`）、`Compress`、`Compression Settings`、`CompressionTargetMode`、`Compression preset`/`Compression mode` | 8028, 8276, 34755–34758, 8280–8286, 34287, 34902 |
| 图片（隐私） | `Remove metadata now and save a new file…`、`Metadata Removed`、`Redact one still photo at a time…`、`Redaction rectangle`、`Remove all drawn strokes`、`Resize redaction` | 34351, 34280, 34323, 34878–34888, 1120 |
| 视频 | `Trim`（`Trim silent ends automatically`、`TrimEndpointHandle`）、`Split`（`Add split points…at least 0.05 seconds apart, inside the video.`）、合并/拼接（`Remove a clip to join the rest into one video, or export separate clips.`）、`Change Video Speed`、`Add a frame to save.`/`Remove selected frame`（抽帧）、`Redaction`（视频涂黑：`RedactionTimeRange`、`RedactionTrack`、`Add redaction at playhead`）、`Could not read the video bitrate for cropping.` | 34748, 34302/34715–34716, 1118–1119, 34451, 34302/1122, 8279–8281, 34888, 34817 |
| 音频 | `Normalize Volume`（`Normalized audio preview is unavailable…`）、`Bleep Entire Audio`/`Add bleep at playhead`、`Convert Audio Channels`、`Trim silent ends automatically` | 34452, 34325/34337, 34886/34883, 34449, 34748 |
| 文档 | `Document to PDF failed: …`（8 种失败分支）、`EPUBPDFRenderer`、`EPUBZIP`（EPUB→PDF）、`Creates a native Pages document directly on your Mac.`（→ Pages）、`The native Pages writer is unavailable.`、PDF 合并/拆分/重组（`Could not create the organized PDF.`、`Could not create the compressed PDF.`）、`Text recognition could not read a scanned PDF page:`（PDF 扫描页 OCR） | 33873–33879, 33856–33857, 33658, 33745, 34830、34835、33812 |
| 归档 | `Extracting archive`、`Could not create the RAR archive.`、`RAR output cannot store …`、`ArchiveConverter` | 34517, 33623, 33624, 34467 |
| QR | `Copy QR code text from …`、`No QR codes found`、`Tangerine.QRCodeResultsWindowController`、`Tangerine/QRCodeResultsWindowController.swift` | 34670-ish, 34960, 34958–34959 |
| 菜单栏/Float | `Create a New Float`、`Add Files to an Existing Float`、`Close Float without deleting files`、`Collapse Float`、`Float file or folder thumbnail`、`FloatWheelBehavior`、`FormatDropTarget` | 34790 区段、34920、34639、34633、34641、34645、34910 |
| 系统集成 | `Change access in Settings`、`One more step: allow Tangerine in macOS Login Items.`、`Choose whether Tangerine launches at login…`、`Ready whenever you turn on your Mac.` | 34971、34851 区段、33894、1064 |

**[推断]** 用户描述的「9 图片 / 6 视频 / 8 音频 / PDF、TXT、DOCX、SRT、VTT、ZIP、TAR、GZIP、RAR」与静态字符串**方向一致**，但**静态无法直接数出 275 conversions / 26 tools / 6 file actions**：主二进制中没有字面量 `275`、`26 tools`、`6 file actions`（`grep -nE '275|26 tools|6 file' main-binary.strings.txt` 无命中）。见 §6 未知项。

### 1.3 付费墙（静态可确证）

**[观察]** 字符串（`main-binary.strings.txt` 34819–34964 区段）：

```
Unlock Tangerine
Restore Purchase
Unlimited conversions and tools
Batch drops of any size
One-time purchase, no subscription
 free uses left.
've used all  <n> uses, but only  <m> left
Purchases aren't available right now. Please try again later.
No previous purchase was found for this Apple Account.
[Tangerine] RevenueCat API key is missing; purchases are disabled
https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
https://tangerineformac.com/privacy
```

- 付费模型：**[观察]** 一次性买断（`One-time purchase, no subscription`）+ 免费次数计量（`free uses left.` / `you've used all <n> uses`）。
- **[未知]** 免费次数上限的具体数值：文案是插值（` free uses left.` 前无数字字面量），静态不可读；用户口述的「20 文件」来自 App Store 描述，不构成本 App 的静态证据。
- **[观察]** 解锁态也有字符串 `Full version unlocked`、`Your active lifetime subscription`（`messages.txt` 602/1979 行），说明存在「解锁/恢复购买」的显示态分支。

---

## ② Bundle 组件清单（Contents/Resources）

**总览**：16 项（`find Contents/Resources -maxdepth 1`，见 `static/bundle-inventory.txt`）。

| 路径 | 大小 | 作用（证据→判断） | 置信 |
|---|---|---|---|
| `Tools/ffmpeg` | 21,986,240 B | 自编译 FFmpeg 8.0.3 arm64，静态链接；音视频转换/裁剪/变速/归一化/抽帧/合并的引擎。`otool -L` 仅系统框架；`codesign` 含 `app-sandbox`+`inherit` | **[观察]** |
| `Tools/cwebp` | 505,024 B | libwebp 的 `cwebp` CLI（arm64）；用 `-q`/`-lossless`/`-preset`/`-metadata`/`-resize` 等做 WebP 编码 | **[观察]** |
| `Tools/licenses/ffmpeg/{COPYING.LGPLv2.1,COPYING.LGPLv3}` | 26.5 KB / 7.7 KB | FFmpeg 以 **LGPL** 方式分发（无 GPL 文本）→ 与「未链接 libx264/libx265 等 GPL 库」的构建事实自洽 | **[观察]** |
| `Tools/licenses/lame/COPYING` | 25 KB | LAME（libmp3lame，LGPL）许可 | **[观察]** |
| `Tools/licenses/libwebp/COPYING` | 1.5 KB | libwebp（BSD）许可 | **[观察]** |
| `ExifTool/tangerine_metadata.pl` | 438 行 | ExifTool 的**离线 fail-closed 桥**：读写/删除元数据，含 Apple maker-note 相对偏移修补、自定义 XMP 按字节区间删除 | **[观察]** |
| `ExifTool/tangerine_privacy.pl` | 282 行 | **隐私清理专用**：直接按容器 box 结构擦除 HEIC/JPEG 元数据（保留图像样本，可保留方向） | **[观察]** |
| `ExifTool/lib/Image/ExifTool.pm` 等 | — | ExifTool **13.59**（`$VERSION = '13.59'`），`lib/File/RandomAccess.pm`、`lib/Image/ExifTool/` 子树 | **[观察]** |
| `ExifTool/README`, `ExifTool/Artistic.txt` | — | 上游 ExifTool 说明与 Artistic 许可 | **[观察]** |
| `PowerPoint/`（91 MB 级） | — | **jlink 裁剪的 Java 21 运行时**（arm64 与 x86_64 双份）+ POI/pdfbox 依赖 + 自研 `tangerine-powerpoint.jar`，用于 Office/PDF 互转 | **[观察]** |
| `PowerPoint/arm64/release` | 125 B | `JAVA_VERSION="21.0.12.1"`；`MODULES="java.base java.datatransfer java.xml java.prefs java.desktop java.logging jdk.unsupported"` | **[观察]** |
| `OfficePreview.js` | 188,843 B | 打包的 IIFE JS，内含 `docx`/`pages` 处理逻辑；主二进制链接 `JavaScriptCore` →**JS 文档预览/渲染器** | **[推断]** |
| `PagesWriter.js` | 694,646 B | 打包 JS，自带 `btoa/atob/TextEncoder` polyfill，含 `Pages`/`pages` 写法；配合模板写原生 `.pages` | **[推断]** |
| `PagesTemplate.pages` | 82,768 B | iWork 扁平包（`Index/Document.iwa`、`Index/ViewState.iwa`、`Index/Tables/*.iwa`），是 `PagesWriter.js` 的输出模板 | **[观察]** |
| `HighlightSound.mp3` / `.wav` | 9.3 KB / 11.6 KB | 交互音效（推断用于高亮/完成反馈） | **[推断]** |
| `RevenueCat_RevenueCat.bundle` | — | RevenueCat 资源包（内含自己的 `PrivacyInfo.xcprivacy`、`Info.plist`） | **[观察]** |
| `PrivacyInfo.xcprivacy` | 1,455 B | 隐私清单（见 §5.3） | **[观察]** |
| `CupertinoFiles-Licenses.txt` | 2,740 B | 第三方许可（与「文件/文件夹图标或 Cupertino 风格 UI」相关，推断） | **[推断]** |
| `OfficePreview-Licenses.txt` | 59,306 B | `OfficePreview.js` 的第三方许可打包 | **[观察]** |
| `PowerPoint/THIRD-PARTY-NOTICES.txt` | 274,348 B | POI/pdfbox/Java 运行时等第三方声明 | **[观察]** |
| `Assets.car` / `AppIcon.icns` | 3.3 MB / 68 KB | 资源目录与图标 | **[观察]** |

**[观察]** 应用**没有** `Frameworks/` 目录（`ls Contents/Frameworks` 为空），即 RevenueCat 等 Swift 依赖已静态链入主二进制。

---

## ③ 内嵌工具能力

### 3.1 FFmpeg：版本与构建配置

**[观察]** 直接从二进制恢复的 `configuration:`（`static/ffmpeg-config.txt`，`static/ffmpeg-version.txt`）：

```
ffmpeg version 8.0.3
libavutil      60.  8.103
libavcodec     62. 11.103
libavformat    62.  3.103
--arch=arm64 --target-os=darwin
--disable-shared --enable-static --disable-autodetect --disable-doc --disable-debug
--disable-network --disable-ffplay --disable-ffprobe
--disable-encoder=libwebp_anim
--enable-audiotoolbox --enable-videotoolbox --enable-zlib
--enable-libmp3lame --enable-libwebp
```

**[观察]** 关键能力矩阵（来自**运行**该二进制得到的 `-encoders/-decoders/-muxers/-filters`，见 `static/ffmpeg-*.txt`）：

- 编码器（Encoders 表 196 行，含表头）：`h264_videotoolbox`、`hevc_videotoolbox`、`prores_ks`、`aac`、`aac_at`、`libmp3lame`、`libwebp`、`alac`、`flac`、`pcm_s16le`、`gif`、`png`、`mjpeg`
- **无** `libx264` / `libx265` / `libvpx-vp9` / `libsvtav1` / `libaom-av1` 编码器 → H.264/HEVC 走 **VideoToolbox 硬件编码**
- 解码器 525 条，含 `h264`、`hevc`、`vp9`、`av1`、`vc1`
- 复用器（Formats 表 180 条）含 `mp4`、`mov`、`matroska`、`webm`、`mp3`、`wav`、`flac`、`ipod`(m4a)、`aiff`、`ogg`、`adts`、`image2`、`gif`、`apng`、`avif`、`caf`
- 滤镜 444 条，含 `loudnorm`、`atempo`、`silenceremove`、`dynaudnorm`、`speechnorm`、`afftdn`、`ebur128`、`volumedetect`
  - `loudnorm` → `Normalize Volume`；`atempo` → `Change Video Speed`/变速；`silenceremove` → `Trim silent ends automatically`；`pan`/`aresample` → `Convert Audio Channels`；`volumedetect` → 归一化增益测量

**[观察] 进程无法直接执行的根因已定位**：

- `codesign -d --entitlements` 显示 `Tools/ffmpeg` 仅带 `com.apple.security.app-sandbox` + `com.apple.security.inherit`
- 在非沙盒 shell 直接运行会 **SIGTRAP**（`rc=133`，stdout/stderr 均为 0 字节，`bash: Trace/BPT trap: 5`）——这是 `inherit` 型沙盒助手的预期行为，不是二进制损坏
- 验证方法（**不改 App**）：`cp Tools/ffmpeg /tmp/x && codesign --force --sign - /tmp/x && /tmp/x -hide_banner -version` → 正常输出（`static/ffmpeg-version.txt`，rc=0）。**这证明该二进制本身可执行，且其调用方必须是沙盒内父进程**

**[推断]** 构建环境泄露：`configuration` 的 `--prefix=/private/tmp/claude-501/-Users-thameem-Dev-LeapStudio-mac-tools-Tangerine/<uuid>/scratchpad//Tangerine-FFmpeg-Build.WmTj3I/prefix` —— 作者用 AI 编码代理（Claude）在 `~/Dev/LeapStudio/mac-tools/Tangerine` 下用脚本 `pkg_config_ffmpeg.zsh` 构建。这条对开源版复现构建很有价值（同样的 flag 组合即可得到等价二进制）。

### 3.2 cwebp

**[观察]** 505 KB arm64，`file` 为 Mach-O 64-bit executable arm64；`strings` 可见完整 CLI 选项集：`-q`、`-lossless`、`-qrange`、`-preset`、`-metadata`、`-resize`、`-crop`、`-sharp_yuv`、`-segments`、`-partition_limit`、`-sns`、`-strong/-nostrong`、`-sharpness`、`-pass`、`-size`、`-psnr`、`-map`、`-exact`、`-noalpha`、`-hint`、`-progress`、`-quiet`、`-version`。

**[未知]** 精确 libwebp 版本号：二进制里只有 `Error! Version mismatch!` / `Library version mismatch!`，未找到形如 `1.5.x` 的版本串（未做 `-version` 运行验证，因为同样受 `inherit` 沙盒限制；本可 ad-hoc 重签验证，本次未做）。

### 3.3 Java 运行时与 Office 转换栈

**[观察]** `PowerPoint/arm64/release` + `PowerPoint/x86_64/release`：

```
JAVA_VERSION="21.0.12.1"
MODULES="java.base java.datatransfer java.xml java.prefs java.desktop java.logging jdk.unsupported"
```

- 双架构 jlink 镜像（arm64 + x86_64），`PowerPoint/arm64/bin/java` 69 KB 启动器
- 依赖 jar（`PowerPoint/lib/`，`find` 全量列于 `static/bundle-inventory.txt`）：
  - Apache POI **5.5.1**：`poi-5.5.1.jar`、`poi-ooxml-5.5.1.jar`、`poi-ooxml-lite-5.5.1.jar`、`poi-scratchpad-5.5.1.jar`
  - PDFBox **3.0.6**：`pdfbox-3.0.6.jar`、`pdfbox-io-3.0.6.jar`、`fontbox-3.0.6.jar`
  - `xmlbeans-5.3.0`、`commons-{codec,collections4,compress,io,lang3,logging,math3}`、`curvesapi-1.08`、`log4j-api-2.24.3`、`SparseBitSet-1.3`、`graphics2d-3.0.5`（`de.rotutor.pdfbox`，PDF 里画 Java2D 的桥）
  - 自研 `tangerine-powerpoint.jar`（32,301 B）
- **[观察]** `tangerine-powerpoint.jar` 内容（`unzip -l`）：
  ```
  TangerinePowerPoint.class                 14,287
  TangerineSpreadsheet.class                45,539
  TangerineSpreadsheet$1 / $Piece / $PositionStripper / $SizeForIndex
  ```
- **[观察]** 从该 jar 的常量池字符串恢复出的行为约束：
  - `The document must contain between 1 and 1,000 slides or pages.`
  - `Password-protected PDFs cannot be converted to PowerPoint.`
  - `The PowerPoint slide count could not be verified.`
  - 大量 `org/apache/pdfbox/pdmodel/*`、`PdfBoxGraphics2D`、`PDFRenderer` 引用 → **用 PDFBox 渲染 PDF 页面并写入 PPTX**（`graphics2d` 把页面画进 slide），反向则用 POI 读 PPTX → PDF
  - `TangerineSpreadsheet` 常量：`MAX_BYTES`、`MAX_SHEETS`、`MAX_ROWS`、`MAX_COLUMNS`、`MAX_CELLS`、`ODS_MIME`，以及 `extension()`、`progress(D)V`、`complete` → 电子表格（XLSX/ODS）→ PDF，带硬上限
- **[推断]** 主二进制的 `Could not create the PDF.`、`The generated PDF could not be verified.`、`Could not preview PDF page` 等文案与这个 Java 子进程的 `progress(D)V`/`complete` 协议对得上：**Swift 侧 spawn `java -jar tangerine-powerpoint.jar`，通过 stdout 读进度**。

### 3.4 ExifTool 与两个自定义 Perl 桥

**[观察]** `ExifTool/lib/Image/ExifTool.pm`：`$VERSION = '13.59'`（2026 年版本线）。

**[观察]** `tangerine_metadata.pl`（438 行）**不是**薄包装，而是有实质补丁的桥：

- `BEGIN { $Image::ExifTool::configFile = ''; }` + 仅本地 `use lib "$FindBin::Bin/lib"` → **完全离线、无用户配置注入**
- 重定义 `Image::ExifTool::MakerNotes::LocateIFD`，对 `Apple iOS\0` 头的 maker-note 局部强制 `Make='Apple'`（绕过用户删掉 EXIF `Make` 后相对偏移解析失败）
- 把 Apple maker-note 的 `0x0015, 0x0017, 0x002b` 三项 `Permanent` 改为 0 → 允许真正删除这些「永久」描述性字段
- 自定义 XMP 删除：手工 `XML::Parser` 走栈定位属性 → **只删原始字节区间**；显式拒绝 DTD / 外部实体 / 外部资源（XXE 防护）；嵌套属性只按组呈现，不单独写
- 依赖 `Digest::SHA`（sha256）、`File::Temp`（临时目录）→ 有完整性校验与原子替换

**[观察]** `tangerine_privacy.pl`（282 行）：

- 纯字节级容器重写，`privacy_box`/`privacy_boxes` 解析 ISO-BMFF 盒
- `privacy_heic`：删除 `meta` 内的 item 记录**并擦掉 payload**，用空 `free` 盒占位以**保持 `meta` 盒原大小**，从而不改动图像数据偏移；`$preserve_orientation` 时经 `pitm`+`iref(cdsc)` 找出主图元，只保留方向相关项
- 错误文案 `Unsupported HEIC metadata layout/version`、`Unsupported HEIC item tables`、`Image container is too large to clean safely` → **强 fail-closed**
- **[推断]** 这就是 UI 文案 `Remove metadata now and save a new file. Photo cleanup includes private blocks that cannot be removed individually.` 的实现：普通 ExifTool 删不掉的部分（HEIC 私有盒）由这个脚本整块擦除。

### 3.5 JavaScript 文档层

**[观察]** 主二进制链接 `JavaScriptCore`（`otool -L`），并含类名 `JSContext` 相关 Swift 符号（`OfficePreview.js` 的调用环境）。

**[观察]** `OfficePreview.js`：单行 IIFE bundle，`strings` 统计含 `docx`×26、`pages`×17、`DOCX`×2；`PagesWriter.js` 含 `Pages`×25、`pdf`、`pages`，且开头自带 `btoa/atob/TextEncoder` polyfill（说明运行环境是裸 JSContext，没有 `window`/`btoa`）。

**[推断]**
- `OfficePreview.js` = `.docx`/`.pages` 的**预览渲染器**（把文档转成可显示的结构），配合 `OfficePreview-Licenses.txt`（59 KB）说明它打包了第三方解析库（mammoth/jszip 一类）
- `PagesWriter.js` = **生成原生 Pages 文档**：以 `PagesTemplate.pages` 为模板，按 iWork `.iwa` 结构写入，所以需要完整的 zip + protobuf 能力
- **[推断]** 二者与 `Document to PDF failed: Could not prepare offline document rendering.` / `EPUB rendering must run as a background conversion.` 共同构成「离线文档渲染」子系统：**App 不联网、不用 LibreOffice/Word，靠 JS 渲染 + PDFKit 打印 + Java/POI 兜底**

---

## ④ 主二进制功能字符串分类

原始导出：`static/main-binary.strings.txt`（38,293 行，`strings -a -n 4`）；英文文案子集：`static/messages.txt`（1,980 条去重句子）、`static/ui-messages.txt`。

### 4.1 转换/编辑工具（用户可见）

- **图片**：`Annotate Photo`、`Crop`、`Collage`（`CollageOptions`/`CollageBackground`/`CollageStyle`）、`Add BG`（换背景）、`Compress`（`Compression Settings`/`Compression preset`/`Compression mode`/`CompressionTargetMode`）、`Remove metadata`、`Redact`、`Read QR codes`
- **视频**：`Trim`、`Split`（多点分割，≥0.05 s）、合并（`join the rest into one video`）、`Change Video Speed`、抽帧（`Add a frame to save.`/`Remove frame at `）、`Redact`（时间区间涂黑）、按目标码率裁剪（`Could not read the video bitrate for cropping.`）
- **音频**：`Normalize Volume`、`Bleep Entire Audio`（+ 区间 `BleepTrack`）、`Convert Audio Channels`、`Trim silent ends automatically`
- **文档**：`to PDF`（DOCX/EPUB/Pages/TXT…）、`PDF → PowerPoint`（证据见 3.3）、PDF 合并/拆分/重组、压缩 PDF 到目标大小、PDF 扫描页 OCR（`Text recognition could not read a scanned PDF page:`）
- **归档**：解压/压缩（`Extracting archive`、`RAR`、`gzip`）
- **Float（菜单栏文件架）**：`Create a New Float`、`Add Files to an Existing Float`、`Collapse Float, `、`Close Float without deleting files`、`FloatWheelBehavior`、`FormatDropTarget`

### 4.2 压缩到精确大小（这是 Tangerine 的差异化能力）

**[观察]** 字符串链完整存在：
- `Enter a target size between 1 KB and 1 TB.` / `Enter a target size of at least 1 KB.`
- `Could not reach the target size. Smallest attempt was ` → **迭代逼近目标体积**（不是固定 CRF）
- `Compressed output would exceed the original or target file size.`
- `ImageCompressionOptions` / `VideoCompressionOptions` / `FrameImageOptions`

**[推断]** 实现为「多轮试压 + 体积反馈」循环：`Compress` 的 `CompressionTargetMode` 选项含目标体积模式，图片用 `cwebp -size`/`-q` 迭代，视频用 `-b:v` 或 CRF 二分，音频用码率搜索。开源版复现必须做这个循环，否则达不到「功能匹配」。

### 4.3 关键限制常量（来自报错文案，可直接当校验规则）

| 约束 | 字符串 |
|---|---|
| 视频分割点间隔 | `Split points must be at least 0.05 seconds apart.`；距端点 `at least 0.05 seconds from either end` |
| 目标体积范围 | `1 KB` ～ `1 TB` |
| PPTX 页数 | `between 1 and 1,000 slides or pages` |
| Word 页高 | `exceeds Word's 22-inch page limit` |
| 标注 | `Add at least one annotation.` |
| 哔声 | `Add at least one bleep range.` |
| 涂黑 | `Redact one still photo at a time.`（视频涂黑只能按帧/页导出） |
| 文档插图 | `Document artwork exceeds the conversion limit.` |
| 表格（XLSX/ODS） | `MAX_SHEETS`/`MAX_ROWS`/`MAX_COLUMNS`/`MAX_CELLS`/`MAX_BYTES` |

### 4.4 支持的格式（静态出现证据）

- **文档**（最扎实）：`PDF`×47、`EPUB`×46、`DOCX`×13、`RTF`×7、`RTFD`×3、`HTML`、`XHTML`、`TXT`、`MD`(SDMarkdownNode)、`CSV`、`XLSX`/`ODS`（jar：`ODS_MIME`）、`PPTX`/`ODP`（jar）、`PAGES`（PagesWriter）
- **图片**：`PNG`×5、`JPEG`×3、`TIFF`、`BMP`、`WEBP`×5、`HEIC`×5、`AVIF`×2、`GIF`、`ICO`、`SVG`（`WEBP/HEIC/AVIF` 为小写 token 形式，如 `webp`/`heic`/`avif`）
- **视频**：字符串里显式的是 `webm`×2，其余由 ffmpeg 的 muxer 表覆盖（mp4/mov/m4v/mkv/avi/gif/apng…），`Split`/`Trim` 的 AVFoundation 路径另有 `AVFileType` 枚举（未在 strings 单独出现）
- **音频**：`flac`×4、`opus`×3、`aiff`×2、`mp3`（经 `libmp3lame`）、`wav`、`m4a`(ipod)、`alac`、`aac`、`caf`
- **归档**：`zip`、`rar`、`tar`、`gzip`（含 `Could not create the RAR archive.`，说明 RAR 压缩是自研/受限实现）
- **[未知]** `SRT`/`VTT` 字幕：字符串里未直接命中 `SRT`/`VTT` 字面量；用户提供的 App Store 描述列了字幕，需 App Store 文案对照确认（见 §6）

### 4.5 界面骨架（从类型名可复原大致结构）

`MenuBarController`、`PaywallPanel`/`PaywallWindowController`/`PaywallModel`、`UnlockStore`/`UnlockStatusView`、`OperationProgressWindowController`（`Tangerine is working`/`Finished with errors`）、`FileToolOptionsPanel`/`FileToolOptionsWindowController`（工具选项弹窗，支持 `Shift=格式轮盘`、`Option+Shift=工具轮盘` 的键位语义：字符串含 `Shift`、`Option`、`Option` 枚举名）、`EditorThumbnail`、`CropEditor`/`CropThumbnailStrip`、`TrimEndpointHandle`/`TrimHandleShape`、`CollageEditorView`、`RedactionCanvas`/`RedactionTrack`、`BleepTrack`、`MetadataEditorView`、`QRCodeResultsWindowController`、`FloatingFile*` 系列、`ConversionOptions`/`ConversionOptionKind`/`ConversionOptionsFields`。

---

## ⑤ 许可与隐私

### 5.1 第三方许可

| 组件 | 许可文件 | 判断 |
|---|---|---|
| FFmpeg | `Tools/licenses/ffmpeg/COPYING.LGPLv2.1` + `COPYING.LGPLv3` | **[观察]** LGPL 分发；未附 GPL → 未启用 GPL 组件（与 3.1 无 libx264/x265 一致） |
| LAME | `Tools/licenses/lame/COPYING` | **[观察]** LGPL |
| libwebp | `Tools/licenses/libwebp/COPYING` | **[观察]** BSD |
| ExifTool | `ExifTool/Artistic.txt` | **[观察]** Artistic License（Perl） |
| OfficePreview.js | `OfficePreview-Licenses.txt`（59 KB） | **[观察]** 打包的 JS 依赖许可 |
| PowerPoint 栈 | `PowerPoint/THIRD-PARTY-NOTICES.txt`（274 KB） | **[观察]** Java 运行时/POI/PDFBox 等 |
| 其它 | `CupertinoFiles-Licenses.txt` | **[推断]** 图标/文件类型资源许可 |

**[观察]** App 本身是 Mac App Store 分发，受 Apple 标准 EULA（`https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`）。

### 5.2 隐私清单 `PrivacyInfo.xcprivacy`

**[观察]** 原文见 `static/bundle-inventory.txt` 上方导出。要点：
- `NSPrivacyTracking = false`，`NSPrivacyTrackingDomains = []`
- 收集：仅 `NSPrivacyCollectedDataTypePurchaseHistory`（`Linked=false`、`Tracking=false`、用途 `AppFunctionality`）
- 访问的 Required-Reason API：`UserDefaults`（`CA92.1`）、`SystemBootTime`（`35F9.1`）、`FileTimestamp`（`3B52.1`, `C617.1`）
- 没有相册/通讯录/位置/麦克风等敏感数据类别

**[推断]** 结合 `com.apple.security.network.client` + RevenueCat：**唯一联网行为是 IAP 校验**（RevenueCat 后端）；文件转换全程离线。

### 5.3 隐私/安全设计（对开源版有借鉴价值）

- 沙盒 + 用户选择文件 read-write + security-scoped bookmarks（`com.apple.security.files.bookmarks.app-scope`）
- 子进程 `ffmpeg` 用 `inherit` 沙盒继承（见 3.1）
- ExifTool 桥 fail-closed（`$Image::ExifTool::configFile=''`、拒绝 DTD/外部实体，见 3.4）
- HEIC 隐私擦除直接改 box（不依赖库），且保持数据偏移（见 3.4）

---

## ⑥ 观察 / 推断 / 未知 三分表

### 6.1 观察（可直接复核）

1. Bundle 结构与全部 16 个资源条目、所有 jar 版本号 → `static/bundle-inventory.txt`
2. 主二进制 11,200,496 B arm64，链接 JavaScriptCore/PDFKit/AVFoundation 等 → `otool -L`
3. FFmpeg **8.0.3**（libavutil 60.8.103 / libavcodec 62.11.103 / libavformat 62.3.103），构建 flag 全文 → `static/ffmpeg-version.txt`、`static/ffmpeg-config.txt`
4. FFmpeg 编码器表无 libx264/x265/vpx/svt-av1；有 `h264_videotoolbox`/`hevc_videotoolbox`/`libmp3lame`/`libwebp`/`aac(_at)`/`prores_ks`/`alac`/`flac` → `static/ffmpeg-encoders.txt`
5. FFmpeg 解码 525 条、muxer 180 条、filter 444 条 → `static/ffmpeg-{decoders,muxers,filters}.txt`
6. FFmpeg 直跑 SIGTRAP（rc=133）因其只有 `app-sandbox+inherit` 权限；副本 ad-hoc 重签后 `-version` 正常 → 见 3.1 复现步骤
7. ExifTool 13.59；两个自定义 Perl 桥的 438/282 行原文与 fail-closed 逻辑 → `Contents/Resources/ExifTool/*.pl`
8. Java 21.0.12.1 jlink（双架构），POI 5.5.1 / pdfbox 3.0.6 / xmlbeans 5.3.0 等 jar 清单 → `unzip -l` + `find`
9. `tangerine-powerpoint.jar` 类结构与行为约束字符串（1–1000 页、禁用密码保护 PDF）→ `unzip -l` + `strings`
10. 付费墙文案与一次性买断模型、RevenueCat 集成、两个外链 → 主二进制 34819–34964 段
11. 免费次数计量存在（`free uses left.`），但数值非字面量
12. 各工具名与限制常量（0.05 s、1 KB–1 TB、22 英寸等）→ §4.3
13. 隐私清单、许可文件、Info.plist 全字段 → §2/§5

### 6.2 推断（证据合并，需运行时/行为验证）

1. `OfficePreview.js`/`PagesWriter.js` 由 `JavaScriptCore` 执行，承担 `.docx/.pages` 预览与 `.pages` 写入（链接框架 + 文件内容 + 报错文案）
2. `PagesTemplate.pages` 是 `PagesWriter.js` 的写模板（iWork `.iwa` 包结构）
3. Java 子进程通过 stdout 的 `progress(D)V`/`complete` 协议向 Swift 汇报进度
4. 精确体积压缩 = 多轮试压迭代（`Could not reach the target size. Smallest attempt was`）
5. HEIC/JPEG 隐私清理走 `tangerine_privacy.pl` 的盒级重写，而普通元数据编辑走 `tangerine_metadata.pl`
6. 菜单栏轮盘交互：`Shift`=格式轮盘、`Option+Shift`=工具轮盘（来自键位枚举 + `FormatDropTarget` + `FloatWheelBehavior`）
7. 文档→PDF 的通用路径是「离线 JS 渲染 → PDFKit 打印」，EPUB 另有独立 `EPUBPDFRenderer`

### 6.3 未知（静态不可判定，需动态验证或 App Store/PRD 交叉核对）

1. **免费额度精确数值**（用户说的 20 文件）：文案是插值，二进制无数字
2. **275 conversions / 26 tools / 6 file actions** 的精确构成：无字面量；功能名可枚举，但「组合数」需要输入输出矩阵
3. **完整输入→输出格式对**：主二进制里格式 token 零散（文档类齐全，视频/音频类多藏在 `AVFileType`/UTType 常量与 ffmpeg 调用里），未发现显式格式矩阵表
4. `SRT`/`VTT` 字幕支持：App Store 描述有，静态未命中字面量
5. `PDF → PowerPoint` 是否真实为独立工具（只有错误文案侧证）
6. cwebp 精确版本号
7. 菜单栏轮盘的完整交互细节与动画（`HighlightSound` 的触发条件）
8. OCR 引擎（`Vision` 框架未出现在 `otool -L`；`VNImageOption` 字符串存在 → 可能动态加载，需运行时确认）
9. 微信/其他登录、推送、更新机制：未发现 Sparkle 类库或推送 entitlement，**[推断]无自更新**

---

## ⑦ 对「100% 功能匹配」有影响的缺口提示

1. **构建等价 FFmpeg 是硬门槛**
   - 必须复现：`ffmpeg 8.0.3` + `--disable-autodetect --disable-network --disable-ffprobe --disable-ffplay --disable-encoder=libwebp_anim --enable-audiotoolbox --enable-videotoolbox --enable-zlib --enable-libmp3lame --enable-libwebp`
   - 若开源版换成带 x264 的构建：体积、许可（GPL）、编码结果都会与原版不同；**不要**为了「更全」而加 GPL 组件，否则许可不匹配（原版明确 LGPL）
   - 注意 `--disable-ffprobe`：原版**没有 ffprobe**，元数据/时长/码率是解析 `ffmpeg` stderr（字符串里有 `video:([0-9.]+)KiB` 这类正则），开源版若用 ffprobe 属于行为差异但可接受
2. **Office 互转栈是最重的一块（91 MB）**：Java 21 + POI 5.5.1 + PDFBox 3.0.6 + 自研 jar。开源替代可选纯 Swift PDFKit，但 PPTX→PDF 渲染保真度极难对齐；至少要复刻「1–1000 页限制」「密码保护 PDF 拒绝」「XLSX/ODS 上限」这些约束与错误文案
3. **元数据子系统必须复刻两层**：ExifTool 13.59（含 Apple maker-note 相对偏移补丁、XMP 字节区间删除）+ 自研 HEIC box 擦除。只包一个 exiftool 达不到 `Remove metadata ... private blocks` 的行为
4. **精确体积压缩循环**（目标 1 KB–1 TB、迭代逼近、失败时报「smallest attempt」）是差异化功能，不能退化为固定质量压缩
5. **`Float` 菜单栏文件架 + 轮盘交互**是形态核心（`LSUIElement` 无 Dock），开源版若做成普通窗口 App 就不是「功能匹配」
6. **付费墙**：一次性购买 + 免费次数计量（含 `Restore Purchase` 分支、RevenueCat 文案）。开源版不接 IAP 时需保留「解锁态」与「免费次数」语义位，否则交互流缺分支
7. **文档渲染**：`OfficePreview.js`+`PagesWriter.js`+`PagesTemplate.pages` 是「不装 Office/LibreOffice 也能预览与导出」的关键；开源复刻建议直接复用等价开源库（mammoth/jszip/protobuf）并保留离线、无网、无外部实体
8. **许可合规**：原版为 LGPL/BSD/Artistic 组合，若社区基础 Open-Tangerine 是 GPLv3，**「开源版」的许可本身与原版不同**，需在 README 明示差异；复刻的工具链（ffmpeg 构建 flag）不构成许可继承，但分发 ffmpeg 需附 LGPL 文本
9. **未知项建议动态补齐**：免费额度数字、输入输出格式对、字幕支持、二维码结果窗口细节最值得用一次运行时抓取（`log stream`/`fs_usage`/对 `ffmpeg` 子进程参数做 dtruss 或直接 hook `spawn`）确认——但这些属于⑧以外的后续工作

---

## 附录 A：原始证据文件（`tangerine-oss/parity/static/`）

| 文件 | 内容 |
|---|---|
| `bundle-inventory.txt` | 全部 bundle 条目 + `find`/`ls -l` 输出、`PrivacyInfo.xcprivacy` 全文 |
| `Info.plist.xml` | Info.plist 原文（xml1） |
| `entitlements.plist` | 主 App entitlements |
| `codesign-app.txt` | 主 App 签名详情 |
| `main-binary.strings.txt` | 主二进制 `strings -a -n 4`（38,293 行） |
| `messages.txt` | 主二进制英文句子去重集合（1,980 条） |
| `ui-messages.txt` | 主二进制 33,000–35,200 行区段（UI 文案密集区） |
| `ffmpeg.strings.txt` | ffmpeg 二进制 strings（140,201 行） |
| `ffmpeg-config.txt` | ffmpeg 构建配置行 |
| `ffmpeg-version.txt` | ad-hoc 重签副本的 `-version` 输出（8.0.3 全 banner） |
| `ffmpeg-encoders.txt` / `ffmpeg-decoders.txt` / `ffmpeg-muxers.txt` / `ffmpeg-filters.txt` | 运行副本导出的编码器/解码器/复用器/滤镜表 |

## 附录 B：复现命令（关键几条）

```bash
# 1) 不读全量 json 的定位方式：字符串优先
strings -a -n 4 /Applications/Tangerine.app/Contents/MacOS/Tangerine > main.strings.txt
grep -nE 'Annotate|Bleep|Change Video Speed|Normalize|Compress|Split|Trim' main.strings.txt

# 2) ffmpeg 版本与配置（副本签名，绝不改 App）
cp /Applications/Tangerine.app/Contents/Resources/Tools/ffmpeg /tmp/ffmpeg && chmod +w /tmp/ffmpeg
codesign --force --sign - /tmp/ffmpeg
/tmp/ffmpeg -hide_banner -version
/tmp/ffmpeg -hide_banner -encoders | head -40

# 3) Java/Jar
unzip -l /Applications/Tangerine.app/Contents/Resources/PowerPoint/lib/tangerine-powerpoint.jar
unzip -p  .../tangerine-powerpoint.jar TangerinePowerPoint.class | strings -a | grep -iE 'pdf|slide|pptx'

# 4) ExifTool 版本
grep -n "VERSION = " /Applications/Tangerine.app/Contents/Resources/ExifTool/lib/Image/ExifTool.pm
```
