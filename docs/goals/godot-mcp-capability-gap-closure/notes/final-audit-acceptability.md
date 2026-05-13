# Final Audit Acceptability

## Scope

This note does not claim the goal is complete.

It states the current acceptability position for the two remaining non-implementation questions before `T999`:

- whether the current dirty worktree can be judged as intentional goal output rather than unresolved noise,
- and whether the current non-gate verifier debt is explicit enough to be accepted in a completion audit.

## Dirty Worktree Acceptability

Current evidence supports the reading that the worktree is still dirty because the goal output itself is large, not because temporary probe garbage still dominates it.

Evidence:

- `git diff --shortstat`
  - `49 files changed, 15076 insertions(+), 2111 deletions(-)`

- `git status --short`
  - tracked modifications are concentrated in:
    - core tool families under `addons/godot_mcp/`
    - docs under `docs/current/`, `docs/debugging/`, and `docs/goals/`
    - integration and unit coverage under `test/integration/` and `test/unit/`
    - guidance files such as `AGENTS.md`, `CLAUDE.md`, `.gitattributes`, `.editorconfig`, `.pre-commit-config.yaml`

- root-level temporary probe scan
  - `Get-ChildItem -Force -Name | Where-Object { $_ -like '.tmp*' }`
  - current result: no matches

Interpretation:

- The current dirty fingerprint is acceptable as audit input if `T999` is judging artifact completeness rather than git cleanliness.
- The dirty tree is still a blocker only if the final audit finds stray files that are unrelated to the chartered outcome, or if current docs/board truth no longer explain the scope of the changed set.

## Non-Gate Verifier Debt Acceptability

Current evidence supports keeping verifier debt explicit instead of pretending it is green.

Still explicit today:

- `test_resource_tools.gd` fresh embedded-GUT remains non-gate.
- standalone single-file GUT remains environment-limited on this machine.
- a later class-metadata ad hoc direct-probe rerun hit `ConnectionResetError`, but stronger direct evidence for the shipped metadata baseline already exists and is recorded separately.

Interpretation:

- This debt is acceptable only if `T999` continues to treat it as non-gate verifier debt, not as hidden green status.
- If the final audit wants stricter standards than that, the goal is not complete yet.

## Candidate `T999` Reading

If `T999` runs with the current evidence:

- it should not reject completion merely because the worktree is dirty,
  - if the dirty set is still clearly the intended artifact surface for this goal,
- and it should not reject completion merely because the non-gate verifier debt exists,
  - if that debt remains explicit and the shipped baselines are otherwise backed by current product-path evidence.

What would still justify rejection:

1. finding stale or contradictory charter/board wording,
2. finding a required backlog group that is neither shipped nor explicitly deferred,
3. finding that a relied-on verifier does not actually cover the claimed requirement,
4. or deciding that the remaining non-gate debt is too weak for completion under the stricter audit bar.
