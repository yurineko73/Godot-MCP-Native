import hashlib
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
INSTALLER_PATH = REPO_ROOT / "addons" / "godot_mcp" / "ui" / "mcp_cli_installer.gd"
RELEASE_CONFIG_PATH = REPO_ROOT / "addons" / "godot_mcp" / "cli_release.json"
POWERSHELL_INSTALLER_PATH = REPO_ROOT / "cli" / "gdmcp" / "packaging" / "install.ps1"
POSIX_INSTALLER_PATH = REPO_ROOT / "cli" / "gdmcp" / "packaging" / "install.sh"


class CliInstallerContractTests(unittest.TestCase):
    def test_supported_release_target_matrix(self) -> None:
        config = json.loads(RELEASE_CONFIG_PATH.read_text(encoding="utf-8"))
        self.assertEqual(
            config["targets"],
            {
                "x86_64-pc-windows-msvc": "gdmcp.exe",
                "x86_64-unknown-linux-gnu": "gdmcp",
                "aarch64-unknown-linux-gnu": "gdmcp",
                "aarch64-apple-darwin": "gdmcp",
                "x86_64-apple-darwin": "gdmcp",
            },
        )

    def test_ui_uses_godot_architecture_and_platform_install_scripts(self) -> None:
        installer = INSTALLER_PATH.read_text(encoding="utf-8")

        self.assertIn("Engine.get_architecture_name()", installer)
        self.assertNotIn("OS.get_processor_name()", installer)
        self.assertIn('"aarch64-unknown-linux-gnu"', installer)
        self.assertIn('"aarch64-apple-darwin"', installer)
        self.assertIn('"x86_64-apple-darwin"', installer)
        self.assertIn('"x86_64-unknown-linux-gnu"', installer)
        self.assertIn('"install.ps1"', installer)
        self.assertIn('"install.sh"', installer)
        self.assertIn("OS.execute", installer)
        self.assertIn("ExpectedVersion", installer)
        self.assertIn("expected-version", installer)
        self.assertIn("exit_code", installer)
        self.assertIn('PackedStringArray(["--version"])', installer)

    def test_packaged_installers_validate_expected_manifest_identity(self) -> None:
        powershell = POWERSHELL_INSTALLER_PATH.read_text(encoding="utf-8")
        posix = POSIX_INSTALLER_PATH.read_text(encoding="utf-8")

        self.assertIn("ExpectedVersion", powershell)
        self.assertIn("ExpectedTarget", powershell)
        self.assertIn("schema_version", powershell)
        self.assertIn("package", powershell)
        self.assertIn("--expected-version", posix)
        self.assertIn("--expected-target", posix)
        self.assertIn("schema_version", posix)
        self.assertIn("package", posix)

    @unittest.skipIf(os.name == "nt", "POSIX installer test requires /bin/sh")
    def test_posix_installer_verifies_identity_checksum_and_permissions(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            archive_root = Path(temp_dir) / "archive"
            install_root = Path(temp_dir) / "installed"
            archive_root.mkdir()
            executable = archive_root / "gdmcp"
            original_bytes = b"#!/bin/sh\necho gdmcp 1.2.3\n"
            executable.write_bytes(original_bytes)
            digest = hashlib.sha256(original_bytes).hexdigest()
            (archive_root / "SHA256SUMS").write_text(
                f"{digest}  gdmcp\n",
                encoding="utf-8",
            )
            (archive_root / "release-manifest.json").write_text(
                json.dumps(
                    {
                        "schema_version": 1,
                        "package": "gdmcp",
                        "version": "1.2.3",
                        "target": "aarch64-unknown-linux-gnu",
                        "executable": "gdmcp",
                    }
                ),
                encoding="utf-8",
            )
            installer = archive_root / "install.sh"
            installer.write_bytes(POSIX_INSTALLER_PATH.read_bytes())

            result = subprocess.run(
                [
                    "/bin/sh",
                    str(installer),
                    "--install-root",
                    str(install_root),
                    "--expected-version",
                    "1.2.3",
                    "--expected-target",
                    "aarch64-unknown-linux-gnu",
                ],
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            installed = install_root / "gdmcp"
            self.assertEqual(installed.read_bytes(), original_bytes)
            self.assertTrue(os.access(installed, os.X_OK))

            mismatch_root = Path(temp_dir) / "mismatch"
            mismatch = subprocess.run(
                [
                    "/bin/sh",
                    str(installer),
                    "--install-root",
                    str(mismatch_root),
                    "--expected-version",
                    "1.2.3",
                    "--expected-target",
                    "x86_64-unknown-linux-gnu",
                ],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertNotEqual(mismatch.returncode, 0)
            self.assertIn("target mismatch", (mismatch.stdout + mismatch.stderr).lower())
            self.assertFalse((mismatch_root / "gdmcp").exists())

            executable.write_bytes(original_bytes + b"# tampered\n")
            tampered_root = Path(temp_dir) / "tampered"
            tampered = subprocess.run(
                [
                    "/bin/sh",
                    str(installer),
                    "--install-root",
                    str(tampered_root),
                    "--expected-version",
                    "1.2.3",
                    "--expected-target",
                    "aarch64-unknown-linux-gnu",
                ],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertNotEqual(tampered.returncode, 0)
            self.assertIn("sha-256 verification failed", (tampered.stdout + tampered.stderr).lower())
            self.assertFalse((tampered_root / "gdmcp").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
