# shellcheck shell=bash
# inkwell status

cmd_status_help() {
    cat <<'EOF'
Usage: inkwell status

Health report for the shared-docs root and all linked projects.

For each project, prints:
  - link path on disk
  - resolved link target
  - status: OK / MISSING / BROKEN / STALE
  - whether .gitignore includes the link entry

Exit code is 0 if all projects are OK, 1 otherwise.

Options:
  -h, --help   Show this help.
EOF
}

cmd_status() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help) cmd_status_help; return 0 ;;
            *) ink_err "unexpected argument: $1"; return 2 ;;
        esac
    done

    local root cfg
    root="$(ink_default_root)"
    cfg="$(ink_cfg_path "$root")"

    if [ ! -d "$root" ]; then
        ink_err "shared-docs root not found: $root  (run 'inkwell init')"
        return 1
    fi

    local n_plans n_arch n_run
    n_plans=$(find "$root/plans"        -maxdepth 4 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    n_arch=$( find "$root/architecture" -maxdepth 4 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    n_run=$(  find "$root/runbooks"     -maxdepth 4 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')

    local s_plans="s" s_arch="" s_run="s"
    [ "$n_plans" = 1 ] && s_plans=""
    [ "$n_arch" = 1 ] || s_arch="s"
    [ "$n_run" = 1 ] && s_run=""
    printf 'Shared docs: %s    (%s plan%s, %s architecture note%s, %s runbook%s)\n' \
        "$root" "$n_plans" "$s_plans" "$n_arch" "$s_arch" "$n_run" "$s_run"

    if [ ! -f "$cfg" ]; then
        ink_warn "docs.config.yml not found at $cfg"
        return 1
    fi

    local rows
    rows="$(ink_cfg_list_projects "$cfg")"
    if [ -z "$rows" ]; then
        printf 'Projects: (none registered yet — run `inkwell link <project>`)\n'
        return 0
    fi

    printf 'Projects:\n'
    local any_bad=0
    while IFS=$'\t' read -r name path link_as linked_at; do
        [ -z "$name" ] && continue
        local link="$path/$link_as"
        local status="OK" detail=""
        if [ ! -d "$path" ]; then
            status="STALE"
            detail="project path missing"
        elif [ -L "$link" ]; then
            local target target_abs
            target="$(ink_resolve_link "$link" 2>/dev/null || true)"
            target_abs=""
            [ -n "$target" ] && target_abs="$(ink_abs_path "$target")"
            if [ -z "$target" ] || [ ! -e "$link" ]; then
                status="BROKEN"
                detail="symlink target missing: ${target:-?}"
            elif [ "$target_abs" != "$root" ]; then
                status="BROKEN"
                detail="points to $target_abs"
            fi
        elif [ -e "$link" ]; then
            status="BROKEN"
            detail="$link is not a symlink"
        else
            status="MISSING"
            detail="no symlink at $link"
        fi

        local gi="$path/.gitignore"
        local gi_mark="-"
        if [ -f "$gi" ]; then
            if ink_gitignore_has "$gi" "/$link_as"; then
                gi_mark="✓"
            else
                gi_mark="✗"
            fi
        fi

        local status_colored
        case "$status" in
            OK)      status_colored="${INK_GREEN}OK${INK_RESET}" ;;
            MISSING) status_colored="${INK_YELLOW}MISSING${INK_RESET}"; any_bad=1 ;;
            BROKEN)  status_colored="${INK_RED}BROKEN${INK_RESET}";  any_bad=1 ;;
            STALE)   status_colored="${INK_RED}STALE${INK_RESET}";   any_bad=1 ;;
        esac

        printf '  %-12s %-50s %s/ → %s   .gitignore: %s\n' \
            "$name" "$path" "$link_as" "$status_colored" "$gi_mark"
        if [ -n "$detail" ]; then
            printf '               %s%s%s\n' "$INK_DIM" "$detail" "$INK_RESET"
        fi
    done <<EOF
$rows
EOF

    if [ "$any_bad" -eq 0 ]; then
        ink_ok "All OK."
        return 0
    else
        ink_warn "Some projects are not OK."
        return 1
    fi
}
