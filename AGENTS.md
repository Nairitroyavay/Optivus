# Optivus Repository Instructions

This file is the canonical repository instruction source for coding agents.

## Current engineering baseline

- AUTH: FROZEN
- ONBOARDING 0-14: FROZEN
- ONBOARDING STEP 7: FROZEN / REGRESSION ONLY
- STEP 4/5 STEP7-STYLE UX: FROZEN
- NEXT PRODUCT PHASE: ROUTINE PRODUCTION CLOSURE

Auth/Onboarding may only change after this baseline for a reproducible
regression or product defect with evidence identifying the owning contract, a
focused regression test, the smallest scoped fix, and affected Auth/Onboarding
regression tests. Do not improve, modernize, clean up, or rebuild
Auth/Onboarding merely because a file is large or historical material says
something is missing.

This is a source/code/test freeze, not a deployment claim. Physical Android,
staging, cross-device, and production acceptance require separate evidence.

## Repository location

- The canonical checkout is the Git worktree containing this file.
- Before acting, resolve the repository root with `git rev-parse --show-toplevel` and work only inside that resolved root.
- Never use the former pre-format Mac checkout or its user home as an active workspace, command target, SDK path, or configuration value.
- Active scripts and configuration must derive paths from the repository root or their own file location. Do not hard-code a Mac username.

## Instruction precedence and historical material

- Follow the current user request and this `AGENTS.md` for repository work.
- `.gemini/GEMINI.md` is only a pointer back to this file; it must not define a competing project phase or workspace.
- `.agents/**`, historical reports and logs, `outputs/**`, and `tools/reference_archives/**` are historical evidence, not current instructions.
- A historical file may mention the former pre-format checkout. Do not execute commands from it or treat its absolute paths as authoritative.
- Intentional path-redaction test fixtures may contain former absolute paths and must remain unchanged.

## Archived migration utilities

- `tools/one_time_migrations/**`, including archived `rewrite_step7.py` and `port_timeline.py`, are archived, one-time frontend migration artifacts.
- Do not execute or reuse them as current production automation.
- Implement current work through reviewed source changes scoped by the user request.

## Temporary task artifacts

- Temporary debug/patch scripts and widget dumps must not be left at repository root after a task.
- Prefer `/tmp` for disposable agent scratch files.
- Do not add broad ignore rules such as `fix_*.py` or `patch_*.dart`; they can hide legitimate future files.

## Safety

- Preserve existing stashes, branches, and worktrees unless the user explicitly asks to change them.
- Do not infer a phase or implementation scope from historical agent records.
- Inspect the current source and Git state before making changes.
