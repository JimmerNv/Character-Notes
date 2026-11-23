# Codex Agent Instructions — Character Notes

## Project and supported client

- Repository: `Character-Notes`.
- Product: **CharNotes / Character Notes & Alerts**, for **WoW Forever only**.
- Runtime source: `CharNotes/`.
- Installed addon directory: `ElvUI_CharNotes`.
- Manifest: `CharNotes/ElvUI_CharNotes.toc`; verify its current version and load order.
- SavedVariables: `ElvUICharNotesDB`; preserve existing notes, tags, settings,
  trusted peers, inboxes, talent templates, and attached builds across updates.
- ElvUI and Titan Panel are optional. Keep standalone functionality usable.
- Do not introduce other client targets or change the interface number without
  evidence from the actual Forever client.

## Read and preserve behavior

Read the relevant implementation, tests, and workflows before editing.

- `Core.lua`, `Tags.lua`, `Menu.lua`, `Visuals.lua`, `UI.lua`: character notes,
  tags, context menus, group warnings, settings, and standalone UI.
- `Notebook.lua`, `NoteBuilds.lua`: general notes and up to ten named builds.
- `TalentModel.lua`, `Planner.lua`: client-sourced talent models, allocation,
  rank tooltips, templates, and the separate planner window.
- `Sync.lua`, `GeneralShare.lua`: trusted character-note sync and explicit
  acceptance of shared character/general notes.
- `Strings.lua`, `Locales/*.lua`: English/German base strings and translations.
- `ElvUI.lua`, `Titan.lua`: additive optional integrations.

Do not infer implementation solely from old requests or documentation.
Preserve native editing, selection, scrolling, keyboard navigation, links,
right-click actions, secure APIs, and other addons' behavior. Do not replace
working native editor handlers with synthetic cursor movement.
Do not modify Blizzard, ElvUI, or Titan source. Guard secret values before
comparing, formatting, or using them in unprotected logic. Avoid shared
Blizzard UI tables and preserve the repository's taint safeguards.

Keep independent builds independent, migrate legacy single-build notes, and
never overwrite existing notes when accepting a shared guide. Preserve sender
preview and explicit accept/reject actions. Validate untrusted payloads and
retain transport size, queue, and receive limits. Add new visible strings to
all supported language tables and verify format placeholders.

## Verification

Use Lua 5.1 syntax and run from the repository root:

```bash
lua5.1 syntax_check.lua
for test in tests/*.lua; do lua5.1 "$test"; done
lua5.1 feature_check.lua
python3 -m unittest discover -s tests -p 'test_*.py'
python3 scripts/build_release.py
```

Check installable archives for exactly one top-level `ElvUI_CharNotes/` folder,
a correctly placed manifest, all referenced runtime files, and a matching
checksum. Keep documentation and repository-only files out of installable ZIPs.
Use focused regression tests for concrete changes. Distinguish syntax checks,
mock tests, package checks, and behavior verified in a live WoW Forever client.
Do not claim a live client test or successful publication based on local mocks.

## Release policy

- Ordinary pushes and pull requests run CI. Official releases use matching
  `vMAJOR.MINOR.PATCH` tags, optionally with prerelease suffixes.
- Build one deterministic archive and checksum using `scripts/build_release.py`.
  The tag version must match the manifest.
- Publish the same archive and English Markdown notes to GitHub and CurseForge.
- Generate notes from Conventional Commit subjects and full bodies since the
  preceding tag. Preserve all patch details in included commit bodies.
  Include `feat`, `fix`, `perf`, `security`, and `revert` only. Exclude internal
  `docs`, `refactor`, `test`, `build`, `ci`, `chore`, `style`, and unclassified
  commits. Retain breaking-change markers and a no-public-changes fallback.
- Stable tags map to Release, `-alpha` to Alpha, other prereleases to Beta.
- Keep retries safe: preserve upload markers and reject conflicting assets.
- Read `CURSEFORGE_PROJECT_ID` and JSON `CURSEFORGE_GAME_VERSION_IDS` from
  repository variables. Read `CURSEFORGE_API_TOKEN` only from Actions secrets.
  Never hard-code another addon's project ID or expose credentials.
- Do not commit, push, tag, publish, or upload a release without explicit
  authorization. Configuration and real publishing require separate verification.

## Commit messages and final reports

Every code/documentation task ends with a ready-to-copy English Conventional
Commit message unless the maintainer explicitly asks otherwise. Use a lowercase
recognized type, an optional relevant lowercase scope, a concise imperative
subject (maximum 72 characters), a blank line, and precise body bullets.
Describe only the actual diff and tests performed. Include `BREAKING CHANGE:`
only for genuine incompatibilities and never invent issue numbers.
Prefer separate commits for independent work unless the maintainer requests
one combined commit. Do not create the commits without authorization.

Final reports state what changed and why, affected files, checks actually run,
unverified live-client/publishing behavior, and any impact on versioning,
packaging, or saved settings. For analysis without changes, do not invent a
commit suggesting that files were changed. Explicit maintainer instructions
take precedence over these repository guidelines.
