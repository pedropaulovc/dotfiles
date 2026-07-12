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
| `~/.agents/AGENTS.md`           | `dot_agents/AGENTS.md`                   | both         |
| `~/.codex/AGENTS.md`            | `dot_codex/AGENTS.md.tmpl`               | both         |
| `~/.claude/CLAUDE.md`           | `dot_claude/CLAUDE.md.tmpl`              | both         |
| `~/.claude/settings.json`       | `dot_claude/settings.json`               | both         |
| `~/.config/litellm/config.yaml` | `private_dot_config/litellm/config.yaml` | both         |

Each OS ignores the other's files via a platform-branched `.chezmoiignore`, so
`apply` never creates a Linux dotfile on Windows or vice-versa. `.gitconfig` is
the one file whose content legitimately differs per OS (credential-helper path,
`autocrlf`, `hooksPath`), so it's a template that emits each platform's exact
bytes. `settings.json` has one canonical copy shared by both homes. `AGENTS.md`
is the canonical instruction file; chezmoi copies its contents to Codex's
`AGENTS.md` and Claude Code's `CLAUDE.md` targets. `.gitattributes` pins all
files to LF so Windows clones stay byte-identical to the source (chezmoi apply
noop survives `core.autocrlf=true`).

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

On Windows the PowerShell profile sources the same-shaped untracked file at
`~/.config/shell/secrets.ps1` (define `$env:` vars there); it too no-ops when
absent.

### `claudex`

`claudex` runs the Claude Code harness (the UI/tooling) against an alternate
model — **OpenAI, via a local proxy** — while your normal `claude`/`yc` stay on
Anthropic. Claude Code only speaks the Anthropic API, so a
[LiteLLM](https://docs.litellm.ai/) proxy sits in the middle: it exposes an
Anthropic `/v1/messages` endpoint on localhost and translates each request to
OpenAI (and the response back). Two commands, each a bash function (`.bashrc`)
plus a PowerShell twin (aliased the same):

```
claudex-proxy      # start the LiteLLM proxy — leave running in its own terminal/tmux
claudex [args…]    # launch Claude Code pointed at it (args pass through: claudex --continue)
```

`claudex-proxy` runs `litellm` via `uvx` (pinned to Python 3.13 — litellm's Rust
extension caps there) using `~/.config/litellm/config.yaml`, which is
chezmoi-managed and **secret-free** (keys are read from the environment at
runtime). `claudex` pre-flights the proxy and, if it's down, tells you to start
it rather than falling back to Anthropic. Every model/effort override is scoped
to the single invocation.

Only the proxy needs a secret — your **OpenAI key** — from the untracked secrets
file (see above); `claudex-proxy` refuses to start without it:

```bash
# ~/.config/shell/secrets.sh  (POSIX)        # ~/.config/shell/secrets.ps1  (PowerShell)
export OPENAI_API_KEY="sk-…"                  $env:OPENAI_API_KEY = "sk-…"
```

`claudex` itself needs nothing by default: it targets `http://127.0.0.1:4000`
with a throwaway token (the proxy is open on localhost). Optional overrides —
`CLAUDEX_MODEL` (default `gpt-5.6-sol`, the name mapped to OpenAI in
`config.yaml`), `CLAUDEX_BASE_URL` / `CLAUDEX_AUTH_TOKEN` (for a remote or
master-keyed proxy), `CLAUDEX_PROXY_PORT`. To lock down the proxy on a shared
box, set `LITELLM_MASTER_KEY` (proxy side) and matching `CLAUDEX_AUTH_TOKEN`
(client side). Point it at a different OpenAI model by editing the `model:`
line in `config.yaml`.

## Bootstrap

```bash
# Linux / WSL
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply pedropaulovc/dotfiles
```

```powershell
# Windows PowerShell (separate home; run separately from WSL).
# The `--` hands the args to chezmoi; without it the installer swallows them.
iex "&{$(irm 'https://get.chezmoi.io/ps1')} -- init --apply pedropaulovc/dotfiles"
```

Prefer to preview before the first write? Drop `--apply`, then
`chezmoi diff` (should be empty), then `chezmoi apply`.

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
