#!/usr/bin/env bash

# Tests for generate.sh (generator) and the generated run.sh
#
# Everything runs inside a throwaway directory: generate.sh is copied there next to a
# mock rclone, so the real config.txt / run.sh in this folder are never touched.
#
# Usage: ./test_sync.sh [-k|--keep] [-v|--verbose] [TEST_NAME...]
#   -k, --keep      Keep the test directory for inspection
#   -v, --verbose   Print generator / run.sh output for every test
#   TEST_NAME       Run only the named tests (e.g. test_dry_run)
set -u
set -o pipefail

# Color codes
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'
NC='\e[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEEP=false
VERBOSE=false
SELECTED_TESTS=()

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -k|--keep)      KEEP=true ;;
        -v|--verbose)   VERBOSE=true ;;
        -h|--help)
            sed -n '3,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}" >&2
            exit 1
            ;;
        *)              SELECTED_TESTS+=("$1") ;;
    esac
    shift
done

if [[ ! -f "${SCRIPT_DIR}/generate.sh" ]]; then
    echo -e "${RED}generate.sh not found in ${SCRIPT_DIR}${NC}" >&2
    exit 1
fi

REAL_RCLONE="$(command -v rclone || true)"

# Isolated work directory with a copy of generate.sh and a mock rclone next to it
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rclone-easy-test.XXXXXX")"
cleanup() {
    if [[ "$KEEP" == true ]]; then
        echo -e "${YELLOW}Test directory kept at: ${WORK_DIR}${NC}"
    else
        rm -rf "$WORK_DIR"
    fi
}
trap cleanup EXIT

GEN="${WORK_DIR}/generate.sh"
cp "${SCRIPT_DIR}/generate.sh" "$GEN"
chmod +x "$GEN"

# The mock logs every call (one line of %q-quoted args) and delegates to the real rclone
MOCK_RCLONE="${WORK_DIR}/rclone"
CALL_LOG="${WORK_DIR}/rclone_calls.log"
cat << EOF > "$MOCK_RCLONE"
#!/usr/bin/env bash
echo "MOCK_RCLONE_CALLED"
printf '%q ' "\$@" >> $(printf '%q' "$CALL_LOG")
echo >> $(printf '%q' "$CALL_LOG")
REAL_RCLONE=$(printf '%q' "$REAL_RCLONE")
if [[ -z "\$REAL_RCLONE" ]]; then
    exit 0
fi
exec "\$REAL_RCLONE" "\$@"
EOF
chmod +x "$MOCK_RCLONE"

# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------
pass_count=0
fail_count=0
skip_count=0
current_failed=false
failed_tests=()

pass() {
    echo -e "  ${GREEN}[PASS]${NC} $*"
    ((pass_count++))
}

fail() {
    echo -e "  ${RED}[FAIL]${NC} $*" >&2
    ((fail_count++))
    current_failed=true
}

strip_colors() {
    sed 's/\x1b\[[0-9;]*m//g'
}

# Run generate.sh; sets gen_out (colors stripped) and gen_status
gen() {
    gen_out="$("$GEN" "$@" 2>&1 | strip_colors)"
    gen_status=${PIPESTATUS[0]}
    if [[ "$VERBOSE" == true ]]; then
        echo "$gen_out" | sed 's/^/    gen| /'
    fi
}

# Run a generated run.sh from inside the test dir; sets run_out and run_status
run_script() {
    local script="$1"
    shift
    : > "$CALL_LOG"
    run_out="$(cd "$T" && "$script" "$@" 2>&1 | strip_colors)"
    run_status=${PIPESTATUS[0]}
    if [[ "$VERBOSE" == true ]]; then
        echo "$run_out" | sed 's/^/    run| /'
    fi
}

assert_status() {
    local expected="$1" actual="$2" what="$3"
    if [[ "$actual" -eq "$expected" ]]; then
        pass "$what exits $expected"
    else
        fail "$what exited $actual, expected $expected"
    fi
}

assert_contains() {
    local haystack="$1" needle="$2" what="${3:-output}"
    if grep -qF -- "$needle" <<< "$haystack"; then
        pass "$what contains: $needle"
    else
        fail "$what is missing: $needle"
    fi
}

assert_not_contains() {
    local haystack="$1" needle="$2" what="${3:-output}"
    if grep -qF -- "$needle" <<< "$haystack"; then
        fail "$what unexpectedly contains: $needle"
    else
        pass "$what does not contain: $needle"
    fi
}

assert_file() {
    if [[ -f "$1" ]]; then
        pass "Found: ${1#"$WORK_DIR"/}"
    else
        fail "Missing: ${1#"$WORK_DIR"/}"
    fi
}

assert_no_file() {
    if [[ ! -e "$1" ]]; then
        pass "Correctly absent: ${1#"$WORK_DIR"/}"
    else
        fail "Unexpectedly found: ${1#"$WORK_DIR"/}"
    fi
}

# Assert the rclone call for a destination carries the given argument string
assert_call_has() {
    local dest="$1" needle="$2"
    local dest_q
    dest_q="$(printf '%q' "$dest")"
    local line
    line="$(grep -F -- " ${dest_q} " "$CALL_LOG" || true)"
    if [[ -z "$line" ]]; then
        fail "No rclone call for destination ${dest#"$WORK_DIR"/}"
    elif grep -qF -- "$needle" <<< "$line"; then
        pass "rclone call for ${dest##*/} has: $needle"
    else
        fail "rclone call for ${dest##*/} is missing '$needle': $line"
    fi
}

# Tests that need a real sync are skipped when rclone is not installed
require_rclone() {
    if [[ -z "$REAL_RCLONE" ]]; then
        echo -e "  ${YELLOW}[SKIP]${NC} rclone not installed"
        ((skip_count++))
        return 1
    fi
}

# Fresh per-test directory; sets T
new_test_dir() {
    T="${WORK_DIR}/$1"
    mkdir -p "$T"
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_basic_generate_and_sync() {
    new_test_dir basic
    mkdir -p "$T/sources/a" "$T/sources/b" "$T/sources/c with spaces"
    echo "file A" > "$T/sources/a/file1.txt"
    echo "file B" > "$T/sources/b/file2.txt"
    echo "file C" > "$T/sources/c with spaces/file3.txt"

    # Relative paths resolve against the config file's directory
    cat << 'EOF' > "$T/folders_list1.txt"
# Relative folder paths
sources/a
sources/b
EOF
    cat << EOF > "$T/folders_list2.txt"
# Absolute folder path
$T/sources/c with spaces
EOF
    cat << EOF > "$T/config.txt"
# Remote destination 1
Nickname: Test Nickname 1
Remote: $T/dest1
Folders: folders_list1.txt
FastList: true
SizeOnly: true

# Remote destination 2
Remote: $T/dest2/
Folders: $T/folders_list2.txt
FastList: false
RcloneFlags: --checkers 16 --use-server-modtime
EOF

    gen -c "$T/config.txt" -o "$T/run.sh"
    assert_status 0 "$gen_status" "generate.sh"
    assert_contains "$gen_out" "Local rclone binary found" "generator output"
    assert_contains "$gen_out" "Total blocks parsed: 2, total sync tasks configured: 3" "generator output"

    if [[ -x "$T/run.sh" ]]; then pass "run.sh is executable"; else fail "run.sh is not executable"; fi
    if bash -n "$T/run.sh"; then pass "run.sh passes bash -n"; else fail "run.sh has syntax errors"; fi
    assert_contains "$(cat "$T/run.sh")" "RCLONE_CMD=$(printf '%q' "$MOCK_RCLONE")" "run.sh"

    require_rclone || return 0
    run_script "$T/run.sh"
    assert_status 0 "$run_status" "run.sh"
    assert_contains "$run_out" "MOCK_RCLONE_CALLED" "run.sh output"
    assert_contains "$run_out" ">>> Starting block: Sync Block 1 (Test Nickname 1) <<<" "run.sh output"
    assert_contains "$run_out" "Successful: 3" "run.sh output"

    assert_call_has "$T/dest1/a" "--fast-list --size-only"
    assert_call_has "$T/dest2/c with spaces" "--checkers 16 --use-server-modtime"
    assert_call_has "$T/dest2/c with spaces" "-P"
    if grep -F -- "$(printf '%q' "$T/dest2/c with spaces")" "$CALL_LOG" | grep -qF -- "--fast-list"; then
        fail "FastList: false still produced --fast-list"
    else
        pass "FastList: false produces no --fast-list"
    fi

    assert_file "$T/dest1/a/file1.txt"
    assert_file "$T/dest1/b/file2.txt"
    assert_file "$T/dest2/c with spaces/file3.txt"
    assert_no_file "$T/dest1/c with spaces"
    assert_no_file "$T/dest2/a"
    assert_no_file "$T/dest2/b"
}

test_inline_folder_formats() {
    new_test_dir inline
    mkdir -p "$T/src/one" "$T/src/two" "$T/src/three" "$T/src/four"
    for d in one two three four; do echo "$d" > "$T/src/$d/$d.txt"; done
    cat << EOF > "$T/config.txt"
remote: $T/comma
folders: src/one, src/two

REMOTE: $T/json
FOLDERS: ["src/three", 'src/four']
EOF

    gen -c "$T/config.txt" -o "$T/run.sh"
    assert_status 0 "$gen_status" "generate.sh"
    assert_contains "$gen_out" "total sync tasks configured: 4" "generator output"

    require_rclone || return 0
    run_script "$T/run.sh"
    assert_status 0 "$run_status" "run.sh"
    assert_file "$T/comma/one/one.txt"
    assert_file "$T/comma/two/two.txt"
    assert_file "$T/json/three/three.txt"
    assert_file "$T/json/four/four.txt"
}

test_dry_run() {
    new_test_dir dry_run
    mkdir -p "$T/src/data"
    echo "data" > "$T/src/data/file.txt"
    cat << EOF > "$T/config.txt"
Remote: $T/dest
Folders: src/data
EOF

    # Dry-run baked in at generate time
    gen -c "$T/config.txt" -o "$T/run_dry.sh" -d
    assert_status 0 "$gen_status" "generate.sh -d"
    assert_contains "$(cat "$T/run_dry.sh")" "DRY_RUN_FLAG=--dry-run" "run_dry.sh"

    # Dry-run requested at run time
    gen -c "$T/config.txt" -o "$T/run.sh"
    assert_status 0 "$gen_status" "generate.sh"

    require_rclone || return 0
    run_script "$T/run_dry.sh"
    assert_status 0 "$run_status" "run_dry.sh"
    assert_contains "$run_out" "Running in DRY-RUN mode" "run_dry.sh output"
    assert_call_has "$T/dest/data" "--dry-run"
    assert_no_file "$T/dest/data/file.txt"

    run_script "$T/run.sh" --dry-run
    assert_status 0 "$run_status" "run.sh --dry-run"
    assert_call_has "$T/dest/data" "--dry-run"
    assert_no_file "$T/dest/data/file.txt"

    run_script "$T/run.sh"
    assert_status 0 "$run_status" "run.sh"
    assert_file "$T/dest/data/file.txt"
}

test_sync_mirrors_deletions() {
    new_test_dir deletions
    mkdir -p "$T/src/data"
    echo "keep" > "$T/src/data/keep.txt"
    echo "gone" > "$T/src/data/gone.txt"
    cat << EOF > "$T/config.txt"
Remote: $T/dest
Folders: src/data
EOF

    gen -c "$T/config.txt" -o "$T/run.sh"
    assert_status 0 "$gen_status" "generate.sh"

    require_rclone || return 0
    run_script "$T/run.sh"
    assert_file "$T/dest/data/gone.txt"

    rm "$T/src/data/gone.txt"
    run_script "$T/run.sh"
    assert_status 0 "$run_status" "second run.sh"
    assert_file "$T/dest/data/keep.txt"
    assert_no_file "$T/dest/data/gone.txt"
}

test_special_characters_and_injection() {
    new_test_dir special
    local weird="it's \$HOME \"quoted\" \`tick\`"
    mkdir -p "$T/src/$weird"
    echo "weird" > "$T/src/$weird/file.txt"
    echo "temp" > "$T/src/$weird/skip.tmp"
    printf '%s\n' "src/$weird" > "$T/folders.txt"

    # Each $(touch ...) would create a marker file if anything got evaluated
    cat << 'EOF' > "$T/config.txt"
Nickname: Bob's "best" $(touch NICK_PWNED)
Remote: dest
Folders: folders.txt
RcloneFlags: --exclude "*.tmp" --exclude '$(touch FLAG_PWNED)'
EOF
    # Remote must be absolute for the local backend; inject it without expanding the rest
    sed -i "s|^Remote: dest|Remote: $T/dest|" "$T/config.txt"

    gen -c "$T/config.txt" -o "$T/run.sh"
    assert_status 0 "$gen_status" "generate.sh"
    if bash -n "$T/run.sh"; then pass "run.sh passes bash -n"; else fail "run.sh has syntax errors"; fi
    assert_no_file "$T/NICK_PWNED"
    assert_no_file "$T/FLAG_PWNED"
    assert_no_file "${WORK_DIR}/NICK_PWNED"
    assert_no_file "${WORK_DIR}/FLAG_PWNED"

    require_rclone || return 0
    run_script "$T/run.sh"
    assert_status 0 "$run_status" "run.sh"
    assert_contains "$run_out" "Sync Block 1 (Bob's \"best\" \$(touch NICK_PWNED))" "run.sh output"
    assert_call_has "$T/dest/$weird" "--exclude \\*.tmp"
    assert_file "$T/dest/$weird/file.txt"
    assert_no_file "$T/dest/$weird/skip.tmp"
    assert_no_file "$T/NICK_PWNED"
    assert_no_file "$T/FLAG_PWNED"
}

test_config_warnings() {
    new_test_dir warnings
    mkdir -p "$T/src/Pictures" "$T/other/Pictures" "$T/src/docs"
    cat << EOF > "$T/config.txt"
Nickname: Valid
Remote: $T/dest
Folders: src/Pictures, other/Pictures, src/missing
SizeOnly: maybe
Folder: typo

Remote: nowhere:
Remote: $T/dest2
Folders: src/docs
Folders: src/docs
garbage line

Remote: $T/dest3
Folders: src/docs
RcloneFlags: --exclude "unterminated

Nickname: Orphan
Folders: orphan
EOF

    gen -c "$T/config.txt" -o "$T/run.sh"
    assert_status 0 "$gen_status" "generate.sh with warnings"
    assert_contains "$gen_out" "SizeOnly expects true/false, got 'maybe'" "generator output"
    assert_contains "$gen_out" "unknown key 'Folder'" "generator output"
    assert_contains "$gen_out" "Remote 'nowhere:' has no Folders" "generator output"
    assert_contains "$gen_out" "Folders given twice in one block" "generator output"
    assert_contains "$gen_out" "not a 'Key: value' line, ignored: garbage line" "generator output"
    assert_contains "$gen_out" "Could not parse RcloneFlags" "generator output"
    assert_contains "$gen_out" "Folders 'orphan' have no Remote" "generator output"
    assert_contains "$gen_out" "both sync to '$T/dest/Pictures'" "generator output"
    assert_contains "$gen_out" "Source folder does not exist (yet): $T/src/missing" "generator output"
    assert_contains "$gen_out" "Total blocks parsed: 2, total sync tasks configured: 4" "generator output"
    assert_not_contains "$(cat "$T/run.sh")" "$T/dest3" "run.sh"
    assert_not_contains "$(cat "$T/run.sh")" "--size-only" "run.sh"
}

test_missing_source_at_runtime() {
    new_test_dir runtime_missing
    mkdir -p "$T/src/a" "$T/src/b"
    echo "a" > "$T/src/a/a.txt"
    echo "b" > "$T/src/b/b.txt"
    cat << EOF > "$T/config.txt"
Remote: $T/dest
Folders: src/a, src/b
EOF

    gen -c "$T/config.txt" -o "$T/run.sh"
    assert_status 0 "$gen_status" "generate.sh"

    require_rclone || return 0
    rm -rf "$T/src/b"
    run_script "$T/run.sh"
    assert_status 1 "$run_status" "run.sh with a missing source"
    assert_contains "$run_out" "Source directory does not exist: $T/src/b" "run.sh output"
    assert_contains "$run_out" "Successful: 1" "run.sh output"
    assert_contains "$run_out" "Failed/Skipped: 1" "run.sh output"
    assert_file "$T/dest/a/a.txt"
}

test_cli_errors() {
    new_test_dir cli
    printf '# nothing here\n' > "$T/empty.txt"

    gen -c "$T/empty.txt" -o "$T/run.sh"
    assert_status 1 "$gen_status" "generate.sh with an empty config"
    assert_contains "$gen_out" "No sync tasks configured" "generator output"
    assert_no_file "$T/run.sh"
    if compgen -G "$T/run.sh.*" > /dev/null; then
        fail "Temp output file left behind"
    else
        pass "No temp output file left behind"
    fi

    # A failed generation must not clobber an existing run.sh
    echo "previous" > "$T/existing.sh"
    gen -c "$T/empty.txt" -o "$T/existing.sh"
    assert_contains "$(cat "$T/existing.sh")" "previous" "existing run script"

    gen -c "$T/does-not-exist.txt"
    assert_status 1 "$gen_status" "generate.sh with a missing config"
    assert_contains "$gen_out" "Configuration file not found" "generator output"

    gen -o
    assert_status 1 "$gen_status" "generate.sh -o without a value"
    assert_contains "$gen_out" "-o requires a value" "generator output"

    gen --bogus
    assert_status 1 "$gen_status" "generate.sh --bogus"
    assert_contains "$gen_out" "Unknown option: --bogus" "generator output"

    gen --help
    assert_status 0 "$gen_status" "generate.sh --help"
    assert_contains "$gen_out" "Usage:" "help output"
}

test_default_paths_and_permissions() {
    new_test_dir defaults
    mkdir -p "$T/src/data"

    # Without -c/-o, config.txt and run.sh live next to generate.sh
    cat << EOF > "${WORK_DIR}/config.txt"
Remote: $T/dest
Folders: $T/src/data
EOF
    (umask 022 && gen && exit "$gen_status")
    local gen_status_sub=$?
    rm -f "${WORK_DIR}/config.txt"
    assert_status 0 "$gen_status_sub" "generate.sh with default paths"
    assert_file "${WORK_DIR}/run.sh"

    local mode
    mode="$(stat -c '%a' "${WORK_DIR}/run.sh" 2>/dev/null || echo unknown)"
    if [[ "$mode" == "755" ]]; then
        pass "run.sh mode follows umask 022 (755)"
    else
        fail "run.sh mode is $mode, expected 755"
    fi
    rm -f "${WORK_DIR}/run.sh"
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
ALL_TESTS=(
    test_basic_generate_and_sync
    test_inline_folder_formats
    test_dry_run
    test_sync_mirrors_deletions
    test_special_characters_and_injection
    test_config_warnings
    test_missing_source_at_runtime
    test_cli_errors
    test_default_paths_and_permissions
)

if [[ ${#SELECTED_TESTS[@]} -eq 0 ]]; then
    SELECTED_TESTS=("${ALL_TESTS[@]}")
fi

echo -e "${CYAN}=== rclone-easy tests ===${NC}"
echo -e "Work dir: ${WORK_DIR}"
if [[ -z "$REAL_RCLONE" ]]; then
    echo -e "${YELLOW}rclone not found: sync steps will be skipped, generator checks still run.${NC}"
fi

for test_name in "${SELECTED_TESTS[@]}"; do
    if ! declare -F "$test_name" > /dev/null; then
        echo -e "${RED}Unknown test: ${test_name}${NC}" >&2
        failed_tests+=("$test_name")
        ((fail_count++))
        continue
    fi
    echo -e "\n${CYAN}>>> ${test_name}${NC}"
    current_failed=false
    "$test_name"
    if [[ "$current_failed" == true ]]; then
        failed_tests+=("$test_name")
    fi
done

echo -e "\n${CYAN}========================================${NC}"
echo -e "Passed: ${GREEN}${pass_count}${NC}  Failed: ${RED}${fail_count}${NC}  Skipped: ${YELLOW}${skip_count}${NC}"
if [[ ${#failed_tests[@]} -gt 0 ]]; then
    echo -e "${RED}Failed tests:${NC}"
    printf '  - %s\n' "${failed_tests[@]}"
    exit 1
fi
echo -e "${GREEN}All tests passed!${NC}"
exit 0
