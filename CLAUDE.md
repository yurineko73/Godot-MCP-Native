# CLAUDE.md - Godot MCP Repository Guidance

## Scope

- This file codifies the repository-level token-efficiency development rules validated during the capability-gap closure goal.
- Preserve stronger existing policy from `AGENTS.md`; do not weaken unrelated workflow or safety requirements.

## Token-Efficiency Rules

- Treat MCP token efficiency as a repository-wide rule for existing tools, new tools, docs, tests, and future capability-gap work.
- Default responses may be smaller, but they must never silently imply completeness when data is omitted.
- Any bounded or partial result must expose explicit continuation metadata such as `truncated`, `has_more`, `next_cursor`, `next_max_results`, or another domain-appropriate equivalent.
- Prefer bounded output and progressive disclosure from the start: `max_items`, `max_results`, `max_depth`, `count/offset`, summary/detail shapes, and stable rerun hints should be built into tool design when results can grow large.
- Do not force unnecessary extra round trips for small results. Small complete results should still return directly.
- High-risk writes, destructive actions, and final judgments must fetch fuller detail when summary data is insufficient.
- When retrofitting an existing tool, keep exact-fit pages truthful: reaching a limit is not enough to claim `has_more=true` unless there is concrete evidence that more data exists.
- Tool docs and tests must stay aligned with these rules. Any new truncation, pagination, summary/detail, or rerun-hint contract must be reflected in `docs/current/tools-reference.md` and covered by focused regression tests.

## Encoding

- Save repository text files as UTF-8 without BOM.
- Respect the existing repository baseline in `.editorconfig`, `.gitattributes`, `scripts/check_utf8_bom.py`, and `.pre-commit-config.yaml`.
- For non-goal tasks, run an appropriate encoding verification before claiming completion when text files changed; prefer scripts/check_utf8_bom.py when cheap, otherwise check modified, staged, and untracked text files.
- For /goal, treat encoding enforcement as a goal-level gate: check or repair the baseline once per goal/work session, avoid repo-wide encoding audits after every small task, and run a fresh final encoding gate before claiming the goal complete.
- Run changed-files encoding checks during /goal only for bulk text generation, encoding-policy/checker edits, large text-resource migrations, or explicit verify commands; use Git to discover changed files instead of maintaining a manual task-level encoding ledger.