use assert_cmd::Command;
use predicates::prelude::*;

#[test]
fn explicit_url_wins_over_environment() {
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .env("GODOT_MCP_URL", "not-a-url")
        .args([
            "--json",
            "--url",
            "http://127.0.0.1:1",
            "--timeout",
            "1",
            "doctor",
        ])
        .assert()
        .code(4)
        .stdout(predicate::str::contains("SERVICE_UNREACHABLE"));
}
