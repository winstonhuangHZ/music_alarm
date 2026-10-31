# Release and CI

当前开发要求是每个阶段增加版本号、提交并推送，但不自动创建 GitHub Release。

## 当前已知问题

- `build.sh` 仍允许只编译出一个架构并继续完成构建。
- 代码签名失败目前只打印 warning。
- GitHub Actions 使用可变的 major tag。
- 发布脚本有旧版本默认值，并支持明文 token 文件。
- 发布脚本没有统一读取版本源，也没有在上传前严格检查构建新鲜度。

这些问题安排在后续独立阶段处理。正式发布前必须：

1. 从 `VERSION` 统一读取版本。
2. 强制 arm64 与 x86_64 都存在。
3. 签名失败直接失败。
4. 明确 Developer ID 签名和 notarization/stapling 配置。
5. Actions 固定到审核过的 commit SHA，并声明最小 job 权限。
6. 发布前检查 clean tree、tag/HEAD 一致和 DMG 时间戳/构建来源。
7. 将发布动作和普通 push/PR 构建分开，避免普通 CI 意外创建 Release。
