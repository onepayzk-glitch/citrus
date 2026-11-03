# Citrus 发布说明模板（未签名开发包）

> 复制本文件为本次 Release 的说明，替换 `<version>`、日期、校验和与变更条目。
> 仅用于 **unsigned developer build**；正式版必须走签名+公证流程（见 `parity/release-1.0.md`）。

---

# Citrus <version> — 未签名开发版

> ⚠️ **此包未签名、未公证**，仅供测试与开发体验。首次打开需要手动允许，详见下方「首次打开」。

## 本次更新

- <亮点 1>
- <亮点 2>
- 修复：<...>

## 下载

| 文件 | 大小 | SHA-256 |
|---|---|---|
| `Citrus-<version>.dmg` | <大小> | `<sha256>` |
| `Citrus-<version>.zip` | <大小> | `<sha256>` |

校验方式：

```bash
shasum -a 256 -c SHA256SUMS.txt
```

## 安装

1. 下载 DMG，双击打开；
2. 把 **Citrus** 拖到「应用程序」；
3. 首次打开：**右键 → 打开**（或「系统设置 → 隐私与安全性 → 仍要打开」）。

终端备选：

```bash
xattr -d com.apple.quarantine "/Applications/Citrus.app"
```

> 不要全局关闭 Gatekeeper，不要从非官方来源下载。

## 依赖（按需）

Citrus 是组装版本，不捆绑外部引擎：

- **LibreOffice**：Office 文档高保真转换；缺失时可回退内置文本引擎；
- **FFmpeg**：MP3/FLAC/OGG/Opus/WMA/MKV/WebM/AVI/WMV/GIF；
- **Pages**：导出 `.pages`。

首次用到时 App 会检测并提示安装帮助（Homebrew 命令 / 官方下载页 / Mac App Store）。

## 隐私

- 无账号、无遥测、无上传；
- 反馈入口生成的诊断信息只含版本/系统/架构/语言/引擎安装状态，不含文件名、路径或邮箱；
- 更新检查在未配置仓库时不会联网。

## 已知限制

- 未签名/未公证（本包）；
- Office 版式保真取决于 LibreOffice；
- Pages 导出需要 Automation 授权；
- 当前构建为 arm64（macOS 15+）。

## 反馈

菜单栏 **反馈问题…** 或 设置 → 关于 → 反馈问题。请附上「复制诊断信息」，不要附私人文件。
