# shellcheck shell=bash
# docs-hub init [<root-path>] [--git|--no-git]

cmd_init_help() {
    cat <<'EOF'
Usage: docs-hub init [<root-path>] [--git|--no-git]

Initialize a shared-docs root. If <root-path> is omitted, the root is
resolved in this order:
  1. $DOCSHUB_ROOT
  2. The parent of the directory containing the `docs-hub` script (when it
     looks like a shared-docs root — has templates/ or docs.config.yml).
  3. ~/workplace/shared-docs

Creates plans/, architecture/, runbooks/, templates/, a default
templates/plan.md, and an empty docs.config.yml. Re-running on an
existing root only fills in missing pieces.

Options:
  --git        Run `git init` inside the root after setup.
  --no-git     Skip the interactive git-init prompt.
  -h, --help   Show this help.
EOF
}

cmd_init() {
    local root=""
    local git_mode=""  # "" | "yes" | "no"

    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help) cmd_init_help; return 0 ;;
            --git)     git_mode="yes"; shift ;;
            --no-git)  git_mode="no"; shift ;;
            --) shift; break ;;
            -*) dh_err "unknown flag: $1"; return 2 ;;
            *)
                if [ -z "$root" ]; then root="$1"
                else dh_err "unexpected argument: $1"; return 2; fi
                shift
                ;;
        esac
    done

    if [ -z "$root" ]; then
        # Fall back to the shared root resolver so init and the other
        # commands agree on which root to operate on. This makes `docs-hub
        # init` Just Work after the user clones the repo to a non-default
        # location (the script's parent dir becomes the root).
        root="$(dh_default_root)"
    fi
    root="$(dh_abs_path "$root")"

    if [ -e "$root" ] && [ ! -d "$root" ]; then
        dh_err "$root exists and is not a directory"
        return 1
    fi

    local was_existing="no"
    if [ -d "$root" ]; then
        was_existing="yes"
    fi

    mkdir -p -- "$root" || { dh_err "could not create $root"; return 1; }

    local d
    for d in plans architecture runbooks templates; do
        if [ -d "$root/$d" ]; then
            dh_info "${DH_DIM}·${DH_RESET} $root/$d/ already exists"
        else
            mkdir -p -- "$root/$d" || { dh_err "could not create $root/$d"; return 1; }
            dh_ok "Created $d/"
        fi
    done

    # templates/plan.md: copy from script-relative templates dir if present,
    # else emit the canonical content.
    local tpl="$root/templates/plan.md"
    if [ -f "$tpl" ]; then
        dh_info "${DH_DIM}·${DH_RESET} templates/plan.md already exists"
    else
        if [ -f "$DH_TEMPLATES_DIR/plan.md" ] \
           && [ "$DH_TEMPLATES_DIR/plan.md" != "$tpl" ]; then
            cp -- "$DH_TEMPLATES_DIR/plan.md" "$tpl" \
                || { dh_err "could not write $tpl"; return 1; }
        else
            cat >"$tpl" <<'TPL'
# {{title}}

**Date:** {{date}}

## Goal
What is being built and why.

## Files to create / modify
- `path/to/file.ext` — purpose

## Approach
Key decisions, data flow, edge cases.

## Verification
How will we know this works? (tests, manual checks, screenshots)
TPL
        fi
        dh_ok "Wrote templates/plan.md"
    fi

    local cfg
    cfg="$(dh_cfg_path "$root")"
    if [ -f "$cfg" ]; then
        dh_info "${DH_DIM}·${DH_RESET} docs.config.yml already exists"
    else
        dh_cfg_init "$root"
        dh_ok "Wrote docs.config.yml"
    fi

    # Optional git-init.
    if [ "$git_mode" = "yes" ] || { [ "$git_mode" = "" ] && dh_prompt_yn "Initialize a git repo in $root?"; }; then
        if [ -d "$root/.git" ]; then
            dh_info "${DH_DIM}·${DH_RESET} git repo already present"
        else
            if command -v git >/dev/null 2>&1; then
                ( cd "$root" && git init -q ) \
                    && dh_ok "Initialized git repo" \
                    || dh_warn "git init failed"
            else
                dh_warn "git not found on PATH; skipping git init"
            fi
        fi
    fi

    if [ "$was_existing" = "yes" ]; then
        dh_info "Root already existed; filled in missing pieces."
    else
        dh_ok "Created $root/"
    fi

    cat <<EOF

Next: add to PATH and link your first project →
  echo 'export PATH="$root/bin:\$PATH"' >> ~/.zshrc
  docs-hub link <path-to-your-project>
EOF
}
