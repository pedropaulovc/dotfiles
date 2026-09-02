#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

fake_bin="$tmp_dir/bin"
agent_dir="$tmp_dir/omp-agent"
az_log="$tmp_dir/az-calls"
mkdir -p "$fake_bin" "$agent_dir"
: >"$az_log"

cat >"$fake_bin/az" <<'EOF'
#!/bin/sh
set -eu

printf '%s\n' "$*" >>"$AZ_LOG"
if [ "${AZ_FAIL-0}" = 1 ]; then
  exit 42
fi
printf '%s' "${AZ_TOKEN-}"
EOF
chmod +x "$fake_bin/az"

render_hook() {
  source_dir=$1
  output_path=$2
  platform=${3:-linux}
  chezmoi execute-template \
    --source "$source_dir" \
    --file run_onchange_after_hindsight-api-key.sh.tmpl \
    --override-data "{\"platform\":\"$platform\"}" \
    --output "$output_path"
}

hook="$tmp_dir/hindsight-api-key-hook.sh"
render_hook "$repo_dir" "$hook" linux
sh -n "$hook"

wsl_hook="$tmp_dir/hindsight-api-key-wsl-hook.sh"
render_hook "$repo_dir" "$wsl_hook" wsl
if [ "$(awk 'NR == 1 { print; exit }' "$wsl_hook")" != '#!/bin/sh' ]; then
  printf 'WSL did not render the POSIX Hindsight hook.\n' >&2
  exit 1
fi

windows_hook="$tmp_dir/hindsight-api-key-windows-hook.ps1"
render_hook "$repo_dir" "$windows_hook" windows
if ! awk 'length($0) > 0 { found = 1 } END { exit found }' "$windows_hook"; then
  printf 'Windows rendered a non-empty POSIX Hindsight hook.\n' >&2
  exit 1
fi

cat >"$agent_dir/.env" <<'EOF'
OTHER_SETTING=keep
HINDSIGHT_API_TOKEN=stale-token
export HINDSIGHT_API_TOKEN=older-token
EOF

PATH="$fake_bin:$PATH" \
AZ_LOG="$az_log" \
AZ_TOKEN='fresh-test-token' \
PI_CODING_AGENT_DIR="$agent_dir" \
sh "$hook" >"$tmp_dir/first-output"

line_summary=$(awk -F= '
  $1 == "HINDSIGHT_API_TOKEN" { token_count++; token_ok = ($2 == "fresh-test-token") }
  $1 == "OTHER_SETTING" && $2 == "keep" { other_ok = 1 }
  END { print token_count ":" (token_ok + 0) ":" (other_ok + 0) }
' "$agent_dir/.env")
if [ "$line_summary" != '1:1:1' ]; then
  printf 'Unexpected dotenv contents summary: %s\n' "$line_summary" >&2
  exit 1
fi

if [ "$(stat -c '%a' "$agent_dir/.env")" != 600 ]; then
  printf 'Hindsight dotenv permissions are not 600.\n' >&2
  exit 1
fi

first_hash=$(sha256sum "$agent_dir/.env" | awk '{print $1}')
PATH="$fake_bin:$PATH" \
AZ_LOG="$az_log" \
AZ_TOKEN='fresh-test-token' \
PI_CODING_AGENT_DIR="$agent_dir" \
sh "$hook" >"$tmp_dir/second-output"
second_hash=$(sha256sum "$agent_dir/.env" | awk '{print $1}')
if [ "$first_hash" != "$second_hash" ]; then
  printf 'Repeated hook execution changed identical dotenv content.\n' >&2
  exit 1
fi

if PATH="$fake_bin:$PATH" \
  AZ_LOG="$az_log" \
  AZ_TOKEN= \
  PI_CODING_AGENT_DIR="$agent_dir" \
  sh "$hook" >"$tmp_dir/failure-output" 2>"$tmp_dir/failure-error"; then
  printf 'Hook succeeded with an empty Azure token.\n' >&2
  exit 1
fi
third_hash=$(sha256sum "$agent_dir/.env" | awk '{print $1}')
if [ "$second_hash" != "$third_hash" ]; then
  printf 'Failed token refresh changed the existing dotenv file.\n' >&2
  exit 1
fi
if PATH="$fake_bin:$PATH" \
  AZ_LOG="$az_log" \
  AZ_FAIL=1 \
  AZ_TOKEN='fresh-test-token' \
  PI_CODING_AGENT_DIR="$agent_dir" \
  sh "$hook" >"$tmp_dir/command-failure-output" 2>"$tmp_dir/command-failure-error"; then
  printf 'Hook succeeded when Azure CLI failed.\n' >&2
  exit 1
fi
fourth_hash=$(sha256sum "$agent_dir/.env" | awk '{print $1}')
if [ "$second_hash" != "$fourth_hash" ]; then
  printf 'Azure CLI failure changed the existing dotenv file.\n' >&2
  exit 1
fi


expected_az_call='webapp config appsettings list --resource-group rg-hindsight-wu2 --name app-hindsight-wu2 --query [?name=='"'"'HINDSIGHT_API_TENANT_API_KEY'"'"'].value | [0] --output tsv'
call_summary=$(awk -v expected="$expected_az_call" '$0 != expected { unexpected = 1 } END { print NR ":" (unexpected + 0) }' "$az_log")
if [ "$call_summary" != '4:0' ]; then
  printf 'Unexpected Azure invocation summary: %s\n' "$call_summary" >&2
  exit 1
fi

fixture_source="$tmp_dir/source"
mkdir -p "$fixture_source/private_dot_omp/private_agent"
cp "$repo_dir/run_onchange_after_hindsight-api-key.sh.tmpl" "$fixture_source/"
cp "$repo_dir/private_dot_omp/private_agent/private_config.yml" \
  "$fixture_source/private_dot_omp/private_agent/private_config.yml"

baseline_render="$tmp_dir/baseline-hook.sh"
unrelated_render="$tmp_dir/unrelated-hook.sh"
hindsight_render="$tmp_dir/hindsight-hook.sh"
render_hook "$fixture_source" "$baseline_render"

awk '
  $0 == "symbolPreset: unicode" { print "symbolPreset: ascii"; next }
  { print }
' "$fixture_source/private_dot_omp/private_agent/private_config.yml" \
  >"$tmp_dir/unrelated-config.yml"
mv "$tmp_dir/unrelated-config.yml" \
  "$fixture_source/private_dot_omp/private_agent/private_config.yml"
render_hook "$fixture_source" "$unrelated_render"

awk '
  $0 ~ /^  apiUrl:/ { print "  apiUrl: https://changed.example"; next }
  { print }
' "$fixture_source/private_dot_omp/private_agent/private_config.yml" \
  >"$tmp_dir/hindsight-config.yml"
mv "$tmp_dir/hindsight-config.yml" \
  "$fixture_source/private_dot_omp/private_agent/private_config.yml"
render_hook "$fixture_source" "$hindsight_render"

baseline_checksum=$(awk '/^# checksum:/{ print $3; exit }' "$baseline_render")
unrelated_checksum=$(awk '/^# checksum:/{ print $3; exit }' "$unrelated_render")
hindsight_checksum=$(awk '/^# checksum:/{ print $3; exit }' "$hindsight_render")
if [ -z "$baseline_checksum" ] || [ "$baseline_checksum" != "$unrelated_checksum" ]; then
  printf 'Unrelated config changes altered the Hindsight hook checksum.\n' >&2
  exit 1
fi
if [ "$baseline_checksum" = "$hindsight_checksum" ]; then
  printf 'Hindsight config changes did not alter the hook checksum.\n' >&2
  exit 1
fi

printf 'Hindsight hook fetched, preserved, secured, and section-triggered correctly.\n'
