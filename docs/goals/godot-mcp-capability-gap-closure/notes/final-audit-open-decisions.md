# Final-Audit Open Decisions

## Scope

This note does not claim the goal is complete.

It turns the current disposition matrix into candidate `T999` decisions so the final audit can focus on a small set of explicit accept/defer calls instead of rediscovering them.

## Groups That Look Ready To Accept As Shipped Baseline

- `G008`
  - Candidate `T999` wording: accept as shipped baseline if the final drift/BOM gates and current source/docs still show bounded-output and continuation truth across the high-volume surfaces.
- `G008_DOCS`
  - Candidate `T999` wording: accept as shipped baseline if the final docs sweep finds no active stale counts or capability claims outside the already-audited catalog paths.
- `G013`
  - Candidate `T999` wording: accept as shipped baseline if the live resource count and representative resource parity lanes still match the charter.
- `G017`
  - Candidate `T999` wording: accept as shipped baseline if the live charter continues to defer engine-internal or fragile UI-only surfaces instead of silently treating them as promised work.

## Groups That Need Explicit “Shipped Baseline + Deferred Remainder” Language

- `G001`
  - Candidate defer remainder: optional realtime subscribe / `listChanged` semantics unless a concrete client need justifies implementing and testing them.
- `G002`
  - Candidate defer remainder: broader generic resource load/save/convert/property-serialization depth beyond the current bounded single-resource pipeline.
- `G003`
  - Candidate defer remainder: higher-level project bootstrap/orchestration depth beyond current single-entry project-configuration coverage.
- `G004`
  - Candidate defer remainder: deeper write-side EditorInterface orchestration beyond the shipped read-first/getter-heavy surface.
- `G005`
  - Candidate defer remainder: deeper import/preview parity that is not already covered by the current file-system/import baseline.
- `G006`
  - Candidate defer remainder: deeper export-platform depth beyond the current shipped preset/template/validation/run baseline.
- `G007`
  - Candidate defer remainder: harder runtime-session/debugger parity that remains environment-limited.
- `G009`
  - Candidate defer remainder: deeper popup/selector/main-screen orchestration beyond the current utility availability/summaries.
- `G010`
  - Candidate defer remainder: broader unsaved-marker workflows beyond the current scene-tab/current-scene-dirty baseline.
- `G011`
  - Candidate defer remainder: mutation helpers that still lack stable script-bindable public APIs.
- `G012`
  - Candidate defer remainder: deeper inheritance/enum/constant metadata expansion beyond the now-freshly evidenced global-class/class-API baseline.
- `G014`
  - Candidate defer remainder: any optional protocol/error-semantics polish that is not already covered by the shipped truth cleanup.
- `G015`
  - Candidate defer remainder: residual grouping/naming/deduplication debt that requires human judgment beyond current scripted audits.
- `G016`
  - Candidate defer remainder: any remaining policy/documentation tightening beyond the shipped validation-heavy baseline.

## Groups Still Requiring A Final Explicit Evidence Judgment

- None at the backlog-group baseline level.
  - The last explicit evidence-judgment group, `G006`, now has a fresh fixture-backed direct MCP probe with `run_export(..., mode=pack)` returning `success=true` and a non-empty generated pack artifact.
  - What remains for `T999` is no longer whether a backlog-group baseline exists, but whether the final gate reruns and explicit defer language are sufficient for completion.

## Non-Gate Verifier Debt That Must Stay Explicit

- `test_resource_tools.gd`
  - Fresh embedded-GUT remains non-gate because it can complete with zero assertions after `_resource_tools` stays null in `before_each()`.
- standalone single-file GUT on this machine
  - Still environment-limited and must not be treated as a universal red signal against shipped product-path evidence.

## Practical Use In `T999`

If `T999` runs now, it should not spend time rediscovering categories.

It should:

1. confirm the final live gates are green,
2. confirm that no backlog group still needs a stronger baseline-evidence judgment,
3. apply explicit defer language to each `shipped_baseline_plus_defer` group,
4. confirm non-gate verifier debt remains visible,
5. then decide whether the chartered outcome is achieved on that basis.
