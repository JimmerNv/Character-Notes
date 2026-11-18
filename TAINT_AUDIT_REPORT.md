# Character Notes Alerts — Taint and Protected UI Audit

**Audit date:** 2026-11-18  
**Audited release:** Character Notes Alerts 1.8.0 for World of Warcraft Forever  
**Installable archive:** `release/CharNotes_v1.8.0_Forever.zip`  
**Scope:** 3,357 lines across all nine runtime Lua files, the TOC load order, the packaged ZIP, popup flows, protected UI references, hooks, ElvUI integration, context menus, tooltips, unit-frame visuals, saved variables, alerts, sounds, synchronization, guild sharing, and Ignore integration.

The available repository instruction file was reviewed. It is labeled for the unrelated BackCleaner/BagCleaner project, so its BagCleaner product rules were not applied to Character Notes. Its WoW Forever target and English Conventional Commit requirements were respected.

## A. Executive Summary

No active Character Notes code was found that mutates Blizzard's `StaticPopupDialogs` table, replaces protected Blizzard functions, overwrites Blizzard frame handlers, or invokes unrelated protected inventory, guild-bank, auction-house, logout, or game-menu actions.

The previously dangerous popup pattern is already absent. Guild sharing uses an anonymous Character Notes-owned frame created only on demand. Acceptance clears the pending state before sending; cancellation clears the pending state and never calls the sharing action.

No confirmed Blizzard UI taint issue was identified in version 1.8.0.

| Finding | Classification | Severity |
| --- | --- | --- |
| Blizzard static popup registry | No mutation or registration found | None |
| Protected Blizzard functions and frames | No replacement or handler overwrite found | None |
| Add-on dialogs above the game UI | Add-on-owned and closed when the game menu opens | Low residual integration risk |
| Blizzard/ElvUI unit-frame decoration | Visual-only, mouse-disabled, combat-guarded | Low residual integration risk |
| Player context menus | Additive `Menu.ModifyMenu` registration | Low residual integration risk |
| Tooltips and secret unit values | Post-hooks plus secret-value rejection | Low residual integration risk |
| Bags, guild bank, and auction house | No related API calls or frame mutations found | None |

## B. Findings

### B.1 No mutation of `StaticPopupDialogs`

- **Files inspected:** all runtime Lua files.
- **Relevant locations:** `CharNotes/Sync.lua:236-247`, `CharNotes/UI.lua:1145-1180`.
- **Execution path:** `CN:AskShareGuild()` validates the saved note and guild membership, then calls `CN:ShowGuildSharePrompt()`. The prompt is a Character Notes-owned anonymous frame under `UIParent`.
- **Evidence:** the only `StaticPopupDialogs` occurrences are explanatory comments. No indexed assignment, replacement, removal, `StaticPopup_Show`, or `StaticPopup_Hide` call exists.
- **Cancellation behavior:** the Cancel callback clears `CN.pendingGuildShareName`, hides the frame, and does not call `CN:ShareGuild()`.
- **Affected Blizzard components:** none.
- **Conclusion:** safe within the inspected code-level scope.

### B.2 No replacement of protected Blizzard functions or handlers

- **Files inspected:** all runtime Lua files.
- **Search scope:** `GameMenuFrame`, logout/quit buttons, panel functions, close-window functions, container APIs, guild-bank APIs, auction APIs, secure action templates, global assignments, `SetScript`, `HookScript`, and `hooksecurefunc`.
- **Evidence:** no calls or assignments involving `UseContainerItem`, `SplitContainerItem`, `PickupContainerItem`, `BuyGuildBankTab`, `ShowUIPanel`, `HideUIPanel`, `ToggleGameMenu`, `CloseAllWindows`, or `CloseSpecialWindows` exist.
- **Handler review:** all `SetScript` calls target Character Notes-owned frames. Blizzard/ElvUI tooltip and unit frames use additive post-hooks only.
- **Affected Blizzard components:** none.
- **Conclusion:** no code path connects Character Notes to bag use, item splitting, guild-bank purchases, auction-house lifecycle, logout, or exit actions.

### B.3 Character Notes dialogs and the game menu

- **Location:** `CharNotes/UI.lua:179-385`, `CharNotes/UI.lua:951-1180`.
- **Relevant function:** `CN:InitializeUI()`.
- **Behavior:** Character Notes creates its windows under `UIParent`. Some use `DIALOG`, `FULLSCREEN_DIALOG`, or `TOOLTIP` strata so they remain readable.
- **Risk considered:** a visible mouse-enabled add-on frame above the game menu could intercept a logout or exit click even without tainting Blizzard code.
- **Mitigation:** `EventRegistry:RegisterCallback('GameMenuFrame.Shown', ...)` hides every Character Notes top-level window, alert, and confirmation and clears pending guild-share state.
- **Severity:** low residual integration risk because the final ordering and event delivery must be confirmed in the live Forever client.
- **Conclusion:** no confirmed defect; manual verification remains appropriate.

### B.4 Blizzard and ElvUI unit-frame visuals

- **Location:** `CharNotes/Visuals.lua:40-144`, `CharNotes/Visuals.lua:177-259`.
- **Relevant functions:** `makeBorder()`, `tagIconParent()`, `refreshTagIcons()`, `refreshUnitFrame()`, `CN:RefreshHighlights()`.
- **Behavior:** Character Notes adds textures or an anonymous child overlay for borders and tag icons. It does not modify unit attributes, click registrations, secure templates, unit actions, or native handlers.
- **Combat handling:** frame/texture creation and geometry changes are skipped while `InCombatLockdown()` is true. Existing textures may only update their content or visibility.
- **Mouse handling:** the anonymous overlay explicitly uses `EnableMouse(false)`.
- **Severity:** low residual integration risk. Whether a specific ElvUI/Blizzard build marks an otherwise visual region operation as protected requires live-client confirmation.
- **Conclusion:** no evidence of taint or click interception in the code.

### B.5 Context menus and ElvUI integration

- **Locations:** `CharNotes/Menu.lua:13-85`, `CharNotes/ElvUI.lua:75-120`.
- **Relevant functions:** `CN:RegisterMenus()`, `CN:TryRegisterElvUIOptions()`, `CN:InitializeElvUI()`.
- **Behavior:** player entries are added through Blizzard's additive `Menu.ModifyMenu` API. Builders resolve a readable player identity and add three Character Notes callbacks. Legacy dropdown tables and existing right-click handlers are not replaced.
- **ElvUI options:** integration uses `LibElvUIPlugin-1.0` when available and adds a namespaced `cnPunk` options group. This modifies ElvUI's configuration data, not a Blizzard protected UI registry.
- **Severity:** low residual third-party integration risk.
- **Conclusion:** implementation follows additive integration patterns and does not alter standard unit actions.

### B.6 Tooltip hooks and secret values

- **Locations:** `CharNotes/Core.lua:38-83`, `CharNotes/Core.lua:400-475`, `CharNotes/Visuals.lua:261-359`, `CharNotes/Visuals.lua:361-420`.
- **Relevant functions:** `CN:IsSecret()`, `CN:FromUnit()`, `CN:ResolveContext()`, `CN:TooltipUnit()`, `CN:HookGroupFrameTooltips()`.
- **Behavior:** unit tokens, names, booleans, tooltip strings, owners, and attributes are rejected when secret or unreadable. API calls that can reject restricted values are contained with `pcall`; the code does not attempt to reveal or coerce secrets.
- **Hooks:** tooltip data uses `TooltipDataProcessor.AddTooltipPostCall` when available, with `HookScript` fallbacks. ElvUI unit frames receive an `OnEnter` post-hook; their original handler is not replaced.
- **Severity:** low residual client-version risk because secret-value behavior is enforced by the live client.
- **Conclusion:** historical `UnitExists`, `UnitName`, `targettarget`, and tooltip failure modes are explicitly guarded.

### B.7 Titan Panel and global names

- **Locations:** `CharNotes/Titan.lua:5-32`, `CharNotes/Core.lua:3`, `CharNotes/Core.lua:625-627`.
- **Behavior:** Titan creates its own named button and post-hooks its click. Character Notes exposes its namespace and required slash-command globals.
- **Conclusion:** these globals belong to Character Notes/Titan integration and do not replace Blizzard protected functions.

## C. Implemented Changes

No runtime Lua file required modification. Changing already-safe runtime code would have added unnecessary regression risk.

The following audit artifacts were added:

- `tests/taint_audit.lua`
  - Rejects direct `StaticPopupDialogs` mutations.
  - Rejects protected function replacement and unrelated protected action calls.
  - Verifies the custom confirmation path, game-menu cleanup, additive context-menu API, combat guard, and mouse-disabled unit-frame overlay.
- `tests/ui_behavior_spec.lua`
  - Verifies saved-note preservation, note creation/editing/deletion, guild-share acceptance and cancellation, alert opening/closing, sound playback, context-menu callbacks, and tooltip additions using mocks.
- `TAINT_AUDIT_REPORT.md`
  - Documents evidence, test results, manual validation, limitations, and the final assessment.

## D. Test Results

### Automated checks executed

| Command | Result | Coverage |
| --- | --- | --- |
| `texlua syntax_check.lua` | PASS | All nine runtime Lua files load syntactically |
| `texlua feature_check.lua` | PASS | Tags, chat icons, import/export, saved notes, and Ignore behavior using mocks |
| `texlua tests/taint_audit.lua` | PASS | Protected UI/static popup source regression checks |
| `texlua tests/ui_behavior_spec.lua` | PASS | Confirmation, cancellation, notes, alerts, sounds, menu, tooltip, and saved-variable mocks |
| `unzip -t release/CharNotes_v1.8.0_Forever.zip` | PASS | Archive integrity and expected `CharNotes/` root |
| Byte comparison of ZIP entries against audited source | PASS | The packaged 1.8.0 Lua/TOC files match the audited working tree |

### Tests not performed

- No live WoW Forever client was available in this environment.
- No live ElvUI, Titan Panel, guild bank, auction house, combat-lockdown, or secret-value enforcement test was performed.
- LuaTeX/`texlua` was used as the host Lua runner. Passing mocks do not prove live-client compatibility or absence of engine-level taint.

## E. Manual Validation Checklist

### Preparation

1. Install only the audited `CharNotes` folder and the intended ElvUI/Titan versions.
2. Enable detailed taint logging with `/console taintLog 2`.
3. Enable visible Lua errors with `/console scriptErrors 1`.
4. Run `/reload`.
5. Note the exact Character Notes, ElvUI, Titan, and WoW Forever build versions.

### Required scenarios

- [ ] **Logout:** open `/cn`, open its options and a confirmation window, then open the game menu and click Logout. Expected: Character Notes windows close and Logout remains clickable.
- [ ] **Exit Game:** repeat with Exit Game. Expected: no blocked-action warning and no Character Notes frame intercepts the click.
- [ ] **Guild-bank tab:** open the guild bank and purchase a new tab. Expected: the native confirmation and purchase action work normally.
- [ ] **Auction house:** open and close the auction house. Expected: Character Notes does not change auction-frame behavior.
- [ ] **Split stacks:** after closing the auction house, split multiple item stacks. Expected: normal cursor and split behavior.
- [ ] **Use/transform items:** use inventory items and transform essences. Expected: no blocked action attributed to Character Notes.
- [ ] **Right-click players:** test player, target, party, raid, friend, guild, and chat-roster menus. Expected: native entries remain and three Character Notes entries appear when enabled.
- [ ] **Open through context menu:** select Add Note. Expected: the correct player opens without changing the target or breaking the menu.
- [ ] **Notes:** add, edit, save, and delete notes; reload and verify persistence. Expected: saved variables remain account-wide and unchanged in schema.
- [ ] **Alerts and sounds:** trigger a configured PUNK/group alert and test each sound option. Expected: alert opens, dismisses, auto-hides, and plays only as configured.
- [ ] **Combat:** enter combat and exercise supported read-only tooltip/tag/note display paths. Expected: no protected-action warning; no new overlay frame or geometry mutation is attempted during lockdown.
- [ ] **Reload and repeat:** run `/reload`, then repeat logout, exit, guild-bank, auction-house, split-stack, item-use, right-click, tooltip, and combat checks.

### Record every failure

For each blocked action, capture:

| Field | Required value |
| --- | --- |
| Reproduction | Exact sequence from login/reload to failure |
| Error | Full visible blocked-action or Lua error text |
| Taint log | Relevant section from `Logs/taint.log` |
| Suspected function | First Character Notes function in the stack, if present |
| Isolation | Whether the failure persists with Character Notes disabled |
| Add-on matrix | Result with ElvUI/Titan individually enabled and disabled |

After testing, disable verbose logging with `/console taintLog 0` and `/reload`.

## F. Remaining Risks

- Engine-level protection of visual regions parented to unit frames cannot be proven with source inspection or mocks.
- ElvUI may change internal unit-frame ownership or protection behavior between builds even though Character Notes uses post-hooks and namespaced options.
- `GameMenuFrame.Shown` delivery and frame-strata ordering need validation on the exact Forever client build.
- Secret-value availability can differ by context and patch. Current code fails closed, which may omit a note/icon rather than risk inspecting a secret.
- Third-party add-on combinations can taint a shared execution path even when Character Notes does not originate the taint. Isolation testing remains necessary.

## G. Final Assessment

**PASS — code-level audit scope.**

No relevant taint source was found in the audited Character Notes Alerts 1.8.0 source or packaged ZIP. The static popup risk is already removed, protected Blizzard functions are not replaced, unrelated protected actions are not called, and integrations are additive and guarded. Live WoW Forever testing is still required to validate engine-level behavior with the exact ElvUI/Titan/client combination; the checklist above must not be represented as completed until it is run in game.

## Ready-to-copy Conventional Commit Message

```text
test(taint): add protected UI regression audit

- Add source guards against Blizzard popup registry mutations and protected function replacement.
- Cover guild-share acceptance and cancellation with addon-owned confirmation mocks.
- Verify notes, alerts, sounds, context menus, tooltips, and saved-variable preservation.
- Document code-level findings and the required WoW Forever integration test plan.
- Leave runtime addon behavior and saved-variable compatibility unchanged.
```
