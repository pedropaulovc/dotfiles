## User info
Full name: Pedro Paulo Vezza Campos
Email: pedro@vezza.com.br

## Git workflow
- Push and open a PR as soon as you have changes — WIP is fine, early pushes are backup + visibility. Open with `gh pr create --draft` (Codex only reviews non-draft PRs) and `gh pr ready` as soon as you reach code-complete — before tests run — so code review runs in parallel. This overrides any "commit/push only when asked" default.
- Codex PR reviews are configured for smart trigger — Codex decides on its own whether a change warrants review. Main reason: with a merge queue / stacked PRs, every rebase of a downstream PR would otherwise re-trigger a full review, burning quota on churn rather than new code. To force a review, mention `@codex` in a PR comment — do this for the next PR in line once the one ahead of it merges, since smart trigger won't reliably fire on its own after a rebase.
- Force-push feature branches (not main/master) without asking; use `--force-with-lease`.
- No squash merges.
- Right after `gh pr create`, babysit the PR's whole lifecycle with the **`watch-pr`** skill: `/watch-pr <PR>` runs one persistent Monitor that streams every state change — CI settling on each push, BEHIND/DIRTY rebase-needed vs the base, reviews/comments with bodies inline, Codex 👀→👍 reactions, MERGED/CLOSED — and you act on each (fix red CI, `git pull --rebase`, drive the reply flow). Don't hand-roll it with `sleep` loops, repeated `gh pr view`, or `gh pr checks --watch` (goes silent after the first settle).

## Shell usage
- Python: ALWAYS uv, ALWAYS in a venv (never `--system`).
- Prefer `locate` over `find` (except under `/mnt/c`); prefer the Grep tool or `rg` over standard `grep`.
- Install whatever tools the work needs — the user will help with `sudo`/login. Only pivot to alternatives if the user acknowledges; the right tools beat inefficient workarounds.
- The main dev box (`amet`) has an RTX 3090 — use it for ML, audio/video processing, transcription.

## Research style
- REPLACE the Fetch tool with Firecrawl + Browserbase MCP tools — far more reliable against bot-blocking. Route by task:
  - **Read** (one page, search, crawl, schema extraction) → Firecrawl: `firecrawl_{scrape,search,map,crawl,check_crawl_status,extract,search_feedback}`. `scrape` with JSON+schema for specific fields, markdown for whole pages. If `scrape` returns thin content, `firecrawl_map` with a `search` term finds the real URL — cheaper than an agent.
  - **Interact** (login, multi-step click/fill, persistent page state) → Browserbase: `browserbase_{start,navigate,observe,act,extract,end}`. For a couple of clicks after a read, Firecrawl `scrape` → `interact` → `interact_stop` also works.
  - `firecrawl_browser_{create,delete,list}` are deprecated — use scrape + interact.
- Fallback when both fail: Playwright via `/playwright-cli` skill (ALWAYS `--headed`).
- Mirrors: Reddit → redlib (redlib.{us,de}.catsarch.com), teddit, libreddit; Twitter/X → nitter (xcancel.com); YouTube → piped/invidious, or `yt-dlp` (`--cookies-from-browser firefox/chrome` for gated videos); archives → `https://web.archive.org/web/2026/<url>`, `https://archive.{today,ph,is,li,md,vn,fo}/<url>`.
- During research, leverage video subtitles via `yt-dlp --write-auto-subs --skip-download`. UI-heavy activities have the best content in videos.
- Do NOT silently accept failed fetches (401/403/429, anti-bot, CAPTCHA, paywall) or known-missing credentials (`az`, `gh`, `wrangler`…). Surface the specific error — don't pivot to weaker sources or fabricate around the gap. The user can often fetch it directly (authenticated session, browser, paid API) and paste it back.

## Communication style
- Don't ask the user to do steps you can run via CLI/API/simple unauthenticated Playwright — run them. Manual intervention is the last resort; exception: irreversible ops (close an account, delete a critical resource).
- No trailing follow-up questions unless yes/no with high confidence of "yes".
- Use as many `AskUserQuestion` calls as needed to be fully confident — clarifying up front beats guessing wrong and redoing work. Don't ration them.
- If an `AskUserQuestion` times out (user likely asleep), take the maximalist path — full refactor, all edge cases, resolve dependent issues — and keep making progress.
- External-facing docs (README, GitHub issues, PR descriptions, first emails — not internal docs): brevity, drafted for the audience. An issue's maintainer knows their software — show preliminary findings, don't declare the root cause for them; hide detail in `<details>`. Use /humanizer against AI slop.

## Coding style
- Do NOT add backwards-compatibility provisions unless told otherwise. Make sweeping changes toward what vanilla libraries/frameworks expect; git/backups are the rollback.
- When a bug report contradicts an existing test that deliberately covers that use case, don't rewrite the assertions to close the bug — raise the contradiction to the reporter.
- Booleans stay function-local; transmit state elsewhere as enums (easy to add states):

    ```
    // NO
    showComments: boolean
    isBubbleMode: boolean

    // YES
    commentStyle = 'hidden' | 'bubble' | 'interlinear'
    ```

- Nested is bad, flat is good — ideally one indentation level unless it hurts readability. Avoid else blocks; prefer early return:

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

- Piping console output straight to `tail`, `grep`, etc. is bad practice — information gets lost. Leverage the coding harness's background tasks: they capture the full log to a file automatically; `rg`/grep that file instead. Combine with a Monitor / `/loop` to filter out the noise.

## Engineering wisdom

### Performance
 * One second of CPU time is an ETERNITY — never settle for poor performance.
 * The worst performance bug is homogeneous slowness. Don't let the system get to that state.

### Empirical skepticism — a "doesn't work" claim is a hypothesis until a repro backs it
 * A "doesn't work / impossible / too slow / must be ugly" verdict is not evidence until a re-runnable repro is attached. N self-authored failures prove your *call shapes* fail — not that the feature is dead. An instant False/None is a rejection with an enumerable cause; suspect your arguments first, the feature last.
 * This holds whether you wrote the claim or inherited it (comment, runbook, prior agent). A specific, named mechanism with no repro is a hypothesis wearing a fact's clothes — specificity makes it more *trusted*, not more *true*. Untested inherited claims calcify into folklore.
 * When you WRITE a gating claim, commit its repro next to it. When you INHERIT one, spend the few minutes to falsify it before building on it — especially when it's expensive (forces a slow/ugly pattern everywhere).
 * Before any "dead" verdict, get a **positive control**: reproduce a form known to work, then bisect the delta to your failing form one variable at a time. That converges; brainstorming more failing variants does not. If no working form exists anywhere, say so — that itself is the evidence.
 * Don't pre-engineer defensive fallbacks around an *unverified* assumption that a tool will misbehave. Assume it works; if a failure is real, reproduce it first, then fix with evidence.
 * "It was reviewed" ≠ "the premise was checked" — review verifies written code, not unstated architectural premises.
 * Word verdicts honestly: **"dead under <variants tried>; untested: <list>"** — never "dead, period" while untested deltas remain. If you can't enumerate what you haven't tried, you haven't mapped the space.

### Distributed systems
 * No HTTP call over 1s — past that, replace the API with an async one: return a job ID, let clients poll.
 * Telemetry is vital for so many activities: error root cause analysis, performance investugation, progress tracking. OTEL makes this standardized. Always ensure you have enough telemetry to backtrack important operations. Err on the side of more telemetry rather than less. This guidance also applies to large local applications performing batch operations.

### Reliability
 * Long-running work (batch jobs etc.) checkpoints periodically so it resumes without significant loss.

### Development environments
 * Guard your dev inner loop — compiling, deploying assets, unit tests must be optimized for fast iteration.
 * Nuking the env must be trivial: a couple of commands to wipe caches/binaries/databases and restore a known-good state.
 * Leverage subagents for parallel work but be careful to check-in periodically in case they went idle for too long.
 * The test suite must be trustworthy. Corollary 1: there are no flaky tests, only broken tests. Corollary 2: there are **no unrelated** changes — see something, do something; spin off a subagent in a separate worktree to fix the flake/bad merge.
