# Manual gdmcp Release Workflow Design

## Goal

Add a GitHub Actions workflow that is started only through `workflow_dispatch`, reads the version already committed to the repository, builds release archives for all supported CLI targets, packages the Godot plugin, and creates or updates the matching GitHub Release without modifying `scripts/release.ps1` or any version file.

## Scope

The workflow will:

- have no `push`, `pull_request`, `schedule`, or tag trigger;
- read the version from `cli/gdmcp/Cargo.toml`;
- verify that `addons/godot_mcp/plugin.cfg` and `addons/godot_mcp/cli_release.json` contain the same version;
- derive the tag as `v<version>`;
- build Windows x64, Linux x64, Linux arm64, macOS arm64, and macOS x64 packages;
- create `godot-mcp-native-<version>.zip` with an `addons/godot_mcp/` root;
- create a draft Release when the matching Release does not exist;
- optionally replace only the workflow-managed assets when the matching Release already exists;
- never move or recreate an existing tag;
- leave an existing Release title, notes, draft/published state, and other manually uploaded assets unchanged.

The workflow will not:

- modify `scripts/release.ps1`;
- bump versions, edit source files, commit, or push source changes;
- publish a draft Release automatically;
- run GUT or the local release preparation process;
- move an existing tag to a new commit.

## Manual Input

`workflow_dispatch` exposes one boolean input:

- `replace_existing_assets`, default `false`.

The version is never entered manually. The operator chooses the branch or ref in the GitHub Actions UI, and the workflow reads the version from that selected revision.

## Source Commit Resolution

1. Checkout the manually selected revision with full history and tags.
2. Read the candidate version from `cli/gdmcp/Cargo.toml` and derive `v<version>`.
3. If the tag already exists, resolve its peeled commit and use that commit for every build and package job.
4. If the tag does not exist, use the selected workflow commit.
5. Re-check the version files from the resolved source commit.
6. If an existing tag's source does not declare the same version as its tag, fail before building.

This guarantees that replacement assets are rebuilt from the commit already identified by the existing tag.

## Existing Tag and Release Rules

### Tag absent, Release absent

Build the selected commit. After every artifact is available, create `v<version>` at the selected commit and create a draft Release containing all assets.

### Tag present, Release absent

Build the commit referenced by the tag. Keep the tag unchanged and create a draft Release for it.

### Tag present, Release present, replacement disabled

Fail during the prepare job before matrix builds begin.

### Tag present, Release present, replacement enabled

Build the tag commit. Keep the existing tag and Release metadata unchanged. Replace only matching workflow-managed asset names.

## Build Matrix

| Runner | Rust target | Archive executable |
|---|---|---|
| `windows-latest` | `x86_64-pc-windows-msvc` | `gdmcp.exe` |
| `ubuntu-24.04` | `x86_64-unknown-linux-gnu` | `gdmcp` |
| `ubuntu-24.04-arm` | `aarch64-unknown-linux-gnu` | `gdmcp` |
| `macos-latest` | `aarch64-apple-darwin` | `gdmcp` |
| `macos-15-intel` | `x86_64-apple-darwin` | `gdmcp` |

Each matrix job runs a locked release build and creates:

`gdmcp-<version>-<target>.zip`

Every CLI archive contains these files at its root:

- `gdmcp` or `gdmcp.exe`;
- `install.ps1`;
- `install.sh`;
- `README.md`;
- `LICENSE`;
- `SHA256SUMS`;
- `release-manifest.json`.

This preserves compatibility with the existing plugin downloader and packaging contract.

## Plugin Archive

A separate job packages the resolved source commit into:

`godot-mcp-native-<version>.zip`

The archive root contains:

```text
addons/
└── godot_mcp/
```

## Release Update Safety

The release job starts only after all five CLI packages and the plugin package have been uploaded as workflow artifacts. It first verifies that the exact six expected files are present.

For a new release, it creates a draft release with `--target <resolved-source-sha>` and uploads all files.

For an existing release with replacement enabled, it uploads the six exact files with overwrite behavior. GitHub CLI replaces assets with the same names; unrelated assets remain untouched. Because replacing an asset is not transactional, all local artifacts are validated before any upload begins.

## Permissions and Concurrency

- Default workflow permission: `contents: read`.
- Only the final release job receives `contents: write`.
- A concurrency group keyed by repository and tag prevents two manual runs from updating the same version simultaneously.
- Automatic cancellation is disabled so a later run cannot interrupt an in-progress release update.

## Validation

Static validation covers:

- the workflow has only `workflow_dispatch`;
- the replacement input defaults to false;
- all five target/runner combinations are present;
- version consistency checks are present;
- builds use `--locked`;
- all archives use `.zip` names expected by `cli_release.json`;
- existing tags are never force-updated;
- existing releases fail early unless replacement is enabled;
- new releases are drafts;
- replacement affects same-name assets only.

The workflow itself cannot be fully executed until it is present on the default branch. After merge, the first manual run should be performed with replacement disabled against a version that does not already have a Release, or against a temporary test version prepared through the normal local version process.