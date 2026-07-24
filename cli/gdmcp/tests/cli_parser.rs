use assert_cmd::Command;
use predicates::prelude::*;

#[test]
fn help_lists_progressive_discovery_commands() {
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .arg("--help")
        .assert()
        .success()
        .stdout(predicate::str::contains("tools"))
        .stdout(predicate::str::contains("tool-call"))
        .stdout(predicate::str::contains("doctor"));
}

#[test]
fn tool_call_rejects_two_argument_sources() {
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args([
            "tool-call",
            "get_editor_state",
            "--args-json",
            "{}",
            "--args-file",
            "request.json",
        ])
        .assert()
        .failure();
}

#[test]
fn scripts_list_accepts_limit_and_cursor() {
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args([
            "--json",
            "--url",
            "http://127.0.0.1:1",
            "--timeout",
            "1",
            "scripts",
            "list",
            "--limit",
            "5",
            "--cursor",
            "10",
        ])
        .assert()
        .code(4);
}

#[test]
fn project_settings_requires_a_filter() {
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args(["--json", "project", "settings"])
        .assert()
        .code(2)
        .stdout(predicate::str::contains("--filter"));
}

#[test]
fn project_settings_accepts_a_filter() {
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args([
            "--json",
            "--url",
            "http://127.0.0.1:1",
            "--timeout",
            "1",
            "project",
            "settings",
            "--filter",
            "display/",
        ])
        .assert()
        .code(4);
}

#[test]
fn scenes_list_accepts_limit_and_cursor() {
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args([
            "--json",
            "--url",
            "http://127.0.0.1:1",
            "--timeout",
            "1",
            "scenes",
            "list",
            "--limit",
            "5",
            "--cursor",
            "10",
        ])
        .assert()
        .code(4);
}

#[test]
fn nodes_list_accepts_limit_and_cursor() {
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args([
            "--json",
            "--url",
            "http://127.0.0.1:1",
            "--timeout",
            "1",
            "nodes",
            "list",
            "--limit",
            "5",
            "--cursor",
            "10",
        ])
        .assert()
        .code(4);
}

#[test]
fn resources_list_accepts_a_cursor() {
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args([
            "--json",
            "--url",
            "http://127.0.0.1:1",
            "--timeout",
            "1",
            "resources",
            "list",
            "--limit",
            "5",
            "--cursor",
            "10",
        ])
        .assert()
        .code(4);
}
