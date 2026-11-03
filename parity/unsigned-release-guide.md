# 未签名开发包发布指南（无 Apple 凭证）

适用：还没有 Apple Developer Program / Developer ID 证书，但想给测试用户发 **ad-hoc** 包。
正式对外分发请走 [release-1.0.md](release-1.0.md) 的签名+公证流程。

> 原则：未签名包必须明确标注 `unsigned developer build`，不得伪装成正式版；文档必须写明首次打开方式；
> 不要让用户全局关闭 Gatekeeper。

## 1. 构建与打包

```bash
MARKETING_VERSION=1.1.0 BUILD_NUMBER=1 ./scripts/package-release.sh
```

脚本在无 `DEVELOPER_ID_APPLICATION` 时：
- 产出 `dist/release/Citrus-1.1.0.zip` / `.dmg` / `SHA256SUMS.txt`；
- 打印 `WARN: ad-hoc signature only`，跳过公证；
- 适合本机测试与内测分发。

## 2. 生成 Release 说明

复制 [`RELEASE_NOTES_TEMPLATE.md`](../RELEASE_NOTES_TEMPLATE.md)，替换：
- `<version>`、大小、SHA-256（从 `SHA256SUMS.txt` 取）；
- 本次亮点/修复；
- 保留「未签名、首次打开、依赖、隐私、已知限制」段落。

## 3. 发布预发布 Release

```bash
TAG="v1.1.0-unsigned"
gh release create "$TAG" \
  dist/release/Citrus-1.1.0.dmg \
  dist/release/Citrus-1.1.0.zip \
  dist/release/SHA256SUMS.txt \
  --repo onepayzk-glitch/citrus \
  --prerelease \
  --title "Citrus 1.1.0 (unsigned developer build)" \
  --notes-file /path/to/notes.md
```

要点：
- 用 `--prerelease`，tag 带 `-unsigned` 后缀，避免与未来正式版混淆；
- 附件只放 DMG/ZIP/SHA256，不放源码（源码由仓库 tag 提供）；
- 说明里给首次打开步骤和校验命令。

## 4. 用户首次打开（写进说明）

1. 下载 DMG → 拖入「应用程序」；
2. 右键 **Citrus.app → 打开**；或 系统设置 → 隐私与安全性 → 「仍要打开」；
3. 终端备选：`xattr -d com.apple.quarantine "/Applications/Citrus.app"`；
4. 不要全局关闭 Gatekeeper。

## 5. 升级到签名版（凭证到位后）

1. 删除或保留旧 prerelease（建议保留历史，标注 superseded）；
2. 用正式流程产出公证的 `v1.2.0`（或同版本号正式版）；
3. Release 说明写明「此版本已签名+公证，建议替换 unsigned 版」；
4. 不要用同一个 tag/文件名混发 signed 与 unsigned。

## 6. 发布前检查

- [ ] `./scripts/test.sh` 通过（13 套件）
- [ ] `./scripts/build-app.sh` / `package-release.sh` 退出 0
- [ ] DMG 可挂载、App 可启动、版本号正确
- [ ] SHA256 写入说明并可校验
- [ ] Release 标记 prerelease、标题含 `unsigned developer build`
- [ ] 说明包含首次打开与隐私/依赖/限制
- [ ] 未把它宣传为「正式版/公证版」
