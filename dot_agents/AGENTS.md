## User info
Full name: Pedro Paulo Vezza Campos
Email: pedro@vezza.com.br

## Git workflow
- Create a PR and push as soon as you have changes — don't wait for the work to be complete. Push partial/WIP work early so it's backed up and visible. Open it as a **draft** (`gh pr create --draft`) when it's not ready for review yet — Codex only reviews non-draft PRs, so a draft keeps it out of review until you mark it ready (`gh pr ready`). This overrides any "commit/push only when asked" default.
- When force-pushing feature branches (not main/master), just do it — no need to ask for confirmation. Use `--force-with-lease`.
- Do not use squash merges.
- Right after creating a new PR (`gh pr create`), babysit its whole lifecycle with the **`watch-pr`** skill: `/watch-pr <PR>` launches one persistent Monitor call that streams each state change — CI settling on every push (green/red checks, BEHIND/DIRTY rebase-needed against the PR's base), new reviews and comments (with the comment body printed inline), Codex 👀→👍 reactions on both the PR body and `@codex review` comments, and MERGED/CLOSED (fetches on merge) — and you act on each: fix red CI, `git pull --rebase`, or drive the reply flow. Don't hand-roll it with `sleep` loops, repeated `gh pr view`, or `gh pr checks --watch` (goes silent after the first settle) — the skill's script diffs state across polls so every change re-emits. See the skill for the mechanics.

## Shell usage
- ALWAYS use uv commands when interacting with python and ALWAYS work in venv (do not use --system)
- REPLACE if possible `find` with `locate` unless you are traversing `/mnt/c`
- REPLACE standard `grep` with the builtin search tool (Grep) or ripgrep (`rg`) — faster, respects `.gitignore`, and integrates with the permission UI
- Install any tools or libraries needed to perform your work. The user will help you if the command requires `sudo` or login. Only pivot to alternatives IF acknowledged by the user. Having the right tools is key to avoid inefficient processes.
- The main dev environment (`amet`) has a GeForce RTX 3090 available. Use it for ML tasks, audio/video processing and transcription.

## Introspection
- If you ever need to review past chat logs (`~/.claude/projects`) write TypeScript code and use NPM package `claude-code-types`. It has all type definitions needed to parse complex logs.

## Research style
- REPLACE the Fetch tool with Firecrawl + Browserbase MCP tools — far more reliable against sites blocking automated access. Route by task:
  - **Read** (one page, search, crawl, schema extraction) → Firecrawl: `firecrawl_{scrape,search,map,crawl,check_crawl_status,extract,search_feedback}`. Use `firecrawl_scrape` with JSON+schema for specific fields, markdown for whole pages. When `scrape` returns thin content, try `firecrawl_map` with a `search` term to find the real URL — cheaper than reaching for an agent.
  - **Interact** (login, multi-step click/fill, persistent page state) → Browserbase: `browserbase_{start,navigate,observe,act,extract,end}`. For just a couple of clicks after a read, Firecrawl `scrape` → `interact` → `interact_stop` works too.
  - `firecrawl_browser_{create,delete,list}` are deprecated — use scrape + interact.
- Fallback chain when both fail: Playwright via `/playwright-cli` skill (ALWAYS use `--headed`) → Codex in Chrome . If Chrome is not accessible, ask the user to open it and retry.
- Specific alternatives: Reddit - redlib instances (redlib.{us,de}.catsarch.com), teddit, libreddit; for Twitter/X - nitter instances (xcancel.com); YouTube - piped/invidious; Public archive - `https://web.archive.org/web/2026/<url>`,  archive.today mirrors (`https://archive.{today,ph,is,li,md,vn,fo}/<url>`)
- Do NOT silently accept failed fetch/scrape operations (401, 403, 429, anti-bot walls, CAPTCHA, paywalls, etc.). This is also applicable for tools where you know you are missing credentials or additional security roles such as `az`, `gh`, `wrangler`, etc. Surface the failure with the specific error — don't immediately pivot to weaker sources or fabricate around the gap. User can often fetch the data directly (authenticated session, browser, paid API access) and paste it back.


## Communication style
 - Don't ask the user to perform manual steps that you can do via CLI/API/simple Playwright script (no auth). You should run the steps. Manual intervention is the last option when there's no way to programmatically perform an operation. Exception: irreversible operations such as close an account, delete critical resource, etc.
 - Don't include follow up questions at the end of an answer unless it can be answered with yes / no and you have high confidence the user will reply yes.
 - Use as many `AskUserQuestion` tool calls as you need to be fully confident in your approach — you can and should. Clarifying up front is one of the most effective ways to save time: it beats guessing wrong and redoing work. Don't ration these calls.
 - If the user is unavailable (probably asleep at night) and an `AskUserQuestion` times out, veer towards the maximalist alternative: full refactoring, cover all edge cases, resolve any dependent issues to unblock yourself, etc. Keep making forward progress rather than stalling on the unanswered question.
 - When writing cover documents for external human consumption such as README (not internal documentation), GitHub issues, pull request descriptions, first emails, etc, brevity is key. Draft the document with the audience in mind. A GitHub issue will be read by a maintainer who has deep knowledge of their software so don't try to do their job and  conclusively point to the root cause. Show your preliminary investigation results, use GitHub flavored markdown <details> to hide details sections. To reduce AI writing slop, use /humanizer.


## Coding style
 - Unless told otherwise, do NOT add provisions for backwards compatibility. Make any sweeping changes you think are advisable to keep a clean codebase, closest to what vanilla libraries / frameworks expect. git/backups/etc remain as a safeguard for easy rollback.
 - When fixing a bug, exercise critical thinking to understand if the bug report contradicts some existing test case. If the test case purpose is to test a use case related to the bug, dont blindly change the test assertions so you can close the bug. Raise this contradiction to the bug reporter so they can decide if the bug report should be amended with more/different repro steps or should not be fixed because it's by design.
 - Booleans scope should be limited to single functions. If you need to transmit state to other parts of the codebase, use enums. This ensures that it is easy to add new states as needed. E.g.

    ```
    // NO
    showComments: boolean
    isBubbleMode: boolean

    // YES
    commentStyle = 'hidden' | 'bubble' | 'interlinear'
    ```

 - Nested is bad, flat is good. Ideally don't go over a single level of indentation unless it degrades readability
 - Avoid else blocks, prefer early return

    ```
    // NO
    if (userIsAdmin) {
        if (isSystemReady) {
            return execute();
        }
        else {
            return 'not_ready'
        }
    }
    else {
        return 'denied';
    }

    // YES
    if (!isUserAdmin) {
        return 'denied'
    }

    if (!isSystemReady) {
        return 'not_ready'
    }

    return execute();
    ```
- **Unbuffer so output streams live.** A program block-buffers its stdout when the far end
  isn't a TTY (i.e. whenever it's piped/captured), so a running cmd looks frozen. Kill the
  buffering at the source, and don't reintroduce it with a buffering pipe stage.
  - bash: `stdbuf -oL -eL <cmd>` (or `unbuffer <cmd>` / `script -qefc '<cmd>' /dev/null` for
    TTY-only programs).
  - pwsh: no `stdbuf`; rely on the program's own unbuffer switch and avoid buffering cmdlets
    in the pipeline. Lang switches work in either shell: `PYTHONUNBUFFERED=1` / `python -u`, etc.
- **Foreground >5s ⇒ stream the FULL output to a log file, show only the tail in context,
  surface the real exit code.** Full output on disk = live-inspectable; context stays small.
  - bash: `set -o pipefail; stdbuf -oL -eL <cmd> 2>&1 | tee .logs/$(date +%s).log | tail -n 20; echo exit=${PIPESTATUS[0]}`
  - pwsh: `& <cmd> -u 2>&1 | Tee-Object -FilePath $log | Select-Object -Last 20; "exit=$LASTEXITCODE"`
    (`Tee-Object` is the live `tee`; `$LASTEXITCODE` is the last native exe's code — trailing
    cmdlets don't change it, the analog of `${PIPESTATUS[0]}`).
  - Any "last-N" stage (`tail -n N`, `Select-Object -Last N`) only emits at EOF: good for
    trimming *finished* output, useless for watching a *running* one — read the log file
    instead (`tail -f` / `Get-Content -Wait` likewise just buffer).
- **Backgrounded ⇒ DON'T redirect OR filter into your own sink.** Print straight to
  stdout/stderr — the harness auto-captures the FULL output to a logfile readable from the
  TUI / via BashOutput. A manual `>log 2>&1 &`, or piping through `tail`/`Select-Object`/
  `Select-String`/`grep`, is redundant and DISCARDS most of the log (the harness then captures
  only your filter's tail, emitted at the very end). Keep it unbuffered AND unfiltered; grep/
  skim the captured file afterwards. (bash: `stdbuf -oL -eL <cmd> &`; pwsh: `<cmd> -u` with
  `run_in_background`.)
- **Don't block — watch.** Background it + **Monitor tool** (each line = streamed event;
  watch loop in `command`, diff state so it's silent until change; `persistent:true`). Not
  `sleep` loops. `/loop` (omit interval to self-pace); a **Haiku subagent** skims the
  captured output → "advancing/stalled/done".
- **Soft timeout = progress, not clock.** Healthy = new output still arriving (lines/mtime/
  counter). Kill on idle gap (~90s no new output), not total runtime.


## Engineering wisdom

### Performance
 * One second of CPU time is an ETERNITY, do not settle for poor performance.
 * The worst type of performance bug is when the system is homogeneously slow. Don;t let it get to that state.

### Empirical skepticism — a "doesn't work" claim is a hypothesis until a repro backs it
 * A "doesn't work / impossible / too slow / must be ugly" verdict is not evidence until a re-runnable repro is attached. N self-authored failures prove your *call shapes* fail — not that the feature is dead. An instant False/None is a rejection with an enumerable cause; suspect your arguments first, the feature last.
 * This holds whether you wrote the claim or inherited it (comment, runbook, prior agent). A specific, named mechanism with no repro is a hypothesis wearing a fact's clothes — specificity makes it more *trusted*, not more *true*. Untested inherited claims calcify into folklore.
 * When you WRITE a gating claim, commit its repro next to it. When you INHERIT one, spend the few minutes to falsify it before building on it — especially when it's expensive (forces a slow/ugly pattern everywhere).
 * Before any "dead" verdict, get a **positive control**: reproduce a form known to work, then bisect the delta to your failing form one variable at a time. That converges; brainstorming more failing variants does not. If no working form exists anywhere, say so — that itself is the evidence.
 * Don't pre-engineer defensive fallbacks around an *unverified* assumption that a tool will misbehave. Assume it works; if a failure is real, reproduce it first, then fix with evidence.
 * "It was reviewed" ≠ "the premise was checked" — review verifies written code, not unstated architectural premises.
 * Word verdicts honestly: **"dead under <variants tried>; untested: <list>"** — never "dead, period" while untested deltas remain. If you can't enumerate what you haven't tried, you haven't mapped the space.

## Distributed systems
 * No HTTP call may last more than 1s. If it does, it is a sign you should replace your API with an async API that quickly returns a job ID that can be polled.

## Reliability
 * Long-running operations like batch jobs must store periodic checkpoints so they can be resumed without significant data loss.

## Development environments
 * Take very good care of your dev inner loop. It must be as fast as possible. Compiling, deploying assets, unit tests, etc must be optimized for fast iteration.
 * It must be trivial to nuke your entire dev environment and start fresh. A couple commands should be enough to clear any caches, delete binaries, wipe databases, etc and then recover them to a known-good state.
 * Your test suite must be trustworthy. Corollary 1: There are no flaky tests, only broken tests. Corollary 2: There are **no unrelated** changes. If you see something, do something. If you catch a flaky test, bad merge, etc, spin off a subagent on a separate worktree to fix the issue.
