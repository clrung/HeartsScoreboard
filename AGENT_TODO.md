# Agent TODO

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
- [ ] Inline entry Form scrolls at Duo inner size for 4 players in landscape and 6 players in portrait (Submit stays pinned); 10♦ picker sits below the fold with 6 players. Consider compacting rows.
- [x] 6-player header names truncate to ~3 chars in the ~300pt scoreboard pane. Fixed: split layout with 6 players shows initials (`HeartsGame.headerLabels`, collisions -> 2 letters -> full name; full name kept as accessibility label).

### Planned work
- [x] Cap/center main content width on regular width (1200pt cap); score cells shrink with column.
- [x] Wide layout: scoreboard + inline round input side-by-side on regular width, 40pt gap at the center fold (`GameView`).
- [x] Flexible `RoundInputView` row layout (Grid / flexible frames); `presentationSizing(.form)`; `presentation: .sheet | .inline`.
  - [ ] Follow-up: no unit test for the inline reset after submit (entry state is private `@State`; would need extracting an entry-state type).
  - [ ] Follow-up: chips are 32pt tall (below the 44pt tap target) to keep two chip rows per player row.
- [x] Visible Undo button; restore shake first responder after sheets (`ShakeDetectorView.refocusToken`, regression test in `UndoTests.swift`).
  - [ ] Follow-up: the 0.5s re-focus retry after sheet dismissal is a timing guess — verify shake works after closing each sheet on a device.
- [x] Pin device family + orientations in `project.yml` (done in the 10♦ work).
- [x] Unit tests (25: 10♦, undo, Duo snapshot harness). No XCUITest target yet.
- [ ] New App Store screenshot size set for the new device (1398×2034 outer / 2007×2853 inner per blogs — verify in App Store Connect). Unfolded sim can't be driven from CLI; capture via DeviceHub UI or device.
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
- [ ] `sr-Latn.lproj` existing strings are Cyrillic (transliterated, e.g. "Хеартс Сцоребоард"), not Latin; new 10♦ entries are Latin, so the file is mixed. Re-translate sr-Latn.
- [ ] Existing "shoot the moon" translations look literal/machine-made in az, am, my, km, lo, mk, uz, ka, hy, kn, ml, si, zu — native review.
- [ ] Gendered "taken by" phrasing (ru, uk, bs, hr, sr) uses "взял(а)"/"uzeo/la" forms — native review.
- [ ] Moon cells show only the moon icon, so a shooter's −10 (10♦) isn't visible as a number — only the ♦ marker shows it (totals are correct).
- [ ] "Select who took the 10♦" (Submit hint): native check of case/particle endings in am, az, hu, tr, uz, fi, mn, ne, pa, si, ta, te, kn, ml, mr, gu, ka, hy, kk, my, zu; ka/ml/ta/te labels are long (may truncate on the full-width button).
- [ ] Coordinate with Duo work: `RoundInputView` now has a private `FlowLayout` for the 10♦ chips and a `canSubmit` gate — keep both when making rows flexible.
- [ ] "10 of Diamonds" Settings header: native check of suit term in az, eu, hy, km, lo, mn, uz, ka, sw, zu, ar, lt, lv, cy, is, si, ta, te, kn, ml.

### Duo wide layout (2026-10-24, uncommitted)
- [x] GameView: `horizontalSizeClass == .regular` -> `splitLayout` (scoreboard left, inline `RoundInputView` right, gap centered on the fold, max width 1200); Next Round button hidden; game over shows trophy + status in the right pane.
- [ ] Not verified on the Duo unfolded display: simctl cannot fold/unfold (inner display stays black; powering the outer screen off crashes SpringBoard). Verified on iPad Pro 13" (regular/regular) instead. Verify on hardware / DeviceHub UI.
- [ ] iPad landscape (1376pt wide, hits the 1200 cap) not screenshotted: simctl has no rotate command.

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
- [ ] End-of-game moment: winner sheet/overlay (trophy, ranked standings, confetti gated on Reduce Motion, Rematch / View history). Today only subtitle text changes and Next Round goes dead.
- [ ] Undo without alert + "Undone — Redo" toast; edit any past round by tapping its row (needs `GameViewModel.updateHand(id:)` + tests).
- [ ] Scoreboard readability: round-number rail, per-player progress bar toward ending score (amber/red near the end), highlight 26s; empty state "No rounds yet".
- [ ] History detail: Swift Charts cumulative-score `LineMark` per player + `RuleMark` at ending score; stats row (rounds, moons, 10♦, biggest hand); hero line "Deuce won with 54" + rule summary from `completedGame.settings`; flexible cell widths on iPad.
- [ ] Dynamic Type: fixed `frame(height: 26)` cells, `frame(width: 36, height: 26)` total badge, `.system(size: 9)` ♦ glyph, fixed bottom-bar HStack → `@ScaledMetric` / `minHeight` / `ViewThatFits`.
- [ ] Reuse player names from history (suggestion chips/menu in Settings), placeholder "Player N".

### Tier 3 — polish
- [ ] Bottom bar: full-width prominent Next Round; move destructive New Game to a menu.
- [ ] Header: replace "Hearts Scoreboard" title with pass-direction chip + "Round N" + target; remove hard-coded `.padding(.horizontal, 70)`.
- [ ] Pass direction: render arrow as SF Symbol `Label` instead of glyph in strings (RTL + VoiceOver); needs new keys across all locales via scripts/.
- [ ] Settings regroup: Players (incl. dealer picker) / Game Rules / Appearance / About as pushed `NavigationLink`; replace `.id(appearanceVersion)` hack (SettingsView.swift:121).
- [ ] Accessibility announcements on round submit/game over; Reduce Motion for springs + repeating `.symbolEffect(.bounce)`; Increase Contrast / Reduce Transparency fallbacks for white-on-gradient and materials.
- [ ] iPad: ⌘↩ submit, ⌘N next round, ⌘Z undo, ⌘, settings; `.hoverEffect()` on custom buttons; 44pt chip min height; long-press-repeat on +.
- [ ] Shake hint: 3s auto-dismiss too short for VoiceOver; announce instead when VO running.
- [ ] About: header with icon/name, group links, `ShareLink`, version in footer, single tint. PayPal $5 donate link (AboutView.swift:10) may conflict with App Review rules on donations from non-nonprofits — decide.

### Feature ideas (not yet decided)
- [ ] Players leaderboard tab in History (games, wins, win %, avg score, moons) derived from `model.history` — no new storage.
- [ ] Share result card via `ImageRenderer` + `ShareLink` from game over and history detail.
- [ ] Widget / Live Activity (new extension + App Group) — larger; defer.

## Screenshot pipeline (2026-10-24, uncommitted)
- Added `scripts/screenshots.sh`, `scripts/strip_alpha.swift`, `HeartsScoreboardUITests` + scheme `HeartsScoreboardScreenshots`, DEBUG-only `ScreenshotDemo`.
- [ ] `duo-open` never run: needs a human to unfold the Duo in DeviceHub; inner-display capture via XCUIScreen unverified.
- [ ] Only the Duo device type exists on the iOS 27.1 runtime; other devices run on iOS 27.0 (dedicated "HS Screenshots ..." sims). Revisit when 27.1 supports iPhone/iPad.
- [ ] Non-English locales untested: UI tests use identifiers, but demo player names / dates are English-only and Apple-locale rendering of the fixed dates is unchecked.
- [ ] Old `screenshots/iOS` (1284x2778) and `screenshots/iPadOS` (2048x2732) are stale sizes; decide whether to delete and update the README Screenshots section to the new folders.
- [ ] Main shot is an in-progress game (old one was a finished game with "won!"); the Game Summary shot is a separate completed game in history.
- [ ] iPad/Duo-open "Round Input" shows the inline panel; no keyboard-based entry is shown anywhere.
- [ ] Add a CI/lint check that the identifiers used by `ScreenshotTests` still exist (a rename silently breaks the pipeline until run).
- [ ] Screenshot run takes ~1.5-4.5 min per device (first build + sim boot); consider `build-for-testing` once and `test-without-building` per device.

### Tier-1 implementation (2026-10-24, uncommitted)
- Felt-green `AccentColor` (light #1F7A3B / dark #389E57) + `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` in project.yml; shared palette in `Views/Theme.swift` (felt gradient, card, dealer badge, gold `Theme.leader`).
- Leader: crown + gold border, "Leading" a11y value, bigger monospaced totals with numericText, progress bar toward ending score (amber ≥75%, red ≥90%), "%d to go" under the highest scorer, Increase Contrast handling. Helpers in GameViewModel, tests in `LeaderIndicatorTests`.
- History rows derive from `CompletedGame` extension (`sortedResults`, `roundCount`, `hadMoonShot`), tests in `CompletedGameSummaryTests`.
- 24 new keys added to all 75 locales. Google Translate was CAPTCHA-blocked (429), so translations were LLM-generated and validated for specifier types and positions (caught 5 locales that swapped `%@`/`%d` and would have crashed; fixed with positional specifiers). Native review is still worthwhile, especially "Leading", "History" and "points".
- Verified: 44 unit tests pass; screenshot UI tests pass on iPhone 17 + iPad Pro 13 (light/dark main, round input, summary, settings, history list checked visually).

### Follow-ups found during implementation
- [ ] Round-added haptic/announcement also fires when a single round arrives via iCloud sync (bulk restores are filtered by `new == old + 1`). Could gate on a local-submit token.
- [ ] Unused keys left in all locales: "Time", "Winner", "No completed games yet." (history header/empty state). Remove in a cleanup pass.
- [ ] `%d rounds` isn't pluralized (stringsdict); harmless today (finished games always have >1 round).
- [ ] sr-Latn Localizable.strings is actually Cyrillic (pre-existing); new keys were added in Latin.
- [ ] GameView `body` modifier chain is near the type-checker limit; adding modifiers there tripped "unable to type-check in reasonable time". Extract into ViewModifiers before adding more.
- [ ] Settings: "Ending Score" section header + "Ending Score: 100" row duplicate (pre-existing, Tier 3 regroup).
- [ ] Not tested at accessibility Dynamic Type sizes, or with 6 players in the split layout (crown vs dealer badge overlap).
