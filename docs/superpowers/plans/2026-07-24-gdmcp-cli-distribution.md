# gdmcp CLI Distribution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add isolated development installation, deterministic release packaging, and a Rust-free final-package installer for `gdmcp`.

**Architecture:** Keep Rust source and tests under `cli/gdmcp/`. Development installation uses project-local `RUSTUP_HOME` and `CARGO_HOME` under `.gdmcp/`; release packaging builds a locked release binary into an ignored `dist/` staging directory and copies only approved runtime files into the archive. The final installer operates on an extracted release archive and never invokes Cargo.

**Tech Stack:** Rust/Cargo, PowerShell 7+, POSIX shell, Python 3 standard library integration tests, ZIP/tar archives, SHA-256 checksums.

## Global Constraints

- The main workspace must not be modified; all implementation occurs in the existing `C:\tmp\Godot-MCP-Native-gdmcp-test-20260724` worktree.
- No Git add, commit, push, merge, or PR state mutation is performed.
- Source code files use English-only comments, strings, and identifiers; documentation may use English.
- Development toolchain state is project-local by default under `.gdmcp/`.
- Generated release files are written under ignored `dist/` and are never committed.
- Release archives must not contain Rust source, tests, Cargo metadata, `.git`, `.gdmcp`, or toolchain files.
- Default installers must not modify persistent PATH or user Cargo configuration.
- Existing Rust CI commands remain authoritative: format check, Clippy with `-D warnings`, tests, and locked release build.

---

### Task 1: Add a lockfile, ignore generated state, and define packaging metadata

**Files:**
- Create: `cli/gdmcp/rust-toolchain.toml`
- Create: `cli/gdmcp/Cargo.lock`
- Modify: `.gitignore`
- Modify: `cli/gdmcp/Cargo.toml`
- Test: `test/integration/test_gdmcp_packaging.py`

**Interfaces:**
- `rust-toolchain.toml` pins the channel used by development and release scripts.
- `Cargo.lock` is required by `--locked` builds.
- `.gitignore` ignores `.gdmcp/`, `dist/`, and packaging staging output.

- [ ] **Step 1: Write failing metadata tests**

Add Python assertions that `Cargo.lock` exists, `rust-toolchain.toml` declares a channel, and the repository ignore file contains `.gdmcp/` and `dist/`.

- [ ] **Step 2: Run the focused test and verify the expected failure**

Run:

```powershell
python test/integration/test_gdmcp_packaging.py --case metadata
```

Expected: failure because the lockfile, toolchain file, and ignore entries do not exist.

- [ ] **Step 3: Add metadata files and ignore entries**

Use `channel = "stable"` in `rust-toolchain.toml`. Generate `Cargo.lock` from the manifest when Cargo is available; if Cargo is unavailable locally, obtain the lockfile from the same dependency resolution used by CI without changing the host installation. Add `.gdmcp/` and `dist/` to `.gitignore`.

- [ ] **Step 4: Re-run the focused test**

Run the same command and require a passing metadata case.

---

### Task 2: Implement project-local development installation

**Files:**
- Create: `cli/gdmcp/scripts/install-dev.ps1`
- Create: `cli/gdmcp/scripts/install-dev.sh`
- Modify: `cli/gdmcp/README.md`
- Test: `test/integration/test_gdmcp_packaging.py`

**Interfaces:**
- PowerShell parameters: `-InstallRoot`, `-ToolchainRoot`, `-Offline`, `-UseSystemCargo`, `-DryRun`, `-Force`.
- POSIX flags: `--install-root`, `--toolchain-root`, `--offline`, `--use-system-cargo`, `--dry-run`, `--force`.
- Both scripts resolve the same defaults: `.gdmcp/bin` and `.gdmcp/rust`.
- Both scripts export only process-local `RUSTUP_HOME` and `CARGO_HOME`.

- [ ] **Step 1: Add failing path-isolation tests**

Use a temporary repository fixture and fake `cargo`/`rustup-init` executables. Assert that dry-run output names project-local roots, does not contain a persistent PATH mutation, and rejects `--offline` when no local toolchain exists.

- [ ] **Step 2: Run the focused test and verify failure**

Run:

```powershell
python test/integration/test_gdmcp_packaging.py --case dev-install
```

Expected: failure because the development installer scripts do not exist.

- [ ] **Step 3: Implement the PowerShell installer**

Implement deterministic repository resolution, explicit option parsing, local environment variables, cargo reuse, offline validation, and a dry-run mode. When Cargo is unavailable and offline mode is not selected, download `rustup-init` to a temporary path, install the configured stable toolchain under the selected local roots, then invoke the explicit local Cargo binary. Do not use `setx`, registry PATH writes, or user-profile Cargo configuration.

- [ ] **Step 4: Implement the POSIX installer**

Mirror the PowerShell behavior with `getopts`-style long-option parsing, `curl`/`wget` selection, temporary download cleanup, local environment variables, and no shell profile edits.

- [ ] **Step 5: Re-run the focused test**

Run the dev-install case with fake tools and require passing assertions for default paths, system Cargo opt-in, offline rejection, and idempotent reuse.

---

### Task 3: Add final-package installer templates

**Files:**
- Create: `cli/gdmcp/packaging/install.ps1`
- Create: `cli/gdmcp/packaging/install.sh`
- Create: `cli/gdmcp/packaging/README.md`
- Create: `cli/gdmcp/packaging/LICENSE`
- Test: `test/integration/test_gdmcp_packaging.py`

**Interfaces:**
- Release installer parameters: install root, `--add-path`, `--uninstall`, and `--dry-run`.
- The installer reads `release-manifest.json` and `SHA256SUMS` from its own archive directory.
- Default install roots are `%LOCALAPPDATA%\\gdmcp\\bin` on Windows and `$HOME/.local/gdmcp/bin` on POSIX.

- [ ] **Step 1: Add failing archive-install tests**

Create a temporary release directory containing a fake executable, manifest, checksum, and installer. Assert that installation copies only the executable, rejects a checksum mismatch, and leaves PATH unchanged unless `--add-path` is supplied.

- [ ] **Step 2: Run the focused test and verify failure**

Run:

```powershell
python test/integration/test_gdmcp_packaging.py --case release-install
```

Expected: failure because the release installer templates do not exist.

- [ ] **Step 3: Implement the PowerShell release installer**

Verify the platform executable and SHA-256 before copying. Support dry-run and uninstall. Print the exact installed path and a manual PATH command instead of mutating persistent settings by default.

- [ ] **Step 4: Implement the POSIX release installer**

Mirror the verification, copy, uninstall, and optional PATH behavior with POSIX tools.

- [ ] **Step 5: Add the release README and license payload**

Document that this package contains a prebuilt binary and requires no Rust. Keep development instructions out of the release README.

- [ ] **Step 6: Re-run the focused test**

Require passing install, checksum rejection, uninstall, dry-run, and PATH isolation assertions.

---

### Task 4: Implement deterministic release packaging

**Files:**
- Create: `cli/gdmcp/scripts/package.ps1`
- Create: `cli/gdmcp/scripts/package.sh`
- Test: `test/integration/test_gdmcp_packaging.py`

**Interfaces:**
- PowerShell parameters: `-Version`, `-Target`, `-OutputDir`, `-Clean`, `-DryRun`.
- POSIX flags: `--version`, `--target`, `--output-dir`, `--clean`, `--dry-run`.
- Output archive: `gdmcp-<version>-<target>.zip` on Windows and `gdmcp-<version>-<target>.tar.gz` on POSIX.
- Generated metadata: `release-manifest.json` and `SHA256SUMS`.

- [ ] **Step 1: Add failing package tests**

Use a fake Cargo executable that writes a known release binary. Assert that the package rejects a version mismatch and missing lockfile, includes exactly the approved release files, excludes source and tests, and produces checksums matching the archive directory.

- [ ] **Step 2: Run the focused test and verify failure**

Run:

```powershell
python test/integration/test_gdmcp_packaging.py --case package
```

Expected: failure because package scripts and release templates do not exist.

- [ ] **Step 3: Implement the PowerShell packager**

Validate SemVer input against `Cargo.toml`, require `Cargo.lock`, run locked release build commands unless dry-run is selected, create an isolated staging directory, copy the executable and release templates, write deterministic manifest/checksum files, archive the staging contents, and clean only its own staging directory after success.

- [ ] **Step 4: Implement the POSIX packager**

Mirror the PowerShell behavior, using `tar` and `sha256sum` or `shasum -a 256` fallback. Keep archive member paths relative and stable.

- [ ] **Step 5: Re-run the focused package test**

Require passing archive-content, metadata, checksum, version-validation, lockfile-validation, and dry-run assertions.

---

### Task 5: Update documentation and CI verification

**Files:**
- Modify: `cli/gdmcp/README.md`
- Modify: `docs/current/gdmcp-cli-reference.md`
- Modify: `.github/workflows/gdmcp-cli.yml`
- Test: `test/integration/test_gdmcp_packaging.py`

**Interfaces:**
- README documents development installation separately from release installation.
- CI runs the Python packaging tests and validates a dry-run package command without publishing.

- [ ] **Step 1: Add documentation assertions**

Assert that README text contains separate development and release commands and explicitly states that release installation does not require Rust.

- [ ] **Step 2: Run the documentation test and verify failure**

Run:

```powershell
python test/integration/test_gdmcp_packaging.py --case docs
```

- [ ] **Step 3: Update documentation**

Add Windows and POSIX commands, explain `.gdmcp/` isolation, list release archive contents, and document checksum verification and PATH behavior.

- [ ] **Step 4: Update CI**

Keep existing Rust checks, add Python packaging test execution, and add a package dry-run or fixture-based verification that does not upload artifacts.

- [ ] **Step 5: Re-run all packaging tests**

Run:

```powershell
python test/integration/test_gdmcp_packaging.py
```

Expected: all metadata, development-install, release-install, package, and documentation cases pass.

---

### Task 6: Final verification and handoff

**Files:**
- Verify: all files from Tasks 1-5

- [ ] **Step 1: Run Python syntax and packaging tests**

```powershell
python -m py_compile test/integration/test_gdmcp_packaging.py
python test/integration/test_gdmcp_packaging.py
```

- [ ] **Step 2: Run Rust verification when Cargo is available**

```powershell
cargo fmt --manifest-path cli/gdmcp/Cargo.toml --check
cargo clippy --manifest-path cli/gdmcp/Cargo.toml --all-targets -- -D warnings
cargo test --manifest-path cli/gdmcp/Cargo.toml
cargo build --manifest-path cli/gdmcp/Cargo.toml --release --locked
```

If Cargo remains unavailable, report that limitation explicitly and rely only on CI evidence for Rust compilation.

- [ ] **Step 3: Verify release archive contents**

Run the package script in a temporary output directory and inspect archive members. Confirm no source, tests, Cargo metadata, `.git`, `.gdmcp`, or toolchain files are present.

- [ ] **Step 4: Verify workspace isolation**

Confirm `F:\gitProjects\Godot-MCP-Native` remains on `main` with the same user changes and that all generated files are confined to the PR worktree or its temporary output directory.

Git commits and PR state changes are intentionally omitted; the repository instructions require explicit user authorization for those operations.
