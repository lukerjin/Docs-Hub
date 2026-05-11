# Docs-Hub — Shared Docs CLI

A small bash CLI for sharing one body of documentation (plans, architecture
notes, runbooks) across multiple independent projects via filesystem
symlinks.

Mental model: a **docs hub**, not a project integrator. Each project sees a
plain `docs/` directory that's actually a symlink to a single shared root.

```
~/workplace/shared-docs/             ← the true source
├── AGENTS.md / CLAUDE.md            ← rules for AI agents (auto-shared)
├── plans/
│   ├── <project-name>/              ← per-project plans
│   └── shared/                      ← cross-project plans
├── architecture/                    ← unscoped, shared by convention
├── runbooks/                        ← unscoped
├── templates/                       ← plan.md, AGENTS.md, CLAUDE.md seeds
├── docs.config.yml                  ← project registry
├── bin/docs-hub
└── lib/

~/workplace/projectA/docs            → symlink → ~/workplace/shared-docs
~/workplace/projectB/docs            → symlink → ~/workplace/shared-docs
```

## Install

Clone this repo to wherever you want the shared root to live (e.g.
`~/workplace/shared-docs`), then put `bin/` on your PATH:

```bash
echo 'export PATH="$HOME/workplace/shared-docs/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
docs-hub init                          # creates plans/, architecture/, runbooks/, AGENTS.md, config
docs-hub link ~/workplace/projectA
docs-hub link ~/workplace/projectB
docs-hub status
```

`docs-hub init` defaults to `~/workplace/shared-docs`. To use a different
location, pass it as the first argument: `docs-hub init ~/Documents/docs`.

## Commands

| Command | Description |
|---|---|
| `docs-hub init [<root>] [--git\|--no-git]` | Create the shared-docs root and seed it with directories, default templates (`plan.md`, `AGENTS.md`, `CLAUDE.md`), and an empty config. Idempotent. |
| `docs-hub link <project> [--as <dir>] [--repair]` | Symlink `<project>/<dir>` (default `docs`) to the shared root. Backs up any existing folder. Updates `.gitignore` if present. Creates `plans/<project-name>/` automatically. `--repair` fixes a broken symlink. |
| `docs-hub unlink <project>` | Remove the symlink and unregister the project. Offers to restore the most recent backup. |
| `docs-hub new plan <slug> [--shared\|--project <name>] [--open]` | Create `plans/<scope>/YYYY-MM-DD-<slug>.md` from `templates/plan.md`. Scope is inferred from cwd when inside a registered project; use `--shared` for cross-project, or `--project <name>` to target explicitly. |
| `docs-hub ls [<type>] [--project <name>\|--shared]` | List docs newest first. For plans, output is grouped by scope. |
| `docs-hub status` | Health report for the root and each linked project. Exit 1 if anything is wrong. |
| `docs-hub search <keyword> [--all]` | Grep across docs. Uses `rg` when available, falls back to `grep -rn`. |

All commands accept `-h` / `--help`.

## Plan scoping

Plans live under `plans/<scope>/`:

- `plans/<project-name>/` — implementation plans for that project
- `plans/shared/` — plans that affect multiple projects

The CLI enforces it:

```bash
cd ~/workplace/projectA
docs-hub new plan auth-flow
# → plans/projectA/2026-05-11-auth-flow.md  (scope inferred from cwd)

docs-hub new plan team-conventions --shared
# → plans/shared/2026-05-11-team-conventions.md

docs-hub new plan migration --project projectB
# → plans/projectB/2026-05-11-migration.md
```

`docs-hub link` creates `plans/<project-name>/` automatically so the slot
is ready and shows up in `ls`.

`architecture/` and `runbooks/` stay flat — shared by convention.

## Rules for AI agents

`init` writes an `AGENTS.md` and a one-line `CLAUDE.md` (which imports
AGENTS.md) at the shared root. Because each project's `docs/` is a
symlink to the root, Codex / Claude Code / etc. see them as
`docs/AGENTS.md` and `docs/CLAUDE.md` — no per-repo setup.

The default `AGENTS.md` documents:

- the per-project / shared / unscoped layout
- which `plans/<name>/` folder to read for the current project
- how to create new plans through the CLI
- what NOT to do (e.g., don't hand-edit `docs.config.yml`)

Edit `templates/AGENTS.md` to change the convention globally; the next
`docs-hub init` (or a manual copy) publishes it to the root. The root
copy is **never overwritten** by re-running `init`.

## Configuration

Project registry lives at `<root>/docs.config.yml`:

```yaml
version: 1
root: /Users/alice/workplace/shared-docs
projects:
  - name: my-app
    path: /Users/alice/workplace/my-app
    link_as: docs
    linked_at: 2026-05-08T10:00:00+10:00
settings:
  editor: ""
  date_format: "%Y-%m-%d"
```

The config is written atomically (tmp file + `mv`). The `settings:`
block is preserved across `link` / `unlink`, so edits there survive.

## Plan template

`templates/plan.md` is rendered on `docs-hub new plan <slug>` with these
substitutions:

- `{{title}}` — slug with hyphens replaced by spaces, title-cased
- `{{date}}` — today, ISO (`%Y-%m-%d`)
- `{{slug}}` — the original slug
- `{{scope}}` — the project name (or `shared`) the plan is filed under

Edit `templates/plan.md` to change the shape of new plans.

## Environment variables

| Variable | Purpose |
|---|---|
| `DOCSHUB_ROOT` | Override which shared-docs root the CLI operates on. |
| `DOCSHUB_AUTO_OPEN` | Set to `1` to make `docs-hub new plan` open the file automatically. |
| `DOCSHUB_ASSUME_YES` | Set to `1` to auto-confirm prompts (useful in scripts / CI). |
| `EDITOR` | Used by `docs-hub new plan --open`. Falls back to `vim`. |
| `NO_COLOR` | Disable ANSI color in output. |

## Platform notes

Targets macOS (BSD `stat`, `date`, `readlink`) but works on Linux too.
Bash 3.2+ is sufficient. Required tools are all standard: `ln`, `find`,
`grep`, `awk`, `sed`, `mkdir`, `readlink`, `stat`. `rg` is used
opportunistically by `docs-hub search` if installed.

## Tests

End-to-end smoke test (no framework, plain bash):

```bash
./tests/smoke.sh
```

Sets up temp project directories, exercises every command (including
`--repair`, scoping, settings preservation, AGENTS.md seeding), and
prints `passed: N  failed: M`. Exits non-zero on any failure.

## Quick smoke

```bash
docs-hub init /tmp/shared-docs
docs-hub link /tmp/projectA
cd /tmp/projectA
docs-hub new plan example-feature
docs-hub ls
docs-hub search example
docs-hub status
docs-hub unlink /tmp/projectA
```
