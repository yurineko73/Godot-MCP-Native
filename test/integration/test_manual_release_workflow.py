from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = REPO_ROOT / ".github" / "workflows" / "manual-gdmcp-release.yml"


class ManualReleaseWorkflowTests(unittest.TestCase):
    def test_actions_artifact_names_include_release_version(self) -> None:
        text = WORKFLOW.read_text(encoding="utf-8")

        self.assertIn(
            "name: gdmcp-${{ needs.prepare.outputs.version }}-${{ matrix.target }}",
            text,
        )
        self.assertIn(
            "name: godot-mcp-native-${{ needs.prepare.outputs.version }}",
            text,
        )

    def test_uploaded_file_paths_match_installer_download_contract(self) -> None:
        text = WORKFLOW.read_text(encoding="utf-8")

        self.assertIn(
            "path: dist/gdmcp-${{ needs.prepare.outputs.version }}-${{ matrix.target }}.zip",
            text,
        )
        self.assertIn(
            "path: dist/godot-mcp-native-${{ needs.prepare.outputs.version }}.zip",
            text,
        )

    def test_plugin_zip_wraps_addons_in_versioned_root(self) -> None:
        # Godot's asset installer detects a single root directory and strips it by
        # default ("Ignore asset root"). Without the versioned wrapper the zip root
        # is addons/, which gets stripped and installs to res://godot_mcp/ instead
        # of res://addons/godot_mcp/.
        text = WORKFLOW.read_text(encoding="utf-8")

        self.assertIn(
            'root = Path(f"godot-mcp-native-{version}")',
            text,
        )
        self.assertIn(
            'archive_name = (root / "addons/godot_mcp" / relative).as_posix()',
            text,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
