---
name: merge-needs-explicit-approval
description: Don't merge PRs autonomously — a clean Codex review is not authorization; wait for Pedro's explicit go-ahead.
metadata:
  type: feedback
---

Pedro rejected an autonomous `gh pr merge` on dotfiles PR #9 (2026-07-12) even though Codex had reviewed it clean (👍), then added review comments, and only later said "merge when codex happy" — an explicit, scoped authorization.

**Why:** A clean automated review doesn't mean Pedro is done reviewing; he may still be reading the diff or adding comments. Merging closes his review window.

**How to apply:** After a PR goes green/clean, report the verdict and wait. Merge only on an explicit instruction ("merge", "merge when codex happy"). Such an instruction can be conditional and forward-looking — then merging when the condition triggers is fine.
