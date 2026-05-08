# shellcheck shell=bash
# inkwell new plan <slug> [--open]

cmd_new_help() {
    cat <<'EOF'
Usage: inkwell new <type> <slug> [--open]

Create a new doc from a template. Currently supported <type>: plan.

  plan    Creates plans/YYYY-MM-DD-<slug>.md from templates/plan.md.

The slug must match ^[a-z0-9][a-z0-9-]*$ (kebab-case). The title in the
rendered template is the slug with hyphens replaced by spaces, title-cased.

If the file already exists, the path is printed and nothing is overwritten.

Options:
  --open       Open the new file in $EDITOR (or vim) after creation.
               Implied if INKWELL_AUTO_OPEN=1.
  -h, --help   Show this help.
EOF
}

cmd_new() {
    local type="" slug="" do_open="no"
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help) cmd_new_help; return 0 ;;
            --open) do_open="yes"; shift ;;
            --) shift; break ;;
            -*) ink_err "unknown flag: $1"; return 2 ;;
            *)
                if [ -z "$type" ]; then type="$1"
                elif [ -z "$slug" ]; then slug="$1"
                else ink_err "unexpected argument: $1"; return 2; fi
                shift
                ;;
        esac
    done

    [ -z "$type" ] || [ -z "$slug" ] && { cmd_new_help >&2; return 2; }

    case "$type" in
        plan|plans) type="plans" ;;
        *) ink_err "unsupported type: $type (supported: plan)"; return 2 ;;
    esac

    if ! printf '%s' "$slug" | grep -Eq '^[a-z0-9][a-z0-9-]*$'; then
        ink_err "slug must be kebab-case (lowercase letters, digits, hyphens; must start with letter or digit)"
        ink_err "got: $slug"
        return 2
    fi

    local root tpl out
    root="$(ink_default_root)"
    if [ ! -d "$root" ]; then
        ink_err "shared-docs root not found: $root  (run 'inkwell init')"
        return 1
    fi
    tpl="$root/templates/plan.md"
    if [ ! -f "$tpl" ]; then
        ink_err "template not found: $tpl"
        return 1
    fi

    local date today
    today="$(ink_today)"
    out="$root/plans/$today-$slug.md"

    if [ -e "$out" ]; then
        ink_info "$out"
        return 0
    fi

    mkdir -p -- "$root/plans" || { ink_err "could not create $root/plans"; return 1; }

    # Title: replace - with space, then title-case each word.
    local title
    title="$(printf '%s' "$slug" \
        | tr '-' ' ' \
        | awk '{
            for (i=1; i<=NF; i++) {
                $i = toupper(substr($i,1,1)) substr($i,2)
            }
            print
        }')"

    # Render template via simple substitution. Using awk to avoid sed
    # surprises with special characters in the slug or title.
    awk -v title="$title" -v date="$today" -v slug="$slug" '
        {
            gsub(/\{\{title\}\}/, title)
            gsub(/\{\{date\}\}/,  date)
            gsub(/\{\{slug\}\}/,  slug)
            print
        }
    ' "$tpl" >"$out" || { ink_err "could not write $out"; return 1; }

    ink_ok "$out"

    if [ "$do_open" = "yes" ] || [ "${INKWELL_AUTO_OPEN:-0}" = "1" ]; then
        local ed="${EDITOR:-vim}"
        "$ed" "$out" || ink_warn "editor exited with non-zero status"
    fi
}
