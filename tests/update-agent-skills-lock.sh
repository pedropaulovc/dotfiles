#!/bin/sh
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

source_dir="$tmp_dir/source"
lock_file="$tmp_dir/lock.json"
git init -q "$source_dir"
git -C "$source_dir" config user.name 'Skill updater test'
git -C "$source_dir" config user.email 'skill-updater-test@example.invalid'
mkdir -p "$source_dir/skills/demo"
printf '%s\n' 'initial nested skill' >"$source_dir/skills/demo/SKILL.md"
printf '%s\n' 'initial root skill' >"$source_dir/SKILL.md"
git -C "$source_dir" add --all
git -C "$source_dir" commit -qm 'initial skill sources'
old_ref=$(git -C "$source_dir" rev-parse HEAD)
old_nested_hash=$(git -C "$source_dir" rev-parse --verify "$old_ref:skills/demo")
old_root_hash=$(git -C "$source_dir" rev-parse --verify "$old_ref^{tree}")
printf '%s\n' 'updated nested skill' >"$source_dir/skills/demo/SKILL.md"
printf '%s\n' 'updated root skill' >"$source_dir/SKILL.md"
git -C "$source_dir" add --all
git -C "$source_dir" commit -qm 'update skill sources'
new_ref=$(git -C "$source_dir" rev-parse HEAD)
new_nested_hash=$(git -C "$source_dir" rev-parse --verify "$new_ref:skills/demo")
new_root_hash=$(git -C "$source_dir" rev-parse --verify "$new_ref^{tree}")

cat >"$lock_file" <<EOF
{
  "version": 3,
  "skills": {
    "demo": {
      "source": "local/demo",
      "sourceType": "github",
      "sourceUrl": "$source_dir",
      "ref": "$old_ref",
      "skillPath": "skills/demo/SKILL.md",
      "skillFolderHash": "$old_nested_hash",
      "installedAt": "2026-01-01T00:00:00.000Z",
      "updatedAt": "2026-01-01T00:00:00.000Z"
    },
    "root-demo": {
      "source": "local/root-demo",
      "sourceType": "github",
      "sourceUrl": "$source_dir",
      "ref": "$old_ref",
      "skillPath": "SKILL.md",
      "skillFolderHash": "$old_root_hash",
      "installedAt": "2026-01-01T00:00:00.000Z",
      "updatedAt": "2026-01-01T00:00:00.000Z"
    }
  },
  "lastSelectedAgents": ["codex"]
}
EOF

now='2026-09-02T03:17:00.000Z'
node "$repo_dir/.github/scripts/update-agent-skills-lock.mjs" \
  --lock-file "$lock_file" \
  --now "$now"
node - "$lock_file" "$new_ref" "$new_nested_hash" "$new_root_hash" "$now" <<'NODE'
const fs = require("node:fs");

const [, , lockFile, newRef, newNestedHash, newRootHash, now] = process.argv;
const lock = JSON.parse(fs.readFileSync(lockFile, "utf8"));
const nested = lock.skills.demo;
const root = lock.skills["root-demo"];
if (nested.ref !== newRef || nested.skillFolderHash !== newNestedHash) {
  throw new Error("nested skill metadata was not updated");
}
if (root.ref !== newRef || root.skillFolderHash !== newRootHash) {
  throw new Error("root skill metadata was not updated");
}
if (nested.updatedAt !== now || root.updatedAt !== now) {
  throw new Error("updatedAt was not refreshed");
}
if (lock.lastSelectedAgents.join(",") !== "codex") {
  throw new Error("unrelated lock metadata changed");
}
NODE

cp "$lock_file" "$tmp_dir/current-lock.json"
node "$repo_dir/.github/scripts/update-agent-skills-lock.mjs" \
  --lock-file "$lock_file" \
  --now '2026-09-03T03:17:00.000Z' >/dev/null
cmp -s "$lock_file" "$tmp_dir/current-lock.json"

rm "$source_dir/SKILL.md"
git -C "$source_dir" add --all
git -C "$source_dir" commit -qm 'remove root skill source'
cp "$lock_file" "$tmp_dir/failed-lock.json"
if node "$repo_dir/.github/scripts/update-agent-skills-lock.mjs" --lock-file "$lock_file"; then
  printf '%s\n' 'Updater unexpectedly accepted a missing skill.' >&2
  exit 1
fi
cmp -s "$lock_file" "$tmp_dir/failed-lock.json"

printf '%s\n' 'Updater refreshed nested and root skill locks, preserved no-op behavior, and failed atomically.'
