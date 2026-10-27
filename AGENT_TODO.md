# Agent TODO

## Next up (ranked, /next 2026-10-26)
Completed since last pass: d9ce187 (round-entry totals centered, 10♦ chip replaces −10 badge, build 8). Working tree clean except `scripts/fix_ctx_keys.py`.

1. [ ] **Ship 4.0.0 build 8** (S): upload build 8, attach it to the 4.0.0 version in App Store Connect, submit for review (the user submits). Everything since build 4 is unreleased.
2. [x] **Verify round entry at the edges** (done 2026-10-26: SE 375pt, 6 players, AX sizes, light/dark; iPhone 18 Pro 402pt rechecked): iPhone SE width, 6 players, and AX Dynamic Type with the 10♦ chip. These are the open items from the build-8 work, and that layout code is the newest.
3. [ ] **Device checks** (M, needs hardware): shake-to-undo after closing each sheet (the 0.5s refocus is a guess), VoiceOver flow, edit-round sheet, keyboard shortcuts and hover on iPad, partial fold on Duo.
4. [x] **Unused-string cleanup** (done 2026-10-26): removed 10 unused keys from all 75 locales ("Time", "No completed games yet.", 4× "Pass: … ←", "Undo last round" + its message, "10 of Diamonds", "More"). `scripts/fix_ctx_keys.py` (already applied) is still untracked: commit or delete it.
5. [x] **Translation quality** (done 2026-10-26, LLM review; no native speakers yet): six Sonnet reviewers went through every Localizable/InfoPlist value in 73 locales against a domain glossary (~2,400 values changed). They fixed wrong-sense "Pass" (walk past), "Dealer" (merchant), "Player" (media player), "Round" (circle shape), "photograph the moon", reversed "%d wins in %d games" (ja, ko, my, kk, mn, az, uz, ur, am, sw, tr), phonetic English, leftover Simplified Chinese in zh-Hant, and Brazilian Portuguese in pt-PT. `sr` was rewritten; sr-Latn is now generated from it by transliteration (`scripts/sr_latn_from_sr.py`; rerun after editing sr). Regression tests: `testSerbianLatinHasNoCyrillic`, `testTurkishWinsInGamesKeepsArgumentOrder`. Per-batch logs with an "uncertain" list each: scratchpad `l10n-review-*.md` (not in the repo). Still worth a native check: the "shoot the moon" idiom (mostly literal), the new dealer words and one-letter D badges, and "Hold" phrasing.
6. [ ] Small polish (S each): dark-mode More/Undo chips near-black; pass-direction pill truncates at XXXL on iPhone Air; bottom-bar chip height magic number; `%d rounds` stringsdict; delete throwaway simulators.
7. [ ] Deferred: localized App Store screenshots; Widget / Live Activity.

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
- [x] (Done 2026-10-24: captured via DeviceHub; inner display needs SCREENSHOT_LARGEST_SCREEN.) `duo-open` never run: needs a human to unfold the Duo in DeviceHub; inner-display capture via XCUIScreen unverified.
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
- [ ] `%d rounds` isn't pluralized (stringsdict); harmless today (finished games always have >1 round).
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
- [ ] Header/scoreboard redesign not checked in RTL, and the dark-mode 26 tint / empty-state "No rounds yet" have no snapshot.
- [ ] Check in the running app: edit-round sheet layout (snapshot harness squeezes sheets), shake-to-undo + toast, toast over the stacked bottom bar at accessibility sizes, VoiceOver flow. In edit mode the per-player total badges still include the round being edited.
- [x] (Removed 2026-10-26.) Unused keys now: "Undo last round" alert strings.

- [x] (Done 2026-10-25: HeartsGame.totals(excluding:), snapshot cases added.) Edit mode totals included the edited round; empty board / dark 26 highlight / Increase Contrast snapshots.
- [ ] Reduce Transparency has no snapshot (not settable via traits). Score cells are labelled per cell, not per round row; a row-wise VoiceOver order would need a layout restructure.
- [ ] Dark mode: More/Undo chips render near-black (systemBackground on felt); consider a lighter chip fill.
- Note (2026-10-25): the Duo simulator remembers its DeviceHub fold posture across runs. A duo-folded run after an unfolded session captured the dark outer display (all-black PNGs). screenshots.sh now fails on single-colour images; fold the Duo in DeviceHub before duo-folded.

## 4.0.0 release (2026-10-25)

- [x] Build 4.0.0 (4) uploaded; App Store Connect version 4.0.0 created with build 4 attached; screenshots uploaded (6.3", 6.9", Duo folded + open, iPad 13"); old 3.4 iPad and 6.5" sets removed from 4.0.0; What's New + description set in all 39 ASC locales (0aa7107). NOT submitted for review; the user does that.
- App Store Connect rejects "♦" in metadata ("invalid characters"); use "10 of Diamonds" in App Store text. In-app strings can keep ♦.
- Google Translate (deep-translator) was rate-limited for this pass, so App Store metadata translations were LLM-generated. Native review is worthwhile, especially am, az, bn, cy, eu, fa, hy, ka, kk, km, lo, mk, ml, mn, mr, my, ne, pa, si, sw, ta, te, ur, uz, zu, and game names (pl "Kierki", ru "Червы", nl "Hartenjagen", pt/pt-PT "Copas", zh-Hant "傷心小棧", zh-Hans "红心大战").
- [ ] Non-English ASC locales fall back to the English screenshots (no localized screenshots).


## Visual polish follow-ups (2026-10-25)

- [ ] Main-screen pass-direction pill truncates to "← L…" at XXXL Dynamic Type on iPhone Air (pre-existing; seen while verifying bottom-bar heights).
- [ ] Bottom-bar chip height uses `@ScaledMetric` 35pt tuned to match Next Round; at XXXL the chips run a few pt taller than Next Round. A layout-driven equal height (shared `maxHeight: .infinity` + `fixedSize(vertical:)`) would remove the magic number.
- [ ] Throwaway simulators created during this work (chips-air, chips-ipad, chips-se, chips-16e, plus the bottom-bar agent's Air/iPad Pro 13") can be deleted with `xcrun simctl delete`.
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
  - [ ] `scripts/fix_ctx_keys.py` (untracked, already applied): delete it or commit it.
  - Rejected: an empty `tenChip` adding HStack spacing (a false `if` emits no child), duplicate a11y elements (the copies are `accessibilityHidden` and ViewThatFits renders one candidate), AnyView/`stackedLayout` style, and the Settings ⓘ About button (an intentional change in 90f7da4).
- [x] (Done 2026-10-26.) SE width / 6 players / AX sizes. Rows that can't fit name + total + stepper on one line now stack name over total instead of truncating ("Al…"). All non-holder rows decide together, sized to the widest player, so a list never mixes layouts. At SE width every row stacks. At 402pt, 4 players stay on one line, and 6 players (with "Alexandra") stack. AX crown clip fixed with a 20pt top inset. Regression: `NarrowRoundEntryUITests` (env PLAYERS/HOLDER/AX/CHIP_APPEARANCE/SHOT_DIR; DEBUG args `-screenshotPlayerCount`, `-screenshotTenHolder`).
- [ ] NarrowRoundEntryUITests is scroll-driven and was flaky while being written; watch it. Two Claude sessions running xcodebuild test on the same simulator deadlock: use a dedicated sim per session.
