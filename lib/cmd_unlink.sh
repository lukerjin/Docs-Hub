# shellcheck shell=bash
# docs-hub unlink <project-path>

cmd_unlink_help() {
    cat <<'EOF'
Usage: docs-hub unlink <project-path>

Remove the symlink and unregister a project. If a backup directory like
<dirname>.bak.<timestamp> exists, you'll be offered to restore the most
recent one as <dirname>.

The project's .gitignore is intentionally NOT modified — a tip is
printed instead.

Options:
  -h, --help   Show this help.
EOF
}

cmd_unlink() {
    local project=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help) cmd_unlink_help; return 0 ;;
            --) shift; break ;;
            -*) dh_err "unknown flag: $1"; return 2 ;;
            *)
                if [ -z "$project" ]; then project="$1"
                else dh_err "unexpected argument: $1"; return 2; fi
                shift
                ;;
        esac
    done

    [ -z "$project" ] && { cmd_unlink_help >&2; return 2; }

    project="$(dh_abs_path "$project")"

    local root cfg
    root="$(dh_default_root)"
    cfg="$(dh_cfg_path "$root")"

    local link_as="docs"
    if [ -f "$cfg" ]; then
        local row
        row="$(dh_cfg_find_project "$cfg" "$project" 2>/dev/null || true)"
        if [ -n "$row" ]; then
            link_as="$(printf '%s' "$row" | awk -F'\t' '{print $3}')"
            [ -z "$link_as" ] && link_as="docs"
        else
            dh_warn "project not registered in docs.config.yml; assuming link_as=docs"
        fi
    fi

    local link="$project/$link_as"
    if [ -L "$link" ]; then
        local target target_abs
        target="$(dh_resolve_link "$link" 2>/dev/null || true)"
        target_abs=""
        [ -n "$target" ] && target_abs="$(dh_abs_path "$target")"
        if [ -z "$target_abs" ] || [ "$target_abs" = "$root" ]; then
            rm -- "$link" || { dh_err "could not remove $link"; return 1; }
            dh_ok "Removed $link"
        else
            dh_warn "$link points to $target_abs (not the shared root); leaving it alone"
        fi
    elif [ -e "$link" ]; then
        dh_warn "$link is not a symlink; leaving it alone"
    else
        dh_info "${DH_DIM}·${DH_RESET} $link does not exist"
    fi

    # Offer to restore most recent backup.
    local newest=""
    # shellcheck disable=SC2012
    newest="$(ls -1dt -- "$project/$link_as".bak.* 2>/dev/null | head -n1 || true)"
    if [ -n "$newest" ] && [ -d "$newest" ] && [ ! -e "$link" ]; then
        if dh_prompt_yn "Restore backup $(basename -- "$newest") as $link_as?"; then
            mv -- "$newest" "$link" \
                && dh_ok "Restored $link from $(basename -- "$newest")" \
                || dh_warn "could not restore $newest"
        fi
    fi

    if [ -f "$cfg" ]; then
        dh_cfg_remove_project "$cfg" "$project"
        dh_ok "Unregistered project from docs.config.yml"
    fi

    local gi="$project/.gitignore"
    local entry="/$link_as"
    if [ -f "$gi" ] && dh_gitignore_has "$gi" "$entry"; then
        dh_info "Tip: remove '$entry' from $gi if you no longer want it ignored."
    fi
}
