# Tangerine 运行时观察证据（v2.0.2 实测）

观察时间：2026-10-28 22:23–22:36（CST）
观察对象：`/Applications/Tangerine.app`，`com.th.Tangerine`，2.0.2 (build 9)，`LSUIElement=true`
主机：macOS 27.0.1（26A434），arm64，主屏 1280×1440 pt（2560×2880 px），副屏 1920×1080 pt（3840×2160 px）

方法：
- 截图 `screencapture -x`（主屏）；副屏内容用 `screencapture -x -D 2`。
- 可访问性：`osascript` + System Events，以及 `cua-driver 0.28.2`（需先 `cua-driver serve`）。
- **注意**：Tangerine 的界面是 SwiftUI，System Events 的 AX 树几乎不可用（窗口只暴露 1 个 `AXGroup`，`buttons` 为 0）。`cua-driver get_window_state` 能拿到 `AXRadioButton / AXCheckBox / AXPopUpButton / AXButton` 及其 frame，这是本次控件清单的主要来源。
- 所有测试语料生成于 `/tmp/tangerine-probes/`，再复制到 `~/Desktop/tangerine-probes/`（共 23 个文件：PNG/JPEG/HEIC/TIFF/BMP/GIF/SVG/PDF×2/MP4/MOV/MP3/M4A/WAV/TXT/MD/SRT/VTT/HTML/CSV/DOCX/ZIP/TAR）。

截图与 AX 转储在本目录 `tangerine-oss/parity/runtime/`。

---

## 一、首次启动与引导（观察）

- 启动后主屏居中显示窗口「Welcome to Tangerine」，AX frame `(290,477) 700×452`，单个橙色 Continue 按钮（`01-welcome-window.png`）。
- 按 Return 可推进（Continue 是默认按钮）；共 **6 页**（`03-onboarding-pages-2-6.png` 为第 2–6 页拼图）：

| 页 | 标题 | 内容（观察） |
|---|---|---|
| 1 | Welcome to Tangerine | 只有一个 Continue 按钮（`01-welcome-window.png`） |
| 2 | File Converter | 左侧格式轮盘：PNG / PDF / WEBP / BMP / AVIF / TIFF / HEIC，轮盘中心显示文件体积（示意为 2.4 MB）；右侧文案「1. Drag files」「2. Tap ⇧ Shift」+ Continue（`02-onboarding-file-converter.png`） |
| 3 | File Tools | 工具轮盘，可见标签含 CONVERT / …ING / PORTRAIT / METADATA 等；右侧「1. Drag files」「2. Tap ⌘ Command」 |
| 4 | File Actions | 动作轮盘，可见标签含 COMPRESS / RESIZE 等；右侧「2. Tap ⌃ Control」 |
| 5 | Folder access | 橙色文件夹图标 + 文案大意「Folders are saved so Tangerine can read them on return — macOS doesn't ask again.」 |
| 6 | Finish setup | 开关「Launch at login」「Sound and haptic feedback」；「Unlock everything」区块显示「20 free uses left」+「One-time purchase」按钮；说明大意「Change anytime in Settings, or via right-click on the menu bar icon.」；Done |

- **全程没有出现任何系统权限弹窗**：没有辅助功能、屏幕录制、文件与文件夹授权、登录项（SMAppService）确认框。
- 引导结束后窗口自动关闭，App 转为纯菜单栏形态（`Tangerine Settings` 之外无窗口）。
- 引导结束后的偏好（`defaults read com.th.Tangerine` / 容器内 plist，两份一致）：
  - `hasCompletedWelcome = 1`、`hasSeenWelcomeV2 = 1`、`hasFullUnlock = 0`
  - `folderAccessBookmarks = ()`（空）
  - `toolsWheelDragModifierMask = 1`、`didMigrateToolsWheelToCommand = 1`
  - StoreKit 相关：`SK2PurchaseIntentUpdatesLastChecked`、`SKTransactionUpdatesLastChecked`
- 登录项列表实测为 `Magnet, 截图, BetterDisplay, Hammerspoon` —— **Tangerine 未注册登录项**（General 里「Launch at login」也未勾选，见第三节）。
- 免费额度在观察全程稳定为「20 free uses left」，观察结束仍未消耗（About 页显示「20 of 20 free uses left」）。

---

## 二、菜单栏图标与菜单（观察）

- NSStatusItem 的 AX description = **`Tangerine conversions`**，尺寸 24×24。
- 菜单共 10 项，**逐字**（`04-statusitem-menu.png`、`05-statusitem-menu-zoom.png`）：

```
1. Tangerine is ready                        （禁用，状态行）
2. ⇧: Convert · ⌘: Tools · ⌃: Actions        （禁用，修饰键提示行）
3. 20 free uses left                         （禁用，额度行）
4. ——— 分隔线 ———
5. Settings…
6. Unlock Tangerine…
7. Getting Started…
8. About Tangerine
9. ——— 分隔线 ———
10. Quit Tangerine
```

- 结论：菜单结构极简，**没有任何「转换/工具」入口**——转换入口只能在拖拽过程中以轮盘出现（见第四节）。
- 修饰键映射与任务书假设不同：**⇧ = Convert、⌘ = Tools、⌃ = Actions**（不是 Option+Shift）。用 AX 菜单第 2 行与设置页三个下拉框交叉验证一致。`05` 截图放大可直接读该行文字。

---

## 三、设置窗口（观察）

5 个 tab：**General / Formats / Compatibility / Folders / About**（`06-settings-general.png`；各页见 `11`–`19`）。

### General（`06-settings-general.png`；控件与取值来自 AX）

| 分组 | 控件 | 观察值 |
|---|---|---|
| Appearance | Style：Glass / Solid | 选中 Glass |
| General | ☐ Launch at login | 未勾选 |
| General | ☑ Sound and haptic feedback | 已勾选 |
| Drag Modifiers | Conversion wheel：⇧ Shift | ⇧ Shift |
| Drag Modifiers | Tools wheel：⌘ Command | ⌘ Command |
| Drag Modifiers | Actions wheel：⌃ Control | ⌃ Control |
| — | 说明文字 | 「Tap the chosen modifier combination while dragging files.」 |
| — | Float Behaviour：Create a New Float | Create a New Float |
| — | Terminal app：Terminal | Terminal |

### Formats（`11-settings-formats-tab.png`、`17-settings-formats-zoom.png`、`ax-settings-formats.json`）

- 左侧竖排源格式列表，AX 逐个可见，共 **33 项**：

```
JPG PNG WEBP HEIC TIFF SVG AVIF BMP
PDF DOCX PAGES PPT PPTX TXT MD RTF RTFD TEXTCLIPPING HTML EPUB XLSX XLS ODS CSV TSV
MP3 M4A WAV FLAC OGG OPUS AIFF WMA
```

- 右侧区块（观察到的控件原文）：
  - 「JPG Settings」区：☑ Preserve metadata、Restore Defaults
  - 「Image Compression」区：Compression：Balanced / Strong（选中 Balanced）、Image size：Keep original dimensions（下拉）、Restore Compression Defaults

### Compatibility（`12-settings-compatibility-tab.png`、`15-settings-matrix-grid.png`、`16-settings-compatibility-matrix-zoom.png`）

- 这一页是**源×目标转换矩阵**：行 = 源格式，列 = 目标格式，单元格用 ✓ / – 表示该组合是否支持。分组可见 Images、Documents、音频、视频等。
- 观察到的目标列包含：PDF / DOCX / PAGES / PPTX / TXT / MD / HTML / EPUB / JPG / PNG / XLSX / WEBP / HEIC / TIFF / SVG / AVIF / BMP …（矩阵可滚动，未逐一统计完）
- **矩阵单元格是自绘的，AX 不暴露**——AX 只能拿到左侧源格式列表，因此完整 ✓ 统计需要视觉逐屏读取（本次未做完，见第六节）。

### Folders（`13-settings-folders-tab.png`、`18-settings-folders-zoom.png`）

- 说明文字大意：Tangerine 保存书签，macOS 之后不再重复询问（与引导第 5 页呼应）。
- 列表为空（「No folders added yet.」），按钮「Add Folder…」。
- 与偏好 `folderAccessBookmarks = ()` 一致。

### About（`14-settings-about-tab.png`、`19-settings-about-zoom.png`）

- 图标 + 「Tangerine」+「Version 2.0.2 (9)」
- 「**20 of 20 free uses left**」
- 按钮：Unlock…（橙色主按钮）、Restore Purchase、链接 Support

---

## 四、转换实测：**未完成（0/6 条）** —— 如实记录

本次**没有成功执行任何一次转换**，免费额度仍是 20/20。原因是合成输入无法触发 Tangerine 的拖拽轮盘。过程如下（全部有截图/日志）：

| 序号 | 做法 | 结果 |
|---|---|---|
| 1 | `open -a /Applications/Tangerine.app <file>`（文件在 /tmp 与 ~/Desktop 各试一次） | shell 报「The file … does not exist.」，App 侧无窗口/无 HUD/无输出。**注：第一次是因为我确实漏生成 `probe.png`；补齐后从 Desktop 重试仍报同样错误**，说明 App 不走 `open document` 路径（或此路径不可用） |
| 2 | `osascript` 在 Finder 里 `click at` 引导页 Continue | 成功（说明坐标点击对普通按钮有效） |
| 3 | cua-driver `drag`（shift 全程按住，从 Finder 文件行拖出） | `background_unavailable` → 改前台投递后可执行，但 Finder 把它解释为 **Shift 扩选**（截图显示多行被选中），根本没起拖拽；说明「先拖、后按 Shift」的顺序是硬约束 |
| 4 | cua-driver `drag`（不带修饰键）+ 拖拽中途 `System Events key down shift`，边拖边截图 | 成功起了**真实文件拖拽**（截图可见拖动徽标、状态栏「选择 N 项…正在上传」），同时刻截图中**没有出现 Tangerine 轮盘**；松手后无转换、额度不变 |
| 5 | 先单击把单个文件设为唯一选择，再用 `drag` 带 `modifier:"shift"` 从同一行拖出 | 仍无轮盘、无输出、额度不变 |

**推断的失败原因**（列为推断，未验证）：
1. Tangerine 的 `DragMonitor` 依赖拖拽事件（`mouseDragged`）自带的修饰键 flags；cua-driver 合成的拖拽事件即使参数写了 shift，最终投递的事件仍可能不带该 flag；而 `System Events key down shift` 改变的全局修饰键状态不一定进入拖拽事件的 flags。
2. Finder 侧语义冲突：shift 在拖拽开始前按下会被解释为范围选择，导致拖拽根本没开始；拖拽开始后再按 shift 又可能来不及/不被监测到。
3. 目标落点问题：即使轮盘出现，也需要在轮盘某一段上松手才算选定格式；合成手势无法在轮盘出现后重新定位再松手。

**因此这一块（输出位置、命名规则、耗时、体积变化、失败文案、输出可打开性）全部没有实测数据**，请勿在复刻评估里引用任何「实测转换结果」。

---

## 五、推断（未直接观测，但从证据合理推出）

1. **「275 conversions」很可能等于 Compatibility 矩阵里 ✓ 格子的总数**——矩阵本身就是 源×目标 的支持表，与官方数字口径一致。未做完整计数，故不作为结论。
2. **「26 tools」对应 ⌘ Command 的工具轮盘**；**「6 file actions」对应 ⌃ Control 的动作轮盘**（引导第 3、4 页分别演示这两个轮盘，菜单提示行也一一对应）。轮盘里工具/动作的完整清单尚未拿到。
3. 转换引擎来自 bundle 资源：`ExifTool`（元数据读写）、`OfficePreview.js`（Office 预览/转换）、`PagesWriter.js` + `PagesTemplate.pages`（→ .pages 输出）、`PowerPoint`（二进制，Office 相关）、`Tools/` 目录、`CupertinoFiles-Licenses.txt`、`OfficePreview-Licenses.txt`。与静态分析里 ImageEngine / WebP 编码器 / AVIF 编码器 的说法互相印证。
4. IAP 走 **RevenueCat**（`RevenueCat_RevenueCat.bundle`）+ StoreKit2（`SK2PurchaseIntentUpdatesLastChecked`、`SKTransactionUpdatesLastChecked`），解锁状态落在 `hasFullUnlock`。免费额度 20 次，之后「Unlock…」一次性购买。
5. 引导第 5 页 + Folders 页 + `folderAccessBookmarks` 说明它用**安全作用域书签**保存用户授权的文件夹，用于之后免二次授权访问。
6. 「Terminal app」下拉（默认 Terminal）说明某个动作会调用外部终端；「Float Behaviour：Create a New Float」说明结果可以浮窗形式呈现。

---

## 六、未知（这次没拿到，别当已知）

1. 转换的输出位置与命名规则（原目录？下载目录？Float？），以及是否覆盖同名。
2. 转换耗时、体积变化、输出文件能否正常打开。
3. 失败/额度用尽时的提示文案。
4. Compatibility 矩阵的完整 ✓ 计数（是否能精确对上 275）。
5. ⌘ 工具轮盘与 ⌃ 动作轮盘里的完整条目清单（26 / 6 的精确名称）。
6. 首次真实拖拽时是否会弹系统权限请求（本次全程用合成输入，没触发任何真实拖拽成功，故很可能没走到需要权限的分支）。
7. 免费额度按「文件数」还是「转换次数」扣减（本次额度未动，无法判断）。
8. 菜单栏图标是否接受文件拖放（未测）。

---

## 七、对开源复刻（tangerine-oss）的直接影响

可直接当 parity checklist 用：

1. **修饰键默认值修正**：⇧ = 格式轮盘（Convert）、⌘ = 工具轮盘（Tools）、⌃ = 动作轮盘（Actions）。任务书里「Option+Shift = 工具轮盘」不成立。
2. **菜单栏菜单 10 项**逐字对齐（含三条禁用状态行：`Tangerine is ready` / `⇧: Convert · ⌘: Tools · ⌃: Actions` / `N free uses left`）。
3. **设置 5 tab** + 每页控件清单（第三节表格）对齐；General 里三个修饰键都必须是**可配置下拉**，不是硬编码。
4. **Formats 页 28/33 个格式按钮**清单（JPG…WMA）与 JPG Settings / Image Compression / Keep original dimensions / Restore 两组恢复按钮。
5. **Compatibility 页的源×目标矩阵**是这一页的主体，不能省。
6. **引导 6 页**：欢迎 → 格式轮盘 → 工具轮盘 → 动作轮盘 → 文件夹访问 → 完成设置（含 Launch at login、Sound and haptic feedback、解锁区、Done）。
7. **免费额度 20** + `hasFullUnlock` 布尔 + 一次性解锁入口（菜单 `Unlock Tangerine…` / About `Unlock…` / 引导末页）。
8. 偏好键名与语义（`hasCompletedWelcome`、`hasSeenWelcomeV2`、`hasFullUnlock`、`folderAccessBookmarks`、`toolsWheelDragModifierMask`、`didMigrateToolsWheelToCommand`）可参考，但不必逐字复刻。

---

## 八、证据文件清单（`tangerine-oss/parity/runtime/`）

| 文件 | 内容 |
|---|---|
| `01-welcome-window.png` | 首启 Welcome 窗口 |
| `02-onboarding-file-converter.png` | 引导第 2 页：File Converter 格式轮盘 + ⇧ Shift 提示 |
| `03-onboarding-pages-2-6.png` | 引导第 2–6 页拼图（格式轮盘 / 工具轮盘 / 动作轮盘 / 文件夹访问 / 完成设置） |
| `04-statusitem-menu.png` | 菜单栏图标展开的完整菜单 |
| `05-statusitem-menu-zoom.png` | 菜单区放大（可读文字） |
| `06-settings-general.png` | 设置 General 页全貌 |
| `07-settings-tabs-attempt.png` | 设置 tab 点击尝试（坐标校正过程） |
| `08-drag-attempt-files-drag.png` | 拖拽尝试：真实文件拖拽中（无轮盘） |
| `09-drag-attempt-shift-flag.png` | 拖拽尝试：shift flag 版本 |
| `10-drag-attempt-after.png` | 拖拽松手后的屏幕状态（无输出） |
| `11-settings-formats-tab.png` | Formats 页（副屏原图） |
| `12-settings-compatibility-tab.png` | Compatibility 页（副屏原图） |
| `13-settings-folders-tab.png` | Folders 页（副屏原图） |
| `14-settings-about-tab.png` | About 页（副屏原图） |
| `15-settings-matrix-grid.png` | 四个 tab 放大拼图（矩阵最可读） |
| `16-settings-compatibility-matrix-zoom.png` | 兼容性矩阵放大 |
| `17-settings-formats-zoom.png` | Formats 页放大 |
| `18-settings-folders-zoom.png` | Folders 页放大 |
| `19-settings-about-zoom.png` | About 页放大（版本号 / 20 of 20 / Unlock） |
| `ax-settings-general.json` | General 页 AX 元素（role + label + frame） |
| `ax-settings-formats.json` | Formats 页 AX 元素（33 个格式按钮 + 压缩控件） |
| `ax-finder-window.json` | Finder 窗口 AX 元素（拖拽落点计算用） |
| `runtime-raw-observations.txt` | 原始记录：进程、Info.plist、bundle 资源、菜单逐字、defaults、登录项 |
| `settings-formats-targets.txt` | 格式按钮顺序表 + 观察说明 |

测试语料仍在 `/tmp/tangerine-probes/` 与 `~/Desktop/tangerine-probes/`（23 个文件），可复用。

## 九、建议的下一步（本次受阻项）

要拿到转换实测数据，必须用**真实鼠标拖拽**（人手或带真实 HID 输入的会话），并在拖拽过程中按 Shift/⌘/⌃：

1. Finder 里按住文件拖出 → **拖起之后**再按 ⇧ → 轮盘出现 → 移到目标段松手；
2. 记录轮盘出现位置、每段文字、中心显示内容；
3. 转换完成后确认输出路径（本目录 / ~/Downloads / Float 窗口）与命名；
4. 用 `file` / `sips -g` / `ffprobe` 验证输出，并记录「N free uses left」的递减。
