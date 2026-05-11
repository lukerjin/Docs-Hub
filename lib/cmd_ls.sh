# shellcheck shell=bash
# docs-hub ls [<type>] [--project <name>|--shared]

cmd_ls_help() {
    cat <<'EOF'
Usage: docs-hub ls [<type>] [--project <name>|--shared]

List docs in the shared root, newest first.

  <type>   plans (default) | architecture | runbooks | all

For plans, results are grouped by scope (one section per
plans/<scope>/ subfolder, plus any flat files under plans/ shown
under "(unscoped)").

For architecture and runbooks, results are flat — those dirs are
shared by convention.

Options:
  --project <name>   For plans, show only plans/<name>/.
  --shared           For plans, show only plans/shared/.
  -h, --help         Show this help.
EOF
}

# Emit "mtime\trelpath\tsize" for every *.md under a directory.
dh_ls_rows() {
    local root="$1" sub="$2"
    local dir="$root/$sub"
    [ -d "$dir" ] || return 0
    find "$dir" -type f -name '*.md' 2>/dev/null | while IFS= read -r f; do
        local m s rel
        m="$(dh_stat_mtime "$f")"
        s="$(dh_stat_size "$f")"
        rel="${f#"$root"/}"
        printf '%s\t%s\t%s\n' "${m:-0}" "$rel" "${s:-0}"
    done
}

dh_print_rows_flat() {
    sort -t $'\t' -k1,1nr \
        | while IFS=$'\t' read -r mtime rel size; do
            local d hsize
            d="$(dh_date_iso_from_epoch "$mtime")"
            hsize="$(dh_human_size "$size")"
            printf '  %-50s  %s   %s\n' "$rel" "${d:--}" "$hsize"
        done
}

# Group plans output by the first path component after "plans/".
# Files directly in plans/ (no subdir) are grouped under "(unscoped)".
dh_print_plans_grouped() {
    local root="$1"
    local rows="$2"
    [ -z "$rows" ] && return 0

    # Annotate each row with its scope as the first field:
    #   scope<TAB>mtime<TAB>relpath<TAB>size
    local annotated
    annotated="$(printf '%s\n' "$rows" | awk -F'\t' -v OFS='\t' '
        {
            n = split($2, parts, "/")
            if (n >= 3) { scope = parts[2] }
            else        { scope = "(unscoped)" }
            print scope, $1, $2, $3
        }
    ')"

    # Distinct scopes, preserving stable ordering (shared first, then
    # alphabetical, then (unscoped) last).
    local scopes
    scopes="$(printf '%s\n' "$annotated" | awk -F'\t' '{print $1}' | sort -u)"

    # Print sections in the chosen order.
    local s
    for s in shared $(printf '%s\n' "$scopes" | grep -v -e '^shared$' -e '^(unscoped)$' | sort); do
        local sect
        sect="$(printf '%s\n' "$annotated" | awk -F'\t' -v s="$s" '$1==s {print $2"\t"$3"\t"$4}')"
        [ -z "$sect" ] && continue
        printf '[%s]\n' "$s"
        printf '%s\n' "$sect" | dh_print_rows_flat
    done
    # (unscoped) last
    local unsc
    unsc="$(printf '%s\n' "$annotated" | awk -F'\t' '$1=="(unscoped)" {print $2"\t"$3"\t"$4}')"
    if [ -n "$unsc" ]; then
        printf '[(unscoped)]\n'
        printf '%s\n' "$unsc" | dh_print_rows_flat
    fi
}

cmd_ls() {
    local type="plans" filter=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help) cmd_ls_help; return 0 ;;
            --project)
                [ $# -ge 2 ] || { dh_err "--project needs a value"; return 2; }
                filter="$2"; shift 2 ;;
            --project=*) filter="${1#--project=}"; shift ;;
            --shared) filter="shared"; shift ;;
            --) shift; break ;;
            -*) dh_err "unknown flag: $1"; return 2 ;;
            *) type="$1"; shift ;;
        esac
    done

    case "$type" in
        plans|plan)        type="plans" ;;
        architecture|arch) type="architecture" ;;
        runbooks|runbook)  type="runbooks" ;;
        all)               : ;;
        *) dh_err "unknown type: $type (plans|architecture|runbooks|all)"; return 2 ;;
    esac

    if [ -n "$filter" ] && [ "$type" != "plans" ] && [ "$type" != "all" ]; then
        dh_err "--project / --shared only applies when listing plans"
        return 2
    fi

    local root
    root="$(dh_default_root)"
    if [ ! -d "$root" ]; then
        dh_err "shared-docs root not found: $root  (run 'docs-hub init')"
        return 1
    fi

    # Resolve the actual plans subdir(s) to scan.
    local plans_rows arch_rows run_rows
    if [ -n "$filter" ]; then
        if [ ! -d "$root/plans/$filter" ]; then
            dh_info "(no plans found under plans/$filter)"
            plans_rows=""
        else
            plans_rows="$(dh_ls_rows "$root" "plans/$filter")"
        fi
    else
        plans_rows="$(dh_ls_rows "$root" plans)"
    fi
    arch_rows="$(dh_ls_rows "$root" architecture)"
    run_rows="$(dh_ls_rows "$root" runbooks)"

    case "$type" in
        plans)
            if [ -z "$plans_rows" ]; then
                [ -z "$filter" ] && dh_info "(no plans found in $root/plans)"
                return 0
            fi
            dh_print_plans_grouped "$root" "$plans_rows"
            ;;
        architecture)
            if [ -z "$arch_rows" ]; then
                dh_info "(no architecture docs found)"
                return 0
            fi
            printf '%s\n' "$arch_rows" | dh_print_rows_flat
            ;;
        runbooks)
            if [ -z "$run_rows" ]; then
                dh_info "(no runbooks found)"
                return 0
            fi
            printf '%s\n' "$run_rows" | dh_print_rows_flat
            ;;
        all)
            local any=0
            if [ -n "$plans_rows" ]; then
                printf '== plans ==\n'
                dh_print_plans_grouped "$root" "$plans_rows"
                any=1
            fi
            if [ -n "$arch_rows" ]; then
                printf '== architecture ==\n'
                printf '%s\n' "$arch_rows" | dh_print_rows_flat
                any=1
            fi
            if [ -n "$run_rows" ]; then
                printf '== runbooks ==\n'
                printf '%s\n' "$run_rows" | dh_print_rows_flat
                any=1
            fi
            [ "$any" = 0 ] && dh_info "(no docs found in $root)"
            ;;
    esac
}
