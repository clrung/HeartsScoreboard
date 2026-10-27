# iPad UI/UX redesign (started 2026-10-26)

Orchestrated plan. Each phase is one committable unit on `main`. Mark items [x] as they land and
add notes/findings under the phase. Agents: read AGENTS.md and this file first.

## Decisions (user, 2026-10-26)
- Shoot the Moon Preference moves to **Settings › Rules**, plus a compact menu in the round-entry
  panel header (both sheet and inline) so it can still be changed mid-game. Removed from the Form body.
- Scope: shared design system (palette, tokens, entry-row design) applies app-wide (iPhone benefits);
  layout restructuring targets regular width. Duo's equal panes with a centered fold gap are preserved.
- Palette: deeper, calmer card-table felt (no bright lime gradient). Accent stays green.
- Commit per phase to main after build + tests + visual check. Regenerate App Store screenshots at the end.

## Design direction: adaptive hybrid (Concept C, built on A)
Two cards side by side on regular width, both **hugging their content, top-aligned** on the felt
(the felt below is intentional breathing room, not a stretched empty card). The scoreboard grows with
rounds until it reaches the available height, then its round grid scrolls under a pinned standings header.

### Layout (regular width)
- Header row (full width): History · Undo | status (pass chip, "Round N", "to 100") | New Game · Settings.
  New Game and Undo move from the bottom bar into the header as icon buttons (same look as History /
  Settings, same identifiers `newGameButton`, `undoButton`), so the split layout has no bottom bar.
- Pane widths: when the available width is >= 1100pt (iPad landscape) the scoreboard gets ~56%, entry ~44%.
  Below that (iPad portrait, Duo inner, Split View) panes are equal with the centered gap (Duo fold rule).
- Compact width (iPhone, narrow Split View) keeps today's structure: header, scoreboard, bottom bar
  with Next Round; it just picks up the new tokens/palette.

### Scoreboard card
- Pinned **standings header**, one column per player: name (full where it fits; initials rule for 6p
  in split stays), dealer shown as a small "D" badge inline before the name (no extra row), a **large
  rounded monospaced total** (title2/title weight bold), a thin progress bar toward the target and a
  "74 to go" caption. Leader(s) (lowest score; ties = all tied) get a gold crown + gold-tinted total
  well. Game over: winner(s) keep the crown.
- **Round grid**: rail with round numbers; plain numbers, not a pill per cell; full-width zebra rows
  (one row background spanning all columns) so rounds read as lines. 0 = secondary color.
  Moon = moon.fill symbol (indigo, restrained) in the shooter's cell; a "took all 26" cell keeps the
  soft orange emphasis; 10♦ marker kept. Tapping a row/cell still opens Edit Round.
- **Pending row** at the bottom of the grid: "N" in the rail with a subtle dashed outline marking the
  round being entered (split layout). Stretch: show the live entry values from the panel (lift entry
  state via an optional binding) — Phase 3.
- Empty state (0 rounds): standings header + one pending row + a short "Enter round 1 scores →" hint.

### Round-entry panel
- Header: "Round N" (title2 bold) · Moon preference menu (moon icon + "+26 others" / "−26 shooter",
  existing localized labels where possible) · Reset.
- Player row (inline and sheet share one row component; layout adapts to width):
  - Line 1: name (headline) + total as quiet secondary text with crown for leader; trailing: − [value] +
    where the value sits in a rounded "well" (large rounded monospaced digits). Tap the value -> popover
    with a 0...26 grid to set an exact value in one tap.
  - Line 2: quick actions as **tinted** (not filled) capsules: "+5" (quick increment), "+N" (rest),
    "Q♠" and moon. Q♠ shows a selected state for the queen holder; moon shows selected for the shooter.
    Moon chip uses the moon tint; others accent tint. Disabled states are clearly dimmed. 44pt hit areas.
  - Row separators inset; consistent row height.
- Footer (pinned): progress gauge (segmented/linear bar toward 26 + "14 / 26 · 12 left" text, red when
  over, accent check when ready) + prominent Submit. Never overlaps rows (safe-area inset, as today).
- Hardware keyboard (Phase 3): ↑/↓ select player row, digits type the selected row's value, +/− adjust,
  Q = Q♠, M = moon, R = rest, ⌘↩ submit (exists), ⌘⌫ reset. Discoverable via the iPad ⌘ menu
  (`.keyboardShortcut` with titles where possible).

### Design tokens (Theme.swift)
- `Theme.Spacing` (xs 4, s 8, m 12, l 16, xl 24, xxl 32), `Theme.Radius` (card 24, well 12, cell 8),
  `Theme.Elevation` (card shadow), semantic colors: `felt`, `cardSurface`, `cardInset`, `rowZebra`,
  `leader` (gold), `moon` (indigo), `allPointsWarning` (orange), `positive` (accent).
- All with light / dark / increased-contrast variants; keep the 4.5:1 rules already documented.
- Replace scattered magic numbers in the touched views with tokens.

## Phases
- [x] **Phase 1 — Tokens, palette, scoreboard, split layout** (Theme, GameView, PlayerScoreViews scoreboard
      parts, ScreenshotDemo scenarios). Includes DEBUG `-screenshotScenario early|long|tied|over|longnames`
      for verification and iPad sizes in the snapshot harness.
  Phase 1 notes (2026-10-26):
  - New `Views/ScoreboardCard.swift` replaces the scoreboard in GameView; `RoundRail*` and the old pill cells are gone
    (HistoryDetailView still uses `ScoreCellContent`/`ScoreCellFrame`/`PlayerTotalBadge`, restyle later if wanted).
  - Hugging uses `ViewThatFits(in: .vertical)` (no-scroll variant, then pinned header + ScrollView). Compact width fills the height.
  - Pane widths: >=1100pt available -> 56/44 with 24pt gap; else equal panes with a 40pt centered gap (Duo rule). Max content width 1480.
  - Deviations: "N to go" shows for every player (not only the highest scorer) and is hidden when a column is < 78pt (6 players on iPhone) and at game over.
    Initials replace names when a column is < 74pt and there are >= 5 players (also on iPhone now). Header icon buttons are now circles (all four share one look).
    In split, New Game takes Cmd-N (Next Round keeps it in compact). Undo toast sits inside the scoreboard pane in split.
    FeltCardSurface is a solid card color (no material). Game-over card in the entry pane is top-aligned.
  - Entry pane still fills the height (RoundInputView's Form doesn't hug): Phase 2.
  - New string key: "Enter round 1 scores" (needs translations).
  - Open: HistoryDetailView cell overlays (white on the new near-white card) are faint; orange "26" cells look brown in dark mode.
- [x] **Phase 2 — Round-entry panel** (RoundInputView, PlayerScoreViews name/total, SettingsView moon rule,
      strings + translations).
  Phase 2 notes (2026-10-27):
  - Moon preference: Settings gets its own "Shoot the Moon Preference" section right after Game Rules (segmented + per-choice footer);
    the entry header has a moon Menu (icon + "Add 26"/"Subtract 26", menu items use the longer existing "Moon adds 26 to others" strings).
    Inline: in the header next to Reset. Sheet: a trailing row above the list (a toolbar item collapsed into an unreadable glass pill).
    Same `model.settings.shootMoonPreference`, already in the iCloud `SyncableState` (new unit test pins it).
  - RoundInputView no longer uses a Form: ScrollView + VStack of inset tiles (`Theme.cardInset`) on `Theme.cardSurface`.
    Inline is `ViewThatFits(.vertical)` (hug, else header + scrolling rows + pinned footer); the entry card chrome lives in
    `GameView.entryCard` (same surface/radius/hairline/elevation as the scoreboard). Scroll view id: `roundInput.scroll`
    (UI tests TenBadge/NarrowRoundEntry now use it instead of `collectionViews`).
  - Row: name (headline) over "Total N" (secondary, crown for leader); trailing 44pt `-`/`+` circles around a rounded monospaced value well;
    tinted capsules +5 / +rest / Q♠ / moon (Q♠ and moon are solid when selected via `RoundEntryState.queenOwnerID` / `moonShooterID`).
    Deviation: the name block is always name-over-total (not one line) so all rows lay out alike and the 44pt stepper height absorbs it.
  - Value well opens a 6-column 0...26 popover (`PointsGridPicker`, `presentationCompactAdaptation(.popover)`); disabled in a moon round like -/+.
    Clamp logic extracted to `RoundEntryState.adjustPoints/setPoints` (unit tested). New ids: `roundInput.value.<name>`, `.valueOption.<n>`,
    `.moon.<name>`, `.increase.<name>`, `.moonMenu`.
  - Footer: leading progress text + thin gauge (red over, accent when ready, moon tint on a moon round before a 10♦ holder) + prominent Submit.
  - `allPointsFill` token: saturated burnt orange in dark (was brown), used by the scoreboard and HistoryDetail; HistoryDetail scoreboard
    now uses card surface + inset header + zebra rows. `PlayerNameWithTotalView` removed.
  - New strings: "Total %d", "Set points for %@" (+ Phase 1's "Enter round 1 scores") translated into all locales via
    `scripts/translate_new_en_keys.py` (added a SOURCE_OVERRIDE "Total score: %d" so Google doesn't return "totals").
  - Open: 6 players on iPad landscape only just fit; below ~1000pt height the rows scroll. Moon chip in sheet at AX sizes is icon-only
    (menu text hidden). Popover itself only verified as a standalone grid snapshot, not live. Phase 3 still owns keyboard + live pending row.
- [x] **Phase 3 — Keyboard + live pending row + chip polish.**
  Phase 3 notes (2026-10-27):
  - Live pending row: `GameView` owns `inlineEntry` (+ `inlineKeyboard`) and passes bindings to `RoundInputView(.inline)`; sheet/edit keep private state.
    `ScoreboardCard.pendingEntry` renders values in `Theme.pendingValue` (accent text), untouched = faint en dash, moon shooter = moon symbol,
    dashed outline turns accent + faint wash once touched. VoiceOver: row "Round N, in progress" (`pendingRow`) containing per-cell labels (`pendingCell.<name>`), not buttons.
    Reset: `GameViewModel.entryResetKey` (hand ids + player ids) changes on submit/undo/redo/new game/iCloud sync, `GameView` then resets `inlineEntry`;
    settings changes do not. Rules moved from the view into `RoundEntryState` (`addQueenOfSpades`, `addRemainingPoints`, `applyShootMoon`).
  - Keyboard (`RoundEntryKeyboard`, pure + unit tested): up/down/Tab(Shift-Tab) select row (wraps), digits type the value (two-digit buffer, new number after 1s or a third digit
    or a row change, clamped 0...26), + / = and - adjust by 1, Q = Q♠, M = moon, R = rest, Delete/Backspace = 0, Cmd-Return submit (existing), Cmd-Delete reset.
    Each key follows the disabled rules of its on-screen control. Selection ring (`Theme.selectionRing/Wash`) appears only after a key was used.
    Cmd-Up/Down (Previous/Next Player) and Cmd-Delete (Reset) are hidden keyboardShortcut buttons so they show in the Cmd-hold menu; plain keys are not listed.
  - Finding: while `ShakeDetectorViewController` is first responder SwiftUI focus / `onKeyPress` never receives plain keys (verified by disabling it). So the inline panel gets keys via
    `ShakeDetectorView.onKey` (`pressesBegan` on the detector, which only consumes keys it maps; Cmd/Ctrl/Opt combos pass through), handled in `GameView.handleInlineKey` (split layout, no sheet, game not over).
    First-responder behaviour is otherwise unchanged. Sheets/edit use SwiftUI focus + `onKeyPress` (not covered by a UI test).
  - Polish: chip text was 3.8:1 (light) / 4.3:1 (dark) on its own tint; new `Theme.accentText` (>= 5:1 / >= 7:1) and `moonText`. Light moon chip gets a 22% indigo wash + hairline.
    Split layout after 1 round: left as is (hugging card, short next to the tall entry card); the pending row with its dashes now gives the early state presence, no filler added.
  - Tests: `RoundEntryKeyboardTests` (key map, rules, buffer, reset key), snapshot `testPendingRowAndKeyboardSelectionRender`, UI `IPadKeyboardUITests` (chips -> pending row; typeKey digits/Q/+/=/M/Tab, submit by tap).
  - Open: XCUITest cannot drive Cmd shortcuts (even the existing Cmd-, fails at baseline) or Delete/Backspace key presses in the simulator, so Cmd-Return/Cmd-Delete/Delete are verified by unit tests/code only; check on a real iPad with keyboard.
    New strings "Round %d, in progress", "Previous Player", "Next Player" translated to all locales.
- [x] **Phase 4 — Visual QA matrix + fixes** (iPad 13/11/mini, landscape/portrait, Split View narrow,
      iPhone, Duo sizes; light/dark; AX sizes; 3–6 players; long names; ties; game over; moon; 10♦).
  Phase 4 notes (2026-10-27):
  - Stacked portrait layout: regular width, height > width, width >= 744pt (`GameView.usesStackedPanes`) stacks a full-width scoreboard over a
    full-width entry card. Board height is capped (`stackedBoardMaxHeight`: min(52% of height, height - estimated entry height), floor 30%) via a
    `CappedHeight` layout (plain `.frame(maxHeight:)` stretched the card's slot and left a gap). Entry rows use one line (name | chips | stepper) via
    `RoundInputView(wideRows:)`; accessibility sizes keep the two-line row. Duo 669x951 / 951x669 and landscape unchanged.
  - Crown: `CrownGeometry` (badge reaches 2pt into the 4pt well inset, headroom reserved above every well); never touches digits.
  - Initials only when the longest name cannot fit its column (`ScoreboardCard.nameFits`, measured with the capped Dynamic Type size), still only for >= 5 players.
  - Matrix: `IPadLayoutSnapshotTests.testVisualQAMatrix` (opt-in: `TEST_RUNNER_QA_FILTER=<substring>`, ~300 PNGs: 14 sizes x states x light/dark/HC/RTL/xs/xxxL/AX3),
    `testSheetsRenderOnIPadAndPhone` (Settings, History, History detail, Edit round). Live: `OrientationLiveUITests` (both orientations, early/long, light/dark; asserts stacked Submit spans the card).
  - Defects. Found + fixed: (1) portrait 6p squeezed to initials + 60% empty felt -> stacked layout; (2) crown over the digit in narrow columns; (3) initials rule too eager;
    (4) Duo-width entry rows truncated "Alexa...", "Total..." and the moon menu label to "Add..." -> shrink-to-fit on name/total/menu label, menu gets layout priority over the title.
    Found + not a defect: edit-sheet progress strip overlapping the bar was a mid-animation snapshot (re-rendered after 1s settle).
  - Deferred: (a) 6 players on landscape mini (744pt high) and 13in landscape with the 10♦ rule: entry rows scroll under the pinned footer (physical limit; footer never overlaps);
    (b) AX3 on iPad portrait: entry gets ~1.5 rows visible (rows are 2-3 lines tall), scrolls; (c) phone 6p initials are "Av/Al" style (HeartsGame.headerLabels) - ambiguous but unchanged;
    (d) compact width with 1 round leaves a tall empty card (existing Phase 1 behaviour); (e) value popover verified only as a standalone grid, not live; (f) Cmd shortcuts need a hardware keyboard check.
- [ ] **Phase 5 — Final design critique, screenshots regen, ledger update.**

## Verification recipe
- Build/test: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project HeartsScoreboard.xcodeproj -scheme HeartsScoreboard -destination 'platform=iOS Simulator,id=<ipad udid>' test`
- Layout PNGs without rotating a simulator: extend `HeartsScoreboardTests/DuoLayoutSnapshotTests.swift`
  (or a sibling `IPadLayoutSnapshotTests.swift`) to render GameView at 1376x1032, 1032x1376, 1210x834,
  834x1210, 1133x744, 744x1133 and a narrow 507x1032 Split View; run with `TEST_RUNNER_SNAPSHOT_DIR=<dir>`
  and **look at every PNG** (Read tool).
- Live simulator: iPad Pro 13-inch (M5) is booted. `xcrun simctl install/launch <udid> com.clrungdev.Hearts-Scoreboard -screenshotDemo -screenshotScenario <s>`; `xcrun simctl io <udid> screenshot <png>`.
  The demo model never touches iCloud or real saved data.
