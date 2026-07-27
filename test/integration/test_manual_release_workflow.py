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


if __name__ == "__main__":
    unittest.main(verbosity=2)
