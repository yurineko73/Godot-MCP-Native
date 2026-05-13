from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
CLASSIFIER_PATH = ROOT / "addons/godot_mcp/native_mcp/mcp_tool_classifier.gd"
SERVER_NATIVE_PATH = ROOT / "addons/godot_mcp/mcp_server_native.gd"
TOOLS_REFERENCE_PATH = ROOT / "docs/current/tools-reference.md"

CLASSIFIER_ENTRY_RE = re.compile(
    r'\{"name": "([^"]+)", "category": "(core|supplementary)", "group": "([^"]+)"\}'
)
HEADING_RE = re.compile(r"^###\s+(\d+)\.\s+([a-z0-9_]+)\s*$", re.MULTILINE)
OVERVIEW_ROW_RE = re.compile(
    r"^\| \[(Node Tools|Script Tools|Scene Tools|Editor Tools|Debug Tools|Project Tools)\]\(#.+?\) \| (\d+) \| (\d+) \| (\d+) \|",
    re.MULTILINE,
)
TOP_SUMMARY_RE = re.compile(r"\*\*(\d+) 个工具\*\*")
BOTTOM_SUMMARY_RE = re.compile(r"\*\*(\d+) 个工具\*\*（(\d+) 核心 \+ (\d+) 补充）")
RESOURCE_ENTRY_RE = re.compile(
    r'register_resource\(\s*"([^"]+)",\s*"([^"]+)",\s*"([^"]+)",\s*Callable\(self, "[^"]+"\),\s*"([^"]+)"\s*\)',
    re.MULTILINE,
)
RESOURCE_SUMMARY_RE = re.compile(r"\*\*(\d+) 个 MCP 资源\*\*")
RESOURCE_ROW_RE = re.compile(
    r"^\| `([^`]+)` \| ([^|]+?) \| `([^`]+)` \| ([^|]+?) \|$",
    re.MULTILINE,
)


@dataclass(frozen=True)
class ToolEntry:
    name: str
    category: str
    group: str


@dataclass(frozen=True)
class ResourceEntry:
    uri: str
    name: str
    mime_type: str
    description: str


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def load_classifier_entries() -> list[ToolEntry]:
    text = read_text(CLASSIFIER_PATH)
    return [ToolEntry(*match.groups()) for match in CLASSIFIER_ENTRY_RE.finditer(text)]


def load_tools_reference_headings() -> list[tuple[int, str]]:
    text = read_text(TOOLS_REFERENCE_PATH)
    return [(int(number), name) for number, name in HEADING_RE.findall(text)]


def load_server_resource_entries() -> list[ResourceEntry]:
    text = read_text(SERVER_NATIVE_PATH)
    return [ResourceEntry(*match.groups()) for match in RESOURCE_ENTRY_RE.finditer(text)]


def load_overview_rows() -> dict[str, tuple[int, int, int]]:
    text = read_text(TOOLS_REFERENCE_PATH)
    return {
        label: (int(core), int(supplementary), int(total))
        for label, core, supplementary, total in OVERVIEW_ROW_RE.findall(text)
    }


def load_resource_rows() -> list[ResourceEntry]:
    text = read_text(TOOLS_REFERENCE_PATH)
    return [
        ResourceEntry(uri, name.strip(), mime_type, description.strip())
        for uri, name, mime_type, description in RESOURCE_ROW_RE.findall(text)
        if uri.startswith("godot://")
    ]


def compute_family_counts(entries: list[ToolEntry]) -> dict[str, tuple[int, int, int]]:
    counts: dict[str, list[int]] = {
        "Node Tools": [0, 0, 0],
        "Script Tools": [0, 0, 0],
        "Scene Tools": [0, 0, 0],
        "Editor Tools": [0, 0, 0],
        "Debug Tools": [0, 0, 0],
        "Project Tools": [0, 0, 0],
    }

    for entry in entries:
        family = family_for_group(entry.group)
        bucket = counts[family]
        if entry.category == "core":
            bucket[0] += 1
        else:
            bucket[1] += 1
        bucket[2] += 1

    return {family: tuple(values) for family, values in counts.items()}


def family_for_group(group: str) -> str:
    if group.startswith("Node"):
        return "Node Tools"
    if group.startswith("Script"):
        return "Script Tools"
    if group.startswith("Scene"):
        return "Scene Tools"
    if group.startswith("Editor"):
        return "Editor Tools"
    if group.startswith("Debug"):
        return "Debug Tools"
    if group.startswith("Project"):
        return "Project Tools"
    raise ValueError(f"Unrecognized group family: {group}")


def check_summary_text(text: str, total_tools: int, core_tools: int, supplementary_tools: int) -> list[str]:
    errors: list[str] = []

    top_match = TOP_SUMMARY_RE.search(text)
    if top_match is None:
        errors.append("Top tools-reference summary is missing the published total tool count.")
    elif int(top_match.group(1)) != total_tools:
        errors.append(
            f"Top tools-reference summary says {top_match.group(1)} tools but classifier defines {total_tools}."
        )

    bottom_match = BOTTOM_SUMMARY_RE.search(text)
    if bottom_match is None:
        errors.append(
            "Bottom tools-reference summary is missing the published total/core/supplementary counts."
        )
    else:
        published_total, published_core, published_supplementary = map(int, bottom_match.groups())
        if published_total != total_tools or published_core != core_tools or published_supplementary != supplementary_tools:
            errors.append(
                "Bottom tools-reference summary does not match classifier totals: "
                f"published total/core/supplementary={published_total}/{published_core}/{published_supplementary}, "
                f"expected={total_tools}/{core_tools}/{supplementary_tools}."
            )

    return errors


def check_headings(entries: list[ToolEntry], headings: list[tuple[int, str]]) -> list[str]:
    errors: list[str] = []

    if len(headings) != len(entries):
        errors.append(
            f"tools-reference documents {len(headings)} numbered tool sections but classifier defines {len(entries)} tools."
        )

    for index, (number, _) in enumerate(headings, start=1):
        if number != index:
            errors.append(f"tools-reference heading numbering drift at position {index}: found {number}.")
            break

    classifier_name_counts: dict[str, int] = {}
    for entry in entries:
        classifier_name_counts[entry.name] = classifier_name_counts.get(entry.name, 0) + 1
    duplicate_classifier_names = sorted(name for name, count in classifier_name_counts.items() if count > 1)
    if duplicate_classifier_names:
        errors.append(
            "classifier defines duplicate tool names: " + ", ".join(duplicate_classifier_names[:10])
        )

    heading_name_counts: dict[str, int] = {}
    for _, name in headings:
        heading_name_counts[name] = heading_name_counts.get(name, 0) + 1
    duplicate_documented_names = sorted(name for name, count in heading_name_counts.items() if count > 1)
    if duplicate_documented_names:
        errors.append(
            "tools-reference documents duplicate tool sections: " + ", ".join(duplicate_documented_names[:10])
        )

    expected_names = set(classifier_name_counts.keys())
    documented_names = set(heading_name_counts.keys())
    missing_names = sorted(expected_names - documented_names)
    extra_names = sorted(documented_names - expected_names)

    if missing_names:
        errors.append(
            "tools-reference is missing classified tools: " + ", ".join(missing_names[:10])
        )
    if extra_names:
        errors.append(
            "tools-reference documents tools not present in classifier: " + ", ".join(extra_names[:10])
        )

    return errors


def check_overview_rows(expected_rows: dict[str, tuple[int, int, int]], actual_rows: dict[str, tuple[int, int, int]]) -> list[str]:
    errors: list[str] = []

    for family, expected_counts in expected_rows.items():
        actual_counts = actual_rows.get(family)
        if actual_counts is None:
            errors.append(f"tools-reference overview table is missing the '{family}' row.")
            continue
        if actual_counts != expected_counts:
            errors.append(
                f"tools-reference overview row drift for {family}: "
                f"published core/supplementary/total={actual_counts[0]}/{actual_counts[1]}/{actual_counts[2]}, "
                f"expected={expected_counts[0]}/{expected_counts[1]}/{expected_counts[2]}."
            )

    return errors


def check_classifier_groups(entries: list[ToolEntry]) -> list[str]:
    errors: list[str] = []
    seen_groups: set[str] = set()

    for entry in entries:
        try:
            family_for_group(entry.group)
        except ValueError as exc:
            errors.append(str(exc))
        seen_groups.add(entry.group)

    if not seen_groups:
        errors.append("classifier does not define any tool groups.")

    return errors


def check_resource_catalog(text: str, expected_resources: list[ResourceEntry], documented_resources: list[ResourceEntry]) -> list[str]:
    errors: list[str] = []

    summary_match = RESOURCE_SUMMARY_RE.search(text)
    if summary_match is None:
        errors.append("MCP resource summary is missing from tools-reference.")
    elif int(summary_match.group(1)) != len(expected_resources):
        errors.append(
            f"MCP resource summary says {summary_match.group(1)} resources but server registers {len(expected_resources)}."
        )

    expected_uri_counts: dict[str, int] = {}
    for entry in expected_resources:
        expected_uri_counts[entry.uri] = expected_uri_counts.get(entry.uri, 0) + 1
    duplicate_registered_uris = sorted(uri for uri, count in expected_uri_counts.items() if count > 1)
    if duplicate_registered_uris:
        errors.append("server registers duplicate resources: " + ", ".join(duplicate_registered_uris))

    documented_uri_counts: dict[str, int] = {}
    for entry in documented_resources:
        documented_uri_counts[entry.uri] = documented_uri_counts.get(entry.uri, 0) + 1
    duplicate_documented_uris = sorted(uri for uri, count in documented_uri_counts.items() if count > 1)
    if duplicate_documented_uris:
        errors.append("tools-reference documents duplicate resources: " + ", ".join(duplicate_documented_uris))

    expected_by_uri = {entry.uri: entry for entry in expected_resources}
    documented_by_uri = {entry.uri: entry for entry in documented_resources}

    missing_uris = sorted(expected_by_uri.keys() - documented_by_uri.keys())
    extra_uris = sorted(documented_by_uri.keys() - expected_by_uri.keys())

    if missing_uris:
        errors.append("tools-reference is missing registered resources: " + ", ".join(missing_uris))
    if extra_uris:
        errors.append("tools-reference documents unknown resources: " + ", ".join(extra_uris))

    for uri, expected in expected_by_uri.items():
        documented = documented_by_uri.get(uri)
        if documented is None:
            continue
        if documented.name != expected.name:
            errors.append(
                f"Resource name drift for {uri}: documented '{documented.name}' but server registers '{expected.name}'."
            )
        if documented.mime_type != expected.mime_type:
            errors.append(
                f"Resource MIME drift for {uri}: documented '{documented.mime_type}' but server registers '{expected.mime_type}'."
            )
        if documented.description != expected.description:
            errors.append(
                f"Resource description drift for {uri}: documented '{documented.description}' but server registers '{expected.description}'."
            )

    return errors


def main() -> int:
    entries = load_classifier_entries()
    resource_entries = load_server_resource_entries()
    tools_reference_text = read_text(TOOLS_REFERENCE_PATH)
    headings = load_tools_reference_headings()
    overview_rows = load_overview_rows()
    resource_rows = load_resource_rows()

    total_tools = len(entries)
    core_tools = sum(1 for entry in entries if entry.category == "core")
    supplementary_tools = total_tools - core_tools
    family_counts = compute_family_counts(entries)

    errors: list[str] = []
    errors.extend(check_summary_text(tools_reference_text, total_tools, core_tools, supplementary_tools))
    errors.extend(check_headings(entries, headings))
    errors.extend(check_classifier_groups(entries))
    errors.extend(check_overview_rows(family_counts, overview_rows))
    errors.extend(check_resource_catalog(tools_reference_text, resource_entries, resource_rows))

    if errors:
        print("Tools reference drift check failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print(
        "Tools reference drift check passed. "
        f"total={total_tools}, core={core_tools}, supplementary={supplementary_tools}, "
        f"numbered_sections={len(headings)}, resources={len(resource_entries)}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
