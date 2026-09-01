#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

fake_bin="$tmp_dir/bin"
call_log="$tmp_dir/npx-calls"
mkdir -p "$fake_bin"
: >"$call_log"

cat >"$fake_bin/git" <<'EOF'
#!/bin/sh
set -eu

if [ "$1" = clone ]; then
  source="$5"
  repo_dir="$6"
  mkdir -p "$repo_dir"
  case "$source" in
    https://github.com/microsoft/playwright-cli.git)
      hash=ef9a12fdadfb2ad4b67d512a10e840979f162c3a
      ;;
    https://github.com/blader/humanizer.git)
      hash=b8a8804ed9210e539531fc26c2d84fdb603960f4
      ;;
    https://github.com/nutlope/hallmark.git)
      hash=747c924c4767b4d5fa6f1c59985c87a21c918334
      ;;
    https://github.com/vectorize-io/hindsight.git)
      hash=38a67f1634dc12aa545d1cd0ac1e0f83c1c828d7
      ;;
    *)
      printf 'Unexpected clone source: %s\n' "$source" >&2
      exit 1
      ;;
  esac
  printf '%s\n' "$hash" >"$repo_dir/.expected_hash"
  exit 0
fi

if [ "$1" = -C ]; then
  repo_dir="$2"
  case "$3" in
    fetch|checkout)
      exit 0
      ;;
    rev-parse)
      cat "$repo_dir/.expected_hash"
      exit 0
      ;;
  esac
fi

printf 'Unexpected git invocation.' >&2
exit 1
EOF
chmod +x "$fake_bin/git"

cat >"$fake_bin/npx" <<'EOF'
#!/bin/sh
set -eu

if [ "$1" != --yes ] || [ "$2" != skills@1.5.23 ] || [ "$3" != add ]; then
  printf 'Unexpected npx invocation.\n' >&2
  exit 1
fi

agents=
while [ "$#" -gt 0 ]; do
  if [ "$1" = --agent ]; then
    if [ "$#" -lt 2 ]; then
      printf 'Missing --agent value.\n' >&2
      exit 1
    fi
    if [ -n "$agents" ]; then
      agents="$agents "
    fi
    agents="$agents$2"
    shift
  fi
  shift
done

# Deliberately differ from the locked list to model host agent detection.
if [ -z "$agents" ]; then
  agents="$DETECTED_AGENTS"
fi
if [ "$agents" != "$LOCKED_AGENTS" ]; then
  printf 'Agent target mismatch: expected %s, got %s.\n' "$LOCKED_AGENTS" "$agents" >&2
  exit 1
fi
printf '%s\n' "$agents" >>"$CALL_LOG"
EOF
chmod +x "$fake_bin/npx"

(
  cd "$repo_dir"
  chezmoi execute-template \
    --file run_onchange_agents-skills.sh.tmpl \
    --override-data '{"platform":"linux"}' \
    --output "$tmp_dir/hook.sh"
)

locked_agents='amp antigravity antigravity-cli cline codex cursor deepagents gemini-cli github-copilot kimi-code-cli opencode warp zed claude-code'
PATH="$fake_bin:$PATH" \
CALL_LOG="$call_log" \
LOCKED_AGENTS="$locked_agents" \
DETECTED_AGENTS='cursor' \
sh "$tmp_dir/hook.sh"

call_count=$(wc -l <"$call_log")
if [ "$call_count" -ne 4 ]; then
  printf 'Expected four skill installs, got %s.\n' "$call_count" >&2
  exit 1
fi

while IFS= read -r agents; do
  if [ "$agents" != "$locked_agents" ]; then
    printf 'Unexpected locked agent list: %s\n' "$agents" >&2
    exit 1
  fi
done <"$call_log"

printf 'Rendered hook preserved locked agent targets across differing detection: %s installs.\n' "$call_count"
