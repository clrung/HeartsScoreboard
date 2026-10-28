# Agent TODO

## Landscape score-entry cards (2026-10-27)

- [x] Sheet entry uses a width-aware player grid (up to three columns, at least 320pt per card, wider when chip text scales); accessibility text sizes retain one column. Existing inline iPad rows remain unchanged.
- [x] Wide landscape sheets center a compact footer with progress beside Submit, keeping it pinned below the scrollable cards. Compact-height sheets move the moon preference into the toolbar so two complete card rows fit on iPhone Air.
- [x] Extended phone orientation UI regression to check adjacent cards, compact Submit, progress alignment and score entry with six long player names.
- [x] Final simulator verification: four UI runs passed on iPhone Air and iPad Pro 13-inch (M5), covering portrait/landscape in light/dark; screenshots visually reviewed, including simctl captures in all four device/appearance combinations. Build, screenshot identifiers and diff whitespace checks pass. Final results: `/private/tmp/hs-entry-final-{light,dark,ipad}.xcresult`; phone captures `/private/tmp/hs-entry-final/`, iPad captures `/private/tmp/hs-entry-shots/`. Initial cold-start test connections stalled before assertions; restarting the task simulators and running sequentially resolved it.

## Queen entry transfer and score floor (2026-10-27)

- [x] Q♠ chips transfer the queen and its 13 points between players, preserving entered hearts. Tapping the selected Q♠ removes it and exactly 13 points (user decision). Q♠ remains available after a normal round reaches 26; moon score controls keep their existing lock.
- [x] The selected queen owner's minimum is 13 for steppers, exact-value selection, keyboard digits and Delete. The picker disables 0–12, and the minus button disables at 13. Over-26 entries preserve points during transfers and decrement one point at a time instead of silently dropping an overage.
- [x] Moon entry clears the old queen selection; round validation requires exact moon distributions rather than accepting any scores with a moon's total. Regression coverage includes transfer/removal, keyboard parity, the score floor, overages, and the 10♦ bonus.
- [x] Verification: 48 unit regressions passed (`/private/tmp/hs-queen-unit-final.xcresult`); 10 UI checks passed across iPhone 18 Pro and iPad Pro 13-inch (M5), iOS 27.0, light/dark. Picker and transfer screenshots reviewed in all four combinations; `simctl` captures saved too. Results/logs under `/private/tmp/hs-queen-*`, screenshots in `/private/tmp/hs-queen-shots/`. Screenshot identifiers and `git diff --check` pass. Initial simulator accessibility startup/service interruptions occurred before assertions; successful retries are `hs-queen-iphone-light-retry` and `hs-queen-ipad-light-retry`.
- [x] Added optional `Hand.queenOfSpadesPlayerID` (2026-10-27). New rounds preserve explicitly selected ownership across saved-file loading, edit/transfer, undo/redo and sync. Older hands and manually entered scores without a Q♠ selection remain unknown; ownership cannot be reconstructed from scores alone. Regression coverage in `RedoAndEditTests`. Verification is recorded in the orchestration pass below.

## iPhone landscape scoreboard (2026-10-27)

- [x] iPhone compact-height layouts now keep the full-width scoreboard, bottom Next Round button, and round-entry sheet used in portrait. The inline entry panel remains available on regular/regular unfolded Duo. iPad layout selection is unchanged, including shorter regular-width windows.
- [x] Landscape iPhone player headers show full names with up to two reserved lines instead of initials; the dealer badge shares the first text baseline and totals remain aligned. Portrait and iPad name treatment is unchanged.
- [x] Regression coverage: explicit phone/iPad layout-policy cases in `DuoLayoutSnapshotTests`, phone portrait-to-landscape sheet flow with six long names in `OrientationLiveUITests`, and stronger iPad inline-pane assertions. Screenshot identifiers remain valid.
- [x] Final layout-policy unit test passed against the current app source (`/private/tmp/hs-phone-landscape-final-unit.log`); simulator build and `git diff --check` pass.
- [x] iPhone portrait/landscape sheet-flow regression passed in light and dark on iPhone 18 Pro Max (six long names); dark-mode board and sheet screenshots reviewed after the final dealer-baseline fix. Captures: `/private/tmp/hs-phone-landscape-shots`, `/private/tmp/hs-phone-landscape-final`; logs/results under `/private/tmp/hs-phone-landscape-*`. Screenshot identifiers check passes.
- [x] iPad Pro 13-inch (M5) light/dark screenshots reviewed: existing inline landscape and stacked portrait layouts preserved. Captures: `/private/tmp/hs-ipad-layout-shots`.
- [ ] Simulator-only verification follow-up: `OrientationLiveUITests.testOrientationsAndScenarios` passed its layout assertions for early light/dark and long light, then failed in `app.terminate()` (no layout assertion failure), before the last long/dark case. Log: `/private/tmp/hs-phone-landscape-ipad.log`. Several phone test preparations also stalled; the final dark phone retry passed after startup completed and idle simulators were closed.

## Current priorities (orchestrated 2026-10-27)

Scope confirmed by user: fix bugs, complete verification and clean up this ledger; keep Widget / Live Activity and localized App Store screenshots deferred. GPT-6 Luna subagents own picker layout, queen metadata, and share/orientation verification.

1. Fix and verify the reported wrapped 10♦ picker/help overlap (see stability follow-up below).
2. Preserve Q♠ ownership for new saved rounds, retaining backward compatibility with old saves.
3. Finish share/export and orientation simulator checks; distinguish automation failures from app failures.
4. Physical-device release checks: user offered to help. Pending results for iPad keyboard, sheet dismissal/shake, VoiceOver, and Duo partial fold. Native-language review still needs speakers; automated translation review cannot close it.
5. Release decision: build 13 is the latest confirmed TestFlight upload. After device checks, choose the release build and refresh Duo-open screenshots in DeviceHub. App Store submission remains the user's action. Changes in this pass require a new build before release.

Completed housekeeping: removed the two remaining explicitly named throwaway simulators (`chips-se` and `bar-ipad`); the other named chips simulators were already absent. Preserved screenshot and general-purpose simulators.

## Previous ranking (2026-10-26; superseded by current priorities)
0. [ ] **Real-device verification of the iPad redesign** (M): use the latest confirmed TestFlight upload, build 13. Verify hardware keyboard shortcuts, sheet keyboard path, shake-to-undo, VoiceOver and partial-fold Duo. User offered to perform checks; results pending.
Completed since last pass: d9ce187 (round-entry totals centered, 10♦ chip replaces −10 badge, build 8). Working tree clean except `scripts/fix_ctx_keys.py`.

1. [ ] **Ship 4.0.0 after device verification**: build 13 supersedes builds 10/11. This pass adds changes that need a new tested upload before release. Confirm the selected build in App Store Connect; the user submits for review.
2. [x] **Verify round entry at the edges** (done 2026-10-26: SE 375pt, 6 players, AX sizes, light/dark; iPhone 18 Pro 402pt rechecked): iPhone SE width, 6 players, and AX Dynamic Type with the 10♦ chip. These are the open items from the build-8 work, and that layout code is the newest.
3. [ ] **Device checks** (M, needs hardware; also verify the iPad redesign, see section at the bottom): shake-to-undo after closing each sheet (the 0.5s refocus is a guess), VoiceOver flow, edit-round sheet, keyboard shortcuts and hover on iPad, partial fold on Duo.
4. [x] **Unused-string cleanup** (done 2026-10-26): removed 10 unused keys from all 75 locales ("Time", "No completed games yet.", 4× "Pass: … ←", "Undo last round" + its message, "10 of Diamonds", "More"). `scripts/fix_ctx_keys.py` (already applied) is still untracked: commit or delete it.
5. [x] **Translation quality** (done 2026-10-26, LLM review; no native speakers yet): six Sonnet reviewers went through every Localizable/InfoPlist value in 73 locales against a domain glossary (~2,400 values changed). They fixed wrong-sense "Pass" (walk past), "Dealer" (merchant), "Player" (media player), "Round" (circle shape), "photograph the moon", reversed "%d wins in %d games" (ja, ko, my, kk, mn, az, uz, ur, am, sw, tr), phonetic English, leftover Simplified Chinese in zh-Hant, and Brazilian Portuguese in pt-PT. `sr` was rewritten; sr-Latn is now generated from it by transliteration (`scripts/sr_latn_from_sr.py`; rerun after editing sr). Regression tests: `testSerbianLatinHasNoCyrillic`, `testTurkishWinsInGamesKeepsArgumentOrder`. Per-batch logs with an "uncertain" list each: scratchpad `l10n-review-*.md` (not in the repo). Still worth a native check: the "shoot the moon" idiom (mostly literal), the new dealer words and one-letter D badges, and "Hold" phrasing.
6. [x] Small polish: dark-mode More/Undo chips, pass-direction truncation and bottom-bar chip heights fixed 2026-10-26 (details below); [x] `%d rounds` isn't pluralized (stringsdict) (Done 2026-10-26: one key `%lld rounds` with CLDR plural forms in `Localizable.stringsdict` for all 75 locales, generated by `scripts/generate_plural_stringsdict.py`; old `%d rounds`/`%lld rounds`/`1 round` .strings keys removed; tests in `PluralRoundsTests`; forms are LLM-generated, native check pending); named throwaway simulator cleanup completed 2026-10-27.
7. [ ] Deferred: localized App Store screenshots; Widget / Live Activity.

## Appearance picker didn't restyle the board (fixed 2026-10-26, uncommitted)
- [x] Bug (TestFlight build 9, iPad): Settings > Appearance > Dark darkened only the Settings sheet; the board behind stayed light, and stayed light after Done. Reproduced in the iPad simulator (probe reported board style "light" while the sheet was dark).
- Cause: two competing SwiftUI `.preferredColorScheme` sources (App-root `@AppStorage` value and a second one on the Settings sheet). The sheet's own value applied immediately, but the root one did not re-render the board from the `UserDefaults` write that `setAppearance` makes.
- Fix: one source of truth. `WindowAppearanceApplier` (Services/WindowAppearance.swift, attached in `GameView`) sets `window.overrideUserInterfaceStyle` from `model.settings.appearance` (`AppearancePreference.userInterfaceStyle`; System = `.unspecified`, follows the device). The root and sheet `.preferredColorScheme` calls are removed; the DEBUG screenshot demo still forces its scheme. Appearance remains local-only (UserDefaults, not iCloud).
- Tests: `AppearanceLiveSwitchUITests` (UI; board style probe `BoardStyleProbe` is DEBUG-only; launches with `-screenshotDemo -screenshotFollowAppearance`), `AppearancePreferenceTests` (mapping + applier sets/clears the window override).
- Why existing tests missed it: no UI test ever changed the picker with Settings open; snapshot tests render SettingsView/GameView separately and with a forced scheme, so the interaction between root and sheet was never exercised.

## iPhone Duo / wide-screen support (started 2026-10-24)

### Device facts (research 2026-10-24; Apple tech talks 111461/111466 + newsroom)
- Foldable, shipped 2026-10-23 on iOS 27.x. Outer: compact width (portrait & landscape). Inner (open): regular/regular.
- Inner display ignores supported orientations; partially-folded posture curves through the center — keep controls off mid-screen.
- Build with Xcode 27.1 / iOS 27.1 SDK for edge-to-edge; gate Duo-only APIs (`onHingeChange`, reserved regions — names unverified) behind `#available`.
- Don't use `UIScreen.main` (ambiguous with two displays). Use size classes, not idiom/orientation.
- App Store: "Made for iPhone Duo" badge; screenshot sizes per blogs 1398×2034 (outer) / 2007×2853 (inner) — verify in App Store Connect. Possibly required April 2027 (unconfirmed).
- Baseline: app builds clean against iOS 27.1 SDK (0 errors, no deprecations). The iPhone Duo simulator needs the iOS 27 runtime, now installed (iOS 27.1, 24A94425). Simulator "iPhone Duo" created: `xcrun simctl create "iPhone Duo" com.apple.CoreSimulator.SimDeviceType.iPhone-Duo` (prefix `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`).

### Decisions (user, 2026-10-24)
- Unfolded layout: scoreboard + inline round entry side by side; History/Settings stay sheets; folded unchanged.
- Visible Undo button in the bottom bar (keep shake too).
- Tests via xcodegen targets in project.yml (unit + UI/screenshot).
- Keep iOS 17 minimum; `#available(iOS 27.1, *)` for Duo APIs.

### Audit findings (current state)
- iOS 17 target, device family `1,2`, all 4 orientations, no `UIRequiresFullScreen`, multiple scenes on, single `WindowGroup`.
- `project.yml` doesn't pin `TARGETED_DEVICE_FAMILY` or orientations (come from Xcode defaults / Info.plist).
- No size-class / geometry logic anywhere; every screen is a single portrait column.
- `GameView.swift` main VStack has no max content width; score chips fixed `56x26` (~:407); dealer badge height 25 (~:342).
- `RoundInputView.swift` hard-coded widths: name 130 (~:36), steppers 32, chips 52x32 (~:82-119) — tight on narrow, wasted space on wide.
- Fixed sizes also in `HistoryDetailView.swift:194` and `PlayerScoreViews.swift:20`.
- All secondary screens are `.sheet` with no `presentationSizing` / detents.
- Undo is shake-only (`ShakeDetectorView`); first responder not restored after a sheet dismisses; no visible Undo button.
- No tests, no test target. Screenshots are manual PNGs (iOS 1284x2778, iPad 2048x2732).
- `xcode-select` points at Command Line Tools — need `sudo xcode-select -s /Applications/Xcode.app` to build.

### Duo layout snapshot harness (2026-10-24)
- `HeartsScoreboardTests/DuoLayoutSnapshotTests.swift` renders GameView at 669x951 / 951x669 (regular) and 466x678 (compact) and writes PNGs to `$SNAPSHOT_DIR` (run with `TEST_RUNNER_SNAPSHOT_DIR=...`). `GameView(model:)` is now injectable.
- Fixed from screenshots: inline player rows showed names as "..." (stacked layout now: name+stepper, then 4 chips); 6-player score cells (fixed 56pt) overflowed the card; header "Game to" wrapped; inline panel top was above the scoreboard (header is now full-width above both panes); Form top gap in inline panel.
- [ ] Still unverified on a real unfolded device: partial-fold posture, hinge/reserved regions.
- [x] (Done: compact inline rows + Submit as bottom safe-area inset; 6p+10♦ picker starts just above the bar.) Inline entry Form scrolls at Duo inner size for 4 players in landscape and 6 players in portrait (Submit stays pinned); 10♦ picker sits below the fold with 6 players. Consider compacting rows.
- [x] 6-player header names truncate to ~3 chars in the ~300pt scoreboard pane. Fixed: split layout with 6 players shows initials (`HeartsGame.headerLabels`, collisions -> 2 letters -> full name; full name kept as accessibility label).

### Planned work
- [x] Cap/center main content width on regular width (1200pt cap); score cells shrink with column.
- [x] Wide layout: scoreboard + inline round input side-by-side on regular width, 40pt gap at the center fold (`GameView`).
- [x] Flexible `RoundInputView` row layout (Grid / flexible frames); `presentationSizing(.form)`; `presentation: .sheet | .inline`.
  - [x] (Done: RoundEntryState + RoundEntryStateTests.) Follow-up: no unit test for the inline reset after submit (entry state is private `@State`; would need extracting an entry-state type).
  - [x] (Done: ChipButtonStyle gives a 44pt hit area around the 32pt capsule.) Follow-up: chips are 32pt tall (below the 44pt tap target) to keep two chip rows per player row.
- [x] Visible Undo button; restore shake first responder after sheets (`ShakeDetectorView.refocusToken`, regression test in `UndoTests.swift`).
  - [ ] Follow-up: the 0.5s re-focus retry after sheet dismissal is a timing guess — verify shake works after closing each sheet on a device.
- [x] Pin device family + orientations in `project.yml` (done in the 10♦ work).
- [x] Unit tests (25: 10♦, undo, Duo snapshot harness). No XCUITest target yet.
- [x] (Done: scripts/screenshots.sh, all 5 sizes committed; sizes confirmed against Apple's spec page.) New App Store screenshot size set for the new device (1398×2034 outer / 2007×2853 inner per blogs — verify in App Store Connect). Unfolded sim can't be driven from CLI; capture via DeviceHub UI or device.
- [ ] Verify on a real/DeviceHub-unfolded Duo, incl. partial fold; consider `#available(iOS 27.1, *)` hinge APIs only if the center gap proves insufficient.

## 10♦ = −10 rule (Omnibus Hearts variant) (started 2026-10-24)

### Decisions (user, 2026-10-24)
- Toggle in Settings › Rules (default off, iCloud-synced). Separate "10♦ taken by" chip picker below player rows in round input; holder required to submit. ♦ marker on the holder's score cell in game + history views.
- Moon interaction per pagat.com: moon needs only hearts + Q♠; −10 goes to whoever took the 10♦ (can be the shooter).

### Done (uncommitted)
- `Hand.tenOfDiamondsPlayerID`; `pointsByPlayerID` stores FINAL points (holder includes −10); `isMoonHand` backs the −10 out. `HeartsGame.isValidRound` extracted from RoundInputView.
- `HeartsScoreboardTests` unit-test target (13 tests) + scheme test action in project.yml. **Overlaps the Duo plan's "tests via xcodegen targets" item — reuse this target.**
- project.yml now reproduces the committed xcodeproj (effective build settings identical in Debug/Release vs prior HEAD; versions 3.4.0/3, LSApplicationCategoryType, Info.plist keys, LastUpgradeCheck). Before this, `xcodegen generate` silently dropped display name, version vars, encryption flag, orientations and Assets from the build.
- New strings translated into all 75 locales.

### Findings / follow-ups
- [x] (Fixed 2026-10-26.) `sr-Latn.lproj` existing strings are Cyrillic (transliterated, e.g. "Хеартс Сцоребоард"), not Latin; new 10♦ entries are Latin, so the file is mixed. Re-translate sr-Latn.
- [ ] Existing "shoot the moon" translations look literal/machine-made in az, am, my, km, lo, mk, uz, ka, hy, kn, ml, si, zu — native review.
- [ ] Gendered "taken by" phrasing (ru, uk, bs, hr, sr) uses "взял(а)"/"uzeo/la" forms — native review.
- [x] (Done: moon cell shows a small −10; HeartsGame.moonCellTenOfDiamondsBonus.) Moon cells show only the moon icon, so a shooter's −10 (10♦) isn't visible as a number — only the ♦ marker shows it (totals are correct).
- [ ] "Select who took the 10♦" (Submit hint): native check of case/particle endings in am, az, hu, tr, uz, fi, mn, ne, pa, si, ta, te, kn, ml, mr, gu, ka, hy, kk, my, zu; ka/ml/ta/te labels are long (may truncate on the full-width button).
- [x] (Done: FlowLayout and canSubmit preserved.) Coordinate with Duo work: `RoundInputView` now has a private `FlowLayout` for the 10♦ chips and a `canSubmit` gate — keep both when making rows flexible.
- [ ] "10 of Diamonds" Settings header: native check of suit term in az, eu, hy, km, lo, mn, uz, ka, sw, zu, ar, lt, lv, cy, is, si, ta, te, kn, ml.

### Duo wide layout (2026-10-24, uncommitted)
- [x] GameView: `horizontalSizeClass == .regular` -> `splitLayout` (scoreboard left, inline `RoundInputView` right, gap centered on the fold, max width 1200); Next Round button hidden; game over shows trophy + status in the right pane.
- [ ] Unfolded Duo checked by the user in DeviceHub and captured in screenshots; partial-fold posture still unverified. (Was: simctl cannot fold/unfold (inner display stays black; powering the outer screen off crashes SpringBoard). Verified on iPad Pro 13" (regular/regular) instead. Verify on hardware / DeviceHub UI.
- [x] iPad landscape light/dark screenshots reviewed 2026-10-27; see iPhone landscape scoreboard section. Live orientation regression follow-up remains tracked separately.

### Build gotcha (2026-10-24)
- `xcodebuild` hung indefinitely with no output (blocked in `NSFileCoordinator` reading the .xcodeproj) while Xcode.app had the project open after `xcodegen generate` rewrote it. Quitting Xcode fixed it. If a CLI build hangs before any build output, check for an open Xcode first.

## UI/UX review (2026-10-24, 3 parallel reviewers; key claims spot-checked against code)

Verified: no haptics anywhere; no `AccentColor` in asset catalog (only AppIcon); undo uses a blocking `.alert`; Submit is hard-coded `Color.blue`; history empty state is plain `Text`; History/Settings toolbar icons have no a11y label; score cells labelled only `"\(score)"` (GameView.swift:524); no `keyboardShortcut`/`FocusState`/`accessibilityReduceMotion` in Views; pass-direction arrows baked into localized strings ("Pass: Left ←"). Correction to a reviewer claim: stepper width is `@ScaledMetric` 34 (scales), height uses `tapSize`.

### Tier 1 — high impact, small effort
- [x] Haptics: `.sensoryFeedback` on chip/stepper taps (.selection), round submit (.success), undo (.warning), game over (.success).
- [x] Round input: live "18 / 26 — 8 left" / "4 over" strip above Submit; replace 50%-opacity disabled Submit with labelled state; `.borderedProminent` + `.controlSize(.large)`.
- [x] Round input: Quick-add slider moved to Settings (user chose to keep the Shoot-the-Moon picker in round entry).
- [x] Leader not color-only: crown/trophy symbol on leader badge (PlayerScoreViews.swift:15-21), `.accessibilityValue("Leading")`; bigger `.monospacedDigit()` totals with `.contentTransition(.numericText())`.
- [x] VoiceOver labels: History, Settings, About, moon chip, ± steppers, dealer badge; score cells "Round 3, Alice: 13 points[, took 10♦]"; headers `.isHeader`; HistoryDetailView `ScoreCellView` has none.
- [x] History list: two-line rows (winner + score, then all players' totals), relative date, drop fake "Time / Winner" header; `ContentUnavailableView` empty state (HistoryView.swift:15).
- [x] Brand: add `AccentColor` (light/dark) + a `Theme` file for the felt-green palette; replace raw RGB duplicated in GameView/HistoryDetailView and `.tint(.blue)` calls; Settings currently looks stock blue/white.

### Tier 2 — high impact, medium effort
- [x] (Done: GameOverView card + confetti, Rematch, View history.) End-of-game moment: winner sheet/overlay (trophy, ranked standings, confetti gated on Reduce Motion, Rematch / View history). Today only subtitle text changes and Next Round goes dead.
- [x] (Done: UndoToastView + redo stack; tap a cell/rail to edit via updateHand; archive reconciled on undo/edit.) Undo without alert + "Undone — Redo" toast; edit any past round by tapping its row (needs `GameViewModel.updateHand(id:)` + tests).
- [x] (Done: round rail, 26 highlight, "No rounds yet".) Scoreboard readability: round-number rail, per-player progress bar toward ending score (amber/red near the end), highlight 26s; empty state "No rounds yet".
- [x] (Done.) History detail: Swift Charts cumulative-score `LineMark` per player + `RuleMark` at ending score; stats row (rounds, moons, 10♦, biggest hand); hero line "Deuce won with 54" + rule summary from `completedGame.settings`; flexible cell widths on iPad.
- [x] (Done: @ScaledMetric/minHeight/ViewThatFits; scoreboard type size capped per player count.) Dynamic Type: fixed `frame(height: 26)` cells, `frame(width: 36, height: 26)` total badge, `.system(size: 9)` ♦ glyph, fixed bottom-bar HStack → `@ScaledMetric` / `minHeight` / `ViewThatFits`.
- [x] (Done: Recent players chips.) Reuse player names from history (suggestion chips/menu in Settings), placeholder "Player N".

### Tier 3 — polish
- [x] (Done: … menu + Undo + full-width Next Round.) Bottom bar: full-width prominent Next Round; move destructive New Game to a menu.
- [x] (Done.) Header: replace "Hearts Scoreboard" title with pass-direction chip + "Round N" + target; remove hard-coded `.padding(.horizontal, 70)`.
- [x] (Done: PassDirectionChip; English-only chip titles.) Pass direction: render arrow as SF Symbol `Label` instead of glyph in strings (RTL + VoiceOver); needs new keys across all locales via scripts/.
- [x] (Done.) Settings regroup: Players (incl. dealer picker) / Game Rules / Appearance / About as pushed `NavigationLink`; replace `.id(appearanceVersion)` hack (SettingsView.swift:121).
- [x] (Done 2026-10-25: Announcer helper, Reduce Motion gating, solid fallbacks for Reduce Transparency/Increase Contrast; VoiceOver flow still needs a device.) Accessibility announcements on round submit/game over; Reduce Motion for springs + repeating `.symbolEffect(.bounce)`; Increase Contrast / Reduce Transparency fallbacks for white-on-gradient and materials.
- [x] (Done; keyboard/hover/hold-repeat unverified without a device; ⇧⌘Z is an invisible button, ⌘N compact only.) iPad: ⌘↩ submit, ⌘N next round, ⌘Z undo, ⌘, settings; `.hoverEffect()` on custom buttons; 44pt chip min height; long-press-repeat on +.
- [x] (Done: under VoiceOver the hint is appended to the round-added announcement, no overlay.) Shake hint: 3s auto-dismiss too short for VoiceOver; announce instead when VO running.
- [x] (Done; PayPal link kept per user.) About: header with icon/name, group links, `ShareLink`, version in footer, single tint. PayPal $5 donate link (AboutView.swift:10) may conflict with App Review rules on donations from non-nonprofits — decide.

### Feature ideas (not yet decided)
- [x] (Done: Games | Players picker.) Players leaderboard tab in History (games, wins, win %, avg score, moons) derived from `model.history` — no new storage.
- [x] (Done: ResultCardView + ShareLink from game-over card and history detail.) Share result card via `ImageRenderer` + `ShareLink` from game over and history detail.
- [ ] Widget / Live Activity (new extension + App Group) — larger; defer.

## Screenshot pipeline (2026-10-24, uncommitted)
- Added `scripts/screenshots.sh`, `scripts/strip_alpha.swift`, `HeartsScoreboardUITests` + scheme `HeartsScoreboardScreenshots`, DEBUG-only `ScreenshotDemo`.
- [x] Initial `duo-open` set captured via DeviceHub 2026-10-24 (`SCREENSHOT_LARGEST_SCREEN` for inner display). Regeneration after the iPad redesign remains open below; DeviceHub requires a human to unfold the Duo.
- [ ] Only the Duo device type exists on the iOS 27.1 runtime; other devices run on iOS 27.0 (dedicated "HS Screenshots ..." sims). Revisit when 27.1 supports iPhone/iPad.
- [ ] Non-English locales untested: UI tests use identifiers, but demo player names / dates are English-only and Apple-locale rendering of the fixed dates is unchecked.
- [x] (Done: deleted, README points at new folders.) Old `screenshots/iOS` (1284x2778) and `screenshots/iPadOS` (2048x2732) are stale sizes; decide whether to delete and update the README Screenshots section to the new folders.
- [x] (Accepted as-is.) Main shot is an in-progress game (old one was a finished game with "won!"); the Game Summary shot is a separate completed game in history.
- [x] (Accepted as-is.) iPad/Duo-open "Round Input" shows the inline panel; no keyboard-based entry is shown anywhere.
- [x] (Done: scripts/check_screenshot_identifiers.sh, run first by screenshots.sh.) Add a CI/lint check that the identifiers used by `ScreenshotTests` still exist (a rename silently breaks the pipeline until run).
- [x] (Done: build-for-testing once + test-without-building per device.) Screenshot run takes ~1.5-4.5 min per device (first build + sim boot); consider `build-for-testing` once and `test-without-building` per device.

### Tier-1 implementation (2026-10-24, uncommitted)
- Felt-green `AccentColor` (light #1F7A3B / dark #389E57) + `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` in project.yml; shared palette in `Views/Theme.swift` (felt gradient, card, dealer badge, gold `Theme.leader`).
- Leader: crown + gold border, "Leading" a11y value, bigger monospaced totals with numericText, progress bar toward ending score (amber ≥75%, red ≥90%), "%d to go" under the highest scorer, Increase Contrast handling. Helpers in GameViewModel, tests in `LeaderIndicatorTests`.
- History rows derive from `CompletedGame` extension (`sortedResults`, `roundCount`, `hadMoonShot`), tests in `CompletedGameSummaryTests`.
- 24 new keys added to all 75 locales. Google Translate was CAPTCHA-blocked (429), so translations were LLM-generated and validated for specifier types and positions (caught 5 locales that swapped `%@`/`%d` and would have crashed; fixed with positional specifiers). Native review is still worthwhile, especially "Leading", "History" and "points".
- Verified: 44 unit tests pass; screenshot UI tests pass on iPhone 17 + iPad Pro 13 (light/dark main, round input, summary, settings, history list checked visually).

### Follow-ups found during implementation
- [x] (Done: gated on GameViewModel.localRoundToken; regression test in UndoTests.) Round-added haptic/announcement also fires when a single round arrives via iCloud sync (bulk restores are filtered by `new == old + 1`). Could gate on a local-submit token.
- [x] (Done 2026-10-26.) Unused keys left in all locales: "Time", "No completed games yet."; "Winner" is still used.
- [x] Pluralization fixed 2026-10-26 via `%lld rounds` stringsdict in all 75 locales; see ranked item 6 and `PluralRoundsTests`.
- [x] (Fixed 2026-10-26.) sr-Latn Localizable.strings was actually Cyrillic.
- [x] (Done: extracted into private ViewModifiers in GameView.swift.) GameView `body` modifier chain is near the type-checker limit; adding modifiers there tripped "unable to type-check in reasonable time". Extract into ViewModifiers before adding more.
- [x] (Done: header dropped.) Settings: "Ending Score" section header + "Ending Score: 100" row duplicate (pre-existing, Tier 3 regroup).
- [x] (Done: AX3/xxxL snapshot cases in DuoLayoutSnapshotTests; no crown/dealer overlap.) Not tested at accessibility Dynamic Type sizes, or with 6 players in the split layout (crown vs dealer badge overlap).

### Simulator / DeviceHub issues (2026-10-24)
- iOS 27.0 and 26.4 runtimes were removed mid-session (likely a disk cleanup); the iPhone/iPad screenshot sims need 27.0 (27.1 only supports the Duo). Restore with `xcodebuild -downloadPlatform iOS -buildVersion 27.0`.
- `xcodebuild` test runner can crash at bootstrap ("Early unexpected exit"); `xcrun simctl shutdown all` and retry.
- DeviceHub can only show/unfold a sim it booted itself; a headless `simctl boot` makes its Start fail with "current state: Booted". `screenshots.sh` now leaves duo-open booting to DeviceHub.
- [x] (Fixed by a Mac restart.) After the 27.0 runtime install, DeviceHub's Start boots the sim (simctl shows Booted) but never attaches a display — same for every Duo sim, and survived quitting DeviceHub, `simctl erase`, and restarting CoreSimulatorService. Duo Open screenshots blocked until DeviceHub works again (try a Mac restart).
- [x] (Done: visible unscrolled with 4 players.) Duo open inline round-entry panel: the "Add 26 / Subtract 26" segmented control is partly hidden behind the pinned Submit area until scrolled (visible in `screenshots/iPhone Duo Open/1 - Main.png`). Fixing it means regenerating the duo-open screenshots.
- [x] (Done.) At accessibility Dynamic Type (AX3) the ♦ marker overlaps the last digit of "-10" score cells and the crown covers the leader's total (e.g. "-19").
- [x] (Done: stacked rows + 2x2 chips + icon-only Reset at accessibility sizes.) Inline RoundInputView (split layout) at accessibility Dynamic Type (AX3) is broken: names clipped on the leading edge, chips overflow the trailing edge, "Round N"/"Reset" wrap (DuoLayoutSnapshotTests inner-6p-10d-portrait-ax3).
- [x] (Done 886e92b: machine-translated into all locales.) English-only strings pending translation (user decision 2026-10-25): "Game Rules", "Recent players", "Add %@", "Share App"; history/leaderboard keys ("Rounds", "Moons", "Score by round", "%@ won with %d", "Players", "Wins", "Avg score", etc. — see en.lproj tail); game-over keys ("Rematch", "Results", "Winner(s)", "Final standings", "%lld points", ...); share keys ("Share result", "%lld rounds", "1 round", "Hearts Scoreboard result"); header keys ("Left", "Right", "Across", "Hold", "to %d", "No rounds yet", "More"); undo/edit keys ("Round %d undone", "Redo", "Edit Round %d", "Save", ...); "Redo available".
- [x] (Done: ViewThatFits compact layout.) Game-over card in the split layout on a landscape unfolded Duo clips the 4th standings row (scrolls); consider a compact row height there.
- [x] (Removed 2026-10-26.) Unused after header redesign: "Pass: Left ←"-style keys and the "Hearts Scoreboard" title in GameView (verify with grep before removing in the unused-keys cleanup).
- [x] (Checked 2026-10-26; findings in "## RTL audit (2026-10-26)" below.) Header/scoreboard redesign not checked in RTL, and the dark-mode 26 tint / empty-state "No rounds yet" have no snapshot.
- [ ] Check in the running app: edit-round sheet layout (snapshot harness squeezes sheets), shake-to-undo + toast, toast over the stacked bottom bar at accessibility sizes, VoiceOver flow. Edit-mode totals were fixed separately (see next completed item); do not treat that historical observation as an open bug.
- [x] (Removed 2026-10-26.) Unused keys now: "Undo last round" alert strings.

- [x] (Done 2026-10-25: HeartsGame.totals(excluding:), snapshot cases added.) Edit mode totals included the edited round; empty board / dark 26 highlight / Increase Contrast snapshots.
- [ ] Reduce Transparency has no snapshot (not settable via traits). Score cells are labelled per cell, not per round row; a row-wise VoiceOver order would need a layout restructure.
- [x] (Done 2026-10-26: `Theme.feltChipFill/Label/Border`: lifted felt green with a white label in dark; light unchanged.) Dark mode: More/Undo chips render near-black (systemBackground on felt); consider a lighter chip fill.
- Note (2026-10-25): the Duo simulator remembers its DeviceHub fold posture across runs. A duo-folded run after an unfolded session captured the dark outer display (all-black PNGs). screenshots.sh now fails on single-colour images; fold the Duo in DeviceHub before duo-folded.

## 4.0.0 release (2026-10-25)

- [x] Build 4.0.0 (4) uploaded; App Store Connect version 4.0.0 created with build 4 attached; screenshots uploaded (6.3", 6.9", Duo folded + open, iPad 13"); old 3.4 iPad and 6.5" sets removed from 4.0.0; What's New + description set in all 39 ASC locales (0aa7107). NOT submitted for review; the user does that.
- App Store Connect rejects "♦" in metadata ("invalid characters"); use "10 of Diamonds" in App Store text. In-app strings can keep ♦.
- Google Translate (deep-translator) was rate-limited for this pass, so App Store metadata translations were LLM-generated. Native review is worthwhile, especially am, az, bn, cy, eu, fa, hy, ka, kk, km, lo, mk, ml, mn, mr, my, ne, pa, si, sw, ta, te, ur, uz, zu, and game names (pl "Kierki", ru "Червы", nl "Hartenjagen", pt/pt-PT "Copas", zh-Hant "傷心小棧", zh-Hans "红心大战").
- [ ] Non-English ASC locales fall back to the English screenshots (no localized screenshots).


## Visual polish follow-ups (2026-10-25)

- [x] (Done 2026-10-27.) iPhone Air 0–26 score-picker popover could compress the six fixed-width columns' surrounding padding, clipping the outer cells against its rounded corners. `PointsGridPicker` now preserves its intrinsic grid width and adds 24pt horizontal inset. Regression: `IPadLayoutSnapshotTests.testValuePickerKeepsItsWidthWhenPopoverOffersOnlyGridWidth` verifies a 294pt proposal still returns at least 342pt; `ValuePickerLayoutUITests` opens the second player's picker with six players, captures the layout, and selects 26. Both tests passed; screenshots verified on iPhone Air and iPad Pro 11-inch (M5), light/dark. Results and screenshots: `/private/tmp/hs-picker-width-unit.xcresult`, `/private/tmp/hs-value-picker-air-{light,dark}.xcresult`, `/private/tmp/hs-value-picker-ipad-{light-retry,dark}.xcresult`, `/private/tmp/hs-picker-shots/` (Air light attachment in `/private/tmp/hs-picker-air-light-attachment/`).

- [x] (Done 2026-10-26: `PassDirectionChip` is a ViewThatFits, full word else arrow-only, with the spoken title kept as the accessibility label.) Main-screen pass-direction pill truncates to "← L…" at XXXL Dynamic Type on iPhone Air (pre-existing; seen while verifying bottom-bar heights).
- [x] Bottom-bar chip height uses `@ScaledMetric` 35pt tuned to match Next Round; at XXXL the chips run a few pt taller than Next Round. A layout-driven equal height (shared `maxHeight: .infinity` + `fixedSize(vertical:)`) would remove the magic number. (Done 2026-10-26: the scaled metric is gone; chips use `minHeight: 44, maxHeight: .infinity` and the bar HStack is `fixedSize(vertical:)`. Regression: `DuoLayoutSnapshotTests.testPolish*` measure chip vs Next Round pixels at default and XXXL.)
- [x] Named throwaway simulator cleanup completed 2026-10-27: removed remaining `chips-se` and `bar-ipad`; other named chips simulators were already absent. General-purpose and screenshot devices retained.
- [x] 10♦ "−10" badge over the holder's score was clipped at the top on iPad Pro 11" (inline rows, 2pt row inset): it was offset −16pt above the score. Now it sits inside the score's 44pt tap frame. Regression: `HeartsScoreboardUITests/TenBadgeUITests` (DEBUG launch flag `-screenshotTenRule`). The row's accessibility frame grows to include overflow, so the test compares against the stepper's minus button. It fails on the old code (badge 5.5pt above the row).

## Round entry alignment + 10♦ chip (2026-10-26, build 8)
- Root cause of pill/name misalignment: `PlayerTotalBadge` pads ~13pt above the capsule (crown headroom) and 4pt below, so in a center-aligned row the capsule sat ~4.7pt below the name's center. `RoundInputView` now passes `reservesCrownSpace: false` (symmetric padding) and gives the crown headroom via row insets.
- [x] 10♦ holder chip is now a real layout element (`sheetRow` in RoundInputView): left of the stepper when name + total + chip fit (iPad, wide phones); otherwise `ViewThatFits` falls back to the chip under the name (iPhone 17e with a long name / 3-digit total, and even "Cleo 61"). Nothing overlaps and the stepper column never moves.
- Code review (2026-10-26, /code-review medium vs origin/main; checked against the code):
  - [x] Not a bug: crown headroom in `sheetRow`. Screenshots on iPhone 17 (sheet), iPad Pro 13 (inline), and the iPhone 17e stacked layout show the crown unclipped. The 44pt stepper row has enough room without extra insets.
  - [x] Fixed: ScreenshotDemo 5–6 player rounds. `ScreenshotDemo.fit(_:to:)` keeps every round legal (26 points, or a moon shot), and 4-player data is unchanged. Regression: `ScreenshotDemoTests`. NarrowRoundEntryUITests no longer hard-codes totals; it finds the total via the new `playerTotal.<name>` accessibility identifier.
  - [x] Fixed: NarrowRoundEntryUITests now asserts at least 2 rows were measured, and the AX branch is inverted.
  - [x] Fixed: TenBadgeUITests waits for the sheet, then scrolls straight to the picker, and asserts the scroll back to the rows succeeds.
  - [ ] Minor: the one-line candidate builds hidden name blocks for every player in every row (n² views, n ≤ 6). Fine for now. Precompute a max width if stepper taps feel slow.
  - [x] (Deleted 2026-10-26.) `scripts/fix_ctx_keys.py` (untracked, already applied).
  - Rejected: an empty `tenChip` adding HStack spacing (a false `if` emits no child), duplicate a11y elements (the copies are `accessibilityHidden` and ViewThatFits renders one candidate), AnyView/`stackedLayout` style, and the Settings ⓘ About button (an intentional change in 90f7da4).
- [x] (Done 2026-10-26.) SE width / 6 players / AX sizes. Rows that can't fit name + total + stepper on one line now stack name over total instead of truncating ("Al…"). All non-holder rows decide together, sized to the widest player, so a list never mixes layouts. At SE width every row stacks. At 402pt, 4 players stay on one line, and 6 players (with "Alexandra") stack. AX crown clip fixed with a 20pt top inset. Regression: `NarrowRoundEntryUITests` (env PLAYERS/HOLDER/AX/CHIP_APPEARANCE/SHOT_DIR; DEBUG args `-screenshotPlayerCount`, `-screenshotTenHolder`).
- [ ] NarrowRoundEntryUITests is scroll-driven and was flaky while being written; watch it. Two Claude sessions running xcodebuild test on the same simulator deadlock: use a dedicated sim per session.

## RTL audit (2026-10-26)

Method: iPhone 17 / iOS 27.0 simulator, DEBUG `-screenshotDemo` data, `-AppleLanguages "(ar)"` and `(he)`, driven by a scratchpad-only XCUITest copy of the repo (no repo files touched). Locales present: ar, he, fa, ur. Only ar and he were run (fa/ur use the same RTL layout, untested). Screens: main (light/dark), round entry (with 10♦ rule and holder chip), history list, history detail with chart, game-over card, settings. Screenshots: scratchpad `rtl-ar-*.png` and `rtl-he-*.png` (01 main, 02 scrolled, 03-06 entry, 07 history, 08-09b detail, 10-11 settings, 12 dark, 13 game over, 14 main after game over).

Findings:
- [x] (Fixed 2026-10-26: `DirectionalUI.backSymbol` = `chevron.backward`; no other fixed-direction back/next chevrons in Views. Pass-direction arrows left alone.) **med** Round entry sheet, Back button: `Label("Back", systemImage: "chevron.left")` (`RoundInputView.swift:88`). `chevron.left` is a fixed-direction symbol and does not mirror, so in RTL the button sits at the top right but points left (away from the screen edge it goes back to). Fix: `chevron.backward`. (The History detail Back chevron is the system one and is correct.)
- [x] (Fixed 2026-10-26: `DirectionalUI.nextRoundSymbol` = `arrow.forward.circle.fill`.) **med** Main screen bottom bar, "Next Round": `systemImage: "arrow.right.circle.fill"` (`GameView.swift:721`) points right in RTL, which is backwards for "next". Fix: `arrow.forward.circle.fill` (mirrors), or flip with `.flipsForRightToLeftLayoutDirection(true)`. Same arrow in he.
- [x] (Fixed 2026-10-26: Chart forced LTR via `DirectionalUI.chartLayoutDirection`; rounds read 0→N left to right, y labels stay trailing as in English.) **med** History detail, "Score by round" chart (`HistoryDetailView.swift:~117-150`). Swift Charts mirrors the x axis in RTL, so time runs right to left (round 0 at the right edge), while the y-axis labels stay on the left. This mixes the two conventions. Fix: either force the chart LTR (`.environment(\.layoutDirection, .leftToRight)` on the `Chart`; simplest, Western-numeral round numbers read the same either way) or keep the mirror and move the y axis with `.chartYAxis { AxisMarks(position: .trailing) }`. The legend order and the "100" annotation looked fine.
- [x] (Fixed 2026-10-26: `DirectionalUI.quickAddTitle` wraps "+N" in LRI/PDI in code; locale strings untouched.) **low** Settings, "Quick-add button: +%d" row title (`SettingsView.swift:150`; strings `ar.lproj/Localizable.strings:164`, `he.lproj/Localizable.strings:164`). When `+5` is the last token in an RTL line, bidi puts the plus on the wrong side (renders as "5+" after the colon). The same `+5` in the footnote (mid-sentence) is fine. Fix: wrap the number in LRI/PDI (`\u{2066}+%d\u{2069}`) in the format string, or build it with `Text("\(...)").environment(\.layoutDirection, .leftToRight)`. Check the other trailing `+%d` / `-%d` strings too (the "10♦ equals −10" settings row rendered correctly).
- [x] (Not a bug, 2026-10-26: SwiftUI already mirrors `.offset(x:)` in RTL; the pre-change Arabic render overhung outward, and flipping the sign made it worse (centered over the pill). Code unchanged; regression `DirectionalUITests.testCrownOverhangMirrorsInRTL` asserts RTL margins are the LTR margins swapped.) **low** Scoreboard leader crown (`PlayerScoreViews.swift:88-96`). The overlay is `.topTrailing` (the top-left corner in RTL) but uses a physical `.offset(x: +crownSize*0.6)`, so it nudges inward over the pill instead of overhanging outward as it does in LTR. It does not collide with the digits at default size. Fix: multiply the x offset by -1 when `layoutDirection == .rightToLeft`.
- [x] (Fixed 2026-10-26: user chose − N + in all languages; `stepper(for:)` HStack gets `DirectionalUI.stepperLayoutDirection` (.leftToRight), the only −/+ points pair in the app; rest of row still mirrors. Regression `DirectionalUITests.testStepperRendersMinusLeftOfPlusInRTL`.) **low** Round entry stepper order. In RTL it is "+ 5 −" (plus on the left). Native `Stepper` keeps minus-left/plus-right in RTL, because numbers run left to right. Consider forcing the stepper cluster LTR (`.environment(\.layoutDirection, .leftToRight)`) so the control matches the iOS convention. Not clearly wrong, so a design call.
- [ ] **low** Not verified: the 10♦ "who took it" picker in the entry sheet. It sits below the fold behind the pinned submit bar, and my swipe did not bring it into view (same in English? not compared). The selected-holder chip stacked under the name correctly (`rtl-ar-06-entry-ten-chosen.png`). The ♦ markers in the main scoreboard were not shown in the demo data. Re-check with `-screenshotTenRule` plus a committed holder.
- [ ] **low** Not run: iPad (split layout `GameView.swift:160-175` uses `.padding(.leading/.trailing)` which mirrors, so likely fine), Dynamic Type AX sizes in RTL, fa/ur.

Looked correct:
- Pass-direction chip: "Left" (يسار / שמאלה) keeps `arrow.left` pointing left (`PassDirection.swift:27-29` uses non-mirroring `arrow.left`/`arrow.right`), so it stays semantically correct. The chip sits next to "Round 9 to 100", with no clipping in ar or he.
- Main scoreboard: player columns run right to left (first player at the right), the round-number rail is on the right, the totals pills, progress bars (fill grows from the right), "17 remaining" text, dealer badge, the ♠ moon/26 cells and the gold 26 tint all align; no truncated text. Crown is on the correct pill.
- Round entry: names/totals on the right, steppers and chips on the left, 10♦ holder chip, and the "23 / 26 · 3 remaining" bar and Submit button are all fine. Reset (left) / Back (right) swap sides correctly. Negative/plus numerals read correctly in the chips.
- History list: trophy and winner row, scores line, date and round-count capsule, disclosure chevron (points left in RTL, correct), and the tab picker all mirror correctly.
- History detail: summary tiles, scoreboard grid, title bar (share left, back right pointing right) look right.
- Game-over card: close left / share right, rank medals on the right, scores on the left, Rematch and History button icons next to labels all correct. The main screen after game over also looks right.
- Settings: player rows (handle left, delete right), the Add player row, dealer menu, sliders (min on the right, as the system mirrors them), toggle, appearance picker order all correct. "10♦ equals −10" renders as −10.


## iPad UI/UX redesign (2026-10-26/27) — implemented, needs real-device verification
Plan, decisions, per-phase notes: `docs/plans/ipad-redesign.md`. All five phases are committed on main; unit + UI suites green on the iPad Pro 13" (M5) simulator; App Store screenshots regenerated (duo-open untouched).
- [ ] Open: real-device verification (iPad with keyboard: Cmd shortcuts, Delete/Backspace, hold-Cmd menu; sheet keyboard path; partial-fold Duo).
- [x] Build 11 uploaded to TestFlight 2026-10-27 (5ddba0a).
- [x] Build 13 uploaded to TestFlight 2026-10-27 (build 12 was bumped but not confirmed uploaded; 13 supersedes it).
- [ ] Open: regenerate `duo-open` screenshots by hand in DeviceHub (script skips them with --non-interactive).
- [ ] Deferred polish (see plan, Phase 5): few-rounds state leaves empty felt under the scoreboard on iPad landscape; 6p on mini landscape / AX3 portrait scroll the entry rows; phone 6p initials ambiguity; compact width with 1 round leaves a tall empty card; `screenshots.sh` continues to run only `ScreenshotTests`.
- [x] Appearance simulator failure recheck (2026-10-27): the historical `AppearanceLiveSwitchUITests` failure on iPhone 17 Pro Max (where `XCUIDevice.appearance` did not flip the board) was not reproduced in two consecutive runs on the iPhone 17 Pro Max simulator, iOS 27.0, using build 11 source. Both runs passed direct Light/Dark live changes, System following device Dark/Light, and persistence after Done. Screenshots and result bundles are in `/private/tmp/hs-appearance-shots-repeat` and `/private/tmp/hs-appearance-result.xcresult`, `/private/tmp/hs-appearance-repeat-result.xcresult`. Keep the earlier simulator-specific failure as historical; the simulator behavior may remain intermittent.

## Round-entry 10♦ holder indicator stability (2026-10-27)

- [x] Fixed: moving or clearing the 10♦ holder indicator changed the name line's available width and height, which shifted the row. `RoundInputView.identity` now gives every player an intrinsic-size badge slot with a hidden copy of the chip whenever the rule is enabled; only the holder's visible copy is accessible. `TenBadgeUITests.testMovingTenBadgeDoesNotChangePlayerRowLayout` compares name, total, row, stepper and quick-chip positions and sizes relative to the first row, with no holder, a long-name holder, a moved holder and a cleared holder. Verified on iPhone 17 Pro Max and iPad Pro 13-inch (M5), iOS 27.0: movement and containment regressions pass in light mode; containment passes in dark mode (6 successful test cases). Light/dark screenshots reviewed. Results and screenshots: `/private/tmp/hs-ten-*`. The first new-simulator attempt timed out waiting for accessibility before any tests; the retry passed. Optional screenshot/hold environment: `SHOT_DIR`, `HOLD_BADGE_SECONDS`, `CHIP_APPEARANCE`.

- [x] Fixed in the orchestration pass below: `FlowLayout` returned a compressed width after measuring at the larger proposed width; placement could wrap Drew into unreserved space over the help text. Preserve the proposed width and expand the picker container. Original screenshot: `/private/tmp/hs-ten-iphone-dark-attachments/27D856BC-95C4-41BB-876B-B94BF9904A54.png`. Unit and live UI regressions added.

## History detail share export (2026-10-27)

- [x] History share image now reuses the same summary, stats, chart, and round-by-round scoreboard content as `HistoryDetailView`, rendered on a wide light felt canvas with natural height and an adaptive pixel budget for long games.
- [x] Shares export a PNG file named `Hearts-Scoreboard-YYYY-MM-dd-HHmm.png`; each export has a unique temporary folder so repeated shares on the same date do not replace an in-flight file.
- [x] Regression coverage checks descriptive local-time filenames, PNG encoding, and rendering a six-player history with long names and 100 rounds within the pixel budget. `HistoryShareUITests` covers opening the history share sheet in light and dark appearance.
- [x] Verification: simulator build and all 6 `ResultCardTests` pass, including named PNG encoding and six-player / 100-round export; screenshot identifier check passes. Actual four-player exported PNG and chart visually reviewed at `/private/tmp/hs-history-share-preview.png`; snapshots at `/private/tmp/hs-history-share-images`, unit result `/private/tmp/hs-history-share-unit3.xcresult`. Export width adapts to player count (528–708pt including padding), and renderer measures layout before applying a 32MP pixel budget.
- [x] UI verification completed in the all-share-cards pass below: history and game-over flows pass on iPhone/iPad in light/dark (8 cases), including Save to Files and the suggested filename prefix. Full filenames/PNG bytes are covered by unit tests. Earlier orchestration simulator stalls are superseded for sharing; logs retained under `/private/tmp/hs-orch-share-*`.

## Orchestration bug-fix pass (2026-10-27)

- [x] Persist optional Q♠ ownership; legacy payloads remain decodable. Regression includes persisted sync payload with the 10♦ holder, edit transfer, undo/redo and legacy JSON.
- [x] Fix 10♦ picker measurement/placement mismatch: `FlowLayout` preserves the proposed width so an extra wrapped chip cannot occupy unreserved height over the help text. Focused phone UI regression passed; deterministic layout-width regression added.
- [x] Fix brittle history share test: the tested system sheet shows Save to Files but no Save Image. Check the exported filename using Save to Files; Files truncates its accessible suggestion, so the UI checks its prefix; `ResultCardTests` cover the full `.png` filename and encoding. The corrected iPhone dark end-to-end flow passed (`/private/tmp/hs-orch-share-iphone-dark.xcresult`).
- [x] Split the iPad orientation matrix into independent tests, preserving layout assertions and removing the historical explicit termination loop that failed before the final case.
- [x] Fixed duplicate hand IDs in game-over snapshot fixtures: repeated score rows now have distinct UUIDs, removing undefined SwiftUI ForEach identity. The earlier 50 Duo cases passed; rerun the changed fixture in the focused regression set.
- [ ] Verification remains open: the recovered unit run passed 106 tests before cancellation in the 162-image iPad matrix (`/private/tmp/hs-orch-unit-dd/Logs/Test`, run 19-02-16). Current app/test targets compile, but the rebuilt focused queen-persistence/FlowLayout/game-over/export regression run stalled before producing results (`/private/tmp/hs-orch-focused.xcresult` incomplete). Do not count the new queen persistence or layout-width regression as passed. Phone dark and iPad dark picker regressions passed in earlier focused runs; final light/dark matrix, iPad share and isolated long/dark orientation still need completion. Simulator startup stalls persisted across retries; no new app assertion failure was established by those stalls.
- [ ] User physical-device checklist pending; no native-language reviewer available in this pass. Keep hardware/native review, manual Duo screenshot refresh and release selection open. Deferred features remain deferred by user decision.

- Final simulator handoff: resumed focused picker/iPad-share runs compiled but stalled before assertions and were interrupted; no additional passes claimed. Existing iPhone dark and iPad light/dark picker captures were visually reviewed; phone light final capture is missing (available candidate was Home Screen). New iPad share screenshots and isolated long/dark orientation remain open. Direct Device Hub UI fallback also timed out. Use one warmed simulator for the next verification attempt; avoid parallel cold starts.

## All share cards audit (2026-10-27)

- [x] Audited every share entry point: history and game-over export result images; About shares the App Store URL.
- [x] Game-over exports now use the same full-detail image as history (summary, rules, stats, chart, totals and all rounds), on both phone overlay and iPad pane. A caller without completed-game data retains the branded standings fallback.
- [x] Game-over prefers the saved history record, preserving the original finish timestamp and descriptive PNG filename across both entry points. All image exports use `NamedPNGFile` and distinct temporary folders.
- [x] Sharing refreshes when an edited/redo’d completed game changes while retaining its ID/date; value-based task identity has a regression. For legacy/demo completed games without an archive, fallback identity and finish time come from the game ID and last recorded hand.
- [x] Verification: all 9 `ResultCardTests` pass (`/private/tmp/hs-allshare-unit-final.xcresult`); 8 end-to-end history/game-over filename checks pass on iPhone/iPad in light/dark (`/private/tmp/hs-allshare-iphone.xcresult`, `/private/tmp/hs-allshare-ipad-final.xcresult`). Screenshots visually reviewed under the matching folders; final `simctl` captures are `/private/tmp/hs-allshare-iphone-final.png` and `/private/tmp/hs-allshare-ipad-final.png`. Initial iPad attempt was superseded by a successful retry after the fallback stabilization. Screenshot identifiers and diff whitespace checks pass.
