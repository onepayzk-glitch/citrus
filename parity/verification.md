# 验证记录：Tangerine 100% 功能对照版

日期：2026-10-28（第 2 轮收尾）
仓库：`/Users/zhukun/Documents/HARNESS/dsh-mac/tangerine-oss`（Open-Tangerine 基线 + 本次补齐）
产物：`dist/Open Tangerine.app`（arm64，ad-hoc 签名，未公证）

## 1. 构建

```bash
cd tangerine-oss
./scripts/build-app.sh
```

结果：**exit 0**

```
dist/Open Tangerine.app: valid on disk
dist/Open Tangerine.app: satisfies its Designated Requirement
dist/Open Tangerine.app/Contents/Info.plist: OK
Built /Users/zhukun/Documents/HARNESS/dsh-mac/tangerine-oss/dist/Open Tangerine.app (arm64, macOS 15.0+)
```

修复的构建问题：工作区位于文件提供程序同步路径，系统会在 bundle 上重新附加
`com.apple.FinderInfo`，导致 `codesign` 报 `resource fork, Finder information, or similar detritus not allowed`。
`scripts/build-app.sh` 现在在签名前 `xattr -cr` 并重试（最多 4 次），可幂等构建。

## 2. 启动

```bash
open "dist/Open Tangerine.app"
sleep 4
pgrep -fl OpenTangerine          # → .../dist/Open Tangerine.app/Contents/MacOS/OpenTangerine
osascript -e 'tell application "Open Tangerine" to quit'
```

结果：进程存活、菜单栏 App 正常注册、退出后无残留。`LSUIElement=true`，无 Dock 图标。

## 3. 测试套件

```bash
./scripts/test.sh
```

结果：**exit 0**，9 个套件全部通过：

| 套件 | 结果 |
|---|---|
| SatsumaTests | 20/20 passed（断言为 275 条路由 / 29 工具 / 新矩阵） |
| IntegrationTests | passed |
| InteractionTests | passed |
| ImageConversionTests | 45 passed |
| DocumentTests | passed（含 9 组对照用例，见 §4） |
| BatchTests | passed |
| ImageToolsTests | passed |
| MediaIntegrationTests | 55 passed, 0 failed |
| OfficeEngineTests | LibreOffice 26.8.1.1 检测成功；DOCX→PDF/PNG、XLSX→PDF、PPTX→PDF 全部 PASS |

## 4. 转换对照用例（DocumentTests）

| 用例 | 断言 |
|---|---|
| MD → DOCX / PDF / EPUB | 输出存在且可被对应引擎重新读取 |
| MD → DOCX → TXT 往返 | 文本内容保留 |
| CSV → XLSX → CSV / TSV | 单元格值保留（`alpha`/`beta`） |
| XLSX → ODS → CSV | ODS 读写闭环 |
| MD → EPUB → PDF / TXT | EPUB 可重新解析、PDF 页数 > 0 |
| PDF → MD | 提取文本包含原文标记 |
| **PDF → PPTX** | 包内含 `ppt/slides/slide1.xml` 与 `ppt/media/page1.png`，`<p:sldIdLst>` 存在 |
| ZIP → TAR + 解压 | 归档转换与 `ArchiveEngine.extract` 均可用 |
| 新工具可用性 | PNG 出现 annotate/QR；MP4 出现 mute；ZIP 出现 extract |

## 5. 生成文件的外部解析验证

测试会把产物复制到 `/tmp/OpenTangerine-*check*`，用与实现无关的第三方解析器校验：

| 文件 | 校验工具 | 结果 |
|---|---|---|
| `/tmp/OpenTangerine-pptx-check.pptx` | `python-pptx` 1.0.2 | `slides: 1, size: 12192000×6858000`，1 张图片（5299363×6858000） |
| `/tmp/OpenTangerine-docx-check.docx` | `python-docx` 1.2.0 | 段落：`['# Title', '', 'Body paragraph & <tag>.']` |
| `/tmp/OpenTangerine-xlsx-check.xlsx` | `openpyxl` 3.1.5 | 行：`[['name','value'],['alpha','1'],['beta','2']]` |
| `/tmp/OpenTangerine-ods-check.ods` | `zipfile` | 含 `mimetype`/`META-INF/manifest.xml`/`content.xml`，mimetype 正确 |

> 备注：`qlmanage` 缩略图校验在本机测试进程里会挂起（QuickLook 服务阻塞），已从测试中移除，改用上述解析器验证。

## 6. 规模计数（与官方对齐）

```swift
ConversionMatrix.totalConversions  // 275
FileFormat.allCases.count          // 46
ToolID.total                       // 29 = 官方 26 + QR + Resize + Rotate
FileAction.allCases.count          // 9 = 官方 6 + Reveal/Duplicate/SHA-256
```

- 275 条路由与官方站点兼容性矩阵逐对一致（`parity/spec/conversions.json`）。
- 267 条不依赖外部应用；8 条 `→PAGES` 使用本机 Pages.app（首次需 Automation 授权；官方内置 iWork 引擎）。
- 官方宣称 275 conversions / 26 tools / 6 file actions；开源版为 275 / 26+QR+2 / 6+3。

## 7. 本轮新增的功能与设置项

| 项 | 实现 |
|---|---|
| PDF→PPTX | `Engines/PptxWriter.swift`（纯 OOXML，一页一张图片幻灯片） |
| 8 条 →PAGES | `Engines/PagesExporter.swift`（Pages 自动化；PDF 先渲染成图片 DOCX） |
| 拖拽修饰键重映射 | Settings → General 三个下拉框；DragMonitor 按设置分派 ⇧/⌘/⌃/⌥ |
| Terminal 应用选择 | Terminal / iTerm2 / 系统默认 |
| Preserve metadata | 图片转换保留/剥离原始元数据（`ImageEngine`） |
| Compatibility 矩阵页 | Settings 新 tab，逐源格式列出目标与总数（275） |
| 轮盘键盘操作 | Esc 取消 / Enter 确认 / 方向键切换（既已实现，本轮纳入对照） |
| Office 引擎（L2） | `Engines/OfficeEngine.swift`：自动检测本机 LibreOffice，DOCX/PPTX/XLSX/ODS/RTF/HTML/CSV/TSV → PDF/PNG/JPG；不捆绑、不下载；未检测到时回退文本引擎 |
| 共享 LibreOffice profile | `~/Library/Application Support/OpenTangerine/LibreOfficeProfile`，串行化进程；失败自动换新 profile 重试 |
| 设置入口 | Settings → Formats → 「Office engine (optional)」：路径、选择按钮、健康状态（版本/路径/未安装提示） |

### Office 引擎实测

- 检测：`LibreOffice 26.8.1.1 … /Applications/LibreOffice.app/Contents/MacOS/soffice`
- 新增套件 `OfficeEngineTests`：DOCX→PDF、DOCX→PNG、XLSX→PDF、PPTX→PDF 全部 PASS
- 性能：单次转换约 0.6–0.8 秒（进程启动+转换）；冷/暖 profile 差异主要来自 LO 进程启动
- 实测数据：brew 安装 805MB；裁剪 help/extensions/gallery/template/wizards/basic/java/Python + 图标主题后 484MB，转换仍正常（仅作评估记录，本方案不捆绑）

## 7.5 首启引导与反馈（本轮）

- `App/OnboardingView.swift`：6 步引导（欢迎 / ⇧ 转换 / ⌘ 工具 / ⌃ 动作 / 隐私 / 完成设置），
  完成页含「Start automatically at login」「Sound and haptic feedback」开关。
- 验证方式：重置 `hasCompletedWelcome` 后启动 App，用 System Events 逐页点击并按截图核对；
  6 页全部渲染正常，Finish 后 `hasCompletedWelcome=1`、`hasOpenedSettings=1` 且窗口关闭。
- 菜单新增「Getting Started…」可随时重开引导。
- 反馈：`UI/Feedback.swift`（成功音 + 触感，可在设置关闭）；`Float Behaviour`
  支持「新建 Float / 加入当前 Float」。

## 8. 已知未验证项

- 真实鼠标拖拽路径（⇧/⌘/⌃ 轮盘出现→松手转换）未做端到端自动化：Tangerine 与开源版都依赖
  系统拖拽事件自带的修饰键 flag，合成事件拿不到该 flag。运行时观察记录见
  `parity/tangerine-runtime-evidence.md` §"转换实测 0/6"。
- PAGES 输出未在本轮实测：首次调用会触发 macOS Automation 授权弹窗，自动化环境无法点击；
  逻辑已实现，失败时会返回明确的授权提示。
- Office（DOCX/PPTX/XLSX）为文本/表格级重建，未做版式保真基准。
- `qlmanage` 缩略图在本机测试进程里阻塞，PPTX 走 `python-pptx` 校验替代。

## 9. 对照语料

`/tmp/tangerine-probes/` 与 `~/Desktop/tangerine-probes/`（运行时观察员生成，23 个文件：
图片/音视频/PDF/DOCX/PPTX/XLSX/EPUB/SRT/ZIP/QR），可复用于人工拖拽验证。
