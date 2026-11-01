# Music Alarm

Music Alarm 是一个面向 macOS 的本地音乐闹钟。当前版本的核心数据保存在用户级共享目录中，因此从不同应用副本、不同构建版本或不同启动位置打开时，可以继续使用同一份闹钟列表和导入音乐库。

## 当前能力

- 指定日期的一次性、每日、工作日和自定义星期闹钟
- 闹钟标签和可配置错过闹钟补偿策略
- 本地 `.mp3` / `.m4a` 音频导入
- 闹钟音频按应用支持的播放列表顺序播放
- 7 种界面语言
- 关闭窗口后继续在后台运行
- 共享的闹钟与音乐库数据存储
- 共享 JSON 的原子写入和最近一次有效备份恢复
- 基于 occurrence 的调度、睡眠恢复和近期错过闹钟补偿
- 记录每次闹钟 occurrence 的开始、停止、确认、贪睡、失败和过期结果
- 在设置中查看最近历史、系统时间、时区、夏令时和调度 deadline 诊断
- 同一时刻多个闹钟排队播放
- 可选的“我已经真正起床”确认状态
- 可配置渐入、目标音量、最大播放时长和播放列表循环
- 可选测试闹钟和多种起床确认方式
- 可选择系统 fallback 声音，并记录播放失败原因
- 设置中提供调度、时区和系统时间诊断，并带有核心与 UI smoke test 脚本
- 可跳过下一次重复闹钟，并可为每个闹钟设置贪睡时长
- 支持包含音频文件的备份导出和恢复
- 恢复备份前显示摘要，并支持替换或合并当前数据
- 音频库引用清理、失效提示和替换音频
- 音频库 hash 去重、孤立文件扫描和清理
- 严格的 universal 构建、签名和 CI 元数据校验
- 单实例运行，打开其他应用副本时自动激活已有进程
- 可选登录启动、启动后隐藏主窗口和菜单栏常驻

当前版本只支持本地音频。旧版本中的外部流媒体记录会迁移为“需要重新选择本地音频”，不会启动外部播放器。

## 数据位置

所有当前版本共享数据位于：

```text
~/Library/Application Support/Music Alarm/
├── alarms.json
├── alarms.json.bak
├── imported-audios.json
├── imported-audios.json.bak
├── occurrences.json
├── occurrences.json.bak
└── Audio/
```

默认将导入音频复制到 `Audio/`，也可以在设置中保留原始文件路径。详细约束见 [数据存储](docs/DATA_STORAGE.md)。

## 本地构建

```bash
./build.sh
./make_dmg.sh
# Core smoke tests (requires a macOS Swift toolchain)
./scripts/run_smoke_tests.sh
# Optional UI accessibility smoke test after building
./scripts/ui_smoke.sh
```

构建脚本会尝试生成 `arm64` 和 `x86_64` 两个架构。正式发布、签名和公证流程见 [发布与 CI](docs/RELEASE_AND_CI.md)。当前开发阶段不会自动创建 GitHub Release。

## 开发文档

- [架构说明](docs/ARCHITECTURE.md)
- [数据存储与迁移](docs/DATA_STORAGE.md)
- [产品方向与竞品对齐](docs/PRODUCT_DIRECTION.md)
- [发布与 CI 安全](docs/RELEASE_AND_CI.md)
- [变更记录](CHANGELOG.md)
- [开发 TODO](docs/TODO.md)

## 版本约定

每个可独立验证的阶段都会增加版本号并单独提交、推送，但不会自动发布 Release。当前开发版本由 `VERSION` 文件维护，并同步到 `Info.plist`。
