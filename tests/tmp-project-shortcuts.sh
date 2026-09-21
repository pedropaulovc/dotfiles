#!/bin/sh
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

home_dir="$tmp_dir/home"
src_dir="$home_dir/src"
mkdir -p "$home_dir/.cargo" "$src_dir/tmp-stale" "$src_dir/tmp-fresh"
: >"$home_dir/.cargo/env"
touch -d '8 days ago' "$src_dir/tmp-stale"

call_log="$tmp_dir/call-log"

cat >"$tmp_dir/smoke.sh" <<'EOF'
set -e
. "$REPO_DIR/dot_bashrc"
set -u
omp() {
    printf '%s\n' "$*" >>"$OMP_CALL_LOG"
    case "$*" in
        'plugin marketplace update')
            [ "${FAIL_REFRESH:-0}" -eq 0 ] || return 17
            ;;
        'plugin list --json')
            if [ "${EMPTY_MARKETPLACE:-0}" -eq 1 ]; then
                printf '%s\n' '{"marketplace":[]}'
            else
                printf '%s\n' '{"marketplace":[{"id":"watch-pr@agent-plugins","scope":"user","entries":[{"scope":"user","version":"2.0.2"}]},{"id":"watch-pr@agent-plugins","scope":"project","entries":[{"scope":"project","version":"2.0.2"}]},{"id":"worktree-reset@agent-plugins","scope":"project","entries":[{"scope":"project","version":"2.2.0"}]}]}'
            fi
            ;;
        'plugin upgrade watch-pr@agent-plugins --scope user')
            [ "${FAIL_UPGRADE:-0}" -eq 0 ] || return 19
            ;;
        'plugin upgrade watch-pr@agent-plugins --scope project')
            ;;
        'plugin upgrade worktree-reset@agent-plugins --scope project')
            ;;
    esac
}

omp-plugin-upgrade
expected_omp_calls='plugin marketplace update
plugin list --json
plugin upgrade watch-pr@agent-plugins --scope user
plugin upgrade watch-pr@agent-plugins --scope project
plugin upgrade worktree-reset@agent-plugins --scope project'
[ "$(cat "$OMP_CALL_LOG")" = "$expected_omp_calls" ]
: >"$OMP_CALL_LOG"
if ! EMPTY_MARKETPLACE=1 omp-plugin-upgrade; then
    printf 'omp-plugin-upgrade failed with no marketplace plugins.\n' >&2
    exit 1
fi
expected_empty_calls='plugin marketplace update
plugin list --json'
[ "$(cat "$OMP_CALL_LOG")" = "$expected_empty_calls" ]
: >"$OMP_CALL_LOG"
if FAIL_REFRESH=1 omp-plugin-upgrade; then
    printf 'omp-plugin-upgrade continued after marketplace refresh failure.\n' >&2
    exit 1
fi
[ "$(cat "$OMP_CALL_LOG")" = 'plugin marketplace update' ]
: >"$OMP_CALL_LOG"
if FAIL_UPGRADE=1 omp-plugin-upgrade; then
    printf 'omp-plugin-upgrade hid a scoped plugin upgrade failure.\n' >&2
    exit 1
fi
expected_failed_upgrade_calls='plugin marketplace update
plugin list --json
plugin upgrade watch-pr@agent-plugins --scope user'
[ "$(cat "$OMP_CALL_LOG")" = "$expected_failed_upgrade_calls" ]
: >"$OMP_CALL_LOG"
yog --probe
[ "$(cat "$OMP_CALL_LOG")" = '--auto-approve --model openrouter/z-ai/glm-5.3-flash --thinking high --smol openrouter/z-ai/glm-5.3 --slow anthropic/claude-opus-5:medium --plan anthropic/claude-fable-5-1:xhigh --probe' ]
cat >"$TMP_PYO_BINARY" <<'PYOP'
#!/bin/sh
printf '%s\n' "$*" >>"$OMP_CALL_LOG"
PYOP
chmod +x "$TMP_PYO_BINARY"
PYO_BINARY="$TMP_PYO_BINARY"
: >"$OMP_CALL_LOG"
pyog --probe
[ "$(cat "$OMP_CALL_LOG")" = '--auto-approve --model openrouter/z-ai/glm-5.3-flash --thinking high --smol openrouter/z-ai/glm-5.3 --slow anthropic/claude-opus-5:medium --plan anthropic/claude-fable-5-1:xhigh --probe' ]
: >"$OMP_CALL_LOG"
yof --probe
[ "$(cat "$OMP_CALL_LOG")" = '--auto-approve --model anthropic/claude-fable-5-1:medium --thinking medium --smol openrouter/z-ai/glm-5.3 --slow anthropic/claude-opus-5:medium --plan anthropic/claude-fable-5-1:xhigh --probe' ]
: >"$OMP_CALL_LOG"
yoo --probe
[ "$(cat "$OMP_CALL_LOG")" = '--auto-approve --model anthropic/claude-opus-5:medium --thinking medium --smol openrouter/z-ai/glm-5.3 --slow anthropic/claude-opus-5:medium --plan anthropic/claude-fable-5-1:xhigh --probe' ]
: >"$OMP_CALL_LOG"
pyof --probe
[ "$(cat "$OMP_CALL_LOG")" = '--auto-approve --model anthropic/claude-fable-5-1:medium --thinking medium --smol openrouter/z-ai/glm-5.3 --slow anthropic/claude-opus-5:medium --plan anthropic/claude-fable-5-1:xhigh --probe' ]
: >"$OMP_CALL_LOG"
pyoo --probe
[ "$(cat "$OMP_CALL_LOG")" = '--auto-approve --model anthropic/claude-opus-5:medium --thinking medium --smol openrouter/z-ai/glm-5.3 --slow anthropic/claude-opus-5:medium --plan anthropic/claude-fable-5-1:xhigh --probe' ]
: >"$OMP_CALL_LOG"
yos --probe
[ "$(cat "$OMP_CALL_LOG")" = '--auto-approve --model openai-codex/gpt-5.6-sol:medium --thinking medium --smol openai-codex/gpt-5.6-luna:max --slow openai-codex/gpt-5.6-sol:medium --plan openai-codex/gpt-6-astra:high --probe' ]
: >"$OMP_CALL_LOG"
pyos --probe
[ "$(cat "$OMP_CALL_LOG")" = '--auto-approve --model openai-codex/gpt-5.6-sol:medium --thinking medium --smol openai-codex/gpt-5.6-luna:max --slow openai-codex/gpt-5.6-sol:medium --plan openai-codex/gpt-6-astra:high --probe' ]
: >"$OMP_CALL_LOG"
yot --probe
[ "$(cat "$OMP_CALL_LOG")" = '--auto-approve --model openai-codex/gpt-5.6-terra:medium --thinking medium --smol openai-codex/gpt-5.6-luna:max --slow openai-codex/gpt-5.6-sol:medium --plan openai-codex/gpt-6-astra:high --probe' ]
: >"$OMP_CALL_LOG"
pyot --probe
[ "$(cat "$OMP_CALL_LOG")" = '--auto-approve --model openai-codex/gpt-5.6-terra:medium --thinking medium --smol openai-codex/gpt-5.6-luna:max --slow openai-codex/gpt-5.6-sol:medium --plan openai-codex/gpt-6-astra:high --probe' ]

for shortcut in \
    omp-plugin-upgrade \
    yc-t ycft ycot ycst ygt \
    yx-t yxst yxtt yxlt yxat \
    yo yof yoo yog yos yot yol yoa yoc yofc yooc yogc yosc yotc yolc yoac \
    pyo pyof pyoo pyog pyos pyot pyol pyoa pyoc pyofc pyooc pyogc pyosc pyotc pyolc pyoac \
    yo-t yoft yoot yogt yost yott yolt yoat \
    pyo-t pyoft pyoot pyogt pyost pyott pyolt pyoat; do

    type "$shortcut" >/dev/null
done

pyol() {
    printf '%s\n' "$PWD" >"$CALL_LOG"
    printf '%s\n' "$*" >>"$CALL_LOG"
    [ "${1-}" != '--fail' ] || return 17
}

if pyolt; then
    printf 'pyolt accepted a missing project name.\n' >&2
    exit 1
else
    status=$?
    [ "$status" -eq 2 ]
fi

if pyolt ../escape; then
    printf 'pyolt accepted a path traversal project name.\n' >&2
    exit 1
else
    status=$?
    [ "$status" -eq 2 ]
fi
mkdir -p "$HOME/outside"
ln -s "$HOME/outside" "$HOME/src/tmp-linked"
if pyolt linked; then
    printf 'pyolt followed a symbolic-link project path.\n' >&2
    exit 1
else
    status=$?
    [ "$status" -eq 2 ]
fi
[ -L "$HOME/src/tmp-linked" ]

pyolt myproj --flag value
[ "$(sed -n '1p' "$CALL_LOG")" = "$HOME/src/tmp-myproj" ]
[ "$(sed -n '2p' "$CALL_LOG")" = '--flag value' ]
[ -d "$HOME/src/tmp-myproj" ]
[ ! -d "$HOME/src/tmp-stale" ]
[ -d "$HOME/src/tmp-fresh" ]

mkdir -p "$HOME/src/tmp-failing-stale"
touch -d '8 days ago' "$HOME/src/tmp-failing-stale"
if pyolt failing --fail; then
    printf 'pyolt hid the wrapped command failure.\n' >&2
else
    status=$?
    [ "$status" -eq 17 ]
fi
[ ! -d "$HOME/src/tmp-failing-stale" ]
mkdir -p "$HOME/src/tmp-uninspectable" "$HOME/fake-bin"
touch -d '8 days ago' "$HOME/src/tmp-uninspectable"
cat >"$HOME/fake-bin/find" <<'FIND'
#!/bin/sh
case "$*" in
    *-newermt*) exit 1 ;;
    *) exec /usr/bin/find "$@" ;;
esac
FIND
chmod +x "$HOME/fake-bin/find"
old_path=$PATH
PATH="$HOME/fake-bin:$PATH"
pyolt uninspectable
PATH=$old_path
[ -d "$HOME/src/tmp-uninspectable" ]


if type pyolct >/dev/null 2>&1; then
    printf 'A continue temporary shortcut was unexpectedly defined.\n' >&2
    exit 1
fi
EOF

HOME="$home_dir" REPO_DIR="$repo_dir" CALL_LOG="$call_log" \
    OMP_CALL_LOG="$tmp_dir/omp-call-log" TMP_PYO_BINARY="$tmp_dir/fake-pyo" \
    bash --noprofile --norc -i "$tmp_dir/smoke.sh"


printf 'Temporary Bash shortcut created the project, forwarded arguments, and removed stale projects.\n'
