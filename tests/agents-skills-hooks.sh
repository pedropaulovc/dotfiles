#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

fake_bin="$tmp_dir/bin"
call_log="$tmp_dir/npx-calls"
mkdir -p "$fake_bin"
: >"$call_log"
mkdir -p "$tmp_dir/source/dot_agents"
cat >"$tmp_dir/source/dot_agents/dot_skill-lock.json" <<'EOF'
{"skills":{"fixture":{"sourceUrl":"https://github.com/example/skills.git","ref":"1111111111111111111111111111111111111111","skillPath":"skills/fixture/SKILL.md","skillFolderHash":"2222222222222222222222222222222222222222"}},"lastSelectedAgents":["codex","claude-code"]}
EOF
cp "$repo_dir/run_onchange_agents-skills.sh.tmpl" "$tmp_dir/source/"


cat >"$fake_bin/git" <<'EOF'
#!/bin/sh
set -eu

if [ "$1" = clone ]; then
  if [ "$2" != --depth=1 ] || [ "$3" != --filter=blob:none ] ||
    [ "$4" != --no-checkout ] || [ "$5" != -- ]; then
    printf 'Clone was not shallow and blob-filtered.\n' >&2
    exit 1
  fi
  source="$6"
  repo_dir="$7"
  mkdir -p "$repo_dir"

  if [ "$source" != "https://github.com/example/skills.git" ]; then
    printf 'Unexpected clone source: %s\n' "$source" >&2
    exit 1
  fi
  hash=2222222222222222222222222222222222222222
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
  cd "$tmp_dir/source"
  chezmoi --source "$tmp_dir/source" execute-template \
    --file "$tmp_dir/source/run_onchange_agents-skills.sh.tmpl" \
    --override-data '{"platform":"linux"}' \
    --output "$tmp_dir/hook.sh"
)

locked_agents='codex claude-code'
hook_output=$(
  PATH="$fake_bin:$PATH" \
  CALL_LOG="$call_log" \
  LOCKED_AGENTS="$locked_agents" \
  DETECTED_AGENTS='cursor' \
  sh "$tmp_dir/hook.sh" 2>&1
)

case "$hook_output" in
  *'+ git clone --depth=1 --filter=blob:none --no-checkout -- '*)
    ;;
  *)
    printf 'Rendered skill hook did not print the shallow clone command.\n' >&2
    exit 1
    ;;
esac

call_count=$(wc -l <"$call_log")
if [ "$call_count" -ne 1 ]; then
  printf 'Expected one fixture skill install, got %s.\n' "$call_count" >&2
  exit 1
fi

while IFS= read -r agents; do
  if [ "$agents" != "$locked_agents" ]; then
    printf 'Unexpected locked agent list: %s\n' "$agents" >&2
    exit 1
  fi
done <"$call_log"

printf 'Rendered hook preserved locked agent targets across differing detection: %s installs.\n' "$call_count"
