# Backlog-Group Disposition Matrix

## Scope

This note does not claim the goal is complete.

It converts the current backlog-group evidence into a proposed final-audit disposition per group so `T999` can judge against explicit candidate outcomes rather than re-deriving intent from scattered receipts.

## Disposition Categories

- `shipped_baseline`
  - A meaningful baseline for the group is already implemented, documented, and evidenced.
- `shipped_baseline_plus_defer`
  - A meaningful baseline is shipped, but the charter still names deeper work that should be explicitly deferred or accepted as out of scope for this goal.
- `needs_stronger_fresh_evidence`
  - The baseline looks real, but current evidence is too historical or environment-limited for `T999` to accept without an explicit judgment.
- `non_gate_verifier_debt`
  - The shipped behavior is supported by live product-path evidence, but a verifier lane is currently unreliable and must stay explicitly non-gate.

## Proposed Group Dispositions

| Group | Proposed disposition | Why this is the current truthful reading | What `T999` still needs |
| --- | --- | --- | --- |
| `G001` | `shipped_baseline_plus_defer` | Protocol truth is much tighter now: `prompts/get` exists, `resources.subscribe` remains withheld by behavior, and `listChanged` semantics are gated instead of falsely advertised. | Decide whether optional subscribe/listChanged semantics are explicitly deferred or require more protocol-specific verification. |
| `G008` | `shipped_baseline` | Token-efficiency rules are codified and the high-volume tool/resource families visibly expose bounded output and continuation metadata. | Confirm the shipped surfaces still match the codified rules closely enough at final audit time. |
| `G008_DOCS` | `shipped_baseline` | Catalog counts and representative docs are synchronized through drift checks and repeated truth refreshes. | Run the final stale-wording sweep outside catalog-count coverage. |
| `G002` | `shipped_baseline_plus_defer` | Generic resource inspect/update/duplicate/move/delete baseline exists and is no longer hypothetical. | Explicitly defer or accept the still-missing broader load/save/convert/property-serialization depth. |
| `G003` | `shipped_baseline_plus_defer` | Project settings, autoloads, plugins, feature profiles, summaries, and test-runner availability are already covered. | Explicitly defer or accept higher-level project bootstrap/orchestration depth. |
| `G004` | `shipped_baseline_plus_defer` | A wide read-first EditorInterface surface plus selected write/orchestration branches is already shipped. | Explicitly distinguish shipped read-first/getter coverage from deeper write/orchestration gaps. |
| `G007` | `shipped_baseline_plus_defer` | Debugger/log/runtime-state baselines exist, but harder runtime-session parity remains environment-limited. | Accept or defer the harder runtime-session parity work explicitly. |
| `G010` | `shipped_baseline_plus_defer` | Scene open/current/save/close/reload/save-all/save-as/current-dirty flows are present and verified. | Explicitly decide the remaining broader unsaved-marker depth. |
| `G011` | `shipped_baseline_plus_defer` | Script-editor availability and richer open-script summary/breakpoint parity are shipped; mutation helpers without stable script-bindable APIs are already being treated cautiously. | Keep unsupported mutation helpers explicitly deferred unless a real public API appears. |
| `G005` | `shipped_baseline_plus_defer` | File-system/import/preview baseline is shipped and visible, but deeper parity remains optional. | Final audit should explicitly accept or defer deeper import/preview parity. |
| `G006` | `shipped_baseline_plus_defer` | Export baseline is clearly implemented and documented, and the current review now has a fresh fixture-backed direct MCP probe where `list_export_presets` returns `count=1`, `validate_export_preset` returns `valid=true`, `run_export(..., mode=pack)` returns `success=true`, and the generated pack file exists with non-zero size. | Explicitly defer deeper export-platform depth beyond the current shipped preset/template/validation/run baseline. |
| `G015` | `shipped_baseline_plus_defer` | Grouping/naming/duplicate-surface truth has received repeated drift and README/charter cleanup. | Final audit still needs a human decision on any residual grouping debt not caught by scripts. |
| `G016` | `shipped_baseline_plus_defer` | Safer execution policy is codified and reflected in validation-heavy surfaces. | Final audit should explicitly accept any remaining policy/documentation debt. |
| `G013` | `shipped_baseline` | Resource MCP coverage is large and concrete, with repeated green product-path parity checks and live resource count synchronization. | Confirm no still-chartered resource wrappers remain genuinely missing. |
| `G014` | `shipped_baseline_plus_defer` | Capability/error-semantic truth has been repeatedly tightened and no longer appears to be a broad red area. | One last active-doc/receipt pass to ensure no optional semantics are still over-advertised. |
| `G012` | `shipped_baseline_plus_defer` | The metadata baseline is clearly shipped, with prior passed receipts, live docs/source continuity, and a fresh direct MCP probe that succeeds for global-class list/inspect/class-API reads plus `godot://project/autoloads`. | Explicitly defer deeper inheritance/enum/constant metadata expansion beyond the current shipped baseline. |
| `G009` | `shipped_baseline_plus_defer` | Editor utility availability/summary wrappers are now broad and no longer a missing family. | Explicitly defer deeper popup/selector/main-screen orchestration if it remains unshipped. |
| `G017` | `shipped_baseline` | The charter now already treats engine-internal/fragile UI-only surfaces as deferred unless a stable public API exists. | Confirm there are no still-open backlog claims that contradict that stance. |

## Still Blocking `T999`

1. The two `needs_stronger_fresh_evidence` groups still need an explicit final judgment.
   - `G006`
   - `G012`

2. Multiple `shipped_baseline_plus_defer` groups still need explicit accept/defer wording in the final audit outcome.
   - They are not current red failures, but `T999` should not silently treat them as “fully closed” without naming the deferred remainder.

3. Non-gate verifier debt remains real.
   - `test_resource_tools.gd` fresh embedded-GUT remains non-gate.
   - Some standalone single-file GUT lanes still remain environment-limited on this machine.

## Practical Reading For `T999`

`T999` should probably not ask whether every charter sentence became “fully implemented.”

It should ask whether:

- each backlog group now has a defensible disposition,
- the shipped baseline for that group is supported by current artifacts and evidence,
- the remaining depth is explicitly deferred rather than hidden,
- and any verifier debt is acknowledged rather than smuggled in as green.
