# shellcheck shell=bash
# docs-hub ls [<type>]

cmd_ls_help() {
    cat <<'EOF'
Usage: docs-hub ls [<type>]

List docs in the shared root, newest first.

  <type>   plans (default) | architecture | runbooks | all

Each row shows: relative path, last-modified date, human size.

Options:
  -h, --help   Show this help.
EOF
}

dh_ls_one_dir() {
    # Args: <root> <subdir>
    local root="$1" sub="$2"
    local dir="$root/$sub"
    [ -d "$dir" ] || return 0
    # Build tab-separated rows: mtime<TAB>relpath<TAB>size
    find "$dir" -type f -name '*.md' 2>/dev/null | while IFS= read -r f; do
        local m s rel
        m="$(dh_stat_mtime "$f")"
        s="$(dh_stat_size "$f")"
        rel="${f#"$root"/}"
        printf '%s\t%s\t%s\n' "${m:-0}" "$rel" "${s:-0}"
    done
}

cmd_ls() {
    local type="plans"
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help) cmd_ls_help; return 0 ;;
            --) shift; break ;;
            -*) dh_err "unknown flag: $1"; return 2 ;;
            *) type="$1"; shift ;;
        esac
    done

    case "$type" in
        plans|plan)                type="plans" ;;
        architecture|arch)         type="architecture" ;;
        runbooks|runbook)          type="runbooks" ;;
        all)                       : ;;
        *) dh_err "unknown type: $type (plans|architecture|runbooks|all)"; return 2 ;;
    esac

    local root
    root="$(dh_default_root)"
    if [ ! -d "$root" ]; then
        dh_err "shared-docs root not found: $root  (run 'docs-hub init')"
        return 1
    fi

    local rows
    if [ "$type" = "all" ]; then
        rows="$( {
            dh_ls_one_dir "$root" plans
            dh_ls_one_dir "$root" architecture
            dh_ls_one_dir "$root" runbooks
        } )"
    else
        rows="$(dh_ls_one_dir "$root" "$type")"
    fi

    if [ -z "$rows" ]; then
        dh_info "(no $type docs found in $root)"
        return 0
    fi

    # Sort newest-first by mtime, then format.
    printf '%s\n' "$rows" \
        | sort -t $'\t' -k1,1nr \
        | while IFS=$'\t' read -r mtime rel size; do
            local d hsize
            d="$(dh_date_iso_from_epoch "$mtime")"
            hsize="$(dh_human_size "$size")"
            printf '%-50s  %s   %s\n' "$rel" "${d:--}" "$hsize"
        done
}
