# dotfiles

Cross-platform dotfiles managed with [chezmoi](https://chezmoi.io) — one repo,
rendered per-target for **Linux + Windows** and **bash + PowerShell**.

Three axes of variation are handled by templating rather than by forking files:

| axis    | values                          | mechanism                                  |
| ------- | ------------------------------- | ------------------------------------------ |
| OS      | Linux / Windows                 | `{{ if eq .chezmoi.os "windows" }}`        |
| shell   | bash / pwsh                     | separate `dot_bashrc` / `profile.ps1`      |
| machine | amet / workstation / WSL        | `.role` (set in `.chezmoi.toml.tmpl`)      |

## Environment variables: one source of truth

Env vars are defined **once** as neutral data in `.chezmoidata/env.yaml`, and
each shell's template renders the correct syntax — `export FOO=bar` for bash,
`$env:FOO = 'bar'` for PowerShell. Edit the YAML once; both shells stay in sync.

OS-specific values (paths, etc.) stay behind an `{{ if eq .chezmoi.os ... }}`
branch inside the relevant shell template.

## Layout

```
.chezmoidata/env.yaml            # env vars, neutral — single source of truth
.chezmoi.toml.tmpl               # machine config: hostname -> .role
.chezmoiignore                   # keep README/LICENSE out of $HOME
dot_bashrc.tmpl                  # -> ~/.bashrc
dot_claude/CLAUDE.md             # -> ~/.claude/CLAUDE.md  (plain, no template)
Documents/PowerShell/profile.ps1.tmpl   # -> $PROFILE on Windows
```

## Bootstrap

Single command per machine — this is what makes "nuke and rebuild" trivial.

```bash
# Linux / WSL
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply git@github.com:pedropaulovc/dotfiles.git
```

```powershell
# Windows PowerShell
iex "&{$(irm get.chezmoi.io)} init --apply git@github.com:pedropaulovc/dotfiles.git"
```

### WSL note

The WSL Linux home (`/home/pedro`) and the Windows home (`C:\Users\Pedro`) are
separate. Run chezmoi **twice** against this same repo — once inside WSL, once
in Windows PowerShell. The `.chezmoi.os` branches keep each render correct.
Don't try to write across the `/mnt/c` boundary from one invocation — it's slow
and fights the tool.

## Day-to-day

```bash
chezmoi edit ~/.bashrc     # edit the source template
chezmoi diff               # preview pending changes
chezmoi apply              # render + install (idempotent)
chezmoi apply --dry-run -v # see what apply would do, without doing it
chezmoi update             # git pull + apply in one step
```

## Secrets

Never commit secrets. Values you don't want in git route through chezmoi's
[template functions](https://chezmoi.io/user-guide/password-managers/) to a
password manager, or through [age encryption](https://chezmoi.io/user-guide/encryption/age/).
Keep `.chezmoidata/env.yaml` for benign values only.
