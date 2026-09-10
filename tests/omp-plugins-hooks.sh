#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

fake_bin="$tmp_dir/bin"
call_log="$tmp_dir/omp-calls"
hook="$tmp_dir/omp-plugins.sh"
mkdir -p "$fake_bin"
: >"$call_log"

cat >"$fake_bin/omp" <<'EOF'
#!/bin/sh
set -eu

case "$1 $2 $3" in
  'plugin marketplace list')
    printf '%s' "$MARKETPLACES"
    ;;
  'plugin marketplace add')
    printf 'add %s\n' "$4" >>"$CALL_LOG"
    ;;
  'plugin marketplace update')
    printf 'update %s\n' "$4" >>"$CALL_LOG"
    [ "$4" = "agent-plugins" ] || exit 1
    [ "${FAIL_REFRESH:-0}" = "0" ] || exit 1
    : >"$CALL_LOG.refreshed"
    ;;
  'plugin install '*)
    printf 'install %s\n' "$3" >>"$CALL_LOG"
    [ -f "$CALL_LOG.refreshed" ] || exit 1
    ;;
  *)
    printf 'Unexpected omp invocation: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$fake_bin/omp"

cd "$repo_dir"
chezmoi execute-template \
  --file run_onchange_omp-plugins.sh.tmpl \
  --override-data '{"platform":"linux"}' \
  --output "$hook"
sh -n "$hook"

run_success_case() {
  case_name=$1
  marketplaces=$2
  expected_summary=$3

  : >"$call_log"
  rm -f "$call_log.refreshed"
  if ! FAIL_REFRESH=0 MARKETPLACES="$marketplaces" CALL_LOG="$call_log" PATH="$fake_bin:$PATH" sh "$hook" >"$tmp_dir/$case_name-output" 2>&1; then
    printf 'Expected %s marketplace case to succeed.\n' "$case_name" >&2
    cat "$tmp_dir/$case_name-output" >&2
    exit 1
  fi

  summary=$(awk '
    $1 == "add" { adds++ }
    $1 == "update" { updates++ }
    $1 == "install" { installs++ }
    END { print (adds + 0) ":" (updates + 0) ":" (installs + 0) }
  ' "$call_log")
  if [ "$summary" != "$expected_summary" ]; then
    printf 'Unexpected %s call summary: %s\n' "$case_name" "$summary" >&2
    cat "$call_log" >&2
    exit 1
  fi
}

run_success_case \
  url \
  'Configured Marketplaces:

  agent-plugins  https://github.com/pedropaulovc/agent-plugins' \
  '0:1:7'
run_success_case \
  shorthand \
  'Configured Marketplaces:

  agent-plugins  pedropaulovc/agent-plugins' \
  '0:1:7'
run_success_case \
  missing \
  'Configured Marketplaces:' \
  '1:1:7'

if ! awk '$1 == "add" && $2 == "pedropaulovc/agent-plugins" { found = 1 } END { exit !found }' "$call_log"; then
  printf 'Missing marketplace case did not add the manifest source.\n' >&2
  cat "$call_log" >&2
  exit 1
fi

: >"$call_log"
rm -f "$call_log.refreshed"
if FAIL_REFRESH=1 MARKETPLACES='Configured Marketplaces:

  agent-plugins  https://github.com/pedropaulovc/agent-plugins' CALL_LOG="$call_log" PATH="$fake_bin:$PATH" sh "$hook" >"$tmp_dir/refresh-failure-output" 2>&1; then
  printf 'Failed marketplace refresh unexpectedly succeeded.\n' >&2
  exit 1
fi
if [ "$(cat "$call_log")" != 'update agent-plugins' ]; then
  printf 'Failed marketplace refresh did not stop before installs.\n' >&2
  cat "$call_log" >&2
  exit 1
fi

: >"$call_log"
rm -f "$call_log.refreshed"
wrong_source='Configured Marketplaces:

  agent-plugins  https://github.com/another-owner/agent-plugins'
if FAIL_REFRESH=0 MARKETPLACES="$wrong_source" CALL_LOG="$call_log" PATH="$fake_bin:$PATH" sh "$hook" >"$tmp_dir/wrong-output" 2>&1; then
  printf 'Different marketplace source unexpectedly succeeded.\n' >&2
  exit 1
fi
if [ -s "$call_log" ]; then
  printf 'Different marketplace source triggered omp mutations.\n' >&2
  cat "$call_log" >&2
  exit 1
fi

printf '%s\n' 'POSIX OMP hooks refresh stale metadata before installs, stop on refresh failure, accept URL and shorthand sources, add missing sources, and reject mismatches.'
