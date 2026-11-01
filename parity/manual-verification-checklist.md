# 真人 5 分钟拖拽对照清单

目的：验证「拖拽 → 轮盘 → 结果」整条链路。自动化测不到拖拽事件的修饰键 flag，这一份只能人工过。
预计 5 分钟（快速版）；带 ★ 的是必测项。

日志（可选，排障用）：从终端启动可打开诊断日志：
```bash
OPEN_TANGERINE_DEBUG=1 "/Users/zhukun/Documents/HARNESS/dsh-mac/tangerine-oss/dist/Open Tangerine.app/Contents/MacOS/OpenTangerine"
# 日志：$TMPDIR/OpenTangerine-Diagnostics/debug.log
```

准备：桌面新建一个测试文件夹，放入以下文件（可从 `/tmp/tangerine-probes/` 复制，若已清理可用任意文件）：

| 文件 | 用途 |
|---|---|
| `photo.heic` 或 `photo.png` | 图片转换 / 工具 |
| `clip.mp4`（2 秒即可） | 视频工具 |
| `tone.wav` | 音频工具 |
| `doc.docx` | Office 转换（LibreOffice 路径） |
| `slides.pptx` | 演示文稿转换 |
| `notes.txt` / `page.html` | 文本/网页转 PDF |
| `archive.zip` | 解压 |

## A. 启动与引导（30 秒）

| # | 操作 | 预期 |
|---|---|---|
| A1 ★ | 打开 App | 首次启动显示中文引导 6 页；可「跳过」或走完 |
| A2 | 引导最后一页 | 有「登录时自动启动」「声音与触感反馈」开关；点「完成」后窗口关闭 |
| A3 | 菜单栏图标 → 设置 | 中文界面；语言选「简体中文」；重启后菜单/引导为中文 |

## B. ⇧ 格式转换（90 秒）

| # | 操作 | 预期 |
|---|---|---|
| B1 ★ | 拖 `photo.png` 不动，按 ⇧ | 轮盘出现，列出 7 个格式（PNG/WEBP/HEIC/TIFF/AVIF/BMP/PDF），无 DOCX/GIF |
| B2 ★ | 松手放到 `WEBP` | 生成 `photo.webp`（在原文件旁），进度条出现，完成后在访达显示 |
| B3 | 再转换一次 `photo.png → WEBP` | 不覆盖：生成 `photo 2.webp`（或带序号） |
| B4 ★ | 一次拖 3 个图片 + ⇧ | 轮盘只显示三张图共同支持的目标；批量各自产出 |
| B5 | 拖 `clip.mp4` + ⇧ | 目标含 MP4/MOV/MKV/WEBM/AVI/WMV/GIF/MP3；选 `MP3` 能出音频 |
| B6 | 拖 `notes.txt` + ⇧ → PDF | 生成 `notes.pdf`，能打开且文字正确 |
| B7 | 拖 `doc.docx` + ⇧ → PDF | 生成 `doc.pdf`；若本机有 LibreOffice，版式应接近 Word（否则走内置文本级） |

## C. ⌘ 工具轮盘（90 秒）

| # | 操作 | 预期 |
|---|---|---|
| C1 ★ | 拖 `photo.png` + ⌘ | 工具轮盘出现（编辑/标注/裁剪/压缩/…）；选中文字为中文 |
| C2 ★ | 选「压缩」→ 打开「目标文件大小」→ 填 200 KB | 生成 `photo Compressed.*`，体积 ≤ 200KB 左右 |
| C3 | 选「标注照片」→ 画一个框 + 文字 → 保存 | 生成 `photo Annotated.png`，标记可见 |
| C4 ★ | 拖 `clip.mp4` + ⌘ → 「移除音频」 | 生成 `clip Muted.mp4`，播放无声 |
| C5 | 拖 `clip.mp4` + ⌘ → 「视频变速」2× | 生成 `clip Speed 2x.mp4`，时长约一半 |
| C6 | 拖 `tone.wav` + ⌘ → 「音量标准化」 | 生成 `tone Normalized.wav` |
| C7 | 拖 `archive.zip` + ⌘ → 「解压归档」 | 生成 `Extracted/` 文件夹，内容正确 |
| C8 | 拖二维码图片 + ⌘ → 「读取二维码」 | 显示识别文本，可复制 |
| C9 | 拖两个 PDF + ⌘ → 「合并 PDF」 | 生成 `merged.pdf`，页数相加 |

## D. ⌃ 文件动作（60 秒）

| # | 操作 | 预期 |
|---|---|---|
| D1 ★ | 拖文件 + ⌃ → AirDrop | 弹出 AirDrop 分享面板 |
| D2 ★ | 拖文件 + ⌃ → Float | 浮窗出现；再拖一个文件 + ⌃ → Float（设置里 Float 行为=「加入当前 Float」时追加到同一浮窗） |
| D3 | ⌃ → Copy，到访达 ⌘V | 文件被粘贴 |
| D4 | ⌃ → Move，选目标文件夹 | 原文件被移动（原位置消失） |
| D5 | ⌃ → Copy Path | 剪贴板得到完整路径 |
| D6 | ⌃ → Terminal | 终端打开所在文件夹 |

## E. Office / Pages（60 秒）

| # | 操作 | 预期 |
|---|---|---|
| E1 ★ | `doc.docx` + ⇧ → PDF | 有 LibreOffice 时版式接近原始（设置 → 格式 → Office 引擎显示版本） |
| E2 | `slides.pptx` + ⇧ → PNG | 生成 `slides/` 页面图片文件夹（或单页图） |
| E3 | `doc.docx` + ⇧ → PAGES | 首次会弹 macOS「自动化」授权；允许后由 Pages 保存 `.pages` 文件 |
| E4 | 删除/退出 LibreOffice 后再转 `docx → PDF` | 回退到内置文本引擎：仍生成 PDF，版式近似（有提示） |

## F. 设置与失败路径（30 秒）

| # | 操作 | 预期 |
|---|---|---|
| F1 | 设置 → 格式：格式按钮网格 / `JPG → 7 个输出` / 质量滑杆 / 恢复默认 | 中文、可操作 |
| F2 | 设置 → 兼容性：逐源格式列出目标数 | 与轮盘一致 |
| F3 ★ | 改「拖拽修饰键」（如 ⇧↔⌥）后拖拽 | 新键生效，旧键不再弹轮盘 |
| F4 | 拖一个 `.xyz` 未知文件 + ⇧ | 明确错误提示，不崩溃 |
| F5 | 拖一个损坏的 `.png` + ⇧ → JPG | 该文件报错，批量其它文件仍成功 |

## 记录模板

```
环境：macOS ____ / 芯片 ____ / LibreOffice 有/无 / Pages 有/无
A1..A3: 通过/失败（备注）
B1..B7: ...
C1..C9: ...
D1..D6: ...
E1..E4: ...
F1..F5: ...
异常与截图：
```
