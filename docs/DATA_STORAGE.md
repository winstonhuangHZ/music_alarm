# Data Storage and Migration

## 稳定路径

```text
~/Library/Application Support/Music Alarm/
```

这个路径由 macOS 的用户级 Application Support 目录计算得到，不依赖：

- `.app` 所在位置
- 当前构建版本
- 当前工作目录
- 可执行文件的绝对路径
- SwiftUI 的应用容器路径

因此把应用复制到桌面、`/Applications` 或其他目录时，仍然读取同一份数据。

## 文件格式

### `alarms.json`

保存 `[AlarmItem]`。`AlarmItem` 对新字段使用 `decodeIfPresent`，旧版本缺少字段时使用默认值，不会因为新增字段导致整个列表解码失败。一次性闹钟使用 `scheduledDate` 保存完整日期；自定义重复闹钟使用 `weekdays` 保存 Foundation weekday 值。

### `imported-audios.json`

保存 `[ImportedAudio]`。每项记录稳定 UUID、显示名称和共享音频文件路径。

### `occurrences.json`

保存每次具体闹钟 occurrence 的历史。记录计划时间、实际开始/停止/确认时间、
发生时的时区和 UTC 偏移、夏令时状态、是否使用系统 fallback、尝试过的音轨，
以及播放失败原因。它与 `alarms.json` 分离，因此编辑下一次计划不会覆盖历史。

### `Audio/<UUID>.<ext>`

默认导入时将源文件复制到共享目录，闹钟记录引用共享副本，源文件移动后不影响已经导入的音频。用户可以在设置中关闭复制，此时记录原始绝对路径，原文件移动或删除后会显示失效状态。

`ImportedAudio.isManagedCopy` 区分应用管理的共享副本和用户原始文件。删除音频库项目时只删除应用管理的副本，不会删除用户原始文件。

## 写入安全

1. 先编码完整 JSON。
2. 如果主文件存在，复制为 `.bak`。
3. 使用 `.atomic` 写入主文件。
4. 写入失败时保留旧主文件和备份。

读取顺序：

1. 解码主文件。
2. 主文件损坏时尝试 `.bak`。
3. 两者都损坏时保留不可读文件，不自动用空数组覆盖。

用户明确修改受损列表后，应用才会用当前内存中的内容替换受损文件。这样可以避免启动或退出时静默丢失数据，同时允许用户通过新增、删除或编辑完成人工恢复。

## 旧版本迁移

首次发现共享文件不存在时：

1. 尝试读取旧 UserDefaults key。
2. 对旧的单音频字段生成新的 `tracks`。
3. 将旧导入音频复制到共享 `Audio/`。
4. 重写闹钟中的本地音频路径。
5. 成功后写入共享 JSON。

如果旧 JSON 存在但无法解码，不会把空列表当作迁移结果写入共享目录。日志只记录错误，不记录账号、密码、Cookie 或 Token。

## 运行时同步

应用重新激活时调用 `reloadFromSharedStorage()`。这能覆盖常见的“同一台 Mac 上打开另一个应用副本后再切回来”的场景。

未来若要支持多个副本同时编辑，应引入文件协调或数据库事务；JSON 原子替换只能防止半写入，不能合并两个并发编辑。

## 音频引用治理

音频导入前会通过 `AVAudioPlayer` 做可解码性预检。重复导入同一文件会复用已有库项目。删除库项目会清理所有使用该 `audioID` 的闹钟 track，并把闹钟标记为需要重新选择本地音频；替换音频会保持 `audioID` 不变并更新所有引用路径。

## 备份

备份目录包含 `manifest.json`、`alarms.json`、`imported-audios.json`、`occurrences.json` 和 `Audio/`。
备份内的音频路径使用相对路径，恢复时会复制到当前共享 `Audio/` 目录并重写所有闹钟引用。
恢复会先校验清单、JSON 和路径范围，再替换当前共享列表。版本 1 备份没有 occurrence
历史，恢复时按空历史处理。
