# AGENTS.md

Hearts Scoreboard: a SwiftUI score tracker for iPhone/iPad (iOS 17+), 3–6 players, game history, iCloud sync. ~2k lines of Swift, no third-party dependencies.

## Layout

- `HeartsScoreboard/` — app source
  - `Models/` — `HeartsGame`, `CompletedGame` (Codable value types)
  - `ViewModels/GameViewModel.swift` — all scoring/game logic and persistence; the only place rules live
  - `Services/CloudSyncManager.swift` — iCloud key-value sync (`SyncableState`)
  - `Views/` — SwiftUI screens (`GameView`, `RoundInputView`, `HistoryView`, `HistoryDetailView`, `SettingsView`, `AboutView`, …)
  - `Localizations/<locale>.lproj/` — `Localizable.strings`, `InfoPlist.strings`, `AppStoreMetadata.strings` for ~50 locales
- `project.yml` — XcodeGen spec. **`HeartsScoreboard.xcodeproj` is generated but committed**; edit `project.yml`, then regenerate.
- `scripts/` — Python helpers for translating strings (network required, uses `deep-translator`)
- `screenshots/`, `privacy-policy.html`, `README.md` — App Store / repo assets
- `AGENT_TODO.md` — working ledger of audit findings and planned work. Read it first; record new findings there, not only in chat.

## Build

```bash
xcodegen generate          # needs project.local.yml (see below)
xcodebuild -project HeartsScoreboard.xcodeproj -scheme HeartsScoreboard \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Gotchas:
- `xcode-select` may point at Command Line Tools, which can't build iOS. Use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild …` rather than changing the system setting.
- `project.yml` includes `project.local.yml`, which is **gitignored** (holds the signing team ID). If it's missing, `xcodegen generate` fails; create one with only what's needed, e.g. `settings: { base: { DEVELOPMENT_TEAM: "<id>" } }`, and never commit it. For simulator builds, signing isn't required.
- Pick an installed simulator (`xcrun simctl list devices available`) if the name above doesn't exist.
- New Swift files are picked up by XcodeGen on regenerate; after adding/removing files run `xcodegen generate` and commit the updated `.xcodeproj`.
- App Store screenshots: `scripts/screenshots.sh` (see README "Regenerating the App Store screenshots"). It runs the separate `HeartsScoreboardScreenshots` scheme (`HeartsScoreboardUITests`) against DEBUG-only `-screenshotDemo` data; keep accessibility identifiers (`historyButton`, `settingsButton`, `nextRoundButton`, `roundInput.quick.<name>`, `roundInput.queen.<name>`, `history.row`, `historyDetail.date`, `settings.done`) stable.

## Tests

There is currently **no test target**. When fixing a bug or changing scoring logic, add a unit test target (via `project.yml`) covering `GameViewModel` rather than skipping tests. Every bug fix ships with a regression test.

## Conventions

- SwiftUI with an `@Observable` view model (not `ObservableObject`); match the existing style, keep game rules in `GameViewModel`, not in views.
- User-facing strings go through localization. Add new keys to `en.lproj/Localizable.strings` first; other locales are machine-translated via `scripts/` and should not be hand-edited one by one. Don't leave a key only in `en`.
- Appearance preference is deliberately **not** synced via iCloud; only game settings are (see `CloudSyncManager`). Preserve that.
- Don't hand-edit `project.pbxproj`; change `project.yml` and regenerate (the localization scripts are the one exception — they patch the pbxproj and are documented in their headers).
- Version/build numbers live in `project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`).
- Don't commit `scripts/__pycache__/` or `.DS_Store` (the pycache files are currently tracked by mistake; leave them alone unless asked).

## Git

Commit directly to `main`; no feature branches unless asked. Push only when asked.

## Visual changes

Verify UI changes in the simulator (screenshot via `xcrun simctl io booted screenshot`) before declaring done; check both iPhone and iPad, light and dark.
