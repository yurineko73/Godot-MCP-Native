import json
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
INSTALLER_PATH = REPO_ROOT / "addons" / "godot_mcp" / "ui" / "mcp_cli_installer.gd"
RELEASE_CONFIG_PATH = REPO_ROOT / "addons" / "godot_mcp" / "cli_release.json"
POWERSHELL_INSTALLER_PATH = REPO_ROOT / "cli" / "gdmcp" / "packaging" / "install.ps1"
POSIX_INSTALLER_PATH = REPO_ROOT / "cli" / "gdmcp" / "packaging" / "install.sh"


class CliInstallerContractTests(unittest.TestCase):
    def test_supported_release_targets_include_linux_arm64(self) -> None:
        config = json.loads(RELEASE_CONFIG_PATH.read_text(encoding="utf-8"))
        self.assertEqual(config["targets"]["aarch64-unknown-linux-gnu"], "gdmcp")

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

    def test_packaged_installers_validate_expected_manifest_identity(self) -> None:
        powershell = POWERSHELL_INSTALLER_PATH.read_text(encoding="utf-8")
        posix = POSIX_INSTALLER_PATH.read_text(encoding="utf-8")

        self.assertIn("ExpectedVersion", powershell)
        self.assertIn("ExpectedTarget", powershell)
        self.assertIn('package', powershell)
        self.assertIn("--expected-version", posix)
        self.assertIn("--expected-target", posix)
        self.assertIn('package', posix)


if __name__ == "__main__":
    unittest.main(verbosity=2)
