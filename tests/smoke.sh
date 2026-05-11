#!/usr/bin/env bash
# End-to-end smoke test for docs-hub. Self-contained; no test framework.
# Exits 0 on success, 1 on first failure.
#
# Usage:  ./tests/smoke.sh
#
# Layout under $TMP:
#   shared-docs/                 ← docs-hub root
#   projectA/  (has existing docs/ with content, has .gitignore)
#   projectB/  (clean, has .gitignore)
#   has space/projectC/ (path with space, no .gitignore)

set -u
set -o pipefail

REPO="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P )"
DH="$REPO/bin/docs-hub"

TMP="$(mktemp -d -t docs-hub-smoke.XXXXXX)"
trap 'rm -rf -- "$TMP"' EXIT

# Force the CLI to use our temp root, regardless of where the script lives.
export DOCSHUB_ROOT="$TMP/shared-docs"
# Auto-confirm prompts during tests.
export DOCSHUB_ASSUME_YES=1
# Disable color in logs to keep assertions simple.
export NO_COLOR=1

PASS=0
FAIL=0
FAIL_NAMES=()

note() { printf '\n=== %s ===\n' "$*"; }

ok() {
    PASS=$((PASS+1))
    printf '  \033[32mok\033[0m  %s\n' "$*"
}
fail() {
    FAIL=$((FAIL+1))
    FAIL_NAMES+=("$1")
    printf '  \033[31mFAIL\033[0m %s\n' "$*"
}

assert_exit() {
    # assert_exit <expected_code> <label> <cmd...>
    local expected="$1" label="$2"; shift 2
    local actual=0
    "$@" >/tmp/docs-hub-test-out 2>&1 || actual=$?
    if [ "$actual" = "$expected" ]; then
        ok "$label (exit=$actual)"
    else
        fail "$label (expected exit=$expected, got $actual)"
        sed 's/^/      | /' /tmp/docs-hub-test-out
    fi
}

assert_contains() {
    # assert_contains <label> <file> <substring>
    local label="$1" f="$2" needle="$3"
    if grep -F -- "$needle" "$f" >/dev/null 2>&1; then
        ok "$label"
    else
        fail "$label (missing substring: $needle)"
        sed 's/^/      | /' "$f"
    fi
}

assert_file() {
    # assert_file <label> <path>
    if [ -f "$2" ]; then ok "$1"; else fail "$1 (no file at $2)"; fi
}
assert_symlink_to() {
    # assert_symlink_to <label> <link> <target>
    local label="$1" link="$2" want="$3"
    if [ -L "$link" ] && [ "$(readlink -- "$link")" = "$want" ]; then
        ok "$label"
    else
        fail "$label (link=$link readlink=$(readlink -- "$link" 2>/dev/null))"
    fi
}

# --- setup -----------------------------------------------------------------

mkdir -p "$TMP/projectA/docs/plans"
echo "old plan content" >"$TMP/projectA/docs/plans/old.md"
printf 'node_modules\n' >"$TMP/projectA/.gitignore"

mkdir -p "$TMP/projectB"
printf 'vendor\n' >"$TMP/projectB/.gitignore"

mkdir -p "$TMP/has space/projectC"

# --- init ------------------------------------------------------------------

note "init"
assert_exit 0 "init creates shared root"        "$DH" init "$DOCSHUB_ROOT" --no-git
[ -d "$DOCSHUB_ROOT/plans" ] && ok "plans/ dir exists" || fail "plans/ dir exists"
[ -d "$DOCSHUB_ROOT/architecture" ] && ok "architecture/ dir exists" || fail "architecture/ dir exists"
[ -d "$DOCSHUB_ROOT/runbooks" ] && ok "runbooks/ dir exists" || fail "runbooks/ dir exists"
assert_file  "templates/plan.md exists"         "$DOCSHUB_ROOT/templates/plan.md"
assert_file  "docs.config.yml exists"           "$DOCSHUB_ROOT/docs.config.yml"
assert_exit 0 "init is idempotent (re-run)"     "$DH" init "$DOCSHUB_ROOT" --no-git

# --- settings preservation ------------------------------------------------

note "settings preservation"
# user edits settings manually (portable in-place edit: write to tmp + mv)
awk '{ gsub(/editor: ""/, "editor: \"code -w\""); print }' \
    "$DOCSHUB_ROOT/docs.config.yml" >"$DOCSHUB_ROOT/docs.config.yml.edit" \
    && mv "$DOCSHUB_ROOT/docs.config.yml.edit" "$DOCSHUB_ROOT/docs.config.yml"

# --- link ------------------------------------------------------------------

note "link"
assert_exit 0 "link projectA (existing docs, auto-confirm)" "$DH" link "$TMP/projectA"
assert_symlink_to "projectA/docs → shared root" "$TMP/projectA/docs" "$DOCSHUB_ROOT"
[ -d "$TMP/projectA"/docs.bak.* ] && ok "projectA backup created" || fail "projectA backup created"
assert_contains "projectA .gitignore got /docs" "$TMP/projectA/.gitignore" "/docs"

assert_exit 0 "link projectB (clean)"          "$DH" link "$TMP/projectB"
assert_symlink_to "projectB/docs → shared root" "$TMP/projectB/docs" "$DOCSHUB_ROOT"

assert_exit 0 "link projectC (space in path, no .gitignore)" "$DH" link "$TMP/has space/projectC"
assert_symlink_to "projectC/docs → shared root" "$TMP/has space/projectC/docs" "$DOCSHUB_ROOT"

assert_exit 1 "link non-existent project fails"  "$DH" link "$TMP/no-such"
assert_exit 0 "link projectA again is no-op"     "$DH" link "$TMP/projectA"

# settings preserved through re-writes
assert_contains "settings.editor preserved after link" \
    "$DOCSHUB_ROOT/docs.config.yml" 'editor: "code -w"'

# config has 3 projects
grep -c '^  - name:' "$DOCSHUB_ROOT/docs.config.yml" >/tmp/docs-hub-test-out
[ "$(cat /tmp/docs-hub-test-out)" = "3" ] && ok "3 projects registered" \
    || fail "3 projects registered (got $(cat /tmp/docs-hub-test-out))"

# --- link --repair ---------------------------------------------------------

note "link --repair"
# break projectB's link by removing then creating a dangling one
rm -- "$TMP/projectB/docs"
ln -s /no/such/place "$TMP/projectB/docs"
assert_exit 1 "broken symlink is rejected without --repair" "$DH" link "$TMP/projectB"
assert_exit 0 "broken symlink is fixed with --repair"       "$DH" link "$TMP/projectB" --repair
assert_symlink_to "projectB/docs restored" "$TMP/projectB/docs" "$DOCSHUB_ROOT"

# --- new plan --------------------------------------------------------------

note "new plan"
assert_exit 2 "invalid slug rejected"       "$DH" new plan "Bad Slug!"
assert_exit 0 "valid slug accepted"         "$DH" new plan example-feature
today="$(date +%F)"
assert_file  "plan file created"            "$DOCSHUB_ROOT/plans/$today-example-feature.md"
assert_contains "title rendered title-cased" \
    "$DOCSHUB_ROOT/plans/$today-example-feature.md" "# Example Feature"
assert_contains "date rendered" \
    "$DOCSHUB_ROOT/plans/$today-example-feature.md" "**Date:** $today"
assert_exit 0 "re-create same plan is a no-op" "$DH" new plan example-feature

# --- ls --------------------------------------------------------------------

note "ls"
"$DH" ls >/tmp/docs-hub-test-out 2>&1
assert_contains "ls plans shows new file" /tmp/docs-hub-test-out "example-feature.md"

# --- search ----------------------------------------------------------------

note "search"
"$DH" search "Example Feature" >/tmp/docs-hub-test-out 2>&1
assert_contains "search finds the plan" /tmp/docs-hub-test-out "example-feature.md"
assert_exit 1 "search miss returns non-zero" "$DH" search definitely-not-there

# --- status ----------------------------------------------------------------

note "status"
assert_exit 0 "status returns 0 when all OK"   "$DH" status
# break projectC: change link target to /tmp
rm -- "$TMP/has space/projectC/docs"
ln -s /no/such/place "$TMP/has space/projectC/docs"
assert_exit 1 "status returns 1 when broken"   "$DH" status
# repair for next steps
rm -- "$TMP/has space/projectC/docs"
ln -s "$DOCSHUB_ROOT" "$TMP/has space/projectC/docs"

# --- unlink ----------------------------------------------------------------

note "unlink"
assert_exit 0 "unlink projectA restores backup" "$DH" unlink "$TMP/projectA"
[ -d "$TMP/projectA/docs" ] && [ ! -L "$TMP/projectA/docs" ] \
    && ok "projectA/docs restored as real dir" \
    || fail "projectA/docs restored as real dir"
[ -f "$TMP/projectA/docs/plans/old.md" ] \
    && ok "old content present after restore" \
    || fail "old content present after restore"

assert_exit 0 "unlink projectB (no backup to restore)" "$DH" unlink "$TMP/projectB"
[ ! -e "$TMP/projectB/docs" ] && ok "projectB/docs removed cleanly" \
    || fail "projectB/docs removed cleanly"

# config now has only projectC
grep -c '^  - name:' "$DOCSHUB_ROOT/docs.config.yml" >/tmp/docs-hub-test-out
[ "$(cat /tmp/docs-hub-test-out)" = "1" ] \
    && ok "1 project remains after 2 unlinks" \
    || fail "1 project remains after 2 unlinks (got $(cat /tmp/docs-hub-test-out))"

# settings preserved through unlinks too
assert_contains "settings.editor preserved after unlink" \
    "$DOCSHUB_ROOT/docs.config.yml" 'editor: "code -w"'

# --- help ------------------------------------------------------------------

note "help"
for c in init link unlink new ls status search; do
    assert_exit 0 "$c --help works" "$DH" "$c" --help
done

# --- summary ---------------------------------------------------------------

printf '\n----------------------------------------\n'
printf 'passed: %s   failed: %s\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
    printf 'failures:\n'
    for n in "${FAIL_NAMES[@]}"; do printf '  - %s\n' "$n"; done
    exit 1
fi
exit 0
