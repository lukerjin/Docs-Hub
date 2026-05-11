# Docs-Hub

One shared `docs/` folder across many projects, via symlinks. Plans, architecture notes, and runbooks live in one place; every linked repo sees them as a normal `docs/` directory.

## Install

```bash
git clone <this-repo> ~/workplace/shared-docs
echo 'export PATH="$HOME/workplace/shared-docs/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
docs-hub init
```

That's it. PATH is set, the hub is ready.

## Use it (the 5 commands you'll actually run)

```bash
# 1. Connect a project. Run once per repo.
docs-hub link ~/workplace/my-app

# 2. Inside a project, write a new plan. Goes into plans/my-app/ automatically.
cd ~/workplace/my-app
docs-hub new plan auth-flow

# 3. For a plan that affects multiple projects:
docs-hub new plan team-conventions --shared

# 4. See what's there:
docs-hub ls               # plans, grouped by project
docs-hub search "auth"    # grep across everything

# 5. Sanity check anytime:
docs-hub status
```

Files end up at `~/workplace/shared-docs/plans/my-app/2026-05-11-auth-flow.md` — and visible from `~/workplace/my-app/docs/plans/my-app/...` via the symlink. Same files, same place.

## What gets shared, what stays separate

```
shared-docs/
├── plans/
│   ├── my-app/       ← only my-app's plans
│   ├── other-app/    ← only other-app's plans
│   └── shared/       ← plans that touch >1 project
├── architecture/     ← shared by convention (flat)
├── runbooks/         ← shared by convention (flat)
└── AGENTS.md         ← rules for Codex/Claude (auto-discovered via docs/)
```

`plans/` is scoped per project. `architecture/` and `runbooks/` are shared by default.

## For AI agents (Codex / Claude Code)

When you `link` a project, the symlink also exposes `docs/AGENTS.md` and `docs/CLAUDE.md` to the AI. They explain:

- which `plans/<name>/` folder belongs to the current repo
- how to create new plans via the CLI
- what NOT to touch

Edit `templates/AGENTS.md` to change the rules — they propagate to every linked repo instantly.

## Reference

<details>
<summary>All commands</summary>

| Command | What it does |
|---|---|
| `docs-hub init [<root>] [--git\|--no-git]` | Set up the shared root. Idempotent. |
| `docs-hub link <project> [--as <dir>] [--repair]` | Symlink `<project>/docs` → shared root. Backs up existing `docs/`. `--repair` fixes a broken symlink. |
| `docs-hub unlink <project>` | Remove the symlink, restore backup if any. |
| `docs-hub new plan <slug> [--shared\|--project <name>] [--open]` | Create `plans/<scope>/YYYY-MM-DD-<slug>.md`. Scope auto-detected from cwd. |
| `docs-hub ls [<type>] [--project <name>\|--shared]` | List docs. `<type>` = plans (default) / architecture / runbooks / all. |
| `docs-hub search <keyword> [--all]` | grep across docs. Uses `rg` if available. |
| `docs-hub status` | Health report. Exit 1 on any problem. |

Every command accepts `-h` / `--help`.

</details>

<details>
<summary>Environment variables</summary>

| Var | Effect |
|---|---|
| `DOCSHUB_ROOT` | Use this root instead of the default. |
| `DOCSHUB_AUTO_OPEN=1` | `new plan` opens `$EDITOR` automatically. |
| `DOCSHUB_ASSUME_YES=1` | Auto-confirm prompts (CI, scripts). |
| `EDITOR` | Used by `new plan --open`. Falls back to `vim`. |
| `NO_COLOR` | Disable colored output. |

</details>

<details>
<summary>Config file (docs.config.yml)</summary>

Written by the CLI — don't hand-edit:

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

The `settings:` block is preserved across `link`/`unlink`, so edits there survive.

</details>

<details>
<summary>Tests</summary>

```bash
./tests/smoke.sh
```

Self-contained 66-assertion end-to-end test. No framework dependencies. Exits non-zero on failure.

</details>

<details>
<summary>Platform notes</summary>

Targets macOS, works on Linux. Bash 3.2+. Uses only standard tools (`ln`, `find`, `grep`, `awk`, `sed`, `mkdir`, `readlink`, `stat`). `rg` is used opportunistically by `search` if installed.

</details>
