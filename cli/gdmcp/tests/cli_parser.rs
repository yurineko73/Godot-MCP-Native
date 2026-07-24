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
