#!/usr/bin/env bash
set -euo pipefail

# Mirrors what `claude plugin validate` checks, so a broken manifest fails the PR
# rather than every user's next `/plugin marketplace update`.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

marketplace=".claude-plugin/marketplace.json"
status=0

fail() {
  echo "FAIL: $*" >&2
  status=1
}

jq empty "$marketplace" || fail "$marketplace is not valid JSON"

for field in name owner plugins; do
  jq -e "has(\"$field\")" "$marketplace" >/dev/null || fail "$marketplace is missing required field '$field'"
done

jq -e '.owner | has("name")' "$marketplace" >/dev/null || fail "$marketplace owner is missing 'name'"

plugin_root="$(jq -r '.metadata.pluginRoot // "."' "$marketplace")"

while read -r name source; do
  [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "plugin name '$name' is not kebab-case"

  dir="$plugin_root/$source"
  [[ -d "$dir" ]] || { fail "plugin '$name' source directory not found: $dir"; continue; }

  manifest="$dir/.claude-plugin/plugin.json"
  if [[ -f "$manifest" ]]; then
    jq empty "$manifest" || fail "$manifest is not valid JSON"
    manifest_name="$(jq -r '.name // empty' "$manifest")"
    [[ -n "$manifest_name" ]] || fail "$manifest is missing required field 'name'"
  fi

  shopt -s nullglob
  skills=("$dir"/skills/*/SKILL.md)
  agents=("$dir"/agents/*.md)
  commands=("$dir"/commands/*.md)
  shopt -u nullglob

  components=$(( ${#skills[@]} + ${#agents[@]} + ${#commands[@]} ))
  [[ $components -gt 0 ]] || fail "plugin '$name' contributes no skills, agents, or commands"

  # Skills and agents are keyed by their frontmatter name; commands are keyed by filename
  # and only need a description.
  for file in "${skills[@]}" "${agents[@]}"; do
    head -n 1 "$file" | grep -qx -- '---' || fail "$file does not start with YAML frontmatter"
    grep -qE '^name: ' "$file" || fail "$file frontmatter is missing 'name'"
    grep -qE '^description: ' "$file" || fail "$file frontmatter is missing 'description'"
  done

  for file in "${commands[@]}"; do
    head -n 1 "$file" | grep -qx -- '---' || fail "$file does not start with YAML frontmatter"
    grep -qE '^description: ' "$file" || fail "$file frontmatter is missing 'description'"
  done

  shopt -s nullglob
  for script in "$dir"/scripts/*.sh; do
    [[ -x "$script" ]] || fail "$script is not executable"
  done
  shopt -u nullglob
done < <(jq -r '.plugins[] | "\(.name) \(.source)"' "$marketplace")

if [[ $status -eq 0 ]]; then
  echo "All plugin manifests valid."
fi

exit $status
