# 1.0 组装版本：外部依赖按需检测与安装帮助

1.0 不捆绑任何外部引擎（不打包 LibreOffice、FFmpeg、Pages）。App 只做三件事：
**在用户真正用到相关能力时检测 → 缺了就说明清楚 → 帮助用户安装**。安装动作始终由用户执行。

## 依赖与用途

| 依赖 | 用在哪里 | 缺失时 | 是否可降级 |
|---|---|---|---|
| **LibreOffice** | DOCX / PPTX / XLSX / ODS / RTF / HTML / CSV 等 → PDF、PNG、JPG 的高保真导出 | 提示安装；可选择「用内置文本引擎继续」 | ✅ 回退内置文本/表格引擎（内容保留，版式近似） |
| **FFmpeg** | MP3、FLAC、OGG、Opus、WMA、MKV、WebM、AVI、WMV、GIF 输出；声道转换、音频哔声、音频可视化工具 | 提示安装；这些路由无原生替代 | ❌ 无回退（其余格式不受影响） |
| **Pages** | 导出 `.pages` | 提示安装（Mac App Store 免费应用） | ❌ 无回退（可先导出 PDF/DOCX） |

## 检测时机

| 时机 | 行为 |
|---|---|
| 拖拽后选转换目标时 | `DependencyAdvisor` 按「源格式 × 目标格式」判断；只在该路由真的需要且缺失时弹提示 |
| 打开需要 FFmpeg 的音频工具时 | 打开工具前检查，缺失则提示（不打开窗口） |
| 设置 → 格式页 | FFmpeg / Office 引擎状态实时显示；缺失时显示「帮助我安装」按钮 |
| 安装后再次使用 | 每次使用都重新检测，不需要重启 App |

## 提示与帮助行为

提示框包含：**需要什么、为什么（当前操作）、缺失的后果**，按钮：

| 按钮 | 行为 |
|---|---|
| **帮助我安装** | 有 Homebrew：把安装命令复制到剪贴板，打开 Terminal 并提示粘贴执行（`brew install ffmpeg` / `brew install --cask libreoffice`）；无 Homebrew：打开官方下载页 |
| **用内置文本引擎继续**（仅 LibreOffice） | 本次会话记住选择，继续转换（文本级版式） |
| **取消** | 不执行任何操作 |

- Pages：打开 Mac App Store 页面（`macappstore://…`，失败回退 https）。
- 不自动执行安装、不请求管理员权限、不后台静默下载；只打开官方 HTTPS 页面或把命令交给用户执行。
- 同一会话内对 LibreOffice 选择过「用内置引擎继续」后不再重复提示。

## 实现位置

| 文件 | 职责 |
|---|---|
| `NativeApp/Sources/Core/ExternalDependencies.swift` | `ExternalDependency`（LibreOffice/FFmpeg/Pages）与 `DependencyAdvisor` 纯判断逻辑（可测试） |
| `NativeApp/Sources/UI/DependencyPrompt.swift` | NSAlert 提示、安装帮助（Terminal 命令/官方页面/App Store）、会话内回退记忆 |
| `NativeApp/Sources/Radial/RadialController.swift` | 轮盘选择转换目标 / 打开工具前调用检测与提示 |
| `NativeApp/Sources/App/SettingsView.swift` | 依赖状态旁「帮助我安装」按钮 |
| `NativeApp/Tests/DependencyTests.swift` | 纯逻辑回归（Office/FFmpeg/Pages 的提示与不提示边界） |

## 手动验证（3 分钟）

1. **LibreOffice 缺失**：`mv /Applications/LibreOffice.app /tmp/` 后拖 `doc.docx` 选 PDF → 应弹出提示；选「用内置文本引擎继续」→ 生成 PDF；选「帮助我安装」→ Terminal 打开并已复制 `brew install --cask libreoffice`。
2. **FFmpeg 缺失**：把 `/opt/homebrew/bin/ffmpeg` 暂时改名后拖 `clip.mp4` 选 MKV → 应提示安装；恢复后重试即可。
3. **Pages 缺失**（可选）：在 Finder 里临时把 Pages.app 改名为 Pages.off → 拖 docx 选 PAGES → 应提示并打开 Mac App Store；恢复后可用。
4. 安装完成后**不需要重启 App**，再次拖拽会重新检测并走高保真引擎。

> 注意：临时改名系统 App 后记得改回；本机 `brew` 安装的 LibreOffice 位于 `/Applications/LibreOffice.app`。
