use assert_cmd::Command;
use predicates::prelude::*;

#[test]
fn non_object_tool_arguments_are_rejected_before_network_access() {
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args([
            "--json",
            "tool-call",
            "get_editor_state",
            "--args-json",
            "[]",
        ])
        .assert()
        .code(2)
        .stdout(predicate::str::contains("INVALID_ARGUMENT"));
}
