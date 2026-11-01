# Development TODO

This file contains the remaining product and reliability work. Completed items
are removed after their version is committed and pushed.

## Remaining

- [ ] Add `scheduledDate` for true one-time calendar dates.
- [ ] Add custom weekday selection, alarm labels, skip-next, and configurable snooze.
- [ ] Add missed-alarm policies: never, 15 minutes, 1 hour, 2 hours, and wake-only.
- [ ] Add configurable local audio library copy behavior and portable relative paths.
- [ ] Recompute `audioNeedsSelection` from actual playable tracks and expose missing/decode states.
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
