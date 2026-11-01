# 对外分发：签名与公证流程（1.0）

本文档描述如何把 `Open Tangerine.app` 打成对外可分发的 DMG/ZIP，并用 Apple Developer ID
签名 + 公证（notarization）+ stapling。仓库内脚本：`scripts/build-app.sh`（构建/签名）、
`scripts/package-release.sh`（打包/公证/staple/校验和）。

> 当前开发机状态：`security find-identity -v -p codesigning` 返回 **0 valid identities**，
> 也没有 `notarytool` 凭据，所以现在只能产出 **ad-hoc 签名**的包（见 §6）。
> 要对外分发，需要你先完成 §1–§3 的账号与证书准备。

## 0. 产物形态

| 产物 | 用途 |
|---|---|
| `dist/release/OpenTangerine-<版本>.dmg` | 对外主下载：拖入 Applications 安装 |
| `dist/release/OpenTangerine-<版本>.zip` | 备用下载 / 自动更新 / GitHub Release 附件 |
| `dist/release/SHA256SUMS.txt` | 校验和，发布页一并提供 |

## 1. 前置条件

1. **Apple Developer Program**（个人或公司，$99/年）——公证必须。
2. **Developer ID Application 证书**（不是 App Store 证书）。
   - 最简单：Xcode → Settings → Accounts → 选中团队 → Manage Certificates… → 左下 `+` →
     **Developer ID Application** → 生成并下载。
3. Xcode Command Line Tools（`xcrun notarytool`、`xcrun stapler`、`hdiutil`、`spctl` 已在本机可用）。
4. 你的 **Team ID**（developer.apple.com → Membership 里 10 位字符）。

验证证书已就绪：

```bash
security find-identity -v -p codesigning
# 期望看到: "Developer ID Application: <你的名字> (TEAMID)"
```

## 2. 创建公证凭据（只需一次）

任选一种方式，凭据存在钥匙串里，后续打包脚本通过 `NOTARY_PROFILE` 名称引用。

### 方式 A：App Store Connect API Key（推荐，适合自动化）

developer.apple.com → Users and Access → Integrations → App Store Connect API → 生成 Key（
下载 `.p8`，记录 Key ID 与 Issuer ID）：

```bash
xcrun notarytool store-credentials "open-tangerine-notary" \
  --key ~/Keys/AuthKey_XXXXXXXXXX.p8 \
  --key-id XXXXXXXXXX \
  --issuer 00000000-0000-0000-0000-000000000000
```

### 方式 B：Apple ID + App 专用密码

appleid.apple.com → 登录与安全 → App 专用密码 → 生成：

```bash
xcrun notarytool store-credentials "open-tangerine-notary" \
  --apple-id "你的 Apple ID 邮箱" \
  --team-id "TEAMID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

验证凭据：

```bash
xcrun notarytool history --keychain-profile "open-tangerine-notary"
# 能返回历史记录（可能为空）即表示凭据可用
```

## 3. 打包 + 签名 + 公证（一条命令）

```bash
MARKETING_VERSION=1.0.0 \
BUILD_NUMBER=1 \
DEVELOPER_ID_APPLICATION="Developer ID Application: <你的名字> (TEAMID)" \
NOTARY_PROFILE="open-tangerine-notary" \
./scripts/package-release.sh
```

脚本执行顺序：

1. 构建（`build-app.sh` 使用 Developer ID + hardened runtime + timestamp 签名）；
2. `codesign --verify --deep --strict`；
3. 打 ZIP 与 DMG；
4. `notarytool submit` ZIP 并 `--wait`；
5. `stapler staple` 到 App；
6. 用已 staple 的 App 重建 ZIP/DMG，再公证 + staple DMG；
7. `spctl --assess --type execute` 校验；
8. 生成 `SHA256SUMS.txt`。

成功时输出类似：

```
Processing complete
status: Accepted
The staple and validate action worked!
dist/release/Open Tangerine.app: accepted
```

## 4. 手工验收（发布前）

```bash
# 1) 签名与公证
codesign -dv --verbose=4 "dist/Open Tangerine.app"
spctl --assess --type execute --verbose=2 "dist/Open Tangerine.app"

# 2) DMG 可挂载、App 可启动
hdiutil attach "dist/release/OpenTangerine-1.0.0.dmg" -nobrowse -readonly
open "/Volumes/Open Tangerine/Open Tangerine.app"
# 检查：首次启动是否无 Gatekeeper 拦截、引导/设置/About/反馈是否正常
hdiutil detach "/Volumes/Open Tangerine"

# 3) 校验和
shasum -a 256 -c "dist/release/SHA256SUMS.txt"
```

## 5. 分发

1. **GitHub Release**（推荐）：仓库 `github.com/onepayzk-glitch` 建 tag `v1.0.0`，上传
   DMG、ZIP、`SHA256SUMS.txt`；Release 说明里写系统要求（macOS 15+、arm64）与组装版本依赖说明。
2. 发布页/README 标注：**未安装 LibreOffice/FFmpeg 时对应能力会提示安装**（见 `dependencies.md`）。
3. 用户安装说明：
   - 下载 DMG → 拖入「应用程序」→ 首次打开；
   - 若提示「无法验证开发者」：说明该版本未公证，请下载公证版本或按 Apple 官方指引在
     「系统设置 → 隐私与安全性」中允许（不要全局关闭 Gatekeeper）。
4. 不要分发 ad-hoc 签名的包给外部用户（会被 Gatekeeper 拦截且无法验证来源）。

## 6. 本机当前的 ad-hoc 打包（无证书时的临时产物）

```bash
./scripts/package-release.sh
# 只生成 dist/release/ 下的 ad-hoc ZIP/DMG，并打印警告；跳过公证
```

这些包**仅用于本机测试**。本机当前没有 Developer ID 证书，无法完成 §3 的公证步骤。

## 7. 常见问题

| 现象 | 原因与处理 |
|---|---|
| `0 valid identities found` | 没有 Developer ID Application 证书；按 §1 生成 |
| `notarytool` 401 / `Invalid credentials` | 凭据错误或过期；重新 `store-credentials`；确认 Team ID |
| `status: Invalid` | `xcrun notarytool log <submission-id> --keychain-profile <profile>` 看具体原因；常见为未启用 hardened runtime、嵌套二进制未签名、Info.plist 缺字段 |
| 公证通过但用户仍被拦截 | 未 staple 或用户离线；`stapler staple`/`stapler validate`，并确认分发的是 stapled 产物 |
| `The signature of the binary is invalid` | 扩属性/嵌套签名问题：`xattr -cr` 后重签；确认只签一次顶层 bundle |
| DMG 挂载后 App 无法启动 | 确认 DMG 内是已公证的 App；检查 `spctl` 输出 |

## 8. 安全与隐私

- App 无遥测、无崩溃上报、无账号；公证只是 Apple 对二进制做恶意软件扫描。
- 反馈由用户手动发送（About → 反馈问题），诊断信息不含文件名/路径/邮箱（见 `AppInfo.swift`）。
- 签名私钥只保存在你的钥匙串；不要提交 `.p8`、证书或凭据到仓库。
