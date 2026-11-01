# Development TODO

This file contains the remaining product and reliability work. Completed items
are removed after their version is committed and pushed.

## Remaining

- [ ] Add fallback choice and detailed playback diagnostics.
- [ ] Add occurrence history and user-visible time/timezone/DST diagnostics.
- [ ] Add restore preview and conflict handling for backups.
- [ ] Add orphaned-audio cleanup and content-hash duplicate detection.
- [ ] Add reliability diagnostics, accessibility coverage, and UI automation tests.
- [ ] Update release documentation after signing and notarization are configured.

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

## Completed in 2.10.0

- Added per-alarm fade, target volume, maximum playback duration, and playlist loop settings.
- Added a non-persistent Test Alarm flow using local audio or system fallback.
- Added Settings controls for enabling wake confirmation, its deadline, and confirmation method.
- Added wake start, stop, confirmation, and deadline timestamps.
- Added button, short-word, hold, slide, and main-window confirmation interfaces.
