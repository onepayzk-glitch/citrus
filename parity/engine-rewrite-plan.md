# 从零重写 PPTX / Pages 排版引擎：方案、分工、消耗（评估稿）

日期：2026-10-29
前提：不复制 Tangerine 的私有实现（`tangerine-powerpoint.jar`、`OfficePreview.js`、`PagesWriter.js`、`PagesTemplate.pages`、品牌资产、付费墙）。以下“从零”均指**渲染/写入引擎自研**，允许用开源库做解析与容器（POI、Snappy、protobuf、CoreText/CoreGraphics）。

## 0. 边界先说清

| 层 | 可否复用 | 说明 |
|---|---|---|
| OOXML 解析（PPTX/XLSX/DOCX） | ✅ 可用 Apache POI（Apache-2.0） | Tangerine 也是 POI 之上自研渲染层；POI 只给文档模型，不给排版/栅格化 |
| Zip / Snappy / protobuf | ✅ 开源实现可用 | iWork IWA 是“分块封装 + Snappy + protobuf”，开源参考：numbers-parser/keynote-parser(codec)、Go iwork、Rust iwork |
| 布局/排版/几何/图表渲染 | ❌ 必须自研 | 这是 Tangerine 私有 jar + JS 的核心，不能抄 |
| 验证 oracle | ✅ 本机 Keynote 14.5 / Pages 14.5 | 用官方 App 导出 PDF 作为参照，需一次 Automation 授权 |

事实证据：`/Applications/Tangerine.app/Contents/Resources/PowerPoint/` 90MB（arm64 JRE + POI 5.5.1 + PDFBox 3.0.6 + 自研 jar）；`PagesTemplate.pages` 是 zip + `Index/*.iwa`（Document.iwa 8,617B，头部 `00 a5 21 00 c2 6e 68 56`，无 `sNaPpY` 流标识，属 iWork 自有分块封装）；Pages/Keynote 均为 14.5。

## 1. PPTX 渲染引擎（PPTX/PPT → PDF/PNG/JPG）

### 1.1 目标

- 输入：`.pptx`（OOXML 包；`.ppt` 二进制先按 POI HSLF 解析）
- 输出：PDF（矢量）+ PNG/JPG（150/300 DPI）；1–1000 页上限；加密文件明确拒绝
- 覆盖：文本框/段落/项目符号、图片（裁剪/缩放）、形状（preset geometry）、表格、主题色/字体、母版占位符继承、渐变/描边/阴影、组合形状、旋转、自动缩放；图表与 SmartArt 放 v2（先降级为文本/占位）

### 1.2 模块与工作量（人日，单人）

| 模块 | 内容 | v1 | v2 |
|---|---|---|---|
| 读取层 | POI XSLF/HSLF → 中间模型（形状树、文本段、样式、图片、表格、主题） | 5–8 | — |
| 布局层 | 坐标/EMU、组变换、旋转/翻转、占位符继承、母版/版式链、层叠顺序 | 10–15 | — |
| 文本排版 | CoreText：行盒、换行、对齐、行距、段前段后、项目符号、编号、autofit、CJK 换行/标点、竖排、字体回退与度量近似 | 15–20 | — |
| 形状与几何 | 187 个 presetGeom 生成器、custom geometry、solid/gradient/pattern/picture fill、线型/箭头/join/cap、阴影 | 15–20 | — |
| 表格 | 合并单元格、行高/列宽、边框、单元格内文本布局 | 8–12 | — |
| 图表 | Chart XML（bar/line/pie/area/scatter/radar…）→ CoreGraphics，图例/坐标轴/数据标签 | — | 15–25 |
| SmartArt/3D/媒体 | SmartArt 降级（文本+占位框）、3D 效果忽略并标注、媒体 poster 取首帧 | — | 5–10 |
| 导出 | CGPDF 页面、PNG/JPG DPI、分页边界 | 3–5 | — |
| 语料与金标 | python-pptx 生成 20–40 份 deck + 公开样本；Keynote 导出 PDF 作 oracle；文本 diff + SSIM | 10–15 | 5 |
| **合计** | | **66–95** | **+20–40** |

里程碑：

- **M0（3–5 人日）**：3 份 deck → PDF；文本框/图片/纯色形状正确，字体回退表雏形
- **M1（+10–15 人日）**：20 份常见 deck ≥80% 页面 SSIM>0.85；文本提取无缺段；表格与主题色可用
- **M2（+15–20 人日）**：母版占位符/项目符号/渐变/旋转/组/autofit 完整
- **M3（+20–30 人日）**：图表 v1、SmartArt 降级、媒体 poster

### 1.3 保真度上限（必须先接受）

- 字体是最大变量：PPTX 常用 Calibri/Arial/思源，Mac 缺字体只能度量近似；CJK 差异更明显。
- 图表/SmartArt/3D/动画：静态导出可降级，但**像素级 100% 不现实**；LibreOffice/PowerPoint 自身也做不到跨平台 100%。
- 现实目标：**常见商务 deck 90–95% 可看**（M2–M3），特殊版式列为 documented limitation。

## 2. Pages 写入引擎（docx/md/txt/rtf/html/epub/pdf → .pages）

### 2.1 事实与路线

`.pages` = zip 包：`Index/Document.iwa` 等；IWA 是分块 + Snappy + protobuf（无公开 schema）。三条路线：

| 路线 | 做法 | 工作量 | 风险 |
|---|---|---|---|
| A：自研 IWA writer | 用 Pages 生成最小样张 → 解码反推字段 → 写文本/样式/图片页 → Pages 打开验证 | 45–80 人日 | 高（无文档、版本敏感） |
| B：旧版 Pages'09 XML（APXL） | 写 XML 让 Pages 14.5 导入 | 10–20 人日 + 1–2 天 spike 验证兼容 | 中（Pages 可能已不支持） |
| C：Pages 自动化（现状） | AppleScript 让 Pages 另存 | 已完成 | 低（需 Automation 授权、依赖 App） |

### 2.2 自研路线 A 的模块与工作量

| 模块 | 内容 | 人日 |
|---|---|---|
| IWA 容器编解码 | Snappy block 解压/压缩 + protobuf wire 类型读写（Swift 实现） | 5–10 |
| 字段反推 | Pages 14.5 生成样张集（空文档/一段文本/图片/多页），逐字段 diff 建立字段表 | 15–25 |
| 文档写入 | 最小文档骨架、文本存储、段落样式、页面尺寸/分页、图片页（PDF→Pages 用页面图） | 15–25 |
| 引擎接入 | TextDocumentEngine → Pages 输出；错误与回退 | 5–10 |
| 验证 | Pages 打开无警告 → 导出 PDF → 与源文本/图片 diff（≥95% 内容一致） | 5–10 |
| **合计** | | **45–80 人日（9–16 人周）** |

风险控制：先做 **3–5 人日 spike**（解出空文档 + 一段文本的字段并写出能被 Pages 打开的文件）再决定是否继续；失败则回退路线 C（现有 `PagesExporter`），不阻塞其余交付。

## 3. 分工计划（Agent Teams + 免费模型）

| 角色 | 职责 | 交付物 | 建议模型/额度 |
|---|---|---|---|
| Lead（主循环） | 架构、评审、集成、构建与验收 | 引擎接入、CI、parity 文档 | deepseek-flash（不受 :free 池限） |
| `pptx-core` | 读取层 + 布局层 + 导出（M0–M1） | `PptxRenderCore.swift`、M0/M1 报告 | :free 池，≤12 步/任务 |
| `pptx-text` | 文本排版 + 字体回退 + 项目符号/autofit | `PptxTextLayout.swift`、字体映射表 | :free 池 |
| `pptx-geom` | preset geometry + 填充/描边/阴影 + 表格 | `PptxGeometry.swift`、`PptxTable.swift` | :free 池 |
| `pages-spike` | IWA 解码 + 最小文档写入（2 周内给出 go/no-go） | `IWAProto.swift`、字段表、样张验证 | :free 池，优先用 nemotron 1M 上下文 |
| `verify` | 语料生成、Keynote oracle、SSIM/文本 diff、回归 | 语料库 + 评分脚本 + 报告 | :free 池 + 本地 2B 做短判定 |

排期（墙钟，按 2 个 agent lane 并行、free 池 50 req/day 约束估算）：

1. 第 1 周：M0（PPTX 3–5 人日）+ Pages spike 启动（并行）
2. 第 2–3 周：M1（PPTX）+ Pages go/no-go 决策
3. 第 4–6 周：M2（PPTX）；若 Pages go：字段反推完成
4. 第 7–10 周：M3（图表/SmartArt 降级）+ Pages 写入器收尾（若 go）
5. 全程：回归语料每日跑；每周一次 Keynote oracle 对比

免费额度策略：`OpenRouter :free` 共享 50 req/day / 20 req/min → 并发 ≤2，单 agent 任务 ≤12 步；长链（语料生成、批量对比）放主循环或本地脚本，不占池。

## 4. 消耗汇总

| 项 | 从零双引擎（自研 PPTX + Pages） | 对比 A 档（内置开源组件 + LibreOffice + Pages 自动化） |
|---|---|---|
| 工程人日 | **110–175 人日**（PPTX 66–95 + Pages 45–80） | 3–8 人日 |
| 墙钟（单 agent lane） | ~10–14 周 | 2–4 天 |
| 代码量（估） | 8k–14k 行 Swift + 测试 | 1k–2k 行 |
| Agent 轮次（估） | 250–400 轮（主循环 + 免费池并行） | 20–40 轮 |
| Token（估） | 5–12M | 0.3–0.8M |
| 磁盘/带宽 | 语料 200–500MB；无需新增运行时 | LibreOffice ~700MB（可选捆绑） |
| 法律风险 | 低（不复制私有资产；格式互操作为目的） | 低 |
| 保真度 | 自研可达“常见 deck 90–95%”；Pages 依赖字段反推成功 | LibreOffice 通常更高；Pages 由 Pages 自身保证 |
| 维护成本 | 高（OOXML 演进、字体/图表需长期补） | 低（跟随上游） |

## 5. 建议

- 若目标是**尽快、合法、保真最高**：选 A 档（内置 FFmpeg/ExifTool/POI + LibreOffice 做 Office，Pages 保留自动化），投入 3–8 人日，把预算留在 UI 细节。
- 若必须**完全自研、不依赖 Apple/LibreOffice**：先投 2–3 周做 PPTX M0–M1 + Pages 3–5 天 spike，用可量化验收（SSIM/文本 diff）决定是否继续到 M2/M3；总预算按 110–175 人日评估。
- 折中（我倾向）：**PPTX 自研 M0–M2 + Pages 保留自动化**（约 25–40 人日），拿到“自研渲染 + 功能面 100%”，Pages 仍保留 Pages.app 依赖并明确文档化。

## 6. 需要拍板的三个问题

1. 解析层是否允许用 POI/Snappy/protobuf（只自研布局与渲染）？——允许可省 20–30 人日。
2. 是否接受 Keynote/Pages 作为验收 oracle（首次需 Automation 授权）？
3. 从零目标到哪一档：PPTX M1 / M2 / M3；Pages 自研 writer 是否必须（还是接受 Pages 自动化）？


## 7. 决策记录（2026-10-29）

用户选择 **L2：不内置 LibreOffice，运行时检测复用**。据此：

- 已在 `NativeApp/Sources/Engines/OfficeEngine.swift` 落地：自动检测（用户路径 → `/Applications` → `~/Applications` → Homebrew → PATH）、健康检查、隔离 profile、超时/取消、失败回退文本引擎；Settings → Formats 提供路径与状态。
- 本机实测（评估用，非交付捆绑）：
  - brew cask LibreOffice 26.8.1 arm64：安装 **805MB**（Frameworks 435MB / Resources 361MB）；
  - 删除 help(61)、extensions(61)、gallery(13)、template(8)、wizards(5.6)、basic(4.6)、java(7.7)、LibreOfficePython.framework(82)、图标主题(40) 后：**484MB**，docx/pptx→PDF 仍正常；
  - 再删 `soffice.cfg`(35MB) 会导致文档加载失败，**不可删**；
  - 参考：DSH 自带的预构建 LibreOffice 引擎（`libreoffice-kit-darwin-arm64`）约 **148MB**，说明“裁剪/最小构建”体积下限约 150MB 量级（其配方在 `sources/scripts/slim-native.mjs`）。
- 未选路线：L1 裁剪内置（484MB）、L3 源码最小构建（150–250MB 但维护成本高）、L4 自研渲染（110–175 人日）。
