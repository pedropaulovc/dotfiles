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
for shortcut in \
    yc-t ycft ycot ycst ygt \
    yx-t yxst yxtt yxlt \
    yo-t yoft yoot yost yott yolt \
    pyo-t pyoft pyoot pyost pyott pyolt; do
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
    bash --noprofile --norc -i "$tmp_dir/smoke.sh"

printf 'Temporary Bash shortcut created the project, forwarded arguments, and removed stale projects.\n'
