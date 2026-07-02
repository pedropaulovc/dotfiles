# dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io). Seeded from a live
WSL/Linux machine, so `chezmoi apply` is a **noop** on the source host — the
source tree is byte-identical to what's installed.

## Managed files

| target                          | source                              |
| ------------------------------- | ----------------------------------- |
| `~/.bashrc`                     | `dot_bashrc`                        |
| `~/.profile`                    | `dot_profile`                       |
| `~/.inputrc`                    | `dot_inputrc`                       |
| `~/.tmux.conf`                  | `dot_tmux.conf`                     |
| `~/.gitconfig`                  | `dot_gitconfig`                     |
| `~/.claude/CLAUDE.md`           | `dot_claude/CLAUDE.md`              |
| `~/.claude/settings.json`       | `dot_claude/settings.json`          |
| `~/.config/nvtop/interface.ini` | `private_dot_config/nvtop/interface.ini` |

All are plain managed files (no templating), which is what guarantees the noop.

## Platform detection (WSL vs Windows vs Linux)

`.chezmoi.toml.tmpl` computes a single `.platform` fact, available to every
template:

| running on     | `.chezmoi.os` | `.platform` |
| -------------- | ------------- | ----------- |
| native Windows | `windows`     | `windows`   |
| WSL            | `linux`       | `wsl`       |
| native Linux   | `linux`       | `linux`     |

WSL is separated from native Linux by looking for `microsoft` in the kernel
`osrelease`. Check it any time with:

```bash
chezmoi execute-template '{{ .platform }}'   # -> wsl on this box
```

Use it in any `.tmpl` file:

```
{{ if eq .platform "windows" }}$env:CACHE = "$env:LOCALAPPDATA\cache"
{{ else if eq .platform "wsl" }}export CACHE="$HOME/.cache"   # WSL-specific
{{ else }}export CACHE="$HOME/.cache"{{ end }}
```

## Secrets

**No secrets live in this repo.** Machine-local secrets (API keys, connection
strings) are sourced by `~/.bashrc` from an untracked file:

```bash
# ~/.bashrc
[ -f "$HOME/.config/shell/secrets.sh" ] && . "$HOME/.config/shell/secrets.sh"
```

`~/.config/shell/secrets.sh` is `chmod 600` and never added to chezmoi. On a
fresh machine it won't exist; the guard makes that a harmless no-op until you
recreate it. To make secrets reproducible across machines, upgrade to chezmoi's
[age encryption](https://chezmoi.io/user-guide/encryption/age/) and commit the
encrypted blob instead.

## Bootstrap

```bash
# Linux / WSL
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply pedropaulovc/dotfiles
```

```powershell
# Windows PowerShell (separate home; run separately from WSL)
iex "&{$(irm get.chezmoi.io)} init --apply pedropaulovc/dotfiles"
```

### Adding Windows / PowerShell config

There's no Windows config in here yet — this was seeded from WSL. When you run
chezmoi on a Windows box, add its real files the same way they were added here,
and `.platform` will report `windows`:

```powershell
chezmoi add $PROFILE
```

## Day-to-day

```bash
chezmoi edit ~/.bashrc      # edit the source
chezmoi diff                # preview pending changes (empty == in sync)
chezmoi apply               # install (idempotent)
chezmoi add ~/.somefile     # start managing a new file
chezmoi update              # git pull + apply
chezmoi re-add              # pull local edits back into the source
```
