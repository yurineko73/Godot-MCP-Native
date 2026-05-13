# Godot MCP Capability Gap Closure

## Objective

Prioritize every identified capability gap between the current Godot MCP Native plugin and the Godot editor/runtime automation surface that can be implemented without modifying Godot engine source, including a cross-cutting MCP token-efficiency plan for all existing, upcoming, and future tools, then execute future work in safe, verified slices when the user starts the goal.

## Original Request

将缺口按大小进行优先级排序，全部列举出来，写成 GoalBuddy 的 /goal 文档，先不要开始 /goal。
## Intake Summary

- Input shape: `specific`
- Audience: Godot MCP Native maintainer and future Codex `/goal` PM/agents
- Authority: `requested`
- Proof type: `artifact`
- Completion proof: `docs/goals/godot-mcp-capability-gap-closure/goal.md` and `state.yaml` contain a complete business-value-ranked gap backlog, safe execution constraints, and live execution state for the currently active goal.
- Likely misfire: Treating "complete coverage" as a need to patch Godot engine source, or starting implementation during board preparation.
- Blind spots considered: Godot has no official MCP capability list in the inspected source; "complete coverage" must be scoped to public EditorPlugin/GDScript-accessible APIs unless a later Scout proves otherwise.
- Existing plan facts: current plugin source inspection, classifier tests, and published tool docs now report a 205-tool / 47-resource MCP surface; published docs are count-synchronized by regression coverage and drift-check audit paths, but charter/board text still needs spot refreshes when live capability facts change; `prompts/get` now works for registered prompts, while optional `resources/subscribe` and prompt/resource `listChanged` semantics are currently truthfully withheld unless a concrete real-time need justifies implementing them; most listed gaps can be implemented in plugin code only; MCP token usage is a major business concern and should be optimized without reducing correctness or practical workflow efficiency; resource MCP slices are green on live product-path reads and focused integrations, but the latest fresh embedded-GUT probe for `res://test/unit/tools/test_resource_tools.gd` still reaches `status=complete` with zero assertions, and direct diagnostics show `before_each()` leaves `_resource_tools` null in that lane, so it is currently treated as a non-gate verifier rather than a green proof; this machine still reproduces the broader standalone single-file GUT `signal 11` crash, so some other targeted unit verifiers remain environment-limited even when the corresponding product-path evidence is green.

## Goal Kind

`specific`

## Current Tranche

This goal has now completed its plugin-only final audit at the shipped-baseline level. The current backlog is closed as shipped baseline, or shipped baseline plus explicit deferred remainder, for every active backlog group. Remaining depth is now documented as deferred follow-up rather than as an unresolved blocker to this goal. Engine source under `C:\SourceCode\godot` remains evidence only and was not modified.

Token efficiency remains a cross-cutting rule for future work: existing tools were retrofitted where valuable, new surfaces were added with bounded output or resource wrappers where appropriate, and the remaining verifier debt is explicit rather than hidden behind false green status.

## Business-Value-Ranked Gap Backlog

Priority is sorted by expected business value for Godot MCP users and maintainers: client trust/interoperability, discoverability, day-to-day project authoring leverage, runtime/debug feedback speed, and maintenance risk reduction. Size remains an implementation-cost label, not the primary ordering key.

### Highest Value

1. **MCP protocol capability truth and completeness**
   - Size: XL
   - Current issue: baseline protocol truth is now much tighter: `prompts/get` works, and unsupported optional capability advertisement is mostly withheld, including `resources.subscribe`, `resources.listChanged`, and prompt `listChanged`. The remaining question is no longer basic truth alignment, but whether those optional real-time semantics justify the extra implementation and verification cost.
   - Expected work: preserve truthful withholding of optional subscribe/listChanged capability advertisement unless a concrete real-time client need justifies implementing and testing those semantics; if they stay unimplemented, keep negative behavior and capability declarations explicitly aligned.
   - Evidence: `addons/godot_mcp/native_mcp/mcp_types.gd`, `addons/godot_mcp/native_mcp/mcp_server_core.gd`.
   - Verification: protocol unit tests for initialize capabilities, resource subscribe behavior, prompt list/get behavior, and negative cases.

2. **MCP token budget optimization and context efficiency**

   - Size: XL
   - Current issue: broad MCP tool schemas and large tool results can still consume excessive model context, especially with the current 205-tool / 47-resource surface and large scene/resource/debug outputs. The project now already ships many bounded-output and continuation contracts, but they are not yet fully uniform across every high-volume surface and default response shape.
   - Expected work: preserve the shipped bounded-output foundation, and continue tightening cross-surface consistency for `detail_level`, pagination/cursors, `max_items`, `max_bytes`, truncation metadata, summary/detail tool pairs, stable snapshot/revision/hash fields, diff/since semantics, and shorter safe defaults where that consistency is still missing.
   - Scope: applies to all existing tools and resources, all capability gaps implemented in this goal, and all future MCP tool development rules.
   - Correctness rule: default responses may be smaller, but must never silently imply completeness when data is omitted; every truncated or partial result must expose `truncated`, `has_more`, `next_cursor` or equivalent continuation metadata.
   - Efficiency rule: optimizations must avoid unnecessary extra round trips for small results; high-risk writes or final judgments must require detail/full reads when summary data is insufficient.
   - Verification: full relevant feature regression tests must pass after token-efficiency changes, including summary/full/truncated/cursor/stale or revision cases. After tests pass, codify the development rules in `AGENTS.md` and `CLAUDE.md`.

3. **Documentation and generated tool reference synchronization**

   - Size: L
   - Current issue: the project now has an authoritative catalog-level drift check for published tools/resources, but it still does not generate the full reference from live metadata; detailed schemas/annotations remain partly hand-maintained and could still drift at the per-entry level.
   - Expected work: preserve the current repeatable drift check, and extend it or replace it with fuller metadata-driven generation/checking only where the added scope is justified by real drift risk.
   - Evidence: `docs/current/tools-reference.md`, `addons/godot_mcp/tools/*.gd`.
   - Verification: doc generation/check command that fails on drift.

4. **Generic resource inspection/edit/save pipeline**

   - Size: XL
   - Current issue: generic resource support is no longer just narrow read-only coverage: the project now has bounded list/inspect/update/duplicate/move/delete flows for single savable resources. The remaining gap is broader generic resource depth, such as unified load/save surfaces, richer property serialization/conversion, broader type validation, and convert-style workflows.
   - Expected work: preserve the verified bounded single-resource pipeline, and only extend into broader load/save/convert/property-serialization depth where the contract stays safe and testable.
   - Evidence: `addons/godot_mcp/tools/project_tools_native.gd`, `addons/godot_mcp/tools/resource_tools_native.gd`.
   - Verification: create/edit/save `.tres` resources and inspect persisted values.

5. **Project configuration write coverage**

   - Size: XL
   - Current issue: the project-configuration family now covers single-entry project setting read/write/clear, autoload add/remove/inspect, plugin enablement plus plugin catalog/inspect, feature profile select/list/inspect, project configuration summary, single-entry input/global-class/test inspection, and project-test runner availability. The remaining gap is broader project-configuration depth, such as batch or higher-level orchestration, wider settings coverage, and adjacent EditorInterface-level project bootstrap operations.
   - Expected work: preserve the verified single-entry project-configuration surface, and only extend it where broader write depth or orchestration is justified by real user value and can still be validated safely.
   - Evidence: Godot `ProjectSettings`, `EditorInterface.set_plugin_enabled`, `EditorInterface.set_current_feature_profile`.
   - Verification: integration tests on a temporary project copy or isolated fixture project.

6. **Broad EditorInterface automation coverage**

   - Size: XL
   - Current issue: the plugin now covers a broad read-first `EditorInterface` surface, including save/reload scene branches, current path/directory, selected paths, playing-scene state, editor language/theme/shell metadata, plugin enabled-state checks, open-scene summaries, and several availability handles. The remaining gap is deeper write-side or orchestration coverage, such as stable main-screen switching, richer edit/inspect flows, and operations that need stronger truth/verification than a simple getter wrapper.
   - Expected work: preserve the verified read-only/editor-metadata surface, and only add deeper EditorInterface wrappers where the public API is stable and the resulting behavior can be validated truthfully in CLI-first tests.
   - Evidence: `C:\SourceCode\godot\doc\classes\EditorInterface.xml`.
   - Verification: editor-mode integration tests plus read-only tool tests where possible.

7. **Debugger and runtime parity hardening**

   - Size: L
   - Current issue: debug/runtime coverage is broad, but edge capabilities remain: accurate capability reporting for stack routing limitations, unsubscribe/capture lifecycle, breakpoint listing/clear behavior, profiler data flow, remote inspector parity, and execution-control reliability.
   - Expected work: harden existing debugger bridge and runtime probe tools rather than adding broad unsafe execution.
   - Evidence: `addons/godot_mcp/tools/debug_tools_native.gd`, `addons/godot_mcp/native_mcp/mcp_debugger_bridge.gd`, `C:\SourceCode\godot\doc\classes\EngineDebugger.xml`.
   - Verification: integration tests that run a debug target and exercise break/step/vars/profiler/capture lifecycle.

8. **Scene tab and multi-scene operations**

   - Size: M
   - Current issue: scene open/current/save/close tab now also covers save-all, editor-native save-as, reload-from-disk, inherited-open, open-scene-root enumeration, close-specific-scene semantics through `close_scene_tab(scene_path=...)`, and active-scene dirty-state read/set truth through `get_editor_current_scene_dirty_state(set_dirty=...)`. The remaining gap is narrower still: broader unsaved-marker workflows beyond the current edited scene root are still incomplete.
   - Expected work: preserve the verified scene-tab and current-scene dirty-state surface, and only extend the remaining broader unsaved-marker flows where public APIs and validation stay truthful.
   - Evidence: `addons/godot_mcp/tools/scene_tools_native.gd`, `EditorInterface.xml`.
   - Verification: fixture with multiple open scenes and save/reload assertions.

9. **Script editor state and breakpoint parity**

   - Size: M
   - Current issue: script file tools are broad, and the plugin now also exposes script-editor availability plus a richer current/open-script summary surface covering current/open script types, open-editor type lists, aggregate breakpoint lists, and current-editor breakpoint lines. The remaining gap is the deeper ScriptEditor parity surface: docs update/clear or goto-help helpers are still open, while breakpoint-clear parity and other editor-state mutations should stay deferred unless a stable script-bindable public API is found instead of fragile UI traversal or private C++ hooks.
   - Expected work: preserve the verified ScriptEditor availability/open-script summary surface, then add only the remaining read-first and safe navigation/update helpers where public APIs and verification stay stable; explicitly defer mutation helpers that are not actually script-bindable.
   - Evidence: `C:\SourceCode\godot\doc\classes\ScriptEditor.xml`.
   - Verification: editor integration tests for open scripts and breakpoint state.

### Medium Value

10. **Editor file system, import pipeline, and preview tools**
    - Size: L
    - Current issue: this family no longer starts from just reimport support: the plugin already covers project scan/reload status, FileSystem dock navigation state, resource-filesystem and previewer availability, reimport, import metadata, resource UID info, and resource dependency reads. The remaining gap is deeper EditorFileSystem and EditorResourcePreview parity, such as richer scan status/details, file-type/source-scan/update-file ergonomics, and stable preview queue/check behavior.
    - Expected work: preserve the verified file-system/import baseline, and only add deeper `EditorFileSystem` or `EditorResourcePreview` tools where they expose stable state without relying on fragile UI traversal.
    - Evidence: `C:\SourceCode\godot\doc\classes\EditorFileSystem.xml`, `EditorResourcePreview.xml`.
    - Verification: import fixture assets, scan/reimport/update, and assert metadata changes.

11. **Export pipeline depth**

    - Size: L
    - Current issue: export preset listing/inspection, export template visibility, export validation, and export run baselines are already present, but deeper export platform capabilities such as pack/zip export, message inspection, forced/internal export file reporting, patch export, and richer platform metadata are still not fully covered.
    - Expected work: build on the existing export baseline with narrowly scoped export-platform or export-file metadata tools where public APIs allow stable operation.
    - Evidence: `C:\SourceCode\godot\doc\classes\EditorExportPlatform.xml`, `EditorExportPlugin.xml`.
    - Verification: dry-run or fixture export tests that avoid destructive paths.

12. **Tool grouping, naming, and duplicate-surface audit**

    - Size: S
    - Current issue: the current 205-tool / 47-resource surface may still overwhelm clients, and some functions overlap across resources/tools or editor/runtime scopes.
    - Expected work: audit naming consistency, categories/groups, destructive/read-only annotations, deduplication opportunities, and UI enablement defaults against the current catalog.
    - Verification: generated catalog diff and classifier/state-manager tests.

13. **Safe execution policy for powerful tools**

    - Size: S
    - Current issue: the project now already ships multiple high-impact surfaces, including editor script execution, runtime node mutation/method calls, project-setting writes, resource property writes, and codebase-wide rename flows. Validation exists in several individual tools, but the overall policy posture is still only partly codified and could be clearer and more consistent across annotations, scopes, and opt-in expectations.
    - Expected work: preserve the current per-tool validation, and continue documenting or enforcing scopes, opt-in flags, validation rules, and clearer annotations where those powerful surfaces still rely on implicit policy.
    - Verification: tests for rejected unsafe paths/keys/methods and expected allowed cases.

14. **Resource MCP URI coverage**

    - Size: S
   - Current issue: registered resources now cover scene/script/project/editor basics plus dedicated `godot://scene/open`, `godot://tools/catalog`, `godot://project/info`, `godot://project/settings`, `godot://project/class_metadata`, `godot://project/global_classes`, `godot://project/configuration_summary`, `godot://project/autoloads`, `godot://project/plugins`, `godot://project/feature_profiles`, `godot://project/tests`, `godot://project/test_runners`, `godot://project/dependency_snapshot`, `godot://editor/logs`, `godot://editor/state`, `godot://editor/script_summary`, `godot://editor/paths`, `godot://editor/shell_state`, `godot://editor/language`, `godot://editor/current_location`, `godot://editor/current_feature_profile`, `godot://editor/selected_paths`, `godot://editor/play_state`, `godot://editor/3d_snap_state`, `godot://editor/subsystem_availability`, `godot://editor/previewer_availability`, `godot://editor/undo_redo_availability`, `godot://editor/base_control_availability`, `godot://editor/file_system_dock_availability`, `godot://editor/inspector_availability`, `godot://editor/viewport_availability`, `godot://editor/selection_availability`, `godot://editor/command_palette_availability`, `godot://editor/toaster_availability`, `godot://editor/resource_filesystem_availability`, `godot://editor/script_editor_availability`, `godot://editor/settings_availability`, `godot://editor/theme_availability`, `godot://editor/current_scene_dirty_state`, `godot://editor/open_scene_summary`, `godot://editor/open_scenes_summary`, `godot://editor/open_scene_roots_summary`, and `godot://runtime/state`.
   - Expected work: preserve the verified read-only `godot://...` resource surface and only extend it where a new resource clearly reduces repeated tool calls without introducing fragile runtime/editor coupling.
    - Verification: `resources/list` and `resources/read` tests.

15. **Capability declarations and error semantics cleanup**

    - Size: S
    - Current issue: the project has already fixed several major truth drifts: unsupported optional capability advertisement is mostly withheld, and success-shaped placeholder handlers were converted to explicit MCP errors. The remaining gap is narrower: `resources/subscribe` and prompt/resource `listChanged` semantics are still unimplemented, and some unavailable-state or edge-case responses may still need clearer MCP error or disabled-capability treatment.
    - Expected work: preserve the shipped capability-truth cleanup, and continue aligning the remaining advertised capabilities, error responses, and annotations with actual behavior where edge semantics are still loose.
    - Verification: protocol conformance unit tests.

### Lower Value Or Mostly Supporting

16. **ClassDB and project API metadata expansion**
    - Size: M
    - Current issue: this family no longer starts from a single API metadata call: the plugin already covers project global-class listing/inspection plus `get_class_api_metadata`. The remaining gap is broader API discovery depth, such as inheritance search, creatable-type discovery, enums/constants filtering, richer property hint details, and stronger cross-checks between engine ClassDB metadata and project global-class state.
    - Expected work: preserve the shipped read-only class/global-class metadata baseline, and only add deeper API discovery helpers where the resulting contract stays ergonomic and stable.
    - Evidence: `addons/godot_mcp/tools/project_tools_native.gd`.
    - Verification: unit tests against stable built-in classes.

17. **Editor UI utility wrappers**

    - Size: M
    - Current issue: the plugin now exposes a useful read-only utility surface for command palette, toaster, selection, selected paths, file-system dock, inspector, resource filesystem, script editor, and related availability/summary checks. The remaining gap is the more fragile side of this family: popup/selectors, main-screen or dock/panel orchestration, and deeper UI traversal or mutation workflows.
    - Expected work: preserve the verified availability/summary utility surface, and only expose additional UI helpers where public `EditorInterface`/`EditorPlugin` APIs support a stable, non-fragile contract.
    - Evidence: `EditorInterface.get_command_palette`, popup selector methods, `EditorPlugin` bottom panel/dock methods.
    - Verification: read-only state checks and limited UI action smoke tests.

18. **Engine-internal or fragile UI-only gaps marked deferred**

    - Size: S
    - Current issue: some Godot editor capabilities are private C++ internals or unstable UI state not cleanly exposed to EditorPlugin/GDScript.
    - Expected work: document as deferred or unsupported unless a Scout finds a stable public API.
    - Verification: final audit confirms no board task proposes engine edits or fragile Control-tree scraping without explicit approval.

## Non-Negotiable Constraints

- Do not modify `C:\SourceCode\godot` engine source for this goal.
- Do not start `/goal` during this `$goalbuddy` preparation turn.
- Plugin work must stay in `C:\SourceCode\Godot-MCP-Native`.
- Treat `C:\Users\milli\.codex` as high-risk application state; do not edit it.
- Before later implementation, validate the current source again because tool counts and docs may have changed.
- Prefer public Godot EditorPlugin/GDScript APIs over fragile editor UI traversal.
- Keep every implementation slice small, testable, and reversible.
- Token-efficiency changes must be correctness-preserving: partial, summarized, filtered, cached, or diff responses must be explicitly marked and must expose a path to full detail.
- Every related function touched by token optimization must receive full relevant regression coverage before the rule is considered done.
- Encoding enforcement is now a goal-level gate: the repository baseline is already present, so do not spend every small task re-checking the baseline or running repo-wide BOM audits.
- Worker slices must still write touched text files as UTF-8 without BOM; run changed-files encoding checks only for bulk text generation, encoding-policy/checker edits, large text-resource migrations, or explicit verify commands.
- The final audit must include a fresh encoding check over the full changed set, including untracked files; `scripts/check_utf8_bom.py` is acceptable when a repo-wide run is cheap.
- Only after token-efficiency implementation and full relevant tests pass should the development rules be written into project-level `AGENTS.md` and `CLAUDE.md`.

## Stop Rule

Stop only when a final audit proves the full original outcome is complete.

Do not stop after planning, discovery, or Judge selection if the user starts `/goal` and a safe Worker task can be activated.

Do not stop after a single verified Worker slice when the broader owner outcome still has safe local follow-up slices. After each slice audit, advance the board to the next highest-leverage safe Worker task and continue.

Do not stop because a slice needs owner input, credentials, production access, destructive operations, or policy decisions. Mark that exact slice blocked with a receipt, create the smallest safe follow-up or workaround task, and continue all local, non-destructive work that can still move the goal toward the full outcome.

## Canonical Board

Machine truth lives at:

`docs/goals/godot-mcp-capability-gap-closure/state.yaml`

If this charter and `state.yaml` disagree, `state.yaml` wins for task status, active task, receipts, verification freshness, and completion truth.

## Run Command

```text
/goal Follow docs/goals/godot-mcp-capability-gap-closure/goal.md.
```

## PM Loop

On every `/goal` continuation:

1. Read this charter.
2. Read `state.yaml`.
3. Re-check the intake: original request, input shape, authority, proof, blind spots, existing plan facts, and likely misfire.
4. Work only on the active board task.
5. Assign Scout, Judge, Worker, or PM according to the task.
6. Write a compact task receipt.
7. Update the board.
8. If Judge selected a safe Worker task with `allowed_files`, `verify`, and `stop_if`, activate it and continue unless blocked.
9. Treat a slice audit as a checkpoint, not completion, unless it explicitly proves the full original outcome is complete.
10. Finish only with a Judge/PM audit receipt that maps receipts and verification back to the original user outcome and records `full_outcome_complete: true`.
11. Keep encoding checks on the goal-level gate path: no per-task repo-wide encoding audit unless the active task is an encoding-risk task or explicitly requires that verification.
