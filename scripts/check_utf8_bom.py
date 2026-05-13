from __future__ import annotations

from pathlib import Path


TEXT_EXTENSIONS = {
    ".c",
    ".cc",
    ".cfg",
    ".cpp",
    ".cs",
    ".css",
    ".gd",
    ".gdshader",
    ".gitignore",
    ".gitattributes",
    ".go",
    ".h",
    ".hpp",
    ".html",
    ".ini",
    ".java",
    ".js",
    ".json",
    ".md",
    ".mjs",
    ".py",
    ".rs",
    ".sh",
    ".sql",
    ".svg",
    ".toml",
    ".ts",
    ".tsx",
    ".tres",
    ".tscn",
    ".txt",
    ".xml",
    ".yaml",
    ".yml",
}

SKIP_DIRS = {
    ".git",
    ".godot",
    ".idea",
    ".vscode",
    "node_modules",
    "dist",
    "build",
    "bin",
    "obj",
    "__pycache__",
}


def should_check(path: Path) -> bool:
    if not path.is_file():
        return False
    if any(part in SKIP_DIRS for part in path.parts):
        return False
    if path.name in {".editorconfig", ".pre-commit-config.yaml"}:
        return True
    return path.suffix.lower() in TEXT_EXTENSIONS


def has_utf8_bom(path: Path) -> bool:
    with path.open("rb") as handle:
        return handle.read(3) == b"\xef\xbb\xbf"


def main() -> int:
    root = Path.cwd()
    offenders: list[Path] = []

    for path in root.rglob("*"):
        if should_check(path) and has_utf8_bom(path):
            offenders.append(path.relative_to(root))

    if offenders:
        print("UTF-8 BOM check failed. These files must be saved as UTF-8 without BOM:")
        for path in sorted(offenders):
            print(f"- {path.as_posix()}")
        return 1

    print("UTF-8 BOM check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
