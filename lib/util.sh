# shellcheck shell=bash
# Shared helpers for docs-hub. Sourced by bin/docs-hub and lib/cmd_*.sh.

# ----- logging --------------------------------------------------------------

dh_is_tty() { [ -t 1 ]; }

if dh_is_tty && [ "${NO_COLOR:-}" = "" ]; then
    DH_GREEN=$'\033[32m'
    DH_YELLOW=$'\033[33m'
    DH_RED=$'\033[31m'
    DH_DIM=$'\033[2m'
    DH_BOLD=$'\033[1m'
    DH_RESET=$'\033[0m'
else
    DH_GREEN=""; DH_YELLOW=""; DH_RED=""; DH_DIM=""; DH_BOLD=""; DH_RESET=""
fi

dh_ok()   { printf '%s\n' "${DH_GREEN}✓${DH_RESET} $*"; }
dh_info() { printf '%s\n' "$*"; }
dh_warn() { printf '%s\n' "${DH_YELLOW}⚠${DH_RESET}  $*" >&2; }
dh_err()  { printf '%s\n' "${DH_RED}✗${DH_RESET} $*" >&2; }
dh_die()  { dh_err "$*"; exit 1; }

dh_prompt_yn() {
    # Usage: dh_prompt_yn "question" [default_yes]
    # Returns 0 for yes, 1 for no.
    # Honors DOCSHUB_ASSUME_YES=1 for non-interactive auto-confirm.
    # Reads from /dev/tty when available so it still works under piped stdin.
    local q="$1"
    local default_yes="${2:-}"
    local hint="[y/N]"
    [ -n "$default_yes" ] && hint="[Y/n]"

    if [ "${DOCSHUB_ASSUME_YES:-0}" = "1" ]; then
        printf '%s %s y (auto)\n' "$q" "$hint" >&2
        return 0
    fi

    local ans=""
    if [ -r /dev/tty ] && [ -w /dev/tty ]; then
        printf '%s %s ' "$q" "$hint" >/dev/tty
        if ! IFS= read -r ans </dev/tty; then
            return 1
        fi
    elif [ -t 0 ]; then
        printf '%s %s ' "$q" "$hint" >&2
        IFS= read -r ans || ans=""
    else
        # Fully non-interactive and no /dev/tty: cannot prompt safely.
        return 1
    fi
    case "$ans" in
        y|Y|yes|YES) return 0 ;;
        n|N|no|NO)   return 1 ;;
        "")          [ -n "$default_yes" ] && return 0 || return 1 ;;
        *)           return 1 ;;
    esac
}

# ----- platform shims -------------------------------------------------------

dh_uname="$(uname 2>/dev/null || echo unknown)"

# Resolve a path to an absolute, symlink-free path.
# Works on macOS (BSD) and Linux without GNU coreutils.
dh_abs_path() {
    local p="$1"
    [ -z "$p" ] && return 1
    # expand leading ~
    case "$p" in
        "~")    p="$HOME" ;;
        "~/"*)  p="$HOME/${p#~/}" ;;
    esac
    if [ -d "$p" ]; then
        ( cd "$p" 2>/dev/null && pwd -P )
    elif [ -e "$p" ] || [ -L "$p" ]; then
        local d b
        d="$(dirname -- "$p")"
        b="$(basename -- "$p")"
        if [ -d "$d" ]; then
            printf '%s/%s\n' "$( cd "$d" && pwd -P )" "$b"
        else
            printf '%s\n' "$p"
        fi
    else
        # path doesn't exist; best-effort lexical absolutization
        case "$p" in
            /*) printf '%s\n' "$p" ;;
            *)  printf '%s/%s\n' "$(pwd -P)" "$p" ;;
        esac
    fi
}

# Read the immediate symlink target (one level). Empty if not a symlink.
dh_readlink_one() {
    local p="$1"
    if [ -L "$p" ]; then
        # BSD readlink and GNU readlink both support no-flag single-level read
        readlink -- "$p"
    fi
}

# Resolve a symlink target to an absolute path (one level).
dh_resolve_link() {
    local p="$1"
    [ -L "$p" ] || return 1
    local t
    t="$(dh_readlink_one "$p")"
    [ -z "$t" ] && return 1
    case "$t" in
        /*) printf '%s\n' "$t" ;;
        *)  printf '%s/%s\n' "$(dirname -- "$p")" "$t" ;;
    esac
}

# mtime in unix seconds.
dh_stat_mtime() {
    local p="$1"
    if [ "$dh_uname" = "Darwin" ]; then
        stat -f '%m' -- "$p" 2>/dev/null
    else
        stat -c '%Y' -- "$p" 2>/dev/null
    fi
}

# size in bytes.
dh_stat_size() {
    local p="$1"
    if [ "$dh_uname" = "Darwin" ]; then
        stat -f '%z' -- "$p" 2>/dev/null
    else
        stat -c '%s' -- "$p" 2>/dev/null
    fi
}

# ISO date for an epoch (yyyy-mm-dd).
dh_date_iso_from_epoch() {
    local s="$1"
    if [ "$dh_uname" = "Darwin" ]; then
        date -r "$s" '+%Y-%m-%d' 2>/dev/null
    else
        date -d "@$s" '+%Y-%m-%d' 2>/dev/null
    fi
}

dh_today() { date '+%Y-%m-%d'; }
dh_now_offset() { date '+%Y-%m-%dT%H:%M:%S%z'; }

dh_human_size() {
    local b="${1:-0}"
    if [ "$b" -lt 1024 ]; then
        printf '%s B' "$b"
    elif [ "$b" -lt 1048576 ]; then
        awk -v b="$b" 'BEGIN{printf "%.1f KB", b/1024}'
    else
        awk -v b="$b" 'BEGIN{printf "%.1f MB", b/1048576}'
    fi
}

# ----- root + script discovery ---------------------------------------------

# DH_SCRIPT_DIR is set by bin/docs-hub before sourcing this file.
# DH_LIB_DIR likewise.

# Determine which shared-docs root to operate on:
#   1. $DOCSHUB_ROOT env var
#   2. directory containing bin/docs-hub that was invoked
#   3. ~/workplace/shared-docs (default)
dh_default_root() {
    if [ -n "${DOCSHUB_ROOT:-}" ]; then
        printf '%s\n' "${DOCSHUB_ROOT%/}"
        return 0
    fi
    if [ -n "${DH_SCRIPT_DIR:-}" ]; then
        # bin/ sits inside the root; root = parent of bin
        local maybe_root
        maybe_root="$(dirname -- "$DH_SCRIPT_DIR")"
        if [ -f "$maybe_root/docs.config.yml" ] || [ -d "$maybe_root/templates" ]; then
            printf '%s\n' "$maybe_root"
            return 0
        fi
    fi
    printf '%s/workplace/shared-docs\n' "$HOME"
}

# ----- config I/O -----------------------------------------------------------
# We use a known YAML schema; no full parser needed. See spec §6.

dh_cfg_path() {
    local root="${1:-$(dh_default_root)}"
    printf '%s/docs.config.yml\n' "$root"
}

# Write a fresh config file with no projects.
dh_cfg_init() {
    local root="$1"
    local cfg
    cfg="$(dh_cfg_path "$root")"
    if [ -f "$cfg" ]; then
        return 0
    fi
    local tmp="${cfg}.tmp.$$"
    if ! {
        printf 'version: 1\n'
        printf 'root: %s\n' "$root"
        printf 'projects: []\n'
        printf 'settings:\n'
        printf '  editor: ""\n'
        printf '  date_format: "%%Y-%%m-%%d"\n'
    } >"$tmp"; then
        rm -f -- "$tmp"
        return 1
    fi
    mv -- "$tmp" "$cfg" || { rm -f -- "$tmp"; return 1; }
}

# Print all project entries as TSV: name<TAB>path<TAB>link_as<TAB>linked_at
dh_cfg_list_projects() {
    local cfg="$1"
    [ -f "$cfg" ] || return 0
    awk '
        BEGIN { in_proj=0; have=0; name=""; path=""; link_as=""; linked_at="" }
        function flush() {
            if (have) { printf "%s\t%s\t%s\t%s\n", name, path, link_as, linked_at }
            have=0; name=""; path=""; link_as=""; linked_at=""
        }
        function strip(v) {
            sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
            # strip surrounding quotes
            if (v ~ /^".*"$/) { v = substr(v, 2, length(v)-2) }
            return v
        }
        /^[a-zA-Z_][a-zA-Z_0-9]*:/ {
            # top-level key — leave projects mode
            if ($0 !~ /^projects:/) { flush(); in_proj=0; next }
            else { flush(); in_proj=1; next }
        }
        in_proj && /^  - name:/ {
            flush()
            v=$0; sub(/^  - name:[ \t]*/, "", v); name=strip(v); have=1; next
        }
        in_proj && /^    path:/ {
            v=$0; sub(/^    path:[ \t]*/, "", v); path=strip(v); next
        }
        in_proj && /^    link_as:/ {
            v=$0; sub(/^    link_as:[ \t]*/, "", v); link_as=strip(v); next
        }
        in_proj && /^    linked_at:/ {
            v=$0; sub(/^    linked_at:[ \t]*/, "", v); linked_at=strip(v); next
        }
        END { flush() }
    ' "$cfg"
}

# Print the value of a top-level scalar (root, version).
dh_cfg_get_scalar() {
    local cfg="$1" key="$2"
    [ -f "$cfg" ] || return 1
    awk -v k="$key" '
        $0 ~ "^" k ":" {
            sub("^" k ":[ \t]*", "")
            if ($0 ~ /^".*"$/) { $0 = substr($0, 2, length($0)-2) }
            print; exit
        }
    ' "$cfg"
}

# Extract the verbatim `settings:` block from an existing config file.
# Captures the `settings:` line and all following indented (or blank) lines
# until the next top-level key or EOF. Prints empty if the block is missing.
dh_cfg_get_settings_block() {
    local cfg="$1"
    [ -f "$cfg" ] || return 0
    awk '
        /^settings:/ { capture=1; print; next }
        capture {
            if ($0 ~ /^[A-Za-z_]/) { exit }
            print
        }
    ' "$cfg"
}

# Rewrite the config. Preserves the existing `settings:` block and `root:`
# scalar; replaces the `projects:` list with TSV read from stdin.
dh_cfg_write_projects() {
    local cfg="$1"
    local root_val
    root_val="$(dh_cfg_get_scalar "$cfg" root)"
    [ -z "$root_val" ] && root_val="$(dirname -- "$cfg")"

    local settings_block
    settings_block="$(dh_cfg_get_settings_block "$cfg")"

    local lines
    lines="$(cat)"

    local tmp="${cfg}.tmp.$$"
    if ! {
        printf 'version: 1\n'
        printf 'root: %s\n' "$root_val"
        if [ -z "$lines" ]; then
            printf 'projects: []\n'
        else
            printf 'projects:\n'
            while IFS=$'\t' read -r name path link_as linked_at; do
                [ -z "$name" ] && continue
                printf '  - name: %s\n' "$name"
                printf '    path: %s\n' "$path"
                printf '    link_as: %s\n' "$link_as"
                printf '    linked_at: %s\n' "$linked_at"
            done <<EOF
$lines
EOF
        fi
        if [ -n "$settings_block" ]; then
            printf '%s\n' "$settings_block"
        else
            printf 'settings:\n'
            printf '  editor: ""\n'
            printf '  date_format: "%%Y-%%m-%%d"\n'
        fi
    } >"$tmp"; then
        rm -f -- "$tmp"
        return 1
    fi
    mv -- "$tmp" "$cfg" || { rm -f -- "$tmp"; return 1; }
}

# Add or update a project entry (dedupe by absolute path).
dh_cfg_add_project() {
    local cfg="$1" name="$2" path="$3" link_as="$4" linked_at="$5"
    local rows
    rows="$(dh_cfg_list_projects "$cfg" 2>/dev/null || true)"
    {
        if [ -n "$rows" ]; then
            printf '%s\n' "$rows" | awk -F'\t' -v p="$path" '$2 != p { print }'
        fi
        printf '%s\t%s\t%s\t%s\n' "$name" "$path" "$link_as" "$linked_at"
    } | dh_cfg_write_projects "$cfg"
}

# Remove a project entry by absolute path.
dh_cfg_remove_project() {
    local cfg="$1" path="$2"
    local rows
    rows="$(dh_cfg_list_projects "$cfg" 2>/dev/null || true)"
    if [ -z "$rows" ]; then
        dh_cfg_write_projects "$cfg" </dev/null
        return 0
    fi
    printf '%s\n' "$rows" \
        | awk -F'\t' -v p="$path" '$2 != p { print }' \
        | dh_cfg_write_projects "$cfg"
}

# Look up a project by absolute path. Prints TSV row or returns 1.
dh_cfg_find_project() {
    local cfg="$1" path="$2"
    local rows
    rows="$(dh_cfg_list_projects "$cfg" 2>/dev/null || true)"
    [ -z "$rows" ] && return 1
    printf '%s\n' "$rows" \
        | awk -F'\t' -v p="$path" '$2 == p { print; found=1 } END { exit !found }'
}

# Look up a project by name. Prints TSV row or returns 1.
dh_cfg_find_project_by_name() {
    local cfg="$1" name="$2"
    local rows
    rows="$(dh_cfg_list_projects "$cfg" 2>/dev/null || true)"
    [ -z "$rows" ] && return 1
    printf '%s\n' "$rows" \
        | awk -F'\t' -v n="$name" '$1 == n { print; found=1 } END { exit !found }'
}

# Detect which registered project, if any, contains $PWD. Prints the project
# name on success; returns 1 if PWD is not under any registered project path.
# Uses longest-prefix match so nested registrations (e.g. /foo and /foo/bar)
# resolve to the more specific one.
dh_detect_project_from_cwd() {
    local cfg="$1"
    [ -f "$cfg" ] || return 1
    local cwd
    cwd="$(pwd -P 2>/dev/null)" || return 1

    local rows
    rows="$(dh_cfg_list_projects "$cfg")"
    [ -z "$rows" ] && return 1

    local best_name="" best_len=0
    while IFS=$'\t' read -r name path link_as linked_at; do
        [ -z "$path" ] && continue
        case "$cwd" in
            "$path"|"$path"/*)
                local n=${#path}
                if [ "$n" -gt "$best_len" ]; then
                    best_len=$n
                    best_name="$name"
                fi
                ;;
        esac
    done <<EOF
$rows
EOF
    [ -n "$best_name" ] && printf '%s\n' "$best_name" && return 0
    return 1
}

# ----- gitignore helpers ----------------------------------------------------

dh_gitignore_has() {
    local file="$1" entry="$2"
    [ -f "$file" ] || return 1
    # Match exact line, with or without leading slash variants stripped
    awk -v e="$entry" '
        { line=$0; sub(/^[ \t]+/, "", line); sub(/[ \t]+$/, "", line) }
        line == e { found=1; exit }
        END { exit !found }
    ' "$file"
}

dh_gitignore_add() {
    local file="$1" entry="$2"
    if [ ! -f "$file" ]; then
        return 2  # signal: no .gitignore present
    fi
    if dh_gitignore_has "$file" "$entry"; then
        return 1  # already present
    fi
    # ensure trailing newline before append
    if [ -s "$file" ] && [ "$(tail -c1 -- "$file" 2>/dev/null | wc -l | tr -d ' ')" = "0" ]; then
        printf '\n' >>"$file"
    fi
    printf '%s\n' "$entry" >>"$file"
    return 0
}
