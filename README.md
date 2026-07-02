# dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io), seeded from live
**WSL** and **Windows** homes. `chezmoi apply` is a verified **noop** on both —
the source tree renders byte-identical to what's already installed on each OS.

## Managed files

| target                          | source                                   | applies on   |
| ------------------------------- | ---------------------------------------- | ------------ |
| `~/.bashrc`                     | `dot_bashrc`                             | WSL/Linux    |
| `~/.profile`                    | `dot_profile`                           | WSL/Linux    |
| `~/.inputrc`                    | `dot_inputrc`                           | WSL/Linux    |
| `~/.tmux.conf`                  | `dot_tmux.conf`                         | WSL/Linux    |
| `~/.config/nvtop/interface.ini` | `private_dot_config/nvtop/interface.ini` | WSL/Linux    |
| `$PROFILE` (PowerShell 7)       | `OneDrive/Documentos/PowerShell/Microsoft.PowerShell_profile.ps1` | Windows |
| `~/.gitconfig`                  | `dot_gitconfig.tmpl`                     | both (templated) |
| `~/.claude/CLAUDE.md`           | `dot_claude/CLAUDE.md`                   | both         |
| `~/.claude/settings.json`       | `dot_claude/settings.json`               | both         |

Each OS ignores the other's files via a platform-branched `.chezmoiignore`, so
`apply` never creates a Linux dotfile on Windows or vice-versa. `.gitconfig` is
the one file whose content legitimately differs per OS (credential-helper path,
`autocrlf`, `hooksPath`), so it's a template that emits each platform's exact
bytes. `CLAUDE.md` and `settings.json` are unified — one canonical copy shared
by both homes. `.gitattributes` pins all files to LF so Windows clones stay
byte-identical to the source (chezmoi apply noop survives `core.autocrlf=true`).

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

The WSL Linux home (`/home/pedro`) and the Windows home (`C:\Users\pedro`) are
separate. Run chezmoi once in each; the `.platform` branches keep each render
correct. Note the PowerShell profile path is OneDrive-redirected and
locale-specific (`OneDrive\Documentos\...`) on this machine — on a box without
that redirection, re-add `$PROFILE` so chezmoi learns the right target.

## Day-to-day

```bash
chezmoi edit ~/.bashrc      # edit the source
chezmoi diff                # preview pending changes (empty == in sync)
chezmoi apply               # install (idempotent)
chezmoi add ~/.somefile     # start managing a new file
chezmoi update              # git pull + apply
chezmoi re-add              # pull local edits back into the source
```
