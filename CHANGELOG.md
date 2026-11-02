# Changelog

## 2.26.3 - unreleased

### Calculus confirmation protection

- Stop now silences a calculus-confirmation alarm and leaves the challenge open.
- The challenge must be answered correctly before the active alarm session is finalized.
- Applied the same behavior to the notification Stop action and the maximum playback timeout.

## 2.26.2 - unreleased

### Calculus popup layout and math typography

- Kept the calculus content in a scrollable region while pinning Snooze and Stop below it.
- Limited the popup to the screen's visible height so the action buttons remain reachable.
- Updated formula rendering to prefer the installed Computer Modern / CMU Serif family.
- Standardized build, DMG, and UI smoke-test defaults on `dist/Music Alarm.app`.

## 2.26.1 - unreleased

### Hold confirmation motion

- Reworked the three-second confirmation progress from timer-driven polling to a continuous SwiftUI linear animation.
- The gesture now starts on press, cancels on release or excessive pointer movement, and completes from one deadline timer.

## 2.26.0 - unreleased

### Offline calculus wake confirmation

- Added an optional four-choice calculus confirmation mode for waking up.
- Added offline LaTeX rendering for the bundled substitution and AP Calculus BC Unit 10 series questions.
- Added convergence questions covering geometric series, nth-term behavior, p-series, integral test, direct and limit comparison, alternating series, ratio test, and absolute versus conditional convergence.
- Prevented the alarm row and notification action from bypassing the calculus challenge after playback stops.
- Added localized calculus prompts, answer feedback, hints, and accessibility labels across all seven language bundles.
- Linked WebKit explicitly in universal and smoke-test builds for the local renderer.

## 2.25.1 - unreleased

### Reliability Check crash fix

- Fixed a crash when opening or running Reliability Check on macOS by passing numeric counts as string objects to localized `%@` format arguments.
- Explicitly bridged output-device and volume strings before formatting the diagnostic row.

## 2.25.0 - unreleased

### macOS integrations

- Added native notification actions for Stop and Snooze, with a conditional wake-up confirmation action and stale-notification protection.
- Added an optional Command-Option-M global shortcut, Dock menu actions, and Test Alarm / pause / resume actions in the menu bar.
- Added Shortcuts intents for opening Music Alarm and starting a non-persistent Test Alarm on macOS 13 and later.
- Published current local playback metadata through macOS Now Playing.
- Added a localized diagnostic report export with app build metadata and a home-directory-neutral shared-storage path.
- Added the shortcut and diagnostics controls to Settings and completed their seven-language translations.

## 2.24.0 - unreleased

### Wake confirmation feedback

- Added live hold progress, elapsed time, cancellation on excessive pointer movement, reset after release, completion state, and cleanup when the alarm popup closes.
- Added a dynamic accessibility value for the three-second confirmation control.

## 2.23.0 - unreleased

### Music playback and staged wake-up

- Added sequential, shuffle, and repeat-one playback modes with correct loop and stop behavior.
- Added live playback progress and duration feedback to the music library bar.
- Added support for additional local audio extensions: AAC, WAV, AIFF, and AIF, with decode validation before import.
- Added an Advanced staged wake-up section where each playlist track can have its own volume and fade-in duration.

## 2.22.0 - unreleased

### Reliability center

- Added a Reliability Check page in Settings for the next alarm, enabled alarm audio, imported audio health, fallback sound, output device and system volume, shared storage, and scheduler activity.
- Added readable pass, warning, and failure results so users can run a preflight check before sleep.

## 2.21.1 - unreleased

### Playback and wake confirmation

- Fixed the three-second wake confirmation so the long-press gesture is handled by a direct gesture surface on macOS.
- Fixed completed playlist tracks being retained as the active player while the next track was starting.
- Made playlist advancement explicitly select the next track and preserve the configured loop or stop behavior.

## 2.21.0 - unreleased

### Interface polish

- Replaced decorative emoji in the main window, alarm rows, playlist editor, audio library, and alarm popup with native SF Symbols.
- Added a visible Settings button to the main window footer while keeping the menu command available.
- Rebuilt the Settings window as a wider, resizable, vertically scrollable layout with stable label and control columns.
- Fixed settings labels being clipped in Chinese and English layouts and completed the visible Simplified Chinese settings and backup translations.
- Added the application name to every localization bundle for status item accessibility text.

## 2.20.3 - unreleased

### Application icon proportions

- Added a macOS-style transparent safety margin around the application icon artwork.
- Reduced the visual mark to 84% of the canvas so it sits closer to the apparent size of native applications in Finder and the Dock.

## 2.20.2 - unreleased

### Playlist layout

- Made the alarm editor content vertically scrollable while keeping Cancel and Save actions visible.
- Removed the nested playlist scroller so track rows keep their height and the outer form handles long playlists.

## 2.20.1 - unreleased

### Application icon loading fix

- Declared both the generated `AppIcon.icns` file and its bundle icon name in `Info.plist` so Finder and Dock can resolve the icon reliably.
- Kept the icon generation and signing order unchanged, with the final bundle plist and icon resource validated after each build.

## 2.20.0 - unreleased

### Application icon redesign

- Replaced the placeholder red clock icon with a code generated macOS icon that combines an alarm clock, musical note, and Dawn Flow orange, coral, violet, and plum palette.
- Kept the icon source deterministic in `scripts/generate_icon.swift` so all generated `.icns` sizes stay consistent.
- Tuned the silhouette and contrast for 16px, 32px, 128px, and 512px representations.

## 2.19.1 - unreleased

### Localization polish

- Translated audio-library maintenance labels and diagnostic/history labels across the seven localization bundles.
- Removed the remaining English fallback text from the new library panel and the most visible Settings sections.

## 2.19.0 - unreleased

### Localization and library navigation

- Changed Light and Dark themes to use solid backgrounds without animated gradients.
- Replaced the crowded horizontal music strip with a compact summary bar and expandable trailing library panel.
- Moved pause controls and audio-library maintenance actions out of Settings into the main window and library panel.
- Added localized labels for opening and closing the music library.

## 2.18.0 - unreleased

### Themes, temporary pauses, and shared runtime state

- Added System, Light, Dark, Dawn Flow, Dracula, Nord, and Catppuccin themes.
- Added state-aware animated gradients for idle, upcoming, paused, ringing, and confirmation states.
- Added reduced-motion support for the animated background.
- Added pause today, pause for one hour, resume all alarms, and per-alarm temporary disable actions.
- Persisted global pause state in shared `runtime.json` so app copies use the same pause state.
- Added runtime state to format 3 backups while keeping format 1 and 2 backups readable.
- Merge restore preserves a currently active local pause before considering the backup pause state.
- Added smoke coverage for pause behavior, runtime persistence, and runtime backup restore.

## 2.17.0 - unreleased

### Reliability, accessibility, and verification

- Added runtime scheduler diagnostics to Settings.
- Added accessibility labels to alarm controls, confirmation controls, audio controls, and primary window actions.
- Added repeatable core smoke tests for storage, backup, localization parity, and accessibility coverage.
- Added an optional macOS UI accessibility smoke test for the built application.
- Documented signing, notarization, stapling, and Gatekeeper verification commands without storing credentials.

## 2.16.0 - unreleased

### Audio library health

- Added SHA-256 content hashes to imported audio metadata.
- Reuses an existing library item when the same audio content is imported again.
- Added missing-file, duplicate-content, and orphaned-managed-file scanning.
- Added safe cleanup for orphaned managed files and duplicate library records while preserving user-owned source files.

## 2.15.0 - unreleased

### Backup preview and conflict handling

- Added pre-restore validation and a backup summary showing alarm, audio, history, and missing-file counts.
- Added replace-current-data and merge-with-current-data restore policies.
- Kept format 1 backups readable and restored them with empty occurrence history.

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
