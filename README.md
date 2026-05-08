# Inkwell — Shared Docs CLI

A small bash CLI for sharing one body of documentation (plans, architecture
notes, runbooks) across multiple independent projects via filesystem
symlinks.

Mental model: a **docs hub**, not a project integrator. Each project sees a
plain `docs/` directory that's actually a symlink to a single shared root.

```
~/workplace/shared-docs/             ← the true source
├── plans/
├── architecture/
├── runbooks/
├── templates/plan.md
├── docs.config.yml
├── bin/inkwell
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
inkwell init                          # creates plans/, architecture/, runbooks/, config
inkwell link ~/workplace/projectA
inkwell link ~/workplace/projectB
inkwell status
```

`inkwell init` defaults to `~/workplace/shared-docs`. To use a different
location, pass it as the first argument: `inkwell init ~/Documents/docs`.

## Commands

| Command | Description |
|---|---|
| `inkwell init [<root>] [--git\|--no-git]` | Create the shared-docs root and seed it with directories, a default plan template, and an empty config. Idempotent. |
| `inkwell link <project> [--as <dir>]`   | Symlink `<project>/<dir>` (default `docs`) to the shared root. Backs up any existing folder. Updates `.gitignore` if present. |
| `inkwell unlink <project>`              | Remove the symlink and unregister the project. Offers to restore the most recent backup. |
| `inkwell new plan <slug>`               | Create `plans/YYYY-MM-DD-<slug>.md` from `templates/plan.md`. Pass `--open` to open in `$EDITOR`. |
| `inkwell ls [<type>]`                   | List docs (`plans` default, `architecture`, `runbooks`, `all`), newest first. |
| `inkwell status`                        | Health report for the root and each linked project. Exit 1 if anything is wrong. |
| `inkwell search <keyword> [--all]`      | Grep across docs. Uses `rg` when available, falls back to `grep -rn`. |

All commands accept `-h` / `--help`.

## Configuration

Project registry lives at `<root>/docs.config.yml`:

```yaml
version: 1
root: /Users/jin/workplace/shared-docs
projects:
  - name: vueadmin
    path: /Users/jin/workplace/vueadmin
    link_as: docs
    linked_at: 2026-05-08T10:00:00+10:00
settings:
  editor: ""
  date_format: "%Y-%m-%d"
```

The config is written atomically (tmp file + `mv`).

## Plan template

`templates/plan.md` is rendered on `inkwell new plan <slug>` with these
substitutions:

- `{{title}}` — slug with hyphens replaced by spaces, title-cased
- `{{date}}` — today, ISO (`%Y-%m-%d`)
- `{{slug}}` — the original slug

Edit `templates/plan.md` to change the shape of new plans.

## Environment variables

| Variable | Purpose |
|---|---|
| `INKWELL_ROOT` | Override which shared-docs root the CLI operates on. |
| `INKWELL_AUTO_OPEN` | Set to `1` to make `inkwell new plan` open the file automatically. |
| `EDITOR` | Used by `inkwell new plan --open`. Falls back to `vim`. |
| `NO_COLOR` | Disable ANSI color in output. |

## Platform notes

Targets macOS (BSD `stat`, `date`, `readlink`) but works on Linux too. Bash
3.2+ is sufficient. Required tools are all standard: `ln`, `find`, `grep`,
`awk`, `sed`, `mkdir`, `readlink`, `stat`. `rg` is used opportunistically by
`inkwell search` if installed.

## Acceptance checklist

See the spec (in handoff doc) for the full acceptance criteria. Quick smoke:

```bash
inkwell init /tmp/shared-docs
inkwell link /tmp/projectA
inkwell new plan example-feature
inkwell ls
inkwell search example
inkwell status
inkwell unlink /tmp/projectA
```
