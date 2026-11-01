# Development TODO

This file contains the remaining product and reliability work. Completed items
are removed after their version is committed and pushed.

## Remaining

- [ ] Add skip-next and configurable snooze.
- [ ] Add playback settings: fade, target volume, maximum duration, playlist behavior, and fallback choice.
- [ ] Add a test alarm flow with playback, popup, stop, snooze, confirm, and fallback diagnostics.
- [ ] Move wake confirmation into settings and add confirmation deadline/time records.
- [ ] Add optional confirmation modes: button, short word, hold for 3 seconds, simple slide, and main-window confirmation.
- [ ] Add occurrence history and explicit system time/timezone/DST handling.
- [ ] Add cross-process storage locking or migrate shared data to SQLite transactions.
- [ ] Add backup/export/import with audio files and restore preview.
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
