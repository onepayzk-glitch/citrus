# 对外分发：签名与公证流程（1.0）

本文档描述如何把 `Citrus.app` 打成对外可分发的 DMG/ZIP，并用 Apple Developer ID
签名 + 公证（notarization）+ stapling。仓库内脚本：`scripts/build-app.sh`（构建/签名）、
`scripts/package-release.sh`（打包/公证/staple/校验和）。

> 当前开发机状态：`security find-identity -v -p codesigning` 返回 **0 valid identities**，
> 也没有 `notarytool` 凭据，所以现在只能产出 **ad-hoc 签名**的包（见 §6）。
> 要对外分发，需要你先完成 §1–§3 的账号与证书准备。

## 0. 产物形态

| 产物 | 用途 |
|---|---|
| `dist/release/Citrus-<版本>.dmg` | 对外主下载：拖入 Applications 安装 |
| `dist/release/Citrus-<版本>.zip` | 备用下载 / 自动更新 / GitHub Release 附件 |
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
dist/release/Citrus.app: accepted
```

## 4. 手工验收（发布前）

```bash
# 1) 签名与公证
codesign -dv --verbose=4 "dist/Citrus.app"
spctl --assess --type execute --verbose=2 "dist/Citrus.app"

# 2) DMG 可挂载、App 可启动
hdiutil attach "dist/release/Citrus-1.0.0.dmg" -nobrowse -readonly
open "/Volumes/Citrus/Citrus.app"
# 检查：首次启动是否无 Gatekeeper 拦截、引导/设置/About/反馈是否正常
hdiutil detach "/Volumes/Citrus"

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


## 9. 开源仓库与"绑定凭证"的关系

**开源本身不需要任何 Apple 凭证**：源码公开、License 写明即可，任何人可以自己构建
（`./scripts/build-app.sh`，ad-hoc 签名，无需账号）。凭证只与「官方分发预编译的 macOS App」有关：

| 模式 | 需要 Apple 凭证？ | 用户首次打开体验 |
|---|---|---|
| 只开源源码，用户自行构建 | ❌ 不需要 | 需右键打开 / 系统设置允许（Gatekeeper） |
| 官方提供 ad-hoc 构建（无公证） | ❌ 不需要（但不推荐主渠道） | 同上，且来源无法验证 |
| 官方提供 Developer ID 签名 + 公证的 DMG | ✅ 需要（$99/年） | 双击直接打开，无拦截 |
| 提交 Mac App Store | ✅ 需要（App Store 证书 + 审核） | 商店安装 |

凭证的正确"绑定"方式：**放在 GitHub Actions 的加密 Secrets 或本机钥匙串，绝不写进仓库。**

### GitHub Actions（本仓库已配置 `.github/workflows/release.yml`）

在仓库 Settings → Secrets and variables → Actions 添加：

| Secret | 内容 |
|---|---|
| `APPLE_CERT_P12_BASE64` | Developer ID Application 证书 `.p12` 的 base64（`base64 -i cert.p12`) |
| `APPLE_CERT_PASSWORD` | 该 `.p12` 的密码 |
| `KEYCHAIN_PASSWORD` | CI 临时钥匙串密码（任意强密码） |
| `APPLE_TEAM_ID` | 10 位 Team ID |
| `NOTARY_KEY_ID` | App Store Connect API Key ID |
| `NOTARY_ISSUER_ID` | Issuer ID（UUID） |
| `NOTARY_KEY_P8_BASE64` | `AuthKey_*.p8` 的 base64 |

使用：推送 tag（`git tag v1.0.0 && git push origin v1.0.0`）→ workflow 自动：
构建 → Developer ID 签名 → 公证 ZIP → staple App → 重建 ZIP/DMG → 公证并 staple DMG →
校验 → 上传构建产物 → 创建 GitHub Release。

- Fork / PR 构建拿不到 secrets，因此只能产出 ad-hoc 包（安全默认）。
- 私钥、`.p8`、密码**永远不要**提交或上传到 issue/Release。
- 证书过期（Developer ID 有效期通常 5 年）后需更新 Secret 并重发版本。

### 开源还需准备（与凭证无关）

1. 仓库公开到 `github.com/onepayzk-glitch`（README 已有作者/反馈/路线图）；
2. License：本仓库为 GPL-3.0-only，保留 Satsuma（MIT）与上游 Open-Tangerine 的归属声明；
3. 第三方声明：组装版本不捆绑 LibreOffice/FFmpeg，因此不承担其分发许可义务；将来若捆绑，
   需补 MPL-2.0 / LGPL 许可证文本与源码获取说明；
4. 不在仓库中存放 `.p8`、`.p12`、公证凭据、用户数据。


## 10. 发布身份（bundle id / 仓库）说明

这是 **Open Tangerine 的 GPL fork**，由假宝玉维护；上游作者是 Sintax Error Private Limited。
用户可见的身份（作者、反馈、Release 链接）应指向本 fork，但**版权归属与 GPL/MIT 声明必须保留**。

- **bundle identifier**：开发构建默认沿用上游 `com.syntaxerror.opentangerine`（保持本地设置）；
  `package-release.sh` 默认使用本 fork 的 `com.onepayzk.opentangerine`，可用 `BUNDLE_ID=` 覆盖。
  不同 bundle id 会使用不同的偏好设置域，正式发布前请确认。
- **GitHub 仓库**：构建时可注入 `GITHUB_REPO=owner/repo`（写入 Info.plist `OTGitHubRepo`）。
  未注入时，App 内「检查更新」不会访问网络，只打开 GitHub 个人主页；注入后才会访问
  `api.github.com/repos/<repo>/releases/latest`。
- **上游链接**：README 不再链接上游官网/下载页；上游仓库只作为版权与来源说明保留。
- **远程仓库**：已创建并推送 https://github.com/onepayzk-glitch/citrus （`origin`），
  上游只读引用保留为 `upstream`；`GITHUB_REPO` 默认 `onepayzk-glitch/citrus`。


## 11. 没有 Apple 凭证时的替代方案

**结论：只有「官方发布、用户双击即开」需要 Apple Developer Program（$99/年）。** 没有凭证也能开源和自用，只是分发体验不同。

| 方案 | 费用 | 用户体验 | 可行性 |
|---|---|---|---|
| 只发源码，用户自行 `./scripts/build-app.sh` | 0 | 需要 Xcode/命令行工具；首次手动打开 | ✅ 最干净 |
| 发布 ad-hoc/unsigned 包 | 0 | 需右键打开或系统设置允许；无法验证来源 | ⚠️ 只适合开发者/测试 |
| 让有 Developer ID 的团队/公司代签 | 对方付费 | 取决于对方身份与信任 | ⚠️ 证书属于对方团队，分发身份不是你的，不建议 |
| Apple 费用豁免（非营利/教育/政府机构） | 0 | 与付费相同（需审核） | 个人一般不符合；若你有对应机构可申请 |
| Apple Developer Program | $99/年 | 双击即开，可公证 | ✅ 唯一正规路径 |
| Mac App Store | $99/年 + 审核 | 商店安装 | ❌ 与 GPL 分发冲突风险，不建议 |

说明：
- **免费 Apple ID** 只能做本地开发签名（Apple Development），**不能**获得 Developer ID，也无法公证；换台 Mac 仍会被 Gatekeeper 拦截。
- 公证（notarytool）本身不额外收费，费用就是 Developer Program 年费。
- 任何第三方都无法替代 Apple 的公证服务；自签名/自建 CA 不会被 Gatekeeper 认可。
- 建议顺序：先开源 + 源码构建 + ad-hoc 测试包 → 有用户/打赏后再买 $99 → 用 GitHub Actions Secrets 自动签名公证。
- 若你属于非营利组织、认证教育机构或政府机构，可在 developer.apple.com 查询 fee waiver 政策并申请（以 Apple 当前政策为准）。

### 无凭证期间的发布建议

1. GitHub Release 只放 **源码 zip** 或明确标注 `unsigned developer build` 的包；
2. README 写清「首次打开方式」，不要让用户全局关闭 Gatekeeper；
3. 收集打赏/赞助，覆盖 $99 年费后再发正式公证版；
4. 代码层面的签名/公证流水线已就绪，拿到凭证后一条命令即可。
