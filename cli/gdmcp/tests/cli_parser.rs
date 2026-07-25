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

#[test]
fn list_commands_reject_zero_limit() {
    for args in [
        vec!["scenes", "list", "--limit", "0"],
        vec!["nodes", "list", "--limit", "0"],
        vec!["scripts", "list", "--limit", "0"],
        vec!["resources", "list", "--limit", "0"],
        vec!["debug", "logs", "--limit", "0"],
        vec!["tools", "search", "query", "--limit", "0"],
    ] {
        Command::cargo_bin("gdmcp")
            .unwrap()
            .args(args)
            .assert()
            .code(2);
    }
}

#[test]
fn scripts_read_accepts_line_range() {
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args([
            "--json",
            "--url",
            "http://127.0.0.1:1",
            "--timeout",
            "1",
            "scripts",
            "read",
            "res://test.gd",
            "--lines",
            "10:50",
        ])
        .assert()
        .code(4);
}

#[test]
fn scripts_read_rejects_zero_start_line() {
    Command::cargo_bin("gdmcp")
        .unwrap()
        .args(["scripts", "read", "res://test.gd", "--lines", "0:10"])
        .assert()
        .code(2);
}

#[test]
fn scripts_read_rejects_inverted_line_range() {
    Command::cargo_bin("gdmcp")
        .unwrap()
        .args(["scripts", "read", "res://test.gd", "--lines", "20:10"])
        .assert()
        .code(2);
}

#[test]
fn scripts_read_allows_open_ended_range() {
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args([
            "--json",
            "--url",
            "http://127.0.0.1:1",
            "--timeout",
            "1",
            "scripts",
            "read",
            "res://test.gd",
            "--lines",
            "50:",
        ])
        .assert()
        .code(4);
}

#[test]
fn nodes_properties_set_is_accepted() {
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args([
            "--json",
            "--url",
            "http://127.0.0.1:1",
            "--timeout",
            "1",
            "nodes",
            "properties",
            "set",
            "/root/Player",
            "--property",
            "speed",
            "--value",
            "300",
        ])
        .assert()
        .code(4);
}

#[test]
fn nodes_get_accepts_fields() {
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args([
            "--json",
            "--url",
            "http://127.0.0.1:1",
            "--timeout",
            "1",
            "nodes",
            "get",
            "/root/Player",
            "--fields",
            "position,visible",
        ])
        .assert()
        .code(4);
}

#[test]
fn runtime_nodes_subcommands_are_accepted() {
    for subcommand in ["get", "set", "call"] {
        let mut command = Command::cargo_bin("gdmcp").unwrap();
        let mut args = vec![
            "--json",
            "--url",
            "http://127.0.0.1:1",
            "--timeout",
            "1",
            "runtime",
            "nodes",
            subcommand,
            "/root/Main",
        ];
        if subcommand == "set" {
            args.extend_from_slice(&["--property", "speed", "--value", "100"]);
        } else if subcommand == "call" {
            args.extend_from_slice(&["--method", "queue_free"]);
        }
        command.args(args).assert().code(4);
    }
}
