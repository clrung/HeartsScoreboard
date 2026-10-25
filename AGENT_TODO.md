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
