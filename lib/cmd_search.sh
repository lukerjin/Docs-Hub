# shellcheck shell=bash
# docs-hub search <keyword> [--all]

cmd_search_help() {
    cat <<'EOF'
Usage: docs-hub search <keyword> [--all]

Grep across all docs in the shared root. Uses ripgrep (`rg`) when
available; falls back to `grep -rn` otherwise. Results are limited to
the first ~50 hits unless --all is passed.

Excluded: bin/, lib/, templates/, .git/.

Options:
  --all        Print all hits (no limit).
  -h, --help   Show this help.
EOF
}

cmd_search() {
    local keyword="" all="no"
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help) cmd_search_help; return 0 ;;
            --all) all="yes"; shift ;;
            --) shift; break ;;
            -*) dh_err "unknown flag: $1"; return 2 ;;
            *)
                if [ -z "$keyword" ]; then keyword="$1"
                else dh_err "unexpected argument: $1 (quote multi-word patterns)"; return 2; fi
                shift
                ;;
        esac
    done

    [ -z "$keyword" ] && { cmd_search_help >&2; return 2; }

    local root
    root="$(dh_default_root)"
    [ -d "$root" ] || { dh_err "shared-docs root not found: $root"; return 1; }

    local limit=50
    [ "$all" = "yes" ] && limit=0

    local out=""
    if command -v rg >/dev/null 2>&1; then
        out="$(
            rg --no-heading --line-number --color never \
               --glob '!bin/**' --glob '!lib/**' \
               --glob '!templates/**' --glob '!.git/**' \
               -- "$keyword" "$root" 2>/dev/null
        )" || true
    else
        out="$(
            grep -rn --color=never \
                 --exclude-dir=bin --exclude-dir=lib \
                 --exclude-dir=templates --exclude-dir=.git \
                 -- "$keyword" "$root" 2>/dev/null
        )" || true
    fi

    if [ -z "$out" ]; then
        dh_info "(no matches for '$keyword' in $root)"
        return 1
    fi

    local total
    total="$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
    if [ "$limit" -gt 0 ] && [ "$total" -gt "$limit" ]; then
        printf '%s\n' "$out" | head -n "$limit"
        printf '%s%s more hit(s) — pass --all to see them.%s\n' \
            "$DH_DIM" "$((total - limit))" "$DH_RESET"
    else
        printf '%s\n' "$out"
    fi
}
