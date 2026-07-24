use assert_cmd::Command;
use predicates::prelude::*;

#[test]
fn destructive_node_delete_requires_apply_before_network_access() {
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args(["--json", "nodes", "delete", "/root/Main/Enemy"])
        .assert()
        .code(6)
        .stdout(predicate::str::contains("PERMISSION_REQUIRED"));
}

#[test]
fn script_replace_requires_apply_before_reading_content() {
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args([
            "--json",
            "scripts",
            "replace",
            "res://player.gd",
            "--content-file",
            "missing.gd",
        ])
        .assert()
        .code(6)
        .stdout(predicate::str::contains("PERMISSION_REQUIRED"));
}
