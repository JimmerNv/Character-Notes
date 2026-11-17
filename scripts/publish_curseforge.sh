#!/usr/bin/env bash
set -euo pipefail

if (( $# != 4 )); then
    echo "Usage: bash scripts/publish_curseforge.sh TAG ZIP NOTES DISPLAY_NAME" >&2
    exit 2
fi

tag="$1"
archive="$2"
notes="$3"
display_name="$4"
if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ || ! -s "$archive" || ! -s "$notes" ]]; then
    echo "Provide a version tag, its release ZIP, and its Markdown release notes." >&2
    exit 2
fi

release_body="$(gh release view "$tag" --json body --jq '.body')"
if grep -Eq '^<!-- curseforge-file-id:[1-9][0-9]* -->$' <<< "$release_body"; then
    echo "CurseForge already accepted this release."
    exit 0
fi

pending='<!-- curseforge-upload-pending -->'
if grep -Fxq -- "$pending" <<< "$release_body"; then
    echo "The earlier upload outcome is uncertain. Check the CurseForge file list and resolve the pending marker in the GitHub release notes before retrying." >&2
    exit 1
fi

: "${CURSEFORGE_API_TOKEN:?Add the GitHub Actions secret CURSEFORGE_API_TOKEN}"
if [[ ! "${CURSEFORGE_PROJECT_ID:-}" =~ ^[1-9][0-9]*$ ]]; then
    echo "Set CURSEFORGE_PROJECT_ID to your Character Notes CurseForge project ID." >&2
    exit 2
fi
if ! jq -e 'type == "array" and length > 0 and all(.[]; type == "number" and . > 0 and floor == .)' \
    <<< "${CURSEFORGE_GAME_VERSION_IDS:-null}" > /dev/null; then
    echo "Set CURSEFORGE_GAME_VERSION_IDS to a JSON array of positive game version IDs." >&2
    exit 2
fi

case "${tag,,}" in
    *-alpha*) release_type='alpha' ;;
    *-*) release_type='beta' ;;
    *) release_type='release' ;;
esac

metadata="$(jq -nc --rawfile changelog "$notes" --arg displayName "$display_name" \
    --arg releaseType "$release_type" --argjson gameVersions "$CURSEFORGE_GAME_VERSION_IDS" \
    '{changelog: $changelog, changelogType: "markdown", displayName: $displayName, releaseType: $releaseType, gameVersions: $gameVersions}')"

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

record_upload_status() {
    {
        cat "$notes"
        printf '\n%s\n' "$1"
    } > "$temp_dir/release-notes.md"
    gh release edit "$tag" --notes-file "$temp_dir/release-notes.md" >/dev/null
}

# Record the in-flight state before sending the upload so an interrupted
# request cannot result in a second copy on a workflow rerun.
record_upload_status "$pending"
if ! status="$(curl --silent --show-error --connect-timeout 20 --max-time 600 \
    --header @- --form-string "metadata=$metadata" \
    --form "file=@$archive;type=application/zip" \
    --output "$temp_dir/response.json" --write-out '%{http_code}' \
    "https://wow.curseforge.com/api/projects/$CURSEFORGE_PROJECT_ID/upload-file" \
    <<< "X-Api-Token: $CURSEFORGE_API_TOKEN")"; then
    echo "CurseForge did not confirm the upload. Check the project files before retrying." >&2
    exit 1
fi

case "$status" in
    2??) ;;
    408)
        echo "CurseForge timed out. Check the project files before retrying." >&2
        exit 1
        ;;
    4??)
        gh release edit "$tag" --notes-file "$notes" >/dev/null
        echo "CurseForge rejected the upload (HTTP $status). Check the token, project ID, and game version IDs before retrying." >&2
        exit 1
        ;;
    *)
        echo "CurseForge did not confirm the upload (HTTP $status). Check the project files before retrying." >&2
        exit 1
        ;;
esac

if ! file_id="$(jq -er '.id | select(type == "number" and . > 0 and floor == .)' "$temp_dir/response.json")"; then
    echo "CurseForge returned no valid file ID. Check the project files before retrying." >&2
    exit 1
fi
printf 'CurseForge accepted file ID %s.\n' "$file_id"
record_upload_status "<!-- curseforge-file-id:$file_id -->"
