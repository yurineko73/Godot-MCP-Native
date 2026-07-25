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
fn project_settings_trims_the_filter_before_network_access() {
    let (url, request_rx, server_thread) = spawn_mock_server();
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args([
            "--json",
            "--url",
            &url,
            "project",
            "settings",
            "--filter",
            " display/ ",
        ])
        .assert()
        .success();

    let request = request_rx.recv_timeout(Duration::from_secs(5)).unwrap();
    assert!(request.contains("\"filter\":\"display/\""));
    assert!(!request.contains("\"filter\":\" display/ \""));
    server_thread.join().unwrap();
}

#[test]
fn batch_preview_uses_tool_and_arguments_operations() {
    let (url, request_rx, server_thread) = spawn_batch_mock_server(2);
    let temp_dir = tempfile::tempdir().unwrap();
    let batch_path = temp_dir.path().join("operations.json");
    std::fs::write(
        &batch_path,
        r#"{"operations":[{"tool":"get_project_info","arguments":{}}]}"#,
    )
    .unwrap();

    let mut command = Command::cargo_bin("gdmcp").unwrap();
    let output = command
        .args(["--json", "--url", &url, "batch", "preview"])
        .arg(&batch_path)
        .output()
        .expect("batch command should have produced output");
    assert!(output.status.success());

    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("\"execution\":\"sequential\""));
    assert!(stdout.contains("\"atomic\":false"));

    // First request: schema preflight GET
    let schema_req = request_rx.recv_timeout(Duration::from_secs(5)).unwrap();
    assert!(schema_req.contains("GET /cli/v1/tools/get_project_info"));
    // Second request: execute POST
    let exec_req = request_rx.recv_timeout(Duration::from_secs(5)).unwrap();
    assert!(exec_req.contains("/cli/v1/tools/get_project_info/execute"));
    assert!(exec_req.contains("\"arguments\":{}"));
    server_thread.join().unwrap();
}

#[test]
fn batch_prevalidates_all_operations_before_network_access() {
    // Second operation has non-object arguments, caught by local structural
    // validation before any network request is made.
    let temp_dir = tempfile::tempdir().unwrap();
    let batch_path = temp_dir.path().join("operations.json");
    std::fs::write(
        &batch_path,
        r#"{"operations":[{"tool":"get_project_info","arguments":{}},{"tool":"bad","arguments":[] }]}"#,
    )
    .unwrap();

    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args(["--json", "--url", "http://127.0.0.1:1", "batch", "preview"])
        .arg(&batch_path)
        .assert()
        .code(2)
        .stdout(predicate::str::contains(
            "batch operation 1: arguments must be a JSON object",
        ));
}

#[test]
fn batch_rejects_unknown_fields_and_blank_tool_names() {
    // Unknown fields (serde deny_unknown_fields) and blank tool names are
    // caught by local validation before any network access.
    for contents in [
        r#"{"operations":[{"tool":"get_project_info","arguments":{},"extra":true}]}"#,
        r#"{"operations":[{"tool":"   ","arguments":{}}]}"#,
    ] {
        let temp_dir = tempfile::tempdir().unwrap();
        let batch_path = temp_dir.path().join("operations.json");
        std::fs::write(&batch_path, contents).unwrap();
        let mut command = Command::cargo_bin("gdmcp").unwrap();
        command
            .args(["--json", "--url", "http://127.0.0.1:1", "batch", "preview"])
            .arg(&batch_path)
            .assert()
            .code(2);
    }
}

#[test]
fn debug_logs_sends_cursor_offset_and_larger_output_limit_for_files() {
    let (url, request_rx, server_thread) = spawn_mock_server();
    let temp_dir = tempfile::tempdir().unwrap();
    let output_path = temp_dir.path().join("logs.json");
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args([
            "--json", "--url", &url, "debug", "logs", "--limit", "5", "--cursor", "10", "--out",
        ])
        .arg(&output_path)
        .assert()
        .success();

    let request = request_rx.recv_timeout(Duration::from_secs(5)).unwrap();
    assert!(request.contains("/cli/v1/tools/get_editor_logs/execute"));
    assert!(request.contains("\"count\":5"));
    assert!(request.contains("\"offset\":10"));
    assert!(request.contains("\"max_bytes\":4194304"));
    server_thread.join().unwrap();
}

#[test]
fn list_commands_send_the_default_limit() {
    let (url, request_rx, server_thread) = spawn_mock_server();
    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args(["--json", "--url", &url, "scripts", "list"])
        .assert()
        .success();
    let request = request_rx.recv_timeout(Duration::from_secs(5)).unwrap();
    assert!(request.contains("\"limit\":50"));
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

fn spawn_batch_mock_server(
    expected_requests: usize,
) -> (String, mpsc::Receiver<String>, thread::JoinHandle<()>) {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let address = listener.local_addr().unwrap();
    let (request_tx, request_rx) = mpsc::channel();
    let server_thread = thread::spawn(move || {
        for _ in 0..expected_requests {
            let (mut stream, _) = match listener.accept() {
                Ok(conn) => conn,
                Err(_) => break,
            };
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

            let request_str = String::from_utf8_lossy(&request);
            let body = if request_str.contains("GET ") && !request_str.contains("/execute") {
                // Schema request — return a minimal valid schema
                r#"{"schema_version":1,"ok":true,"data":{"input_schema":{"type":"object","properties":{}}},"meta":{}}"#
            } else {
                // Execute request
                r#"{"schema_version":1,"ok":true,"data":{},"meta":{"truncated":false,"next_cursor":null}}"#
            };
            let response = format!(
                "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                body.len(),
                body
            );
            stream.write_all(response.as_bytes()).unwrap();
        }
    });
    (format!("http://{address}"), request_rx, server_thread)
}

#[test]
fn batch_reports_partial_failure_with_completed_count() {
    // Use a batch mock that returns an error for the second execute.
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let address = listener.local_addr().unwrap();
    let url = format!("http://{address}");
    let server_thread = thread::spawn(move || {
        // Batch does schema preflight for ALL ops before any execution.
        // Request 1: schema preflight for op 0
        let (mut stream, _) = listener.accept().unwrap();
        let mut buf = [0_u8; 4096];
        let n = stream.read(&mut buf).unwrap();
        let _req = String::from_utf8_lossy(&buf[..n]);
        let body = r#"{"schema_version":1,"ok":true,"data":{"input_schema":{"type":"object","properties":{}}},"meta":{}}"#;
        let resp = format!("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}", body.len(), body);
        stream.write_all(resp.as_bytes()).unwrap();
        drop(stream);

        // Request 2: schema preflight for op 1
        let (mut stream, _) = listener.accept().unwrap();
        let mut buf = [0_u8; 4096];
        let n = stream.read(&mut buf).unwrap();
        let _req = String::from_utf8_lossy(&buf[..n]);
        let body = r#"{"schema_version":1,"ok":true,"data":{"input_schema":{"type":"object","properties":{}}},"meta":{}}"#;
        let resp = format!("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}", body.len(), body);
        stream.write_all(resp.as_bytes()).unwrap();
        drop(stream);

        // Request 3: execute op 0 — success
        let (mut stream, _) = listener.accept().unwrap();
        let mut buf = [0_u8; 4096];
        let n = stream.read(&mut buf).unwrap();
        let _req = String::from_utf8_lossy(&buf[..n]);
        let body = r#"{"schema_version":1,"ok":true,"data":{"name":"test"},"meta":{}}"#;
        let resp = format!("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}", body.len(), body);
        stream.write_all(resp.as_bytes()).unwrap();
        drop(stream);

        // Request 4: execute op 1 — returns error
        let (mut stream, _) = listener.accept().unwrap();
        let mut buf = [0_u8; 4096];
        let n = stream.read(&mut buf).unwrap();
        let _req = String::from_utf8_lossy(&buf[..n]);
        let body = r#"{"schema_version":1,"ok":false,"error":{"code":"SIMULATED","message":"simulated failure"},"data":null}"#;
        let resp = format!("HTTP/1.1 500 Internal Server Error\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}", body.len(), body);
        stream.write_all(resp.as_bytes()).unwrap();
    });

    let temp_dir = tempfile::tempdir().unwrap();
    let batch_path = temp_dir.path().join("operations.json");
    std::fs::write(
        &batch_path,
        r#"{"operations":[{"tool":"get_project_info","arguments":{}},{"tool":"get_project_info","arguments":{}}]}"#,
    )
    .unwrap();

    let mut command = Command::cargo_bin("gdmcp").unwrap();
    let output = command
        .args(["--json", "--url", &url, "batch", "preview"])
        .arg(&batch_path)
        .output()
        .expect("batch command should have produced output");
    assert!(!output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("BATCH_PARTIAL_FAILURE"));
    assert!(stdout.contains("\"completed_count\":1"));
    assert!(stdout.contains("\"failed_index\":1"));
    assert!(stdout.contains("\"execution\":\"sequential\""));
    assert!(stdout.contains("\"atomic\":false"));
    server_thread.join().unwrap();
}

#[test]
fn batch_missing_arguments_field_defaults_to_empty_object() {
    let (url, _request_rx, server_thread) = spawn_batch_mock_server(2);
    let temp_dir = tempfile::tempdir().unwrap();
    let batch_path = temp_dir.path().join("operations.json");
    // No "arguments" field — backwards compat
    std::fs::write(
        &batch_path,
        r#"{"operations":[{"tool":"get_project_info"}]}"#,
    )
    .unwrap();

    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args(["--json", "--url", &url, "batch", "preview"])
        .arg(&batch_path)
        .assert()
        .success();
    server_thread.join().unwrap();
}

#[test]
fn batch_schema_preflight_catches_wrong_argument_type() {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let address = listener.local_addr().unwrap();
    let url = format!("http://{address}");
    let server_thread = thread::spawn(move || {
        let (mut stream, _) = listener.accept().unwrap();
        let mut buf = [0_u8; 4096];
        let n = stream.read(&mut buf).unwrap();
        let _req = String::from_utf8_lossy(&buf[..n]);
        // First schema: property "count" expects "integer"
        let body = r#"{"schema_version":1,"ok":true,"data":{"input_schema":{"type":"object","properties":{"count":{"type":"integer"}}}},"meta":{}}"#;
        let resp = format!("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}", body.len(), body);
        stream.write_all(resp.as_bytes()).unwrap();
    });

    let temp_dir = tempfile::tempdir().unwrap();
    let batch_path = temp_dir.path().join("operations.json");
    std::fs::write(
        &batch_path,
        r#"{"operations":[{"tool":"some_tool","arguments":{"count":"not-a-number"}}]}"#,
    )
    .unwrap();

    let mut command = Command::cargo_bin("gdmcp").unwrap();
    command
        .args(["--json", "--url", &url, "batch", "preview"])
        .arg(&batch_path)
        .assert()
        .code(2)
        .stdout(predicate::str::contains(
            "arguments.count must be a integer",
        ));
    server_thread.join().unwrap();
}
