#!/usr/bin/env bash
set -euo pipefail

# Writes the version semantic-release derived into every plugin manifest and
# marketplace entry, so `claude plugin validate --strict` passes and users get a
# pinned version rather than a moving commit SHA. Run from .releaserc.json's
# prepare step; never edit these version fields by hand.

version="${1:?usage: sync-version.sh <version>}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

write_json() {
  local file="$1" filter="$2"
  local tmp
  tmp="$(mktemp)"
  jq --arg version "$version" "$filter" "$file" >"$tmp"
  mv "$tmp" "$file"
}

write_json .claude-plugin/marketplace.json \
  '.version = $version | .plugins |= map(.version = $version)'

for manifest in plugins/*/.claude-plugin/plugin.json; do
  write_json "$manifest" '.version = $version'
done

echo "Synced version $version into plugin manifests."
