# Release and CI

当前开发要求是每个阶段增加版本号、提交并推送，但不自动创建 GitHub Release。

当前版本统一读取根目录的 `VERSION` 文件。`Info.plist` 是仓库中的基准元数据，构建时会被 `build.sh` 用 `VERSION` 和当前 Git commit 覆盖到 app bundle 中。

## 已落实的构建与发布约束

- 本地开发可以显式设置 `REQUIRE_UNIVERSAL=0` 生成单架构包；默认和 CI 都强制 `arm64 + x86_64`。
- 配置 `SIGNING_IDENTITY` 后签名失败直接终止；正式签名模式用 `REQUIRE_SIGNING=1` 强制身份存在。
- GitHub Actions 已固定到审核过的 commit SHA，并声明 `contents: read`。
- 发布脚本只使用 `gh auth login` 或 `GH_TOKEN`，不读取 token 文件，也不把 token 放入 curl 参数。
- 发布脚本要求 clean tree、tag 指向 HEAD、DMG 构建元数据版本和 commit 都匹配。
- 普通 push、PR 和 tag 构建只上传 artifact，不自动创建 GitHub Release。

这些问题安排在后续独立阶段处理。正式发布前必须：

1. 从 `VERSION` 统一读取版本。
2. 强制 arm64 与 x86_64 都存在。
3. 签名失败直接失败。
4. 明确 Developer ID 签名和 notarization/stapling 配置。
5. Actions 固定到审核过的 commit SHA，并声明最小 job 权限。
6. 发布前检查 clean tree、tag/HEAD 一致和 DMG 时间戳/构建来源。
7. 将发布动作和普通 push/PR 构建分开，避免普通 CI 意外创建 Release。需要发布时由人工运行 `publish_release.sh`。
