# Docs-Hub

One shared `docs/` across many repos, via symlinks.

```bash
git clone <this-repo> ~/workplace/shared-docs
export PATH="$HOME/workplace/shared-docs/bin:$PATH"

docs-hub init
docs-hub link ~/workplace/my-app
cd ~/workplace/my-app
docs-hub new plan auth-flow        # → plans/my-app/2026-05-11-auth-flow.md
```

```
shared-docs/
├── plans/<project>/   ← per-project
├── plans/shared/      ← cross-project (use --shared)
├── architecture/      ← unscoped, shared
├── runbooks/          ← unscoped, shared
└── AGENTS.md          ← rules for Codex/Claude, auto-shared via the symlink
```

Commands: `init`, `link`, `unlink`, `new plan`, `ls`, `search`, `status`. Every one has `--help`. Tests: `./tests/smoke.sh`.
