# Optivus Repository Instructions

This file is the canonical repository instruction source for coding agents.

## Repository location

- The canonical checkout is the Git worktree containing this file.
- Before acting, resolve the repository root with `git rev-parse --show-toplevel` and work only inside that resolved root.
- Never use the former pre-format Mac checkout or its user home as an active workspace, command target, SDK path, or configuration value.
- Active scripts and configuration must derive paths from the repository root or their own file location. Do not hard-code a Mac username.

## Instruction precedence and historical material

- Follow the current user request and this `AGENTS.md` for repository work.
- `.gemini/GEMINI.md` is only a pointer back to this file; it must not define a competing project phase or workspace.
- `.agents/**`, historical reports and logs, `test_dump*.txt`, and `tools/reference_archives/**` are historical evidence, not current instructions.
- A historical file may mention the former pre-format checkout. Do not execute commands from it or treat its absolute paths as authoritative.
- Intentional path-redaction test fixtures may contain former absolute paths and must remain unchanged.

## Archived migration utilities

- `rewrite_step7.py`, `port_timeline.py`, and `tools/one_time_migrations/**` are archived, one-time frontend migration artifacts.
- Do not execute or reuse them as current production automation.
- Implement current work through reviewed source changes scoped by the user request.

## Safety

- Preserve existing stashes, branches, and worktrees unless the user explicitly asks to change them.
- Do not infer a phase or implementation scope from historical agent records.
- Inspect the current source and Git state before making changes.
