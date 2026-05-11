# Docs-Hub

One shared `docs/` folder across many repos, via symlinks. Plans, architecture notes, and runbooks live in one place; every linked repo sees them as a normal `docs/`.

## Quickstart

```bash
git clone <this-repo> ~/workplace/shared-docs
echo 'export PATH="$HOME/workplace/shared-docs/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

docs-hub init
docs-hub link ~/workplace/my-app

cd ~/workplace/my-app
docs-hub new plan auth-flow        # → plans/my-app/2026-05-11-auth-flow.md
```

Done. That plan is now visible from every linked repo at `docs/plans/my-app/...`.

## Commands

| | |
|---|---|
| `init` | set up the shared root |
| `link <project>` | symlink `<project>/docs` to the root |
| `unlink <project>` | reverse `link`; offers to restore the original `docs/` |
| `new plan <slug>` | dated plan in `plans/<current-project>/`; `--shared` for cross-project |
| `ls`, `search`, `status` | browse, grep, health-check |

Every command has `--help`. Tests: `./tests/smoke.sh`.

## Layout

```
shared-docs/
├── plans/<project>/   ← per-project
├── plans/shared/      ← cross-project
├── architecture/      ← unscoped, shared by convention
├── runbooks/          ← unscoped
└── AGENTS.md          ← rules AI agents read via each repo's docs/AGENTS.md
```

`AGENTS.md` (and a one-line `CLAUDE.md` that imports it) ships at the shared root and reaches every linked repo through the symlink — no per-repo setup. Edit `templates/AGENTS.md` to change the rules globally.
