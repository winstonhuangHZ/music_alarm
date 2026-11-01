# Changelog

## 2.14.0 - unreleased

### Fallback and playback diagnostics

- Added selectable system fallback sounds in Settings.
- Recorded missing-file, decode, fallback-unavailable, and fallback-start failures in occurrence history.
- Test Alarm and scheduled playback now use the same selected fallback sound.

## 2.13.0 - unreleased

### Occurrence history and playback diagnostics

- Added durable history for started, stopped, confirmed, snoozed, failed, and expired alarm occurrences.
- Recorded scheduled/actual times, time zone, UTC offset, daylight-saving state, fallback usage, attempted tracks, and failure reasons.
- Added recent alarm history and scheduler diagnostics to Settings.
- Added occurrence history to backup export and restore while keeping format 1 backups readable.
- Failed playback now ends the ringing state instead of leaving a stuck popup.
- Non-looping playlists now finish through the normal cleanup path.

## 2.12.0 - unreleased

### Scheduling reliability

- Added a cross-process file lock around shared JSON writes.
- Replaced the repeating one-second alarm scan with a timer for the nearest computed deadline.
- Reschedules after store changes, application activation, Mac wake, and system clock changes.

## 2.11.0 - unreleased

### Backup and alarm controls

- Added skip-next occurrence for repeating alarms.
- Added configurable per-alarm snooze duration.
- Added backup export and validated restore for alarms, audio metadata, and audio files.
- Backups use relative audio paths and preserve missing audio as a repairable state.

## 2.10.0 - unreleased

### Playback and wake confirmation

- Added per-alarm fade, target volume, maximum playback duration, and playlist loop settings.
- Added a non-persistent Test Alarm flow using local audio or system fallback.
- Added Settings controls for enabling wake confirmation, its deadline, and confirmation method.
- Added wake start, stop, confirmation, and deadline timestamps.
- Added button, short-word, hold, slide, and main-window confirmation interfaces.

## 2.9.0 - unreleased

### Scheduling and audio state

- Added a true calendar date for one-time alarms.
- Added custom weekday repetition and alarm labels.
- Added missed-alarm policies: never, 15 minutes, 1 hour, 2 hours, and wake-only.
- Added an option to keep imported audio at its original location instead of copying it into the shared library.
- Added missing versus undecodable audio status in the editor.
- Recompute `audioNeedsSelection` from the actual playable track list when saving.
- Replacing managed audio now removes stale files from previous extensions.

## 2.8.0 - unreleased

### Application lifecycle

- Added a per-user single-instance guard so opening another app copy activates the existing process.
- Added optional launch-at-login registration on supported macOS versions.
- Added optional hidden-on-launch behavior.
- Added an optional menu bar item and settings window.
- Added `docs/TODO.md` as the maintained list of remaining product and reliability work.

## 2.7.0 - unreleased

### 构建与发布安全

- 版本统一从 `VERSION` 读取，并写入 app bundle 构建元数据。
- 默认和 CI 构建强制包含 `arm64` 与 `x86_64`。
- 配置签名身份后签名失败直接终止；正式签名模式不允许缺少身份。
- DMG 打包检查版本、构建 commit 与当前源码一致。
- GitHub Actions 固定到 commit SHA，job 使用最小读取权限。
- 普通 CI 不再自动创建 GitHub Release；发布脚本改用 `gh` 认证并检查 clean tree、tag 和构建来源。

## 2.6.0 - unreleased

### 本地音频库

- 导入前使用 AVAudioPlayer 预检，拒绝无法解码或空音频文件。
- 重复导入同一文件时复用已有库项目。
- 删除音频库项目时同步清理所有闹钟引用，并标记闹钟需要重新选择音频。
- 增加替换音频入口，保持稳定 audio ID 并自动更新闹钟路径。
- 音频文件缺失时在音乐库和闹钟编辑界面显示明确状态。

## 2.5.0 - unreleased

### 起床确认

- 闹钟可选要求“我已经真正起床”确认。
- 开始播放后显示待确认状态，一次性闹钟不会立即完成。
- 停止声音会记录“未确认”，主列表提供后续确认入口。
- 确认后记录已确认状态，并完成一次性闹钟。
- 关闭该选项时保持普通闹钟的最短操作路径。

## 2.4.0 - unreleased

### 本地音频边界

- 删除外部流媒体播放桥接、界面入口和 Apple Events 权限声明。
- 闹钟只会尝试本地音频，失效后使用系统 fallback。
- 旧外部音频记录会迁移为“需要重新选择本地音频”，并清除旧外部链接字段。
- 清理对应本地化文案和旧修复脚本。

## 2.3.0 - unreleased

### 调度可靠性

- 使用具体 occurrence 判断到期，不再依赖恰好命中某一分钟。
- 应用启动、重新激活和 Mac 从睡眠唤醒时会检查近期错过的 occurrence。
- 支持同一时刻多个闹钟排队处理。
- 一次性闹钟在实际播放或 fallback 成功开始后才被消费。
- 播放失败时继续尝试下一个本地音频，再使用系统 fallback。
- 编辑时间或重复规则时清除旧贪睡状态和旧 occurrence 去重状态。
- 防止旧 AVAudioPlayer 完成回调推进新的播放会话。

## 2.2.0 - unreleased

### 数据可靠性

- 引入用户级共享存储目录，跨应用路径和构建版本共享闹钟列表与导入音乐库。
- 旧 UserDefaults 数据首次启动时迁移到共享目录。
- 新增 JSON 原子写入和 `.bak` 最近一次有效副本。
- 主 JSON 与备份都损坏时不再用空数组覆盖原数据。
- 应用重新激活时重新加载共享数据。
- 旧闹钟新增字段缺失时使用默认值，避免整表解码失败。
- 导入音频复制到共享目录，减少源文件移动导致的失效。
