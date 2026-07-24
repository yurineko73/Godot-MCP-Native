use assert_cmd::Command;
use predicates::prelude::*;
use std::io::{Read, Write};
use std::net::TcpListener;
use std::sync::mpsc;
use std::thread;
use std::time::Duration;

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

#[test]
fn scripts_list_sends_limit_and_cursor_to_the_cli_api() {
    let (url, request_rx, server_thread) = spawn_mock_server();
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args([
            "--json", "--url", &url, "scripts", "list", "--limit", "5", "--cursor", "10",
        ])
        .assert()
        .success();

    let request = request_rx.recv_timeout(Duration::from_secs(5)).unwrap();
    assert!(request.contains("/cli/v1/tools/list_project_scripts/execute"));
    assert!(request.contains("\"limit\":5"));
    assert!(request.contains("\"cursor\":\"10\""));
    server_thread.join().unwrap();
}

#[test]
fn project_settings_sends_the_filter_to_the_cli_api() {
    let (url, request_rx, server_thread) = spawn_mock_server();
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args([
            "--json", "--url", &url, "project", "settings", "--filter", "display/",
        ])
        .assert()
        .success();

    let request = request_rx.recv_timeout(Duration::from_secs(5)).unwrap();
    assert!(request.contains("/cli/v1/tools/get_project_settings/execute"));
    assert!(request.contains("\"filter\":\"display/\""));
    server_thread.join().unwrap();
}

#[test]
fn batch_preview_uses_tool_and_arguments_operations() {
    let (url, request_rx, server_thread) = spawn_mock_server();
    let temp_dir = tempfile::tempdir().unwrap();
    let batch_path = temp_dir.path().join("operations.json");
    std::fs::write(
        &batch_path,
        r#"{"operations":[{"tool":"get_project_info","arguments":{}}]}"#,
    )
    .unwrap();

    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args(["--json", "--url", &url, "batch", "preview"])
        .arg(&batch_path)
        .assert()
        .success();

    let request = request_rx.recv_timeout(Duration::from_secs(5)).unwrap();
    assert!(request.contains("/cli/v1/tools/get_project_info/execute"));
    assert!(request.contains("\"arguments\":{}"));
    server_thread.join().unwrap();
}

#[test]
fn scenes_list_sends_limit_and_cursor_to_the_cli_api() {
    let (url, request_rx, server_thread) = spawn_mock_server();
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args([
            "--json", "--url", &url, "scenes", "list", "--limit", "5", "--cursor", "10",
        ])
        .assert()
        .success();

    let request = request_rx.recv_timeout(Duration::from_secs(5)).unwrap();
    assert!(request.contains("/cli/v1/tools/list_project_scenes/execute"));
    assert!(request.contains("\"limit\":5"));
    assert!(request.contains("\"cursor\":\"10\""));
    server_thread.join().unwrap();
}

#[test]
fn nodes_list_sends_limit_and_cursor_to_the_cli_api() {
    let (url, request_rx, server_thread) = spawn_mock_server();
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args([
            "--json", "--url", &url, "nodes", "list", "--limit", "5", "--cursor", "10",
        ])
        .assert()
        .success();

    let request = request_rx.recv_timeout(Duration::from_secs(5)).unwrap();
    assert!(request.contains("/cli/v1/tools/list_nodes/execute"));
    assert!(request.contains("\"limit\":5"));
    assert!(request.contains("\"cursor\":\"10\""));
    server_thread.join().unwrap();
}

#[test]
fn resources_list_sends_cursor_to_the_cli_api() {
    let (url, request_rx, server_thread) = spawn_mock_server();
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args([
            "--json",
            "--url",
            &url,
            "resources",
            "list",
            "--limit",
            "5",
            "--cursor",
            "10",
        ])
        .assert()
        .success();

    let request = request_rx.recv_timeout(Duration::from_secs(5)).unwrap();
    assert!(request.contains("/cli/v1/tools/list_project_resources/execute"));
    assert!(request.contains("\"limit\":5"));
    assert!(request.contains("\"cursor\":\"10\""));
    server_thread.join().unwrap();
}

fn spawn_mock_server() -> (String, mpsc::Receiver<String>, thread::JoinHandle<()>) {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let address = listener.local_addr().unwrap();
    let (request_tx, request_rx) = mpsc::channel();
    let server_thread = thread::spawn(move || {
        let (mut stream, _) = listener.accept().unwrap();
        let mut request = Vec::new();
        let mut buffer = [0_u8; 4096];
        loop {
            let bytes_read = stream.read(&mut buffer).unwrap();
            if bytes_read == 0 {
                break;
            }
            request.extend_from_slice(&buffer[..bytes_read]);
            if request.windows(4).any(|window| window == b"\r\n\r\n") {
                let headers_end = request
                    .windows(4)
                    .position(|window| window == b"\r\n\r\n")
                    .unwrap();
                let headers = String::from_utf8_lossy(&request[..headers_end]);
                let content_length = headers
                    .lines()
                    .find_map(|line| line.strip_prefix("Content-Length: "))
                    .and_then(|value| value.trim().parse::<usize>().ok())
                    .unwrap_or(0);
                if request.len() >= headers_end + 4 + content_length {
                    break;
                }
            }
        }
        request_tx
            .send(String::from_utf8_lossy(&request).into_owned())
            .unwrap();

        let body = r#"{"schema_version":1,"ok":true,"data":{},"meta":{"truncated":false,"next_cursor":null}}"#;
        let response = format!(
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
            body.len(),
            body
        );
        stream.write_all(response.as_bytes()).unwrap();
    });
    (format!("http://{address}"), request_rx, server_thread)
}
