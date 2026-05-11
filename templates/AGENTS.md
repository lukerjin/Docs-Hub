# Shared docs — for AI agents

This directory is a **shared documentation hub** managed by
[`docs-hub`](https://github.com/lukerjin/Docs-Hub). It is symlinked into
every participating project as `docs/`. Files you see here are visible to
every project that links to this hub.

## Layout and scoping rules

```
plans/
├── <project-name>/   ← plans specific to that project
└── shared/           ← plans that affect multiple projects
architecture/         ← shared architecture notes (flat, no per-project subdir)
runbooks/             ← shared operational runbooks (flat)
templates/            ← canonical templates; ignore when reading for context
docs.config.yml       ← registry of linked projects (see below)
```

**Plans are scoped by folder.** If you're working in `<some-project>`,
the plans relevant to you live in:

- `plans/<some-project>/` — plans for THIS project
- `plans/shared/` — plans that span multiple projects (read these too)

Plans under other `plans/<other-project>/` folders are **not yours**
unless explicitly cross-referenced.

**Architecture and runbooks are unscoped by convention** — anything in
those folders applies to all linked projects.

## When you're asked to read context

1. Identify the current project. The simplest signal: the repo name of
   the working directory you're in.
2. Read every file under `plans/<current-project>/` and
   `plans/shared/`, newest first. These are the most recent
   implementation plans.
3. Skim `architecture/` and `runbooks/` for cross-cutting concerns.
4. **Do not** load plans from other projects' folders unless the task
   explicitly references them.

To list quickly:

```bash
docs-hub ls plans --project <current-project>
docs-hub ls plans --shared
docs-hub ls architecture
```

To search across everything:

```bash
docs-hub search "<keyword>"
```

To know which other projects exist:

```bash
cat docs.config.yml      # the `projects:` block lists every linked repo
```

## When you're asked to create a new plan

Use the CLI — it picks the right scope folder automatically:

```bash
# Inside a registered project's directory tree, no flag needed:
docs-hub new plan <kebab-case-slug>

# For a plan that affects multiple projects:
docs-hub new plan <slug> --shared

# Targeting a specific project from anywhere:
docs-hub new plan <slug> --project <name>
```

Generated path: `plans/<scope>/YYYY-MM-DD-<slug>.md`, rendered from
`templates/plan.md`. The template has these sections — fill them in,
don't add new top-level sections without checking with the user:

- **Goal** — what is being built and why
- **Files to create / modify** — explicit paths
- **Approach** — key decisions, data flow, edge cases
- **Verification** — how we know it works

## What NOT to do

- **Don't** treat unscoped plans (legacy files directly under `plans/`)
  as belonging to the current project — they're ambiguous. If you must
  use them, flag the ambiguity in your reply.
- **Don't** create a plan with no scope folder. Always go through
  `docs-hub new plan` or write it into `plans/<scope>/` manually.
- **Don't** edit `docs.config.yml` by hand. Use `docs-hub link` /
  `docs-hub unlink`.
- **Don't** edit anything in `templates/` unless the user asks you to.
