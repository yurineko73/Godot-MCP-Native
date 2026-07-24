import argparse
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
CLI_ROOT = REPO_ROOT / "cli" / "gdmcp"
SCRIPTS_ROOT = CLI_ROOT / "scripts"
PACKAGING_ROOT = CLI_ROOT / "packaging"


def run_powershell(script: Path, *arguments: str, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    if os.name != "nt":
        raise unittest.SkipTest("Windows PowerShell packaging tests are Windows-only")
    powershell = shutil.which("pwsh") or shutil.which("powershell")
    if powershell is None:
        raise unittest.SkipTest("PowerShell is not available")
    command = [
        powershell,
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(script),
        *arguments,
    ]
    return subprocess.run(
        command,
        cwd=REPO_ROOT,
        env=env,
        text=True,
        capture_output=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )


def combined_output(result: subprocess.CompletedProcess[str]) -> str:
    return f"{result.stdout}\n{result.stderr}".lower()


class GdmcpPackagingTests(unittest.TestCase):
    def test_metadata(self) -> None:
        lockfile = CLI_ROOT / "Cargo.lock"
        toolchain = CLI_ROOT / "rust-toolchain.toml"
        ignore_file = REPO_ROOT / ".gitignore"

        self.assertTrue(lockfile.is_file(), "Cargo.lock must be checked in")
        self.assertTrue(toolchain.is_file(), "rust-toolchain.toml must be checked in")
        self.assertIn('channel = "stable"', toolchain.read_text(encoding="utf-8"))
        ignore_text = ignore_file.read_text(encoding="utf-8")
        self.assertIn(".gdmcp/", ignore_text)
        self.assertIn("dist/", ignore_text)

    def test_dev_installer_dry_run(self) -> None:
        script = SCRIPTS_ROOT / "install-dev.ps1"
        with tempfile.TemporaryDirectory() as temp_dir:
            install_root = Path(temp_dir) / "bin"
            toolchain_root = Path(temp_dir) / "rust"
            result = run_powershell(
                script,
                "-InstallRoot",
                str(install_root),
                "-ToolchainRoot",
                str(toolchain_root),
                "-DryRun",
            )

        self.assertEqual(result.returncode, 0, combined_output(result))
        output = combined_output(result)
        self.assertIn(str(install_root).lower(), output)
        self.assertIn(str(toolchain_root).lower(), output)
        self.assertNotIn("setx", output)
        self.assertNotIn("[environment]::setenvironmentvariable", output)

    def test_dev_installer_offline_rejects_missing_toolchain(self) -> None:
        script = SCRIPTS_ROOT / "install-dev.ps1"
        with tempfile.TemporaryDirectory() as temp_dir:
            result = run_powershell(
                script,
                "-InstallRoot",
                str(Path(temp_dir) / "bin"),
                "-ToolchainRoot",
                str(Path(temp_dir) / "rust"),
                "-Offline",
            )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("offline", combined_output(result))

    def test_release_installer_files_exist(self) -> None:
        required = [
            PACKAGING_ROOT / "install.ps1",
            PACKAGING_ROOT / "install.sh",
            PACKAGING_ROOT / "README.md",
            PACKAGING_ROOT / "LICENSE",
        ]
        for path in required:
            self.assertTrue(path.is_file(), f"Missing release file: {path}")

        installer_text = (PACKAGING_ROOT / "install.ps1").read_text(encoding="utf-8").lower()
        self.assertIn("sha256", installer_text)
        self.assertIn("uninstall", installer_text)
        self.assertIn("installroot", installer_text)

    def test_release_installer_installs_verified_binary(self) -> None:
        installer = PACKAGING_ROOT / "install.ps1"
        with tempfile.TemporaryDirectory() as temp_dir:
            archive_root = Path(temp_dir) / "archive"
            install_root = Path(temp_dir) / "install"
            archive_root.mkdir()
            executable = archive_root / "gdmcp.exe"
            executable.write_bytes(b"fake-gdmcp")
            digest = hashlib.sha256(executable.read_bytes()).hexdigest()
            (archive_root / "SHA256SUMS").write_text(
                f"{digest}  gdmcp.exe\n",
                encoding="utf-8",
            )
            (archive_root / "release-manifest.json").write_text(
                json.dumps(
                    {
                        "schema_version": 1,
                        "package": "gdmcp",
                        "version": "0.1.0",
                        "target": "test-target",
                        "executable": "gdmcp.exe",
                    }
                ),
                encoding="utf-8",
            )
            shutil.copy2(installer, archive_root / "install.ps1")
            result = run_powershell(
                archive_root / "install.ps1",
                "-InstallRoot",
                str(install_root),
            )
            installed_bytes = (install_root / "gdmcp.exe").read_bytes()

        self.assertEqual(result.returncode, 0, combined_output(result))
        self.assertEqual(installed_bytes, b"fake-gdmcp")

    def test_package_rejects_version_mismatch(self) -> None:
        script = SCRIPTS_ROOT / "package.ps1"
        with tempfile.TemporaryDirectory() as temp_dir:
            result = run_powershell(
                script,
                "-Version",
                "9.9.9",
                "-Target",
                "test-target",
                "-OutputDir",
                temp_dir,
            )

        self.assertNotEqual(result.returncode, 0)
        output = combined_output(result)
        self.assertIn("version", output)
        self.assertIn("mismatch", output)

    def test_package_archive_contents(self) -> None:
        script = SCRIPTS_ROOT / "package.ps1"
        with tempfile.TemporaryDirectory() as temp_dir:
            fake_bin = Path(temp_dir) / "fake-bin"
            fake_bin.mkdir()
            fake_cargo = fake_bin / "cargo.cmd"
            fake_cargo.write_text(
                "@echo off\n"
                "if \"%1\"==\"build\" (\n"
                "  if not exist cli\\gdmcp\\target\\release mkdir cli\\gdmcp\\target\\release\n"
                "  >cli\\gdmcp\\target\\release\\gdmcp.exe echo fake-gdmcp\n"
                ")\n"
                "exit /b 0\n",
                encoding="utf-8",
            )
            env = os.environ.copy()
            path_key = next(key for key in env if key.lower() == "path")
            env[path_key] = str(fake_bin) + os.pathsep + env[path_key]
            output_dir = Path(temp_dir) / "dist"
            result = run_powershell(
                script,
                "-Version",
                "0.1.0",
                "-Target",
                "test-target",
                "-OutputDir",
                str(output_dir),
                env=env,
            )

            self.assertEqual(result.returncode, 0, combined_output(result))
            archives = list(output_dir.glob("gdmcp-0.1.0-test-target.zip"))
            self.assertEqual(len(archives), 1)
            with zipfile.ZipFile(archives[0]) as archive:
                names = set(archive.namelist())

        self.assertEqual(
            names,
            {
                "gdmcp.exe",
                "install.ps1",
                "install.sh",
                "README.md",
                "LICENSE",
                "SHA256SUMS",
                "release-manifest.json",
            },
        )

    def test_documentation_separates_development_and_release(self) -> None:
        readme = (CLI_ROOT / "README.md").read_text(encoding="utf-8").lower()
        self.assertIn("install-dev", readme)
        self.assertIn("package.ps1", readme)
        self.assertIn("does not require rust", readme)


def selected_suite(case: str | None) -> unittest.TestSuite:
    loader = unittest.TestLoader()
    if case is None:
        return loader.loadTestsFromTestCase(GdmcpPackagingTests)
    groups = {
        "metadata": ["test_metadata"],
        "dev-install": [
            "test_dev_installer_dry_run",
            "test_dev_installer_offline_rejects_missing_toolchain",
        ],
        "release-install": [
            "test_release_installer_files_exist",
            "test_release_installer_installs_verified_binary",
        ],
        "package": [
            "test_package_rejects_version_mismatch",
            "test_package_archive_contents",
        ],
        "docs": ["test_documentation_separates_development_and_release"],
    }
    try:
        names = groups[case]
    except KeyError as error:
        raise ValueError(f"Unknown case: {case}") from error
    return unittest.TestSuite(
        GdmcpPackagingTests(name) for name in names
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=["metadata", "dev-install", "release-install", "package", "docs"])
    arguments = parser.parse_args()
    result = unittest.TextTestRunner(verbosity=2).run(selected_suite(arguments.case))
    raise SystemExit(0 if result.wasSuccessful() else 1)
