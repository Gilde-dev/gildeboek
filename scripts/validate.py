#!/usr/bin/env python3
"""Validates registry.yaml and skills/ under a root directory (default: the repo root)."""
import os
import re
import sys

try:
    import yaml
except ImportError:
    print("ERROR: python3 with PyYAML is required (pip install pyyaml)", file=sys.stderr)
    sys.exit(1)

STACKS = ["spring-boot", "nestjs", "nextjs", "node", "other"]
errors = []


def fail(msg):
    errors.append(msg)


def load(text):
    return yaml.safe_load(text)


def main(root):
    registry_path = os.path.join(root, "registry.yaml")
    try:
        with open(registry_path, encoding="utf-8") as f:
            registry = load(f.read())
    except (OSError, yaml.YAMLError):
        print("ERROR: registry.yaml does not parse as YAML", file=sys.stderr)
        return 1
    entries = registry.get("skills") if isinstance(registry, dict) else None
    entries = entries if isinstance(entries, list) else []

    registered = []
    for i, entry in enumerate(entries):
        entry = entry if isinstance(entry, dict) else {}
        name, scope = entry.get("name"), entry.get("scope")
        if name is None:
            fail(f"registry.yaml entry #{i} has no name")
            continue
        registered.append(str(name))
        if not os.path.isfile(os.path.join(root, "skills", str(name), "SKILL.md")):
            fail(f"registry entry '{name}' has no skills/{name}/SKILL.md")
        stacks = entry.get("stacks") or []
        if scope == "global":
            pass
        elif scope == "stack":
            if not stacks:
                fail(f"registry entry '{name}' has scope stack but no stacks")
        else:
            fail(f"registry entry '{name}' has invalid scope '{scope}' (use global or stack)")
        for stack in stacks:
            if str(stack) not in STACKS:
                fail(f"registry entry '{name}' has invalid stack '{stack}' (allowed: {' '.join(STACKS)})")

    skills_dir = os.path.join(root, "skills")
    names = sorted(d for d in os.listdir(skills_dir) if os.path.isdir(os.path.join(skills_dir, d))) if os.path.isdir(skills_dir) else []
    for name in names:
        if name not in registered:
            fail(f"skills/{name} is not listed in registry.yaml")
        rel = f"skills/{name}/SKILL.md"
        path = os.path.join(skills_dir, name, "SKILL.md")
        if not os.path.isfile(path):
            fail(f"skills/{name} has no SKILL.md")
            continue
        with open(path, encoding="utf-8") as f:
            lines = f.read().split("\n")
        if lines[0] != "---":
            fail(f"{rel} has no YAML frontmatter")
            continue
        front = []
        for line in lines[1:]:
            if re.match(r"^---\s*$", line):
                break
            front.append(line)
        try:
            data = load("\n".join(front))
        except yaml.YAMLError:
            fail(f"{rel} frontmatter does not parse")
            continue
        data = data if isinstance(data, dict) else {}
        fm_name = str(data.get("name") or "")
        fm_desc = str(data.get("description") or "")
        if not fm_name:
            fail(f"{rel} frontmatter lacks name")
        if not fm_desc:
            fail(f"{rel} frontmatter lacks description")
        if fm_name and fm_name != name:
            fail(f"{rel} name '{fm_name}' differs from folder name '{name}'")
        if len(fm_desc) > 1024:
            fail(f"{rel} description is {len(fm_desc)} characters (max 1024)")

    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        print(f"{len(errors)} error(s) found", file=sys.stderr)
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")))
