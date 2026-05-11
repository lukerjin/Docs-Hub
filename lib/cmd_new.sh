# shellcheck shell=bash
# docs-hub new plan <slug> [--shared|--project <name>] [--open]

cmd_new_help() {
    cat <<'EOF'
Usage: docs-hub new plan <slug> [--shared|--project <name>] [--open]

Create a new plan from templates/plan.md.

Output path: plans/<scope>/YYYY-MM-DD-<slug>.md

Scope resolution (in order):
  1. --shared            → plans/shared/
  2. --project <name>    → plans/<name>/ (must be a registered project)
  3. cwd is inside a registered project → that project's folder
  4. otherwise           → error; pass --shared or --project explicitly

The slug must match ^[a-z0-9][a-z0-9-]*$ (kebab-case). The title is the
slug with hyphens replaced by spaces, title-cased.

If the file already exists, its path is printed and nothing is overwritten.

Options:
  --shared           Put the plan in plans/shared/ (cross-project).
  --project <name>   Put the plan in plans/<name>/.
  --open             Open the new file in $EDITOR (or vim) after creation.
                     Implied if DOCSHUB_AUTO_OPEN=1.
  -h, --help         Show this help.
EOF
}

cmd_new() {
    local type="" slug="" do_open="no" scope="" project_flag=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help) cmd_new_help; return 0 ;;
            --open) do_open="yes"; shift ;;
            --shared)
                [ -n "$scope" ] && { dh_err "--shared and --project are mutually exclusive"; return 2; }
                scope="shared"; shift ;;
            --project)
                [ $# -ge 2 ] || { dh_err "--project needs a value"; return 2; }
                [ -n "$scope" ] && { dh_err "--shared and --project are mutually exclusive"; return 2; }
                project_flag="$2"; scope="$2"; shift 2 ;;
            --project=*)
                [ -n "$scope" ] && { dh_err "--shared and --project are mutually exclusive"; return 2; }
                project_flag="${1#--project=}"; scope="$project_flag"; shift ;;
            --) shift; break ;;
            -*) dh_err "unknown flag: $1"; return 2 ;;
            *)
                if [ -z "$type" ]; then type="$1"
                elif [ -z "$slug" ]; then slug="$1"
                else dh_err "unexpected argument: $1"; return 2; fi
                shift
                ;;
        esac
    done

    [ -z "$type" ] || [ -z "$slug" ] && { cmd_new_help >&2; return 2; }

    case "$type" in
        plan|plans) type="plans" ;;
        *) dh_err "unsupported type: $type (supported: plan)"; return 2 ;;
    esac

    if ! printf '%s' "$slug" | grep -Eq '^[a-z0-9][a-z0-9-]*$'; then
        dh_err "slug must be kebab-case (lowercase letters, digits, hyphens; must start with letter or digit)"
        dh_err "got: $slug"
        return 2
    fi

    local root cfg tpl
    root="$(dh_default_root)"
    if [ ! -d "$root" ]; then
        dh_err "shared-docs root not found: $root  (run 'docs-hub init')"
        return 1
    fi
    cfg="$(dh_cfg_path "$root")"
    tpl="$root/templates/plan.md"
    if [ ! -f "$tpl" ]; then
        dh_err "template not found: $tpl"
        return 1
    fi

    # Validate --project if used: it must be a registered project (or
    # the literal "shared"). This catches typos at the boundary.
    if [ -n "$project_flag" ] && [ "$project_flag" != "shared" ]; then
        if ! dh_cfg_find_project_by_name "$cfg" "$project_flag" >/dev/null 2>&1; then
            dh_err "no project named '$project_flag' is registered. Run 'docs-hub status' to list."
            return 1
        fi
    fi

    # If no explicit scope, try to infer from cwd.
    if [ -z "$scope" ]; then
        scope="$(dh_detect_project_from_cwd "$cfg" 2>/dev/null || true)"
        if [ -z "$scope" ]; then
            dh_err "couldn't infer a project from the current directory."
            dh_err "either cd into a registered project, or pass --shared / --project <name>."
            return 2
        fi
    fi

    # Validate scope name (mirrors --as guard).
    case "$scope" in
        */*|*..*|"")
            dh_err "invalid scope name: '$scope'"; return 2 ;;
    esac

    local today out
    today="$(dh_today)"
    out="$root/plans/$scope/$today-$slug.md"

    if [ -e "$out" ]; then
        dh_info "$out"
        return 0
    fi

    mkdir -p -- "$root/plans/$scope" \
        || { dh_err "could not create $root/plans/$scope"; return 1; }

    local title
    title="$(printf '%s' "$slug" \
        | tr '-' ' ' \
        | awk '{
            for (i=1; i<=NF; i++) {
                $i = toupper(substr($i,1,1)) substr($i,2)
            }
            print
        }')"

    awk -v title="$title" -v date="$today" -v slug="$slug" -v scope="$scope" '
        {
            gsub(/\{\{title\}\}/, title)
            gsub(/\{\{date\}\}/,  date)
            gsub(/\{\{slug\}\}/,  slug)
            gsub(/\{\{scope\}\}/, scope)
            print
        }
    ' "$tpl" >"$out" || { dh_err "could not write $out"; return 1; }

    dh_ok "$out"

    if [ "$do_open" = "yes" ] || [ "${DOCSHUB_AUTO_OPEN:-0}" = "1" ]; then
        local ed="${EDITOR:-vim}"
        "$ed" "$out" || dh_warn "editor exited with non-zero status"
    fi
}
