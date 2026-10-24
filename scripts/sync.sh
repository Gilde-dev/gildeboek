#!/usr/bin/env bash
# Syncs managed skills from a gildeboek checkout into a repo's .claude/skills/.
#
# Usage: scripts/sync.sh <gildeboek-dir> [repo-dir]
#
# The repo's .gilde.json decides which skills it gets:
#   global skills + skills for any of its `stacks` + `skills.include` - `skills.exclude`
#
# Managed skills carry a `managed-by: gildeboek@<sha>` line in their SKILL.md frontmatter
# (<sha> = last gildeboek commit that touched the skill, so unchanged skills produce no diff).
# Skills without that marker belong to the repo and are never overwritten or deleted.
#
# Needs bash, git and yq v4. The gildeboek checkout needs full history (fetch-depth: 0).
set -euo pipefail

BOEK=${1:?usage: sync.sh <gildeboek-dir> [repo-dir]}
REPO=${2:-.}
MANIFEST="$REPO/.gilde.json"
REGISTRY="$BOEK/registry.yaml"
SKILLS_DIR="$REPO/.claude/skills"
MARKER_KEY="managed-by"

warn() { echo "::warning::$*"; }
die() { echo "::error::$*"; exit 1; }

[ -f "$MANIFEST" ] || die "No .gilde.json in $REPO"
[ -f "$REGISTRY" ] || die "No registry.yaml in $BOEK"

list() { yq -p json -oy -r "$1 // [] | .[]" "$MANIFEST"; }
stacks=$(list '.stacks')
include=$(list '.skills.include')
exclude=$(list '.skills.exclude')
known=$(yq -r '.skills[].name' "$REGISTRY")

for name in $include $exclude; do
  grep -qxF "$name" <<<"$known" || die ".gilde.json names unknown skill '$name' (not in gildeboek registry.yaml)"
done

desired=$(
  {
    yq -r '.skills[] | select(.scope == "global") | .name' "$REGISTRY"
    for stack in $stacks; do
      STACK="$stack" yq -r '.skills[] | select(.scope == "stack" and ((.stacks // []) | any_c(. == strenv(STACK)))) | .name' "$REGISTRY"
    done
    for name in $include; do echo "$name"; done
  } | sort -u | { grep -vxF -f <(printf '%s\n' $exclude) || true; } | { grep -v '^$' || true; }
)

is_managed() {
  grep -q "^$MARKER_KEY: gildeboek@" "$1/SKILL.md" 2>/dev/null && return 0
  # Migration: the old sync wrote .gildeboek-version and no markers. In such a repo, folders
  # named after gildeboek skills were copied by that sync, so they count as managed once.
  [ "$legacy" = true ] && grep -qxF "$(basename "$1")" <<<"$known"
}
legacy=false
[ -f "$SKILLS_DIR/.gildeboek-version" ] && legacy=true

mkdir -p "$SKILLS_DIR"

for name in $desired; do
  src="$BOEK/skills/$name"
  dst="$SKILLS_DIR/$name"
  [ -f "$src/SKILL.md" ] || die "gildeboek skill '$name' has no SKILL.md"
  if [ -e "$dst" ] && ! is_managed "$dst"; then
    warn "Skipped '$name': the repo has its own skill with that name (no $MARKER_KEY marker). Remove it or exclude '$name' in .gilde.json."
    continue
  fi
  sha=$(git -C "$BOEK" log -1 --format=%h -- "skills/$name")
  rm -rf "$dst"
  cp -r "$src" "$dst"
  # Insert the marker as the last frontmatter line (before the closing ---).
  awk -v marker="$MARKER_KEY: gildeboek@$sha" '
    NR == 1 && $0 == "---" { infm = 1; print; next }
    infm && $0 == "---"    { print marker; infm = 0; print; next }
    infm && index($0, "managed-by:") == 1 { next }
    { print }
  ' "$src/SKILL.md" > "$dst/SKILL.md"
  is_managed "$dst" || die "gildeboek skill '$name' has no YAML frontmatter"
  echo "synced  $name@$sha"
done

for dst in "$SKILLS_DIR"/*/; do
  [ -d "$dst" ] || continue
  name=$(basename "$dst")
  if is_managed "$dst" && ! grep -qxF "$name" <<<"$desired"; then
    rm -rf "$dst"
    echo "removed $name (no longer subscribed or no longer in gildeboek)"
  fi
done

# Superseded by the per-skill marker.
rm -f "$SKILLS_DIR/.gildeboek-version"
