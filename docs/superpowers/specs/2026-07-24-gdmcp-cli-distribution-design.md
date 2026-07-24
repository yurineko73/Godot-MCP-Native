# gdmcp CLI Distribution and Packaging Design

**Status:** Approved for implementation planning
**Date:** 2026-07-24
**Repository:** `yurineko73/Godot-MCP-Native`
**Related design:** `docs/superpowers/specs/2026-07-24-gdmcp-agent-cli-design.md`

## 1. Summary

The `gdmcp` CLI must distinguish development source files from final user-facing release files. Developers need a reproducible way to build the CLI even when Rust is not installed globally. End users should receive a small prebuilt package and should not need Rust, Cargo, the repository source tree, or a project-wide PATH modification.

The repository will therefore contain a source-oriented development tree and a generated release artifact. Development installers build from source using a project-local Rust environment. The packaging tool creates a platform-specific archive containing only the executable, release installer, documentation, license, checksum, and manifest.

## 2. Goals

1. Keep Rust source, tests, Cargo metadata, and developer tooling separate from release files.
2. Provide one command to bootstrap a project-local Rust toolchain and build from source.
3. Provide one command for maintainers to validate, build, package, and checksum a release.
4. Make the final package usable without Rust or Cargo.
5. Avoid modifying the host system PATH, user Cargo configuration, or system-wide Rust installation by default.
6. Support Windows, Linux, and macOS with equivalent workflows.
7. Make package contents deterministic and auditable.

## 3. Non-goals

1. Installing Rust system-wide as a prerequisite for end users.
2. Committing compiled binaries or generated archives to the Git repository.
3. Building a VM or container sandbox. The project-local toolchain still uses the host OS, network, CPU, and native linker.
4. Supporting every package manager in the first release.

## 4. Source and Artifact Layout

The source tree remains the authoritative development input:

```text
cli/gdmcp/
├── Cargo.toml
├── Cargo.lock
├── src/                       # Rust production source
├── tests/                     # Rust unit and integration tests
├── scripts/
│   ├── install-dev.ps1        # Windows source-build installer
│   ├── install-dev.sh         # POSIX source-build installer
│   ├── package.ps1            # Windows release packager
│   └── package.sh              # POSIX release packager
├── packaging/
│   ├── install.ps1            # Installer shipped inside release archive
│   ├── install.sh
│   ├── README.md
│   └── LICENSE
└── README.md

dist/                          # Generated and ignored
└── gdmcp-<version>-<target>.<zip|tar.gz>
```

`.gdmcp/` is the project-local runtime/build directory and must be ignored:

```text
.gdmcp/
```

It may contain the local Rust bootstrap, Cargo cache, build output, installed CLI, and temporary downloads. It is never part of a release archive.

## 5. Development Installation

`install-dev.ps1` and `install-dev.sh` are for repository contributors and CI-like local builds. They accept equivalent options:

```text
--install-root <path>       Default: .gdmcp/bin
--toolchain-root <path>     Default: .gdmcp/rust
--offline                   Refuse network access
--use-system-cargo          Use cargo from PATH when available
--dry-run                   Print actions without changing files
--force                     Rebuild and replace the installed binary
```

Default behavior:

1. Resolve the repository root from the script location.
2. Set `RUSTUP_HOME` and `CARGO_HOME` below `.gdmcp/rust/`.
3. Reuse the project-local Cargo toolchain if it exists.
4. If no local toolchain exists, download `rustup-init` to a temporary location and install a minimal stable toolchain into the project-local roots.
5. Run `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, and `cargo build --release --locked`.
6. Copy the executable to `.gdmcp/bin/gdmcp` or `.gdmcp/bin/gdmcp.exe`.
7. Print an invocation command without modifying persistent PATH settings.

The scripts must not write Rust settings to the user profile unless the user explicitly selects `--use-system-cargo`.

## 6. Release Packaging

`package.ps1` and `package.sh` are maintainer-facing tools. They operate on the development source tree and produce a release archive in `dist/`.

Required inputs:

```text
--version <semver>          Required and must match Cargo.toml
--target <rust-target>      Optional; defaults to the host target
--output-dir <path>         Optional; defaults to dist/
--clean                     Remove only this invocation's staging directory
--dry-run                   Print resolved paths and commands
```

Packaging steps:

1. Validate the version and target.
2. Require `Cargo.lock` and a clean source build input.
3. Run format, Clippy, all Rust tests, and a locked release build.
4. Create an isolated staging directory below `dist/.staging/`.
5. Copy only the release executable, `packaging/install.ps1`, `packaging/install.sh`, `packaging/README.md`, `packaging/LICENSE`, and generated metadata.
6. Generate `SHA256SUMS` for every release file.
7. Generate `release-manifest.json` containing schema version, package version, target, executable name, source commit when available, and checksums.
8. Create a platform-specific archive named `gdmcp-<version>-<target>.zip` or `gdmcp-<version>-<target>.tar.gz`.
9. Remove the staging directory only when packaging completes successfully.

The package must not include `src/`, `tests/`, `Cargo.toml`, `Cargo.lock`, `.gdmcp/`, `.git/`, Rust toolchains, or Cargo caches.

## 7. Final Release Installer

The installer under `packaging/` is copied into the archive and is the only installer intended for end users. It installs the prebuilt executable into a user-selected directory, defaulting to:

```text
Windows: %LOCALAPPDATA%\gdmcp\bin
Linux/macOS: ~/.local/gdmcp/bin
```

It must:

1. Verify the archive manifest and checksum before installation when metadata is present.
2. Install only the matching executable.
3. Avoid installing Rust, Cargo, or source files.
4. Avoid persistent PATH changes by default.
5. Support an explicit `--add-path` option with a clear confirmation message.
6. Provide a `--version` and `--uninstall` operation.

Future GitHub Release downloads may be added, but the first implementation must work from a locally extracted archive without requiring an external service.

## 8. Testing and Verification

The implementation must add tests before implementation for each installer behavior:

1. Resolve repository, install, toolchain, staging, and output paths deterministically.
2. Use project-local `RUSTUP_HOME` and `CARGO_HOME` by default.
3. Do not modify PATH or user Cargo configuration by default.
4. Reuse an existing local toolchain without reinstalling it.
5. Reject `--offline` when the required local toolchain or source dependency is missing.
6. Package only the approved release file set.
7. Reject version mismatch and missing `Cargo.lock`.
8. Generate valid checksums and a manifest that matches the archive contents.
9. Install and verify a release package without Cargo.
10. Preserve clear non-zero exit codes for validation, bootstrap, build, packaging, checksum, and installation failures.

Rust behavior remains covered by `cargo test --manifest-path cli/gdmcp/Cargo.toml`. Shell-script tests may use isolated temporary directories and fake Cargo/rustup executables; they must never depend on or modify the user's global Rust installation.

## 9. Acceptance Criteria

- A contributor without Cargo can run the development installer and obtain `gdmcp` under `.gdmcp/bin/`.
- A contributor with Cargo can opt into the system toolchain without changing the default isolated behavior.
- A maintainer can run one packaging command and receive a versioned archive plus checksum and manifest.
- An end user can install from the archive without Rust, Cargo, or the repository source tree.
- Re-running the installer is idempotent.
- Release archives contain no development source or toolchain files.
- Main workspace files and persistent host PATH settings remain unchanged during default installation.
- The full Rust CI checks and package verification pass before the PR can leave Draft state.
