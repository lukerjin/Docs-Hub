# shellcheck shell=bash
# inkwell init [<root-path>] [--git|--no-git]

cmd_init_help() {
    cat <<'EOF'
Usage: inkwell init [<root-path>] [--git|--no-git]

Initialize a shared-docs root. If <root-path> is omitted, defaults to
~/workplace/shared-docs.

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
            -*) ink_err "unknown flag: $1"; return 2 ;;
            *)
                if [ -z "$root" ]; then root="$1"
                else ink_err "unexpected argument: $1"; return 2; fi
                shift
                ;;
        esac
    done

    if [ -z "$root" ]; then
        root="$HOME/workplace/shared-docs"
    fi
    root="$(ink_abs_path "$root")"

    if [ -e "$root" ] && [ ! -d "$root" ]; then
        ink_err "$root exists and is not a directory"
        return 1
    fi

    local was_existing="no"
    if [ -d "$root" ]; then
        was_existing="yes"
    fi

    mkdir -p -- "$root" || { ink_err "could not create $root"; return 1; }

    local d
    for d in plans architecture runbooks templates; do
        if [ -d "$root/$d" ]; then
            ink_info "${INK_DIM}·${INK_RESET} $root/$d/ already exists"
        else
            mkdir -p -- "$root/$d" || { ink_err "could not create $root/$d"; return 1; }
            ink_ok "Created $d/"
        fi
    done

    # templates/plan.md: copy from script-relative templates dir if present,
    # else emit the canonical content.
    local tpl="$root/templates/plan.md"
    if [ -f "$tpl" ]; then
        ink_info "${INK_DIM}·${INK_RESET} templates/plan.md already exists"
    else
        if [ -f "$INK_TEMPLATES_DIR/plan.md" ] \
           && [ "$INK_TEMPLATES_DIR/plan.md" != "$tpl" ]; then
            cp -- "$INK_TEMPLATES_DIR/plan.md" "$tpl" \
                || { ink_err "could not write $tpl"; return 1; }
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
        ink_ok "Wrote templates/plan.md"
    fi

    local cfg
    cfg="$(ink_cfg_path "$root")"
    if [ -f "$cfg" ]; then
        ink_info "${INK_DIM}·${INK_RESET} docs.config.yml already exists"
    else
        ink_cfg_init "$root"
        ink_ok "Wrote docs.config.yml"
    fi

    # Optional git-init.
    if [ "$git_mode" = "yes" ] || { [ "$git_mode" = "" ] && ink_prompt_yn "Initialize a git repo in $root?"; }; then
        if [ -d "$root/.git" ]; then
            ink_info "${INK_DIM}·${INK_RESET} git repo already present"
        else
            if command -v git >/dev/null 2>&1; then
                ( cd "$root" && git init -q ) \
                    && ink_ok "Initialized git repo" \
                    || ink_warn "git init failed"
            else
                ink_warn "git not found on PATH; skipping git init"
            fi
        fi
    fi

    if [ "$was_existing" = "yes" ]; then
        ink_info "Root already existed; filled in missing pieces."
    else
        ink_ok "Created $root/"
    fi

    cat <<EOF

Next: add to PATH and link your first project →
  echo 'export PATH="$root/bin:\$PATH"' >> ~/.zshrc
  inkwell link <path-to-your-project>
EOF
}
