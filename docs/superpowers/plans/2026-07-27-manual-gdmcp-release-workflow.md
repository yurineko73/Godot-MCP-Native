# Manual gdmcp Release Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a manual-only GitHub Actions workflow that reads the committed version, builds five CLI packages plus the plugin archive, and creates or selectively updates the matching GitHub Release without changing existing tags.

**Architecture:** A prepare job resolves the version, tag, source commit, and release state. Independent matrix and plugin jobs build immutable workflow artifacts from the resolved commit. A final write-permission job validates the complete artifact set, creates a missing tag/release, or replaces only same-name assets on an existing release.

**Tech Stack:** GitHub Actions YAML, GitHub CLI, Rust/Cargo, Python 3 standard library, actions/checkout, actions/upload-artifact, actions/download-artifact.

## Global Constraints

- The workflow trigger is only `workflow_dispatch`.
- Do not modify `scripts/release.ps1` or any source version file.
- Read the version from `cli/gdmcp/Cargo.toml` and validate `plugin.cfg` and `cli_release.json` match.
- Existing tags are never moved or recreated.
- Existing releases are unchanged unless `replace_existing_assets` is true.
- Replacement changes only the six workflow-managed assets and preserves all Release metadata.
- New Releases are drafts.
- All CLI release archives are ZIP files with the existing seven-file packaging contract.
- Build five targets: Windows x64, Linux x64, Linux arm64, macOS arm64, macOS x64.

---

### Task 1: Add the manual release workflow

**Files:**
- Create: `.github/workflows/manual-gdmcp-release.yml`

**Interfaces:**
- Consumes: committed version declarations and files under `cli/gdmcp/packaging/`.
- Produces: workflow outputs `version`, `tag`, `source_sha`, `tag_exists`, and `release_exists`; six release ZIP files.

- [ ] **Step 1: Define a manual-only trigger and safe permissions**

Create a workflow with exactly one trigger:

```yaml
on:
  workflow_dispatch:
    inputs:
      replace_existing_assets:
        description: Replace workflow-managed assets when the release already exists
        required: true
        type: boolean
        default: false

permissions:
  contents: read
```

Add `concurrency.cancel-in-progress: false` and a tag/version-specific group after the prepare output is available at job level where possible; also guard the release job with a repository/tag concurrency key.

- [ ] **Step 2: Implement the prepare job**

Checkout `${{ github.sha }}` with `fetch-depth: 0`, read the version from `cli/gdmcp/Cargo.toml`, validate strict `X.Y.Z` syntax, and compare it with:

- `addons/godot_mcp/plugin.cfg`;
- `addons/godot_mcp/cli_release.json`.

Fetch tags and resolve `refs/tags/v<version>^{commit}` when present. If present, use that commit as `source_sha`; otherwise use `${{ github.sha }}`. Re-read and validate all three version declarations from `source_sha` using `git show` so an existing tag is validated against its own contents.

Use `gh release view` to detect the Release. If it exists and the boolean input is false, fail before build jobs start. Export all prepare values through `$GITHUB_OUTPUT`.

- [ ] **Step 3: Implement the five-target CLI matrix**

Use the exact runner/target pairs from the design. Checkout `needs.prepare.outputs.source_sha`, install the stable Rust toolchain with the matrix target, and run:

```bash
cargo build --manifest-path cli/gdmcp/Cargo.toml --release --locked --target <target>
```

Use a Python standard-library packaging step to create `dist/gdmcp-<version>-<target>.zip`. The archive root must contain the executable, both installers, README, LICENSE, SHA256SUMS, and `release-manifest.json`. On Unix, preserve executable permission for `gdmcp` and `install.sh` in ZIP metadata.

Upload each ZIP with `actions/upload-artifact` using a unique artifact name and `if-no-files-found: error`.

- [ ] **Step 4: Implement the plugin package job**

Checkout the same `source_sha`. Use Python `zipfile` to create `dist/godot-mcp-native-<version>.zip` with every file under `addons/godot_mcp/` stored under the `addons/godot_mcp/` archive prefix. Exclude no tracked plugin files. Upload it as a workflow artifact.

- [ ] **Step 5: Implement the release job**

Grant only this job `contents: write`. Download all artifacts into one directory with `merge-multiple: true`. Verify the exact six expected filenames exist and reject duplicate or unexpected ZIP names.

If the tag was absent, create and push an annotated or lightweight tag at `source_sha` without force. Re-check that the remote tag resolves to `source_sha`.

If the Release is absent, run `gh release create` with `--draft`, `--title v<version>`, `--target <source_sha>`, generated notes, and all six assets.

If the Release exists, require the replacement input and run `gh release upload <tag> <six exact paths> --clobber`. Do not call `gh release edit`, delete the Release, move the tag, or upload wildcard paths.

- [ ] **Step 6: Commit the workflow**

```bash
git add .github/workflows/manual-gdmcp-release.yml
git commit -m "ci: add manual multi-platform release workflow"
```

### Task 2: Verify the workflow contract

**Files:**
- Test: `.github/workflows/manual-gdmcp-release.yml`

**Interfaces:**
- Consumes: the completed workflow file.
- Produces: evidence that syntax and safety requirements are satisfied before PR creation.

- [ ] **Step 1: Parse the YAML locally**

Run a YAML parser against the workflow and confirm the top-level mapping loads without duplicate keys. Because YAML 1.1 parsers can coerce `on`, also inspect the raw text to ensure the trigger is written as a GitHub Actions `on:` key.

- [ ] **Step 2: Run actionlint**

Run:

```bash
actionlint .github/workflows/manual-gdmcp-release.yml
```

Expected: exit code 0 and no diagnostics.

- [ ] **Step 3: Run static safety assertions**

Assert the file:

- contains `workflow_dispatch`;
- contains no `push:`, `pull_request:`, or `schedule:` trigger;
- defaults replacement to false;
- contains all five targets and runner labels;
- uses `cargo build` with `--locked`;
- creates only ZIP release assets;
- uses `--draft` for new releases;
- uses `gh release upload` with `--clobber` only in the existing-release path;
- contains no force tag update and no `gh release edit`.

- [ ] **Step 4: Review the branch diff**

Compare the feature branch with `main` and confirm `scripts/release.ps1` is unchanged and only the design, plan, and workflow files were added.

- [ ] **Step 5: Open a draft pull request**

Create a draft PR targeting `main`. Describe that the workflow itself cannot appear in the Actions manual-run UI until merged to the default branch, and that the first real multi-platform run remains a post-merge validation step.