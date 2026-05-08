# shellcheck shell=bash
# inkwell link <project-path> [--as <dirname>]

cmd_link_help() {
    cat <<'EOF'
Usage: inkwell link <project-path> [--as <dirname>]

Connect a project to the shared docs by creating a symlink at
<project-path>/<dirname> → <shared-docs-root>.

The default <dirname> is "docs". If a regular folder already exists at
that path, you'll be prompted to back it up to <dirname>.bak.<timestamp>
before the symlink is created.

Behavior:
  - already a symlink to the same root  → no-op
  - already a symlink to a different target → error (remove manually)
  - regular folder with content              → prompt, back up, then link
  - missing                                  → create symlink

The project is registered in docs.config.yml (deduped by absolute path),
and /<dirname> is appended to the project's .gitignore if one exists.

Options:
  --as <dirname>   Directory name inside the project (default: docs).
  -h, --help       Show this help.
EOF
}

cmd_link() {
    local project="" link_as="docs"
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help) cmd_link_help; return 0 ;;
            --as)
                [ $# -ge 2 ] || { ink_err "--as needs a value"; return 2; }
                link_as="$2"; shift 2 ;;
            --as=*) link_as="${1#--as=}"; shift ;;
            --) shift; break ;;
            -*) ink_err "unknown flag: $1"; return 2 ;;
            *)
                if [ -z "$project" ]; then project="$1"
                else ink_err "unexpected argument: $1"; return 2; fi
                shift
                ;;
        esac
    done

    [ -z "$project" ] && { cmd_link_help >&2; return 2; }
    case "$link_as" in
        */*|"") ink_err "--as must be a single directory name"; return 2 ;;
    esac

    project="$(ink_abs_path "$project")"
    if [ ! -d "$project" ]; then
        ink_err "project path not found or not a directory: $project"
        return 1
    fi

    local root cfg
    root="$(ink_default_root)"
    if [ ! -d "$root" ]; then
        ink_err "shared-docs root not found: $root"
        ink_err "run 'inkwell init' first."
        return 1
    fi
    cfg="$(ink_cfg_path "$root")"
    [ -f "$cfg" ] || ink_cfg_init "$root"

    local link="$project/$link_as"

    if [ -L "$link" ]; then
        local target
        target="$(ink_resolve_link "$link" || true)"
        local target_abs=""
        [ -n "$target" ] && target_abs="$(ink_abs_path "$target")"
        if [ "$target_abs" = "$root" ]; then
            ink_info "${INK_DIM}·${INK_RESET} $link already linked to $root"
        else
            ink_err "$link is a symlink pointing elsewhere: ${target:-?}"
            ink_err "remove it manually if you want to relink: rm \"$link\""
            return 1
        fi
    elif [ -d "$link" ]; then
        local count
        count="$(find "$link" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')"
        ink_warn "$link already exists with $count files."
        local stamp backup
        stamp="$(date '+%s')"
        backup="$link.bak.$stamp"
        if ! ink_prompt_yn "   Back it up to $(basename -- "$backup") and replace with symlink?"; then
            ink_err "aborted; nothing changed."
            return 1
        fi
        mv -- "$link" "$backup" || { ink_err "could not move $link to $backup"; return 1; }
        ink_ok "Backed up to $backup"
        ln -s -- "$root" "$link" || { ink_err "could not create symlink"; return 1; }
        ink_ok "Linked $link → $root"
    elif [ -e "$link" ]; then
        ink_err "$link exists and is not a directory or symlink"
        return 1
    else
        ln -s -- "$root" "$link" || { ink_err "could not create symlink"; return 1; }
        ink_ok "Linked $link → $root"
    fi

    # .gitignore handling
    local gi="$project/.gitignore"
    local entry="/$link_as"
    if [ -f "$gi" ]; then
        ink_gitignore_add "$gi" "$entry"
        case $? in
            0) ink_ok "Added $entry to $gi" ;;
            1) ink_info "${INK_DIM}·${INK_RESET} $gi already contains $entry" ;;
        esac
    else
        ink_warn "no .gitignore at $project — skip; add '$entry' yourself if this project is a git repo"
    fi

    # Register in config.
    local name
    name="$(basename -- "$project")"
    ink_cfg_add_project "$cfg" "$name" "$project" "$link_as" "$(ink_now_offset)"
    ink_ok "Registered project '$name' in docs.config.yml"
}
