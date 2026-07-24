use assert_cmd::Command;
use predicates::prelude::*;

#[test]
fn unreachable_service_returns_json_error() {
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
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
