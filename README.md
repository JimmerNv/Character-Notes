# Character-Notes

Character-Notes packages **CharNotes: PUNK** for **WoW Forever only**. It keeps account-wide character notes, marks selected players, and offers optional group alerts, tooltips, context-menu actions, data transfer, and opt-in addon-message sharing.

## Installation

1. Download the release ZIP and extract it into the WoW Forever `Interface/AddOns` directory.
2. Confirm that the installed path is `Interface/AddOns/ElvUI_CharNotes/ElvUI_CharNotes.toc`.
3. Start the game and enable **CharNotes: PUNK** on the AddOns screen.

The repository name is deliberately different from the installable folder name. The ZIP contains exactly one top-level folder: `ElvUI_CharNotes`.

## Development

The runtime addon lives in `CharNotes/`. Its manifest targets Forever interface `16001`. ElvUI and Titan Panel are optional integrations. `ElvUICharNotesDB` is the account-wide SavedVariables name.

Run the checks from the repository root:

```powershell
lua5.1 tests/core_spec.lua
python scripts/build_release.py
```

The Lua test uses API mocks. It cannot validate protected APIs, the UI, ElvUI, or addon messaging in the actual WoW Forever client.

## Releases

CI runs Lua syntax checks, mock tests, and the package build on branch pushes and pull requests.

In the GitHub repository, open **Settings → Secrets and variables → Actions** and configure these values.

| Location | Name | Value |
|---|---|---|
| Secrets | `CURSEFORGE_API_TOKEN` | An [author API token](https://authors.curseforge.com/account/api-tokens) with access to this project. |
| Variables | `CURSEFORGE_PROJECT_ID` | The numeric project ID for Character Notes & Alerts. |
| Variables | `CURSEFORGE_GAME_VERSION_IDS` | A JSON array containing the IDs for the supported WoW Forever versions. The [CurseForge Game Versions API](https://support.curseforge.com/support/solutions/articles/9000197321-curseforge-upload-api#Game-Versions-API) returns the IDs. |

Push a version tag on the commit containing the workflow and the version in `CharNotes/ElvUI_CharNotes.toc`. The current manifest uses `1.4.0-beta`, so the matching tag is `v1.4.0-beta`.

```bash
git tag v1.4.0-beta
git push origin v1.4.0-beta
```

The release workflow checks the tagged source and produces `Character-Notes_v1.4.0-beta_Forever.zip` and its SHA-256 checksum. It publishes the ZIP and checksum on GitHub and invokes `scripts/publish_curseforge.sh` to upload the same ZIP to CurseForge. Both sites get the same English release notes derived from user-facing Conventional Commits since the preceding version tag. A stable tag uploads as Release, an `-alpha` tag as Alpha, and a `-beta` or `-rc` tag as Beta.

You can rerun a failed workflow from **Actions → Publish WoW Forever release**. A recorded CurseForge file ID lets the workflow skip an upload that already succeeded. If an interrupted upload leaves `<!-- curseforge-upload-pending -->` in the GitHub release notes, check the project’s CurseForge file list. Replace the marker with `<!-- curseforge-file-id:123 -->` using the actual file ID if the ZIP arrived. If CurseForge has no upload for this tag, remove the pending marker and rerun the workflow.
