# CLAUDE.md — global instructions

This file is managed by chezmoi and rendered identically on every machine
(Linux `~/.claude/CLAUDE.md`, Windows `%USERPROFILE%\.claude\CLAUDE.md`).

Because it is plain Markdown with no per-target differences, it lives as a
plain managed file (`dot_claude/CLAUDE.md`) — no `.tmpl` extension, no
templating. Edit it directly:

    chezmoi edit ~/.claude/CLAUDE.md
    chezmoi apply

If you later want per-machine sections (e.g. a note that only applies to a
GPU box), rename it to `CLAUDE.md.tmpl` and branch on `.chezmoi.hostname`
or the `.role` variable set in `.chezmoi.toml.tmpl`:

    {{ if eq .role "amet" }}
    ## amet
    This machine has an RTX 3090 — prefer it for ML/transcode work.
    {{ end }}

> Replace this placeholder with your real instructions. Keep secrets out of
> it — this is a public repo.
