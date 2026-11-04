#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM
mkdir -p "$tmp_dir/source/.chezmoitemplates" "$tmp_dir/bin" "$tmp_dir/home/.local/bin"
cp "$repo_dir/.chezmoitemplates/scrapfly-cli.json" "$tmp_dir/source/.chezmoitemplates/"
cp "$repo_dir/run_onchange_after_scrapfly-cli.sh.tmpl" "$tmp_dir/source/"
printf 'existing executable\n' >"$tmp_dir/original"
cp "$tmp_dir/original" "$tmp_dir/home/.local/bin/scrapfly"
chmod +x "$tmp_dir/home/.local/bin/scrapfly"

cat >"$tmp_dir/bin/curl" <<'EOF'
#!/bin/sh
set -eu
while [ "$#" -gt 0 ]; do
  if [ "$1" = --output ]; then
    printf 'corrupt release archive\n' >"$2"
    exit 0
  fi
  shift
done
exit 1
EOF
chmod +x "$tmp_dir/bin/curl"

(
  cd "$tmp_dir/source"
  chezmoi --source "$tmp_dir/source" execute-template \
    --file "$tmp_dir/source/run_onchange_after_scrapfly-cli.sh.tmpl" \
    --override-data '{"platform":"linux"}' \
    --output "$tmp_dir/hook.sh"
)
if output=$(HOME="$tmp_dir/home" PATH="$tmp_dir/bin:$PATH" sh "$tmp_dir/hook.sh" 2>&1); then
  printf 'Corrupt Scrapfly archive unexpectedly installed.\n' >&2
  exit 1
fi
case "$output" in
  *'Scrapfly CLI archive SHA256 mismatch.'*) ;;
  *)
    printf 'Hook failed without rejecting the corrupt checksum:\n%s\n' "$output" >&2
    exit 1
    ;;
esac
if ! cmp -s "$tmp_dir/original" "$tmp_dir/home/.local/bin/scrapfly" ||
   [ ! -x "$tmp_dir/home/.local/bin/scrapfly" ]; then
  printf 'Checksum failure changed the existing Scrapfly executable.\n' >&2
  exit 1
fi
printf 'Scrapfly checksum failure preserves the existing Linux executable.\n'
