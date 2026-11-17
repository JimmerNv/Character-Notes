# Codex Agent Instructions — BackCleaner / BagCleaner

This file defines the standing rules for AI coding agents working in this repository. Treat them as requirements for every task unless the maintainer explicitly overrides a specific rule. Read the relevant source files before changing code or documentation.

## 1. Project identity and non-negotiable target

- **GitHub repository / project root:** `BackCleaner`
- **Installed World of Warcraft addon name and directory:** `BagCleaner`
- **Only supported game:** **World of Warcraft Forever (WoW Forever)**
- **Primary language:** Lua, following the Lua version and API supported by the actual Forever client.
- **No support for retail WoW, Classic Era, original Wrath of the Lich King 3.3.5a, or other private servers is requested.** Do not add compatibility layers, old API shims, assumptions, instructions, or release targets for those clients unless the maintainer explicitly asks.
- The checked-in `.toc` currently declares `## Interface: 16001` and `## Version: 1.4.1`. These values describe the checked-in baseline, **not guaranteed future client/version values**. Verify actual Forever client/API requirements when updating them; do not blindly bump the Interface field.
- Never rename `BagCleaner` to `BackCleaner` inside WoW-installable files. The distinction is intentional.

**If the maintainer says “WoW”, “the game”, “client”, or “addon” anywhere in this project, interpret that as WoW Forever by default.** Do not repeatedly ask which WoW edition is meant.

## 2. Read before editing

Start by inspecting the existing implementation and workflow, especially:

- `BagCleaner/BagCleaner.toc` — client interface, version, metadata, load order, SavedVariables.
- `BagCleaner/Core.lua` — scanning, filtering, pricing, protection, slash commands, deletion checks.
- `BagCleaner/UI.lua` — bag panel, standalone and ElvUI integrations, context menus, settings.
- `BagCleaner/Titan.lua` — Titan Panel and/or LibDataBroker integration.
- `tests/*.lua` — existing tests and mocked client behavior.
- `.github/workflows/ci.yml`, `.github/workflows/release.yml` — CI and release execution.
- `scripts/build_release.py` — actual contents and version checks of downloadable ZIPs.
- `README.md`, `BagCleaner/README.md`, `BagCleaner/CHANGELOG.md` — current documentation.

Do not infer that a feature is present solely because it was requested, appears in old release notes, or is mentioned in a README. Verify it in current code. When reporting results, distinguish **implemented**, **mock-tested**, and **verified in a live WoW Forever client**.

## 3. Product behavior to preserve

### Inventory scanning and ordering

- Display eligible **gray (Poor)** and **white (Common)** bag items only.
- Only consider items with a **known, positive vendor sell price**. Exclude unsellable or unknown-price items.
- Exclude recognized **Hearthstones**, **conjured items**, and **quest items**. Protect quest items regardless of other settings; fail closed where the client cannot reliably determine a risky item's status.
- Rank candidates by **total vendor value of the complete stack**: `unit vendor sell price × quantity`, ascending. The lowest-value stack is at the top.
- Automated cleanup selection (`/clean`, `/clean N`, `/clean all`) must use the **same ascending total-stack-value order** as the UI. Never switch to unit price or arbitrary bag-slot order.
- Re-evaluate results when bags change; consistently break ties to prevent unstable ordering.
- Distinguish **N items** from **N inventory slots**: removing one full stack frees one slot. Do not claim to free a slot unless it was actually freed.

### Protection, hidden items, and confirmation

- White items are globally protected by default, with a user-controlled setting to turn that protection off.
- Preserve independent, persistent item-ID rules:
  - **Hide:** omit the item from BagCleaner's list **and automatic cleanup selection**.
  - **Protect (blacklist):** keep the item visible but prevent BagCleaner deletion.
  - **Hide + Protect:** apply both rules independently.
- Context menu on a BagCleaner list row (right-click): **Hide**, **Protect**, **Hide + Protect**; provide management to undo either rule.
- Support the configurable quick-blacklist modifier shortcut (currently default **Ctrl + Shift + Left Click**) **only within BagCleaner's own item list**, unless a future task explicitly requests broader behavior. Do not interfere with ElvUI's or Blizzard's native inventory click actions.
- Keep the **confirmation checkbox** user-configurable; default enabled. Disabling BagCleaner's confirmation must not bypass client-provided dialogs, protected actions, or safety checks.
- Never delete a newly changed/moved item because a slot was reused. Validate the current bag, slot, item identity, quantity, quality, price, and protection before deletion; abort safely on mismatch.
- Respect WoW Forever's actual secure/protected-action restrictions. **Do not try to bypass them with timers, automation, taint, macro exploits, or fabricated user clicks.** If one click per stack is required, implement and document that limitation honestly.
- Avoid unexpected destructive side effects. Do not create new unattended auto-delete behavior without explicit maintainer approval.

### User interface and integrations

- **Prefer ElvUI** whenever a supported ElvUI bag frame is active, but keep the addon usable on the standard WoW interface.
- Integrate a visible, discoverable **Clean** button with the ElvUI bag area. Avoid overlapping existing controls or attaching it where clipping can hide it.
- Provide a side panel docked next to the bag frame (prefer left, fall back when space is insufficient), with a clear **Delete** action on each deletable row, separately displayed stack quantity and stack total price, and a visible protected state.
- In standalone mode, provide a real opaque/dark background and frame border, not floating text over the game world.
- Provide a minimap/standalone access path; Titan Panel support is optional and must degrade gracefully when absent.
- Keep settings directly accessible from the bag UI, including **automatic panel opening**, **global white-item protection**, **delete confirmation**, **saved desired free-slot count**, **quick-blacklist shortcut**, and hide/protect rule management.
- Do not reuse ambiguous short labels such as `BC` (which conflicts with other in-game functions); use **Clean** or **BagCleaner**.
- Do not patch or overwrite ElvUI/Titan source files. Use additive integration that fails safely when optional addons or internal frames are missing.
- Maintain addon-list categorization under **Bags / Taschen**, not Miscellaneous.

### Commands and persisted state

Check `Core.lua` before documenting commands or changing their behavior. The baseline exposes `/clean` and `/bagcleaner`, plus commands such as `/clean N`, `/clean all`, `/clean show`, `/clean settings`, `/clean rules`, `/clean blacklist`, `/clean status`, `/clean auto`, `/clean protect`, and `/clean confirm`.

- Changes must not silently break established slash commands.
- Store user preferences and item-ID rules using the existing saved-variable schema (currently `BagCleanerDB`); handle absent/older data defensively.
- Preserve existing saved settings across updates. Introduce migrations for breaking schema changes and test them.

## 4. Code quality and verification

- Use the **actual WoW Forever inventory APIs**. Do not assume WotLK 3.3.5a globals exist. Verify updated APIs instead of guessing.
- Keep production Lua compatible with the Lua runtime actually used by Forever; the repository currently tests with Lua 5.1.
- Prefer small, isolated changes. Avoid unrelated refactors and unnecessary dependencies.
- Preserve normal right-click, modifier-click, drag/drop, secure buttons, and combat behavior of native UI and other addons.
- Add/update tests for changed logic, including cheapest-stack ordering, protection precedence, quest/unsellable/conjured exclusion, slot revalidation, UI fallback, and integration availability.
- Run the existing tests, where possible, from the repository root:

  ```bash
  for test in tests/*.lua; do lua5.1 "$test"; done
  python3 scripts/build_release.py
  ```

- Check the ZIP's internal structure: **`BagCleaner/BagCleaner.toc` must be at the expected path inside the installable ZIP**. The output must not contain an extra `BackCleaner/` wrapper.
- For new runtime assets, verify they are actually referenced/packaged by the build script. Creating `BagCleaner/Assets/` alone does **not** make `build_release.py` include those files automatically.
- Do not claim successful runtime testing if only mocks, syntax checks, or CI simulation were performed. Clearly list unresolved live-client checks.

## 5. Git, versioning, and release behavior

The maintainer wants **one tag-driven release flow** that builds a single installable ZIP, then publishes the **same ZIP** to **GitHub Releases** and **CurseForge**.

- Use **GitHub Actions**, not GitLab CI.
- Keep ordinary pushes and pull requests for CI/testing. Use tags of the form `vMAJOR.MINOR.PATCH` (optionally a prerelease suffix) to trigger official releases.
- A release tag must match the version declared by `BagCleaner/BagCleaner.toc`. `scripts/build_release.py --tag "$RELEASE_TAG"` already validates this.
- Use the existing build as the single source for the ZIP and its SHA-256 checksum; do not maintain separate ad hoc CurseForge packaging.
- Generate player-facing **English Markdown release notes from Conventional Commit subjects since the preceding release tag**. Fetch complete Git history for this calculation.
- Include these Conventional Commit types in player-facing notes:
  - `feat` → **New Features**
  - `fix` → **Bug Fixes**
  - `perf` → **Performance**
  - `security` → **Security**
  - `revert` → **Reverts**
- Exclude internal-only types from the public changelog by default: `refactor`, `test`, `ci`, `chore`, `docs`, `build`, `style`. **Do not automatically publish refactor commits as user-facing changes.** If a refactor has visible effects, describe those effects in a separate `feat:` or `fix:` commit.
- Use one identical filtered changelog in GitHub and CurseForge. Handle the first release (no prior tag) and releases with no player-facing changes gracefully.
- Respect semver/prerelease naming: stable tag → release, `-beta`/`-rc` → beta, `-alpha` → alpha (where supported by the publishing API).
- Keep workflows safe to retry; avoid publishing duplicate CurseForge files for the same version, and do not overwrite unrelated release assets.
- Do **not** create tags, publish releases, push commits, or upload to CurseForge unless the maintainer explicitly asks you to do so.

### CurseForge configuration

- Intended CurseForge project ID: **`1810294`** (BagCleaner).
- Previous configuration used WoW Forever game-version ID **`17053`**. Treat this as a configuration value to validate against CurseForge when needed, not a timeless client version.
- Read deployment settings from GitHub repository **Variables**:
  - `CURSEFORGE_PROJECT_ID`
  - `CURSEFORGE_GAME_VERSION_IDS` (JSON array, e.g. `[17053]`)
- Read the private API token only from GitHub Actions **Secrets**:
  - `CURSEFORGE_API_TOKEN`
- Never commit API tokens, echo them to logs, embed them in ZIPs, or paste them into documentation.
- If deployment settings are absent, fail with a clear actionable error, rather than silently marking CurseForge publication successful.
- An upload accepted by the API does not necessarily mean the file has passed CurseForge moderation.

**Implementation note:** A proposed CurseForge-enabled `release.yml` has been discussed, but the checked-in workflow may still be an older GitHub-only release workflow. **Inspect the repository's actual workflow before claiming dual publication is implemented.**

## 6. Documentation and project assets

- Root `README.md` is the public GitHub project description, preferably in clear professional English.
- Use **BagCleaner** for the installed addon/product and **BackCleaner** for the GitHub repository/root folder.
- State **WoW Forever only** prominently in documentation, metadata, changelogs, and release titles. Do not advertise other WoW editions.
- Document only verified commands, configuration, and implemented behavior. Mark unverified client/version compatibility explicitly.
- CurseForge descriptions can be English and German, and should highlight value-based sorting, manual cleanup, safety features, hide/protect rules, and optional UI integrations.
- Screenshot reference pages supplied by the maintainer:
  - ElvUI: `https://ibb.co/GfC9K7XH`
  - Standalone: `https://ibb.co/Y42q4x57`
- Runtime asset layout when needed:

  ```text
  BagCleaner/Assets/
  ├── Icons/
  ├── Images/
  └── Textures/
  ```

- Keep documentation screenshots separate from runtime textures when appropriate; avoid moving images without updating references and release packaging.

## 7. Mandatory English Conventional Commits (critical)

**This section is a permanent instruction, not an optional style suggestion.** The maintainer wants **detailed, precise commit messages in English** using Conventional Commits, with a prefix such as `feat:`, `fix:`, or `refactor:`. This applies even when the chat/task is in German. Every code or documentation task must end with a ready-to-copy English commit message **unless the user explicitly asks not to include one**.

### 7.1 Required commit format

```text
<type>(<scope>): <short imperative summary>

- <specific change and its effect>
- <another concrete implementation detail>
- <relevant behavior, compatibility, or safety note>
- <relevant tests/docs/packaging notes if actually done>

<optional footer, for example Closes #123 or BREAKING CHANGE: ...>
```

**Requirements:**

1. Use **English for the entire subject, body, and footers**. Never generate German commit messages for this repository unless the maintainer explicitly overrides the rule.
2. **Always use a recognized lowercase type** followed by a colon; add a lowercase scope in parentheses when useful, e.g. `fix(ui):`, `feat(cleanup):`, `refactor(core):`, `ci(release):`.
3. Keep the **subject concise (aim for 50 characters, maximum 72)**; use the **imperative mood** (`add`, `fix`, `prevent`, `document`, `optimize`, `remove`) and no trailing period. Describe the **observable change**, not a vague activity. Avoid subjects like `updates`, `changes`, `bugfix`, `work in progress`, or `refactor stuff`.
4. Leave **one empty line** between the subject and body. Use a detailed body with **specific bullet points** (normally 3–8 for multi-file changes, fewer when appropriate). Explain *what changed* and, when not obvious, *why*. For important behavior changes, mention user-visible effects and relevant safeguards.
5. **Do not fabricate tests, compatibility guarantees, fixes, or release deployment results.** If mentioning a test, only say it passed if it really ran. If testing was not performed, say so in the task report, not as an invented success in the commit body.
6. Keep the message **tightly scoped to the actual diff**. Do not claim a feature merely because it was planned or mentioned in previous releases.
7. Include a `BREAKING CHANGE: ...` footer, and optionally use `type(scope)!:`, for genuinely incompatible changes, including breaking settings migrations or command removals. Explain impact and migration. Do not classify breaking changes as ordinary `refactor:`.
8. If there is a known GitHub issue, include `Closes #123`, `Fixes #123`, or `Refs #123` when applicable and supported by the work. **Do not invent issue numbers or collaborators.**
9. **Do not create commits, push, tag, or publish** unless specifically asked. Ordinarily **propose the complete commit message for copying**; if explicitly authorized to commit, use the same conventions.
10. If work includes independent changes with different intents (e.g., a new feature plus an unrelated build fix), **recommend separate logical commits** rather than hiding everything under `chore:`.

### 7.2 Approved types and public release-note policy

| Type | Intended purpose | Included in player-facing GitHub/CurseForge release notes? |
| --- | --- | --- |
| `feat` | New functionality or player-visible improvements | **Yes — New Features** |
| `fix` | Correct broken behavior or a user-visible issue | **Yes — Bug Fixes** |
| `perf` | Improve performance | **Yes — Performance** |
| `security` | Improve security or prevent risky user-facing behavior | **Yes — Security** |
| `revert` | Revert a previously shipped behavior | **Yes — Reverts** |
| `refactor` | Internal reorganization with **no** behavior change | **No** |
| `test` | Test coverage, mocks, fixtures, test infrastructure | **No** |
| `docs` | README, instructions, screenshots, comments only | **No** |
| `ci` | GitHub Actions, deployment workflow, automation | **No** |
| `build` | Packaging/build tooling without user-facing changes | **No** |
| `chore` | Maintenance, dependency housekeeping, repository administration | **No** |
| `style` | Formatting or style-only source changes | **No** |

Choose the **most semantically accurate type**, not the one that merely creates a public changelog entry. A `fix(ui)` that corrects a missing Delete button is player-facing, even if implemented by rewriting internals; a `refactor(core)` that changes no behavior stays internal.

A change can have **a player-facing feature and internal refactoring in the same task**. Prefer separate commits when practical. If only one logical commit is appropriate, choose the primary purpose and give a detailed body; do **not** pretend a refactor by itself is a new feature. If a refactor introduces a real behavior change, use `feat:` or `fix:` for that change and document the behavior explicitly.

**Changelog implications:** The release automation is intended to parse the commit type, ignore the non-public types above, and use the remaining **English** messages since the prior version tag for both GitHub and CurseForge. Do not assume the currently checked-in workflow already implements that filter—verify it before reporting a release workflow as ready. For breaking behavior, ensure the release notes clearly mention it even if its Conventional Commit has special punctuation (`!`).

### 7.3 Scopes to use consistently

Useful scopes include:

- `core` — inventory logic and saved variables
- `cleanup` — candidate selection, vendor-value ordering, deletion flow
- `ui` — BagCleaner frames, controls, dropdowns, and standalone appearance
- `elvui` — ElvUI bag integration
- `titan` — Titan Panel/LibDataBroker integration
- `rules` — blacklist, hide/protect, exclusions and safeguards
- `commands` — slash commands and their parsing
- `release` — release packaging, GitHub/CurseForge publishing
- `assets` — artwork, icons, texture resources
- `docs` — documentation content
- `tests` — test harness, fixtures, coverage

Prefer one precise scope. Do not create a new scope for every file name. It is valid to omit the scope when the change truly spans the project and no scope is helpful.

### 7.4 Complete examples — include a detailed body

**Player-visible feature:**

```text
feat(rules): add configurable quick-blacklist shortcut

- Allow players to select a modifier-click shortcut for protected items.
- Keep the shortcut limited to BagCleaner's list to preserve native bag clicks.
- Persist the selected shortcut in existing saved variables.
- Document the new control in the settings and usage guide.
```

**Player-visible bug fix:**

```text
fix(ui): restore standalone cleanup panel background

- Draw a dark backdrop and visible border when ElvUI is unavailable.
- Keep the cleanup list anchored to the active bag window.
- Preserve the existing ElvUI layout and per-row Delete controls.
- Add regression coverage for standalone panel initialization.
```

**Internal refactor — intentionally excluded from release notes:**

```text
refactor(core): centralize inventory candidate filtering

- Consolidate repeated candidate checks into a shared filter function.
- Preserve the existing total-stack-value sorting and protection order.
- Reduce duplication between list rendering and cleanup selection.
- Keep slash commands, saved-variable keys, and user-visible behavior unchanged.
```

**CI/release maintenance — intentionally excluded from release notes:**

```text
ci(release): publish versioned addon archives to CurseForge

- Extend the tag-triggered workflow to reuse the existing release ZIP.
- Read CurseForge project settings from repository variables and secrets.
- Upload the same package and filtered changelog used by GitHub Releases.
- Fail clearly when required deployment configuration is missing.
- Avoid exposing the CurseForge token in workflow logs.
```

**Documentation-only task:**

```text
docs: describe addon features and asset conventions

- Expand installation, commands, and supported WoW Forever client guidance.
- Document blacklist, hide, vendor-price ordering, and deletion safeguards.
- Define conventions for Icons, Images, and Textures in the Assets directory.
- Clarify the GitHub release process and unverified live-client limitations.
```

**Breaking change (only if actually necessary):**

```text
feat(commands)!: replace legacy cleanup command syntax

- Introduce the new command form and update built-in help text.
- Document the removed legacy invocation and the replacement command.
- Include migration guidance for users and automation scripts.

BREAKING CHANGE: The previous cleanup command syntax is no longer supported;
update custom macros to use the new command documented in the README.
```

### 7.5 Mandatory final response after each task

Provide a concise work report and the **full suggested English Conventional Commit message**, including its body, as one copyable code block. The report should state:

1. **What changed** and why.
2. **Files touched**.
3. **Commands/tests actually executed**, with truthful results.
4. **Unverified live WoW Forever behavior** or outstanding manual tests.
5. **Impact on versioning, release packaging, and saved preferences**, when applicable.
6. **Ready-to-copy, detailed English commit message** using the format above.

If no files changed (e.g., pure analysis), do not invent a commit message suggesting files were changed; offer a proposed message only when useful and label it as conditional.

## 8. Priority when instructions conflict

1. Explicit current maintainer request and user safety.
2. These standing project rules.
3. Verified source code, game API behavior, and repository configuration.
4. Existing documentation and historical assumptions.

If the maintainer requests something that the Forever client does not permit, explain the technical restriction and implement the closest safe, user-controlled alternative. Never mask a limitation by claiming an unverified feature works.
