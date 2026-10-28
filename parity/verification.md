# 验证记录：Tangerine 100% 功能对照版

日期：2026-10-28
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
osascript -e 'tell application "System Events" to tell process "Open Tangerine" to return (count of windows)'
osascript -e 'tell application "Open Tangerine" to quit'
```

结果：进程存活、菜单栏 App 正常注册、退出后无残留。`LSUIElement=true`，无 Dock 图标。

## 3. 测试套件

```bash
./scripts/test.sh
```

结果：**exit 0**，8 个套件全部通过：

| 套件 | 结果 |
|---|---|
| SatsumaTests | 20/20 passed（断言更新为 275 条路由 / 29 工具 / 新矩阵） |
| IntegrationTests | passed |
| InteractionTests | passed |
| ImageConversionTests | 45 passed |
| DocumentTests | passed（含新增 8 组对照用例，见 §4） |
| BatchTests | passed |
| ImageToolsTests | passed |
| MediaIntegrationTests | 55 passed, 0 failed |

## 4. 新增对照用例（DocumentTests）

| 用例 | 断言 |
|---|---|
| MD → DOCX / PDF / EPUB | 输出存在且可被对应引擎重新读取 |
| MD → DOCX → TXT 往返 | 文本内容保留 |
| CSV → XLSX → CSV / TSV | 单元格值保留（`alpha`/`beta`）、TSV 用制表符 |
| XLSX → ODS → CSV | ODS 读写闭环 |
| MD → EPUB → PDF / TXT | EPUB 可重新解析、PDF 页数 > 0 |
| PDF → MD | 提取文本包含原文标记 |
| ZIP → TAR + 解压 | 归档转换与 `ArchiveEngine.extract` 均可用 |
| 新工具可用性 | PNG 出现 annotate/QR；MP4 出现 mute；ZIP 出现 extract |

## 5. 规模计数（与官方对齐）

```swift
print(ConversionMatrix.totalConversions)  // 275
print(FileFormat.allCases.count)          // 46（Tangerine 站点矩阵全部格式 + 视频/音频族）
print(ToolID.total)                       // 29 = 官方 26 + 读 QR + Resize + Rotate
print(FileAction.allCases.count)          // 9 = 官方 6 + Reveal/Duplicate/SHA-256
```

对照：官方宣称 275 conversions / 26 tools / 6 file actions；站点模拟数据反推同样是 275 条
（`parity/spec/conversions.json`）。转换矩阵逐对一致（§3.1）。

## 6. 已知未验证项

- 真实鼠标拖拽路径（⇧/⌘/⌃ 轮盘出现→松手转换）未做端到端自动化：Tangerine 与开源版都依赖
  系统拖拽事件自带的修饰键 flag，合成事件（CuaDriver/AppleScript）拿不到该 flag。
  运行时观察记录见 `parity/tangerine-runtime-evidence.md` §"转换实测 0/6"。
- Office（DOCX/PPTX/XLSX）为文本/表格级重建，未做版式保真基准。
- `.pages` 输出与 `pdf → pptx` 未实现（见 `parity-matrix.md` §3.3）。

## 7. 对照语料

`/tmp/tangerine-probes/` 与 `~/Desktop/tangerine-probes/`（运行时观察员生成，23 个文件：
图片/音视频/PDF/DOCX/PPTX/XLSX/EPUB/SRT/ZIP/QR），可复用于人工拖拽验证。
