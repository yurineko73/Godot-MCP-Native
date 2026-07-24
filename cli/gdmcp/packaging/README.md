# gdmcp release package

This directory is a self-contained release package for the `gdmcp` executable.

PowerShell:

```powershell
.\install.ps1
```

POSIX shell:

```sh
./install.sh
```

Both installers verify `gdmcp` against `SHA256SUMS` before copying it. They do not modify persistent PATH by default. Use `--add-path` to print the directory that can be added manually, or `-Uninstall`/`--uninstall` to remove the installed executable.

The package contains a prebuilt executable and does not require Rust.

The Windows PowerShell installer has been validated. The POSIX installer is provided for Linux and macOS but has not been end-to-end validated yet.
