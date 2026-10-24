# Gildeboek

The guild book: shared skills for every repo Gilde works in.

Skills here are copied into each repo's `.claude/skills/`, where Claude Code
(interactive sessions and routines alike) picks them up.

## Layout

```
registry.yaml          which skills go to which repos (global or per stack)
skills/<name>/SKILL.md the skills themselves
templates/             files to copy into repos (the sync workflow)
```

## Adding a repo

1. Copy `templates/sync-skills.yaml` to `.github/workflows/sync-skills.yaml` in the repo.
2. Set `STACK` to the repo's stack (`nestjs`, `spring-boot`, `nextjs`, `node`, `other`).
3. Enable *Settings → Actions → General → Allow GitHub Actions to create and approve pull requests*.
4. Run the workflow once (Actions → Sync Gilde skills → Run workflow) and merge the PR.

## Adding or changing a skill

1. Add or edit `skills/<name>/SKILL.md` (frontmatter `name` must match the folder).
2. Register it in `registry.yaml` with `scope: global` or `scope: stack` + `stacks`.
3. Merge. Every matching repo gets a sync PR on its next run.

## Rules

- Synced skills are managed: change them here, never in a target repo (the next sync overwrites them).
- Repo-specific skills live in the repo under a name that isn't in `registry.yaml`; the sync leaves them alone.
- `.claude/skills/.gildeboek-version` in a repo records which gildeboek commit it was synced from.
