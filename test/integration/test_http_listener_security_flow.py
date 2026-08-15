import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_GODOT_EXE = Path(r"C:\SourceCode\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe")


def find_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


def find_lan_address() -> str:
    candidates: set[str] = set()
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
            probe.connect(("192.0.2.1", 9))
            candidates.add(probe.getsockname()[0])
    except OSError:
        pass
    try:
        for result in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            candidates.add(result[4][0])
    except socket.gaierror:
        pass
    for address in sorted(candidates):
        if not address.startswith("127.") and not address.startswith("169.254."):
            return address
    raise RuntimeError("No non-loopback IPv4 address is available for the LAN binding check")


def request_initialize(host: str, port: int, token: str = "") -> tuple[int, dict]:
    body = json.dumps({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2025-11-25",
            "capabilities": {},
            "clientInfo": {"name": "http-security-test", "version": "1.0"},
        },
    }).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(
        f"http://{host}:{port}/mcp",
        data=body,
        headers=headers,
        method="POST",
    )
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(request, timeout=3) as response:
            return response.status, json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        response_body = error.read().decode("utf-8")
        try:
            payload = json.loads(response_body)
        except json.JSONDecodeError:
            payload = {"error": response_body}
        return error.code, payload


def wait_for_listener(port: int, process: subprocess.Popen[str], timeout_seconds: float = 45.0) -> None:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f"Godot exited before the HTTP listener started (exit={process.returncode})")
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=0.5):
                return
        except OSError:
            time.sleep(0.25)
    raise TimeoutError(f"Timed out waiting for the MCP listener on 127.0.0.1:{port}")


def prepare_isolated_user_data(temp_dir: Path, settings: dict[str, object]) -> dict[str, str]:
    environment = os.environ.copy()
    home_dir = temp_dir / "home"
    home_dir.mkdir()
    environment["HOME"] = str(home_dir)
    if sys.platform == "darwin":
        data_root = home_dir / "Library" / "Application Support" / "Godot" / "app_userdata"
    elif os.name == "nt":
        app_data = home_dir / "AppData" / "Roaming"
        environment["APPDATA"] = str(app_data)
        data_root = app_data / "Godot" / "app_userdata"
    else:
        xdg_data = home_dir / ".local" / "share"
        environment["XDG_DATA_HOME"] = str(xdg_data)
        data_root = xdg_data / "godot" / "app_userdata"

    settings_dir = data_root / "Godot MCP Native"
    settings_dir.mkdir(parents=True)
    lines = ["[meta]", "version=1", "", "[settings]"]
    for key, value in settings.items():
        if isinstance(value, bool):
            encoded = "true" if value else "false"
        elif isinstance(value, str):
            encoded = json.dumps(value)
        else:
            encoded = str(value)
        lines.append(f"{key}={encoded}")
    (settings_dir / "mcp_settings.cfg").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return environment


@contextmanager
def running_editor(
    godot_exe: Path,
    settings: dict[str, object],
) -> Iterator[tuple[int, str]]:
    port = find_free_port()
    temp_dir = Path(tempfile.mkdtemp(prefix=".tmp_http_listener_security_", dir=SCRIPT_DIR))
    log_path = temp_dir / "godot.log"
    process: subprocess.Popen[str] | None = None
    log_text = ""
    try:
        environment = prepare_isolated_user_data(temp_dir, settings)
        with log_path.open("w", encoding="utf-8") as log_file:
            process = subprocess.Popen(
                [
                    str(godot_exe),
                    "--editor",
                    "--headless",
                    "--path",
                    str(REPO_ROOT),
                    "--",
                    "--mcp-server",
                    f"--mcp-port={port}",
                ],
                cwd=REPO_ROOT,
                env=environment,
                stdout=log_file,
                stderr=subprocess.STDOUT,
                text=True,
            )
            wait_for_listener(port, process)
            yield port, str(log_path)
    except Exception:
        if log_path.exists():
            log_text = log_path.read_text(encoding="utf-8", errors="replace")
            print(log_text)
        raise
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        if log_path.exists():
            log_text = log_path.read_text(encoding="utf-8", errors="replace")
        token = settings.get("auth_token")
        shutil.rmtree(temp_dir, ignore_errors=True)
        if isinstance(token, str) and token and token in log_text:
            raise AssertionError("Godot output exposed the configured bearer token")


def assert_default_loopback_policy(godot_exe: Path, lan_address: str) -> None:
    with running_editor(
        godot_exe,
        {"transport_mode": "http", "auth_enabled": False, "allow_remote": False},
    ) as (port, _log_path):
        local_status, local_payload = request_initialize("127.0.0.1", port)
        if local_status != 200 or "result" not in local_payload:
            raise AssertionError(
                f"Loopback initialize failed: status={local_status}, payload={local_payload}"
            )

        try:
            lan_status, lan_payload = request_initialize(lan_address, port)
        except (OSError, urllib.error.URLError):
            pass
        else:
            raise AssertionError(
                "Default listener accepted a LAN connection: "
                f"address={lan_address}, status={lan_status}, payload={lan_payload}"
            )
    print(f"PASS: default listener accepted loopback and refused LAN address {lan_address}")


def assert_remote_authenticated_policy(godot_exe: Path, lan_address: str) -> None:
    token = "http-security-test-token-123456"
    with running_editor(
        godot_exe,
        {
            "transport_mode": "http",
            "auth_enabled": True,
            "auth_token": token,
            "allow_remote": True,
            "cors_origin": "https://editor.example",
        },
    ) as (port, _log_path):
        unauthenticated_status, _payload = request_initialize("127.0.0.1", port)
        if unauthenticated_status != 401:
            raise AssertionError(
                f"Authenticated listener accepted a request without a token: status={unauthenticated_status}"
            )
        local_status, local_payload = request_initialize("127.0.0.1", port, token)
        if local_status != 200 or "result" not in local_payload:
            raise AssertionError(
                f"Authenticated loopback initialize failed: status={local_status}, payload={local_payload}"
            )
        lan_status, lan_payload = request_initialize(lan_address, port, token)
        if lan_status != 200 or "result" not in lan_payload:
            raise AssertionError(
                f"Remote-enabled LAN initialize failed: status={lan_status}, payload={lan_payload}"
            )
    print(f"PASS: remote listener required auth and accepted LAN address {lan_address}")


def main() -> int:
    godot_exe = Path(os.environ.get("GODOT_EXE", str(DEFAULT_GODOT_EXE)))
    if not godot_exe.exists():
        raise FileNotFoundError(f"Godot executable not found: {godot_exe}")

    lan_address = find_lan_address()
    assert_default_loopback_policy(godot_exe, lan_address)
    assert_remote_authenticated_policy(godot_exe, lan_address)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
