#!/usr/bin/env bash
# Validates registry.yaml and skills/. Needs bash and yq v4 (mikefarah).
set -euo pipefail

cd "$(dirname "$0")/.."

STACKS="spring-boot nestjs nextjs node other"
errors=0
fail() { echo "ERROR: $*" >&2; errors=$((errors + 1)); }

if ! yq --version 2>&1 | grep -q 'mikefarah'; then
  echo "ERROR: yq v4 (https://github.com/mikefarah/yq) is required" >&2
  exit 1
fi

if ! yq '.' registry.yaml >/dev/null 2>&1; then
  echo "ERROR: registry.yaml does not parse as YAML" >&2
  exit 1
fi

registered=$(yq '.skills[].name' registry.yaml)

# Registry entries
count=$(yq '.skills | length' registry.yaml)
for ((i = 0; i < count; i++)); do
  name=$(yq ".skills[$i].name" registry.yaml)
  scope=$(yq ".skills[$i].scope" registry.yaml)
  if [[ "$name" == "null" ]]; then
    fail "registry.yaml entry #$i has no name"
    continue
  fi
  [[ -f "skills/$name/SKILL.md" ]] || fail "registry entry '$name' has no skills/$name/SKILL.md"
  case "$scope" in
    global) ;;
    stack)
      n=$(yq ".skills[$i].stacks | length" registry.yaml)
      [[ "$n" -gt 0 ]] || fail "registry entry '$name' has scope stack but no stacks"
      ;;
    *) fail "registry entry '$name' has invalid scope '$scope' (use global or stack)" ;;
  esac
  for stack in $(yq ".skills[$i].stacks // [] | .[]" registry.yaml); do
    [[ " $STACKS " == *" $stack "* ]] || fail "registry entry '$name' has invalid stack '$stack' (allowed: $STACKS)"
  done
done

# Skill folders
for dir in skills/*/; do
  [[ -d "$dir" ]] || continue
  dir=${dir%/}
  name=$(basename "$dir")
  if ! grep -qx "$name" <<<"$registered"; then
    fail "skills/$name is not listed in registry.yaml"
  fi
  file="$dir/SKILL.md"
  [[ -f "$file" ]] || { fail "skills/$name has no SKILL.md"; continue; }

  if [[ "$(head -n 1 "$file")" != "---" ]]; then
    fail "$file has no YAML frontmatter"
    continue
  fi
  front=$(awk 'NR == 1 { next } /^---[[:space:]]*$/ { exit } { print }' "$file")
  fm_name=$(yq '.name // ""' <<<"$front" 2>/dev/null) || { fail "$file frontmatter does not parse"; continue; }
  fm_desc=$(yq '.description // ""' <<<"$front")
  [[ -n "$fm_name" ]] || fail "$file frontmatter lacks name"
  [[ -n "$fm_desc" ]] || fail "$file frontmatter lacks description"
  if [[ -n "$fm_name" && "$fm_name" != "$name" ]]; then
    fail "$file name '$fm_name' differs from folder name '$name'"
  fi
  if ((${#fm_desc} > 1024)); then
    fail "$file description is ${#fm_desc} characters (max 1024)"
  fi
done

if ((errors > 0)); then
  echo "$errors error(s) found" >&2
  exit 1
fi
echo OK
