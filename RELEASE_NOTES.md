# Music Alarm v2.7.0 - unreleased

## 构建与发布安全

- 版本号统一从 `VERSION` 读取。
- 默认构建和 CI 强制生成 arm64 + x86_64 universal binary。
- 构建、签名、DMG 新鲜度和 commit 来源都有明确校验。
- Actions 固定到 commit SHA，并移除自动 Release job。

本阶段只更新开发分支、版本文件和构建配置，不创建 GitHub Release。
