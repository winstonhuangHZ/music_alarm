# Development TODO

This file contains the remaining product and reliability work. Completed items
are removed after their version is committed and pushed.

## Remaining

暂无 2.18.0 之前已确定且未完成的项目。后续功能候选会在确认范围后加入这里，完成后从 Remaining
移动到对应版本的 Completed 小节。

## Completed in 2.20.0

- Redesigned the macOS application icon around the alarm clock, music note, and Dawn Flow brand palette.
- Verified generated icon output at 16px, 32px, 128px, and 512px scale targets.

## Completed in 2.19.1

- Localized the new library maintenance controls and the most visible diagnostic/history labels in all seven language bundles.

## Completed in 2.19.0

- Changed Light and Dark themes to solid backgrounds.
- Added an expandable music library side panel with vertical audio rows and maintenance actions.
- Moved daily pause controls to the main window and audio-library maintenance actions to the library panel.
- Added the new library navigation labels to all localization files.

## Completed in 2.18.0

- Added System, Light, Dark, Dawn Flow, Dracula, Nord, and Catppuccin theme palettes.
- Added state-aware animated background visuals and reduced-motion support.
- Added pause today, pause for one hour, resume all alarms, and per-alarm temporary disable.
- Persisted shared pause state in `runtime.json` for all app copies and install locations.
- Added runtime state to backup export, preview, replace restore, and merge restore.
- Preserved compatibility with format 1 and 2 backups.
- Added pause, temporary disable, runtime persistence, and runtime restore smoke tests.

## Completed in 2.8.0

- Single running instance with activation of an existing process.
- Optional login launch.
- Optional hidden main window on launch.
- Optional menu bar item and settings window.

## Completed in 2.9.0

- True one-time calendar date with `scheduledDate`.
- Custom weekday selection and alarm labels.
- Configurable missed-alarm policy, including wake-only recovery.
- Optional copying of imported audio into the shared Music Alarm library.
- Actual missing and undecodable audio states in the alarm editor.
- `audioNeedsSelection` is recalculated from playable tracks when saving.

## Completed in 2.11.0

- Added skip-next occurrence for repeating alarms and configurable snooze duration.
- Added backup export and validated restore for alarms, audio metadata, and audio files.
- Backups use relative audio paths and do not delete the current data until validation succeeds.

## Completed in 2.12.0

- Added a cross-process file lock around shared JSON writes.
- Replaced the repeating one-second alarm scan with a timer for the nearest computed deadline.
- Reschedules the deadline after store changes, application activation, wake, and system clock changes.

## Completed in 2.13.0

- Added durable occurrence history with playback, snooze, confirmation, failure, and expiry outcomes.
- Added time zone, UTC offset, daylight-saving, attempted-track, fallback, and failure diagnostics.
- Added recent alarm history and scheduler deadline diagnostics to Settings.
- Added occurrence history to backup export and restore, with compatibility for format 1 backups.
- Finished failed playback and naturally completed non-looping playlists through the normal engine cleanup path.

## Completed in 2.14.0

- Added selectable system fallback sounds.
- Added detailed local-track and fallback failure reasons to occurrence history.

## Completed in 2.15.0

- Added restore preview with validated counts and missing-audio information.
- Added explicit replace or merge conflict handling for backup restoration.

## Completed in 2.16.0

- Added SHA-256 content hashes and duplicate-content detection for imported audio.
- Added audio-library health scanning and cleanup for managed files without metadata.
- Added duplicate library cleanup that rewrites alarm references before removing managed copies.

## Completed in 2.17.0

- Added the last scheduler event to the Settings diagnostics panel.
- Added accessibility labels to primary alarm, popup, confirmation, audio, and window actions.
- Added repeatable core and optional UI accessibility smoke-test scripts.
- Documented the signing/notarization readiness checks without putting credentials in the repository.

## Completed in 2.10.0

- Added per-alarm fade, target volume, maximum playback duration, and playlist loop settings.
- Added a non-persistent Test Alarm flow using local audio or system fallback.
- Added Settings controls for enabling wake confirmation, its deadline, and confirmation method.
- Added wake start, stop, confirmation, and deadline timestamps.
- Added button, short-word, hold, slide, and main-window confirmation interfaces.
