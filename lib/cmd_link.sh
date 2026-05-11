# shellcheck shell=bash
# docs-hub link <project-path> [--as <dirname>]

cmd_link_help() {
    cat <<'EOF'
Usage: docs-hub link <project-path> [--as <dirname>] [--repair]

Connect a project to the shared docs by creating a symlink at
<project-path>/<dirname> → <shared-docs-root>.

The default <dirname> is "docs". If a regular folder already exists at
that path, you'll be prompted to back it up to <dirname>.bak.<timestamp>
before the symlink is created.

Behavior:
  - already a symlink to the same root      → no-op
  - already a symlink to a different target → error (remove manually)
  - broken symlink (target missing)         → error, or with --repair: recreate
  - regular folder with content             → prompt, back up, then link
  - missing                                 → create symlink

The project is registered in docs.config.yml (deduped by absolute path),
and /<dirname> is appended to the project's .gitignore if one exists.

Options:
  --as <dirname>   Directory name inside the project (default: docs).
  --repair         Repair a broken symlink by removing and recreating it.
  -h, --help       Show this help.
EOF
}

cmd_link() {
    local project="" link_as="docs" repair="no"
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help) cmd_link_help; return 0 ;;
            --as)
                [ $# -ge 2 ] || { dh_err "--as needs a value"; return 2; }
                link_as="$2"; shift 2 ;;
            --as=*) link_as="${1#--as=}"; shift ;;
            --repair) repair="yes"; shift ;;
            --) shift; break ;;
            -*) dh_err "unknown flag: $1"; return 2 ;;
            *)
                if [ -z "$project" ]; then project="$1"
                else dh_err "unexpected argument: $1"; return 2; fi
                shift
                ;;
        esac
    done

    [ -z "$project" ] && { cmd_link_help >&2; return 2; }
    case "$link_as" in
        */*|"") dh_err "--as must be a single directory name"; return 2 ;;
    esac

    project="$(dh_abs_path "$project")"
    if [ ! -d "$project" ]; then
        dh_err "project path not found or not a directory: $project"
        return 1
    fi

    local root cfg
    root="$(dh_default_root)"
    if [ ! -d "$root" ]; then
        dh_err "shared-docs root not found: $root"
        dh_err "run 'docs-hub init' first."
        return 1
    fi
    cfg="$(dh_cfg_path "$root")"
    [ -f "$cfg" ] || dh_cfg_init "$root"

    local link="$project/$link_as"
    local changed="no"  # whether we actually created/replaced the symlink

    if [ -L "$link" ]; then
        local target
        target="$(dh_resolve_link "$link" || true)"
        local target_abs=""
        [ -n "$target" ] && target_abs="$(dh_abs_path "$target")"

        if [ -n "$target_abs" ] && [ "$target_abs" = "$root" ] && [ -d "$link" ]; then
            dh_info "${DH_DIM}·${DH_RESET} $link already linked to $root"
        elif [ ! -e "$link" ]; then
            # broken symlink (target missing)
            if [ "$repair" = "yes" ]; then
                rm -- "$link" || { dh_err "could not remove broken symlink $link"; return 1; }
                ln -s -- "$root" "$link" || { dh_err "could not create symlink"; return 1; }
                dh_ok "Repaired broken symlink: $link → $root"
                changed="yes"
            else
                dh_err "$link is a broken symlink (target missing: ${target:-?})"
                dh_err "re-run with --repair to recreate it."
                return 1
            fi
        else
            dh_err "$link is a symlink pointing elsewhere: ${target:-?}"
            dh_err "remove it manually if you want to relink: rm \"$link\""
            return 1
        fi
    elif [ -d "$link" ]; then
        local count
        count="$(find "$link" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')"
        dh_warn "$link already exists with $count files."
        local stamp backup
        stamp="$(date '+%s')"
        backup="$link.bak.$stamp"
        if ! dh_prompt_yn "   Back it up to $(basename -- "$backup") and replace with symlink?"; then
            dh_err "aborted; nothing changed."
            return 1
        fi
        mv -- "$link" "$backup" || { dh_err "could not move $link to $backup"; return 1; }
        dh_ok "Backed up to $backup"
        ln -s -- "$root" "$link" || { dh_err "could not create symlink"; return 1; }
        dh_ok "Linked $link → $root"
        changed="yes"
    elif [ -e "$link" ]; then
        dh_err "$link exists and is not a directory or symlink"
        return 1
    else
        ln -s -- "$root" "$link" || { dh_err "could not create symlink"; return 1; }
        dh_ok "Linked $link → $root"
        changed="yes"
    fi

    # .gitignore handling
    local gi="$project/.gitignore"
    local entry="/$link_as"
    if [ -f "$gi" ]; then
        dh_gitignore_add "$gi" "$entry"
        case $? in
            0) dh_ok "Added $entry to $gi" ;;
            1) dh_info "${DH_DIM}·${DH_RESET} $gi already contains $entry" ;;
        esac
    else
        dh_warn "no .gitignore at $project — skip; add '$entry' yourself if this project is a git repo"
    fi

    # Register in config. Skip when already registered AND nothing changed
    # on disk — keeps repeat invocations quiet (and avoids churning
    # linked_at on a true no-op).
    local name
    name="$(basename -- "$project")"
    if [ "$changed" = "no" ] && dh_cfg_find_project "$cfg" "$project" >/dev/null 2>&1; then
        dh_info "${DH_DIM}·${DH_RESET} project '$name' already registered in docs.config.yml"
    else
        dh_cfg_add_project "$cfg" "$name" "$project" "$link_as" "$(dh_now_offset)"
        dh_ok "Registered project '$name' in docs.config.yml"
    fi
}
