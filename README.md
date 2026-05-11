# Docs-Hub — Shared Docs CLI

A small bash CLI for sharing one body of documentation (plans, architecture
notes, runbooks) across multiple independent projects via filesystem
symlinks.

Mental model: a **docs hub**, not a project integrator. Each project sees a
plain `docs/` directory that's actually a symlink to a single shared root.

```
~/workplace/docs-hub/             ← the true source
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

~/workplace/projectA/docs            → symlink → ~/workplace/docs-hub
~/workplace/projectB/docs            → symlink → ~/workplace/docs-hub
```

## Install

**Prerequisites:** macOS or Linux, `git`, and a bash-compatible shell
(zsh is fine — that's the macOS default since Catalina). No `brew`,
no `pip`, no Node, no compile step.

### 1. Clone the repo to wherever you want the shared docs to live

The repo's own directory **is** the shared root. The conventional
location is `~/workplace/docs-hub`:

```bash
mkdir -p ~/workplace
git clone https://github.com/lukerjin/Docs-Hub.git ~/workplace/docs-hub
```

(If you want it somewhere else, e.g. `~/Documents/docs-hub`, swap
the path. The CLI works the same.)

### 2. Put `bin/` on your PATH

Pick the right line for your shell. Check with `echo $SHELL`:

```bash
# zsh (default on macOS):
echo 'export PATH="$HOME/workplace/docs-hub/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# bash (most Linux, older macOS):
echo 'export PATH="$HOME/workplace/docs-hub/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 3. Verify

```bash
docs-hub --version          # → docs-hub 0.1.0
```

If you see `command not found`, the PATH didn't take effect — see
[Troubleshooting](#troubleshooting).

### 4. Initialize and link your first project

```bash
docs-hub init                          # creates plans/, architecture/, AGENTS.md, config, …
docs-hub link ~/workplace/projectA
docs-hub link ~/workplace/projectB
docs-hub status                        # should show both projects: OK
```

`docs-hub init` defaults to `~/workplace/docs-hub`. To use a
different location, pass it as the first argument:
`docs-hub init ~/Documents/docs`.

## Already have a `docs/` folder?

By default, `docs-hub link <project>` symlinks `<project>/docs/` to
the shared root and backs up any existing folder to
`docs.bak.<timestamp>` (nothing deleted, fully reversible). That's
fine if your existing `docs/` is empty, stale, or contains
generated artifacts.

If you have a **real, in-use** `docs/` you want to keep, link under
a different directory name with `--as`:

```bash
docs-hub link /Users/jin/workplace/vueadmin --as docs-hub
```

Now the project looks like:

```
vueadmin/
├── docs/         ← your original files, untouched
└── docs-hub/    ← symlink → shared root
```

**AI tradeoff**: tools like Codex / Claude Code auto-discover
`docs/AGENTS.md` and `docs/CLAUDE.md`. If you used `--as docs-hub`,
the AI won't find them at the standard path. Easiest workaround:
drop a one-line `CLAUDE.md` (or `AGENTS.md`) at the project root
that imports the real one:

```markdown
@./docs-hub/AGENTS.md
```

(Or copy `AGENTS.md` to the project root — but you'll then have to
keep it in sync manually. The import line is cheaper.)

Already linked with the default and want to switch? Roll back, then
re-link:

```bash
docs-hub unlink /Users/jin/workplace/vueadmin              # restores the backup
docs-hub link  /Users/jin/workplace/vueadmin --as docs-hub
```

## Commands

| Command | Description |
|---|---|
| `docs-hub init [<root>] [--git\|--no-git]` | Create the docs-hub root and seed it with directories, default templates (`plan.md`, `AGENTS.md`, `CLAUDE.md`), and an empty config. Idempotent. |
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
root: /Users/alice/workplace/docs-hub
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
| `DOCSHUB_ROOT` | Override which docs-hub root the CLI operates on. |
| `DOCSHUB_AUTO_OPEN` | Set to `1` to make `docs-hub new plan` open the file automatically. |
| `DOCSHUB_ASSUME_YES` | Set to `1` to auto-confirm prompts (useful in scripts / CI). |
| `EDITOR` | Used by `docs-hub new plan --open`. Falls back to `vim`. |
| `NO_COLOR` | Disable ANSI color in output. |

## Platform notes

Targets macOS (BSD `stat`, `date`, `readlink`) but works on Linux too.
Bash 3.2+ is sufficient. Required tools are all standard: `ln`, `find`,
`grep`, `awk`, `sed`, `mkdir`, `readlink`, `stat`. `rg` is used
opportunistically by `docs-hub search` if installed.

## Troubleshooting

**`command not found: docs-hub`**

PATH didn't take effect. Check:

```bash
echo $PATH | tr ':' '\n' | grep docs-hub   # should print the bin path
```

If it doesn't appear, you probably edited the wrong shell rc file or
opened a new terminal that hasn't sourced it. Try again with `~/.zshrc`
vs `~/.bashrc` per [Install §2](#2-put-bin-on-your-path), or just call
the script directly to confirm it works:

```bash
~/workplace/docs-hub/bin/docs-hub --version
```

**`Permission denied` running `docs-hub`**

The script lost its executable bit (rare, but happens after some `git`
operations on Windows-touched repos):

```bash
chmod +x ~/workplace/docs-hub/bin/docs-hub
```

**`docs-hub root not found` from any command**

Either the path moved, or `DOCSHUB_ROOT` is set to the wrong place.
Check what the CLI thinks the root is:

```bash
docs-hub status                  # first line shows the root path
echo "$DOCSHUB_ROOT"             # empty means "auto-detect"
```

If you actually moved the docs-hub directory, just update the PATH
line in your shell rc.

**`link` says my docs already exist with N files — what's safe?**

You'll be prompted. On confirm, the existing `<project>/docs/` is moved
to `<project>/docs.bak.<timestamp>` (nothing deleted). To restore, run
`docs-hub unlink <project>` — it'll offer to restore the most recent
backup.

If those N files are real, in-use project docs you want to keep, answer
**N**, then re-link with `--as docs-hub` so the shared root mounts at
`docs-hub/` instead of stomping on `docs/`. See
[Already have a `docs/` folder?](#already-have-a-docs-folder).

**`status` reports `BROKEN` for a project**

The symlink points to something other than the shared root, or its
target is missing. To fix a missing-target symlink:

```bash
docs-hub link <project-path> --repair
```

For a wrong-target symlink, remove it manually first
(`rm <project>/docs`) then re-`link`.

**My `settings:` block in `docs.config.yml` disappeared**

It shouldn't — the config writer preserves it verbatim across `link`
and `unlink`. If it did, please file an issue with the before/after
contents.

**I'm on Windows**

Not supported. The CLI relies on POSIX symlinks and a Unix shell.
WSL works.

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
docs-hub init /tmp/docs-hub
docs-hub link /tmp/projectA
cd /tmp/projectA
docs-hub new plan example-feature
docs-hub ls
docs-hub search example
docs-hub status
docs-hub unlink /tmp/projectA
```
