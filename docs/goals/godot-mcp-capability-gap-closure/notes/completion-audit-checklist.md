# Completion Audit Checklist

## Goal

Execute `docs/goals/godot-mcp-capability-gap-closure/goal.md` end-to-end by:

- maintaining a complete business-value-ranked capability-gap backlog,
- closing plugin-only Godot MCP capability gaps in safe verified slices,
- keeping docs and board truth synchronized with the shipped surface,
- preserving the cross-cutting token-efficiency rules,
- and reaching a final state where completion can be proven from current artifacts rather than inferred from effort.

## Concrete Success Criteria

1. `goal.md` and `state.yaml` truthfully describe the current live capability surface, backlog, verifier debt, and active execution state.
2. The shipped MCP catalog is synchronized across implementation, docs, classifier truth, and drift checks.
3. Implemented slices are backed by real evidence:
   - live product-path reads or focused integrations,
   - unit or embedded-GUT evidence where trustworthy,
   - and explicit non-gate classification where verifier lanes are environment-limited.
4. Remaining unsupported or public-API-infeasible gaps are explicitly deferred with rationale instead of being silently dropped.
5. Final completion is blocked unless the current changed set passes a fresh encoding gate and the last verification snapshot points at real current evidence.

## Prompt-To-Artifact Checklist

| Requirement | Current evidence | Still needed before `T999` can pass |
| --- | --- | --- |
| Ranked backlog exists and is live | `goal.md` backlog, `state.yaml` `gap_backlog`, `tasks`, `checks` | Completion audit must confirm each live backlog entry is either implemented, narrowed, or defensibly deferred |
| Board is live | `state.yaml` `visual_board.local`, repeated `302` board probes | Keep a fresh board probe in the final audit |
| Tool/resource counts stay synchronized | `docs/current/tools-reference.md`, `scripts/check_tools_reference_drift.py`, classifier/tests | Final audit should rerun drift check and confirm current counts still match docs and board |
| Encoding gate | `scripts/check_utf8_bom.py`, `checks.encoding_policy` | Final audit must rerun over the full changed set immediately before completion |
| Token-efficiency rules preserved | `AGENTS.md`, `CLAUDE.md`, bounded-output tool/resource surfaces, backlog `G008` wording | Final audit must confirm the codified rules still match shipped behavior and no high-volume surface regressed |
| Resource MCP verifier debt is explicit | `goal.md` intake facts, `state.yaml` intake facts, `checks.last_verification`, earlier receipts | Final audit must confirm this remains documented and non-gated, not silently treated as green |
| Completion is based on real evidence, not proxy signals | current focused integrations and drift/BOM gates recorded in `state.yaml` receipts | Build a final evidence matrix that maps each required deliverable to a current artifact or verifier |

## Known Non-Gate Verifier Debt

- `res://test/unit/tools/test_resource_tools.gd` fresh embedded-GUT lane is still not trustworthy as a green verifier; it has been classified as non-gate.
- This machine still reproduces standalone single-file GUT `signal 11`, so some targeted unit lanes remain environment-limited even when product-path evidence is green.

## Completion-Audit Blockers To Resolve Or Explicitly Accept

- Build the final evidence matrix against the actual current surface instead of relying on historical receipts alone.
- Re-check the top-level charter/board for any remaining stale wording or verifier snapshots after the latest cleanup passes.
- Confirm the final changed-set encoding gate and current dirty fingerprint immediately before any completion decision.
- Decide whether any remaining backlog items are still active work or should be explicitly deferred in the charter before `T999`.
