#!/usr/bin/env bash
# Fixture tests for scripts/validate.sh. Needs bash, python3 and PyYAML.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

# fixture <dir> <registry yaml> — creates a valid skill "demo" unless overridden afterwards
fixture() {
  mkdir -p "$1/skills/demo"
  printf '%s\n' "$2" >"$1/registry.yaml"
  printf -- '---\nname: demo\ndescription: A demo skill\n---\nBody\n' >"$1/skills/demo/SKILL.md"
}

# expect <label> <dir> <exit 0|1> <stdout> <stderr substring>
expect() {
  local out err code
  out=$("$here/validate.sh" "$2" 2>"$tmp/err"); code=$?
  err=$(cat "$tmp/err")
  if [[ "$code" -ne "$3" || "$out" != "$4" || "$err" != *"$5"* ]]; then
    echo "FAIL: $1 (exit $code, stdout '$out', stderr '$err')"; failures=$((failures + 1))
  else
    echo "ok: $1"
  fi
}

case_dir() { mkdir -p "$tmp/$1"; echo "$tmp/$1"; }

d=$(case_dir valid); fixture "$d" $'skills:\n  - name: demo\n    scope: global'
expect "valid global registry prints exactly OK" "$d" 0 "OK" ""
d=$(case_dir valid-stack); fixture "$d" $'skills:\n  - name: demo\n    scope: stack\n    stacks: [nestjs, node]'
expect "valid stack registry" "$d" 0 "OK" ""
expect "the repository itself" "$here/.." 0 "OK" ""

d=$(case_dir bad-yaml); fixture "$d" 'skills: [unclosed'
expect "registry that is not YAML" "$d" 1 "" "registry.yaml does not parse as YAML"
d=$(case_dir no-name); fixture "$d" $'skills:\n  - scope: global'
expect "entry without name" "$d" 1 "" "entry #0 has no name"
d=$(case_dir missing-skill); fixture "$d" $'skills:\n  - name: demo\n    scope: global\n  - name: ghost\n    scope: global'
expect "entry without SKILL.md" "$d" 1 "" "registry entry 'ghost' has no skills/ghost/SKILL.md"
d=$(case_dir bad-scope); fixture "$d" $'skills:\n  - name: demo\n    scope: everywhere'
expect "invalid scope" "$d" 1 "" "invalid scope 'everywhere'"
d=$(case_dir no-stacks); fixture "$d" $'skills:\n  - name: demo\n    scope: stack'
expect "stack scope without stacks" "$d" 1 "" "has scope stack but no stacks"
d=$(case_dir bad-stack); fixture "$d" $'skills:\n  - name: demo\n    scope: stack\n    stacks: [cobol]'
expect "invalid stack" "$d" 1 "" "invalid stack 'cobol'"
d=$(case_dir unregistered); fixture "$d" $'skills:\n  - name: demo\n    scope: global'
mkdir -p "$d/skills/extra"; cp "$d/skills/demo/SKILL.md" "$d/skills/extra/SKILL.md"
expect "skill folder not in registry" "$d" 1 "" "skills/extra is not listed in registry.yaml"
d=$(case_dir no-frontmatter); fixture "$d" $'skills:\n  - name: demo\n    scope: global'
echo "just text" >"$d/skills/demo/SKILL.md"
expect "SKILL.md without frontmatter" "$d" 1 "" "has no YAML frontmatter"
d=$(case_dir bad-frontmatter); fixture "$d" $'skills:\n  - name: demo\n    scope: global'
printf -- '---\ndescription: a: b\nname: demo\n---\n' >"$d/skills/demo/SKILL.md"
expect "unparseable frontmatter" "$d" 1 "" "frontmatter does not parse"
d=$(case_dir no-desc); fixture "$d" $'skills:\n  - name: demo\n    scope: global'
printf -- '---\nname: demo\n---\n' >"$d/skills/demo/SKILL.md"
expect "missing description" "$d" 1 "" "frontmatter lacks description"
d=$(case_dir name-mismatch); fixture "$d" $'skills:\n  - name: demo\n    scope: global'
printf -- '---\nname: other\ndescription: x\n---\n' >"$d/skills/demo/SKILL.md"
expect "name differs from folder" "$d" 1 "" "name 'other' differs from folder name 'demo'"
d=$(case_dir long-desc); fixture "$d" $'skills:\n  - name: demo\n    scope: global'
printf -- '---\nname: demo\ndescription: %s\n---\n' "$(printf 'x%.0s' $(seq 1025))" >"$d/skills/demo/SKILL.md"
expect "description over 1024 characters" "$d" 1 "" "description is 1025 characters (max 1024)"

((failures == 0)) || { echo "$failures test(s) failed" >&2; exit 1; }
echo "All tests passed"
