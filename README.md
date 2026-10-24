# Gildeboek

The guild book: shared skills for every repo Gilde works in.

Skills here are copied into each repo's `.claude/skills/`, where Claude Code
(interactive sessions and routines alike) picks them up.

## Layout

```
registry.yaml          which skills go to which repos (global or per stack)
skills/<name>/SKILL.md the skills themselves
scripts/sync.sh        the sync logic, run by each repo's sync workflow
templates/             files to copy into repos (the sync workflow)
```

## Adding a repo

1. Add `.gilde.json` at the repo root:
   ```json
   {
     "name": "my-repo",
     "stacks": ["nestjs"],
     "testCommand": "pnpm test",
     "skills": { "include": [], "exclude": [] }
   }
   ```
   `stacks`: one or more of `nestjs`, `spring-boot`, `nextjs`, `node`, `other`.
2. Copy `templates/sync-skills.yaml` to `.github/workflows/sync-skills.yaml` in the repo (no edits needed).
3. Enable *Settings → Actions → General → Allow GitHub Actions to create and approve pull requests*.
4. Run the workflow once (Actions → Sync Gilde skills → Run workflow) and merge the PR.

## Adding or changing a skill

1. Add or edit `skills/<name>/SKILL.md` (frontmatter `name` must match the folder).
2. Register it in `registry.yaml` with `scope: global` or `scope: stack` + `stacks`.
3. Merge. Every matching repo gets a sync PR on its next run.

## Which skills a repo gets

global skills + skills for any of the repo's `stacks` + `skills.include` − `skills.exclude`.
Names in `include`/`exclude` must exist in `registry.yaml`, or the sync fails.

## Managed skills and repo skills

- The sync adds `managed-by: gildeboek@<sha>` to the frontmatter of every skill it copies
  (`<sha>`: the last gildeboek commit that touched that skill). Change those skills here, never in the repo.
- A skill without that line belongs to the repo. The sync never overwrites or deletes it; if it has the same
  name as a gildeboek skill, the sync skips that skill and warns.
- A managed skill that a repo no longer gets (unsubscribed, excluded, or removed from gildeboek) is deleted on the next sync.

## Promoting a repo skill

1. Copy the skill into `skills/<name>/` here (without a `managed-by` line) and register it.
2. In the repo, delete its own copy and add the name to `skills.include` in `.gilde.json` (unless its stack already gets it).
3. The next sync brings it back as a managed skill.
