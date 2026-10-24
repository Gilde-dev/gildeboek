# Gildeboek — agent guide

Gildeboek is the shared skills registry for Gilde. It holds the skills that Gilde syncs into the `.claude/skills/` folder of other repos. It has no application code and no application stack.

## Repository layout
- `registry.yaml` — which skills go to which repos (`scope: global`, or `scope: stack` + `stacks`)
- `skills/<name>/SKILL.md` — one folder per skill; a skill may carry extra files (e.g. `skills/write-agents-md/templates/`)
- `templates/sync-skills.yaml` — the sync workflow that consuming repos copy to `.github/workflows/sync-skills.yaml`
- `scripts/validate.sh` — validates the registry and every skill (needs bash and yq v4)
- `.github/workflows/ci.yaml` — workflow `CI`, job `build`, runs `./scripts/validate.sh` on pull requests and pushes to `main`
- `README.md` — human overview

## Commands
- Validate: `./scripts/validate.sh` (prints `OK`, exits non-zero with a message per problem). Requires [mikefarah yq](https://github.com/mikefarah/yq) v4; the Python `yq` wrapper does not work.

## How a skill is structured
`skills/<name>/SKILL.md` starts with YAML frontmatter with `name` (must equal the folder name) and `description` (at most 1024 characters; quote it if it contains `: `), followed by Markdown instructions. Valid stacks are `spring-boot`, `nestjs`, `nextjs`, `node`, `other`.

## Adding or changing a skill
1. Add or edit `skills/<name>/SKILL.md` with the frontmatter above.
2. Register it in `registry.yaml`: `scope: global` for every repo, or `scope: stack` with `stacks: [...]` for repos of those stacks.
3. Run `./scripts/validate.sh`; it must pass.
4. Merge. Every matching repo gets a sync PR on its next run.

## How skills reach other repos
Consuming repos run the sync workflow from `templates/sync-skills.yaml`, which copies the matching skills into their `.claude/skills/` and records the gildeboek commit in `.claude/skills/.gildeboek-version`. The next sync overwrites any local edit, so synced skills are changed here, never in the consuming repo. Repo-specific skills live in the consuming repo under a name that is not in `registry.yaml`.

## Conventions
- A skill folder must be listed in `registry.yaml`, and every registry entry must have a `SKILL.md`.
- Keep `AGENTS.md` aligned with the `write-agents-md` skill when either changes.


## Rules for agents
- Make the smallest change that satisfies the task and its acceptance criteria.
- If the task conflicts with existing code or is ambiguous, don't guess: report it as `blocked` and explain.
- Add or update tests for behaviour you change.
- Run the test command before opening a PR; don't open a PR with failing tests unless the task is impossible (then report `blocked`).
- Do not modify `.github/`, `.claude/`, `AGENTS.md`, `CLAUDE.md`, or existing database migrations unless the task says so.
- Skills in `.claude/skills/` are synced from Gilde-dev/gildeboek; never edit them in this repo.
- Do not add dependencies unless the task needs them; mention any new one in the PR.
- Never commit secrets, tokens or `.env` files.
