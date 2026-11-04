#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM
mkdir -p "$tmp_dir/bin" "$tmp_dir/agent" "$tmp_dir/azure"
export AZ_FIXTURES="$tmp_dir/azure"
export PI_CODING_AGENT_DIR="$tmp_dir/agent"
export PATH="$tmp_dir/bin:$PATH"

cat >"$tmp_dir/bin/az" <<'EOF'
#!/bin/sh
set -eu
case "$*" in
  'webapp config appsettings list '*) file=token ;;
  'keyvault secret list '*) file=names ;;
  'keyvault secret show '*)
    while [ "$1" != --name ]; do shift; done
    file=$2 ;;
  *) exit 40 ;;
esac
[ "${AZ_FAIL-}" != "$file" ] || exit 42
cat "$AZ_FIXTURES/$file.json"
EOF
chmod +x "$tmp_dir/bin/az"
printf '%s\n' '"fresh-test-token"' >"$AZ_FIXTURES/token.json"
printf '%s\n' '["EXA-API-KEY","QUOTED-KEY","EMPTY-KEY"]' >"$AZ_FIXTURES/names.json"
printf '%s\n' '"fresh-exa-secret"' >"$AZ_FIXTURES/EXA-API-KEY.json"
printf '%s\n' '"  quote\u0027s # $dollar \\path  "' >"$AZ_FIXTURES/QUOTED-KEY.json"
printf '%s\n' '""' >"$AZ_FIXTURES/EMPTY-KEY.json"

hook="$tmp_dir/hook.sh"
chezmoi execute-template --source "$repo_dir" \
  --file run_onchange_after_hindsight-api-key.sh.tmpl \
  --override-data '{"platform":"linux"}' --output "$hook"
cat >"$PI_CODING_AGENT_DIR/.env" <<'EOF'
OTHER_SETTING=keep
# keep this comment
HINDSIGHT_API_TOKEN=stale-token
export HINDSIGHT_API_TOKEN=older-token
EXA_API_KEY=stale-exa
export EXA_API_KEY=older-exa
EOF
cat >"$tmp_dir/expected" <<'EOF'
OTHER_SETTING=keep
# keep this comment
HINDSIGHT_API_TOKEN='fresh-test-token'
EXA_API_KEY='fresh-exa-secret'
QUOTED_KEY="  quote's # $dollar \path  "
EMPTY_KEY=''
EOF

sh "$hook" >"$tmp_dir/output" 2>"$tmp_dir/trace"
cmp "$tmp_dir/expected" "$PI_CODING_AGENT_DIR/.env"
if [ "$(stat -c '%a' "$PI_CODING_AGENT_DIR/.env")" != 600 ]; then
  printf 'OMP dotenv permissions are not 600.\n' >&2
  exit 1
fi
if grep -E 'fresh-test-token|fresh-exa-secret|quote.s # ' "$tmp_dir/output" "$tmp_dir/trace" >/dev/null; then
  printf 'Hook leaked secrets in its output or trace.\n' >&2
  exit 1
fi
sh "$hook" >"$tmp_dir/repeat-output" 2>"$tmp_dir/repeat-trace"
cmp "$tmp_dir/expected" "$PI_CODING_AGENT_DIR/.env"

# Fail after the token and one vault value have already been read.
for failure in token names QUOTED-KEY; do
  if AZ_FAIL="$failure" sh "$hook" >"$tmp_dir/failure-output" 2>"$tmp_dir/failure-trace"; then
    printf 'Hook succeeded despite Azure failure: %s\n' "$failure" >&2
    exit 1
  fi
  cmp "$tmp_dir/expected" "$PI_CODING_AGENT_DIR/.env"
done
printf '%s\n' '""' >"$AZ_FIXTURES/token.json"
if sh "$hook" >"$tmp_dir/empty-output" 2>"$tmp_dir/empty-trace"; then
  printf 'Hook accepted an empty Hindsight token.\n' >&2
  exit 1
fi
cmp "$tmp_dir/expected" "$PI_CODING_AGENT_DIR/.env"
printf '%s\n' '"fresh-test-token"' >"$AZ_FIXTURES/token.json"
printf '%s\n' '"line one\nline two"' >"$AZ_FIXTURES/QUOTED-KEY.json"
if sh "$hook" >"$tmp_dir/multiline-output" 2>"$tmp_dir/multiline-trace"; then
  printf 'Hook accepted a value OMP cannot read losslessly.\n' >&2
  exit 1
fi
cmp "$tmp_dir/expected" "$PI_CODING_AGENT_DIR/.env"

printf 'OMP secrets imported, quoted, preserved, private, idempotent, and failure-guarded.\n'
