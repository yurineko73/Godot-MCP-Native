from __future__ import annotations

import http.client
import json
import os
import platform
import re
import shutil
import socket
import subprocess
import tempfile
import time
import unittest
import uuid
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_GODOT_EXE = Path("/Applications/Godot-4.6.2.app/Contents/MacOS/Godot")


def find_free_port() -> int:
	with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
		listener.bind(("127.0.0.1", 0))
		return int(listener.getsockname()[1])


def find_non_loopback_ipv4() -> str:
	candidates: list[str] = []
	try:
		for result in socket.getaddrinfo(
			socket.gethostname(), 0, family=socket.AF_INET, type=socket.SOCK_STREAM
		):
			candidates.append(result[4][0])
	except socket.gaierror:
		pass

	with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
		try:
			probe.connect(("192.0.2.1", 9))
			candidates.append(probe.getsockname()[0])
		except OSError:
			pass

	for candidate in candidates:
		if not candidate.startswith("127.") and candidate != "0.0.0.0":
			return candidate
	return ""


def user_data_path(project_name: str) -> Path:
	system = platform.system()
	if system == "Darwin":
		return Path.home() / "Library/Application Support/Godot/app_userdata" / project_name
	if system == "Windows":
		return Path(os.environ["APPDATA"]) / "Godot/app_userdata" / project_name
	data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
	return data_home / "godot/app_userdata" / project_name


def create_isolated_project(temp_root: Path, project_name: str) -> Path:
	project_dir = temp_root / "project"
	project_dir.mkdir()
	project_text = (REPO_ROOT / "project.godot").read_text(encoding="utf-8")
	project_text = re.sub(
		r'config/name="[^"]*"', f'config/name="{project_name}"', project_text, count=1
	)
	(project_dir / "project.godot").write_text(project_text, encoding="utf-8")
	(project_dir / "addons").symlink_to(REPO_ROOT / "addons", target_is_directory=True)
	for asset_name in ("icon.svg", "icon.png", "TestScene.tscn"):
		asset = REPO_ROOT / asset_name
		if asset.exists():
			(project_dir / asset_name).symlink_to(asset)
	return project_dir


def initialize(host: str, port: int, token: str = "") -> tuple[int, dict]:
	payload = json.dumps(
		{
			"jsonrpc": "2.0",
			"method": "initialize",
			"params": {
				"protocolVersion": "2025-03-26",
				"capabilities": {},
				"clientInfo": {"name": "dual-loopback-test", "version": "1.0"},
			},
			"id": 1,
		}
	).encode("utf-8")
	headers = {"Content-Type": "application/json", "Content-Length": str(len(payload))}
	if token:
		headers["Authorization"] = f"Bearer {token}"
	connection = http.client.HTTPConnection(host, port, timeout=3)
	try:
		connection.request("POST", "/mcp", body=payload, headers=headers)
		response = connection.getresponse()
		body = response.read().decode("utf-8")
		try:
			payload = json.loads(body)
		except json.JSONDecodeError:
			payload = {}
		return response.status, payload
	finally:
		connection.close()


class GodotServer:
	def __init__(
		self, *, port: int, expect_ready: bool = True, settings: dict[str, object] | None = None
	) -> None:
		self.port = port
		self.expect_ready = expect_ready
		self.settings = settings or {}
		self.temp_root: Path | None = None
		self.project_name = f"GodotMcpDualLoopback-{uuid.uuid4().hex}"
		self.project_dir: Path | None = None
		self.user_dir = user_data_path(self.project_name)
		self.log_path: Path | None = None
		self.process: subprocess.Popen[str] | None = None
		self.output = ""

	def __enter__(self) -> "GodotServer":
		godot_exe = Path(os.environ.get("GODOT_EXE", str(DEFAULT_GODOT_EXE)))
		if not godot_exe.exists():
			raise FileNotFoundError(f"Godot executable not found: {godot_exe}")
		self.temp_root = Path(
			tempfile.mkdtemp(prefix=".tmp_http_dual_loopback_", dir=REPO_ROOT / "test/integration")
		)
		self.project_dir = create_isolated_project(self.temp_root, self.project_name)
		self.log_path = self.temp_root / "godot.log"
		if self.settings:
			self.user_dir.mkdir(parents=True)
			settings_lines = ["[meta]", "version=1", "", "[settings]"]
			for key, value in self.settings.items():
				serialized = json.dumps(value).lower() if isinstance(value, bool) else json.dumps(value)
				settings_lines.append(f"{key}={serialized}")
			(self.user_dir / "mcp_settings.cfg").write_text(
				"\n".join(settings_lines) + "\n", encoding="utf-8"
			)
		self.process = subprocess.Popen(
			[
				str(godot_exe),
				"--editor",
				"--headless",
				"--path",
				str(self.project_dir),
				"--log-file",
				str(self.log_path),
				"--",
				"--mcp-server",
				f"--mcp-port={self.port}",
			],
			cwd=self.project_dir,
			stdout=subprocess.PIPE,
			stderr=subprocess.STDOUT,
			text=True,
		)
		if self.expect_ready:
			self.wait_until_ready()
		return self

	def wait_until_ready(self, timeout_seconds: float = 30.0) -> None:
		deadline = time.monotonic() + timeout_seconds
		last_error: Exception | None = None
		while time.monotonic() < deadline:
			if self.process is not None and self.process.poll() is not None:
				break
			try:
				token = str(self.settings.get("auth_token", ""))
				status, payload = initialize("127.0.0.1", self.port, token)
				if status == 200 and payload.get("result"):
					return
			except (OSError, ValueError) as error:
				last_error = error
			time.sleep(0.2)
		self._collect_output()
		raise TimeoutError(
			f"Timed out waiting for Godot MCP server: {last_error}\nGodot output:\n{self.output}"
		)

	def wait_until_start_failed(self, timeout_seconds: float = 30.0) -> None:
		deadline = time.monotonic() + timeout_seconds
		while time.monotonic() < deadline:
			if self.log_path is not None and self.log_path.exists():
				log_text = self.log_path.read_text(encoding="utf-8", errors="replace")
				if "Failed to listen on" in log_text:
					return
			if self.process is not None and self.process.poll() is not None:
				break
			time.sleep(0.1)
		self._collect_output()
		raise TimeoutError(f"Godot did not report a bind failure\nGodot output:\n{self.output}")

	def _collect_output(self) -> None:
		if self.process is None or self.process.stdout is None:
			return
		if self.process.poll() is None:
			return
		self.output = self.process.stdout.read()

	def __exit__(self, exc_type, exc_value, traceback) -> None:
		if self.process is not None and self.process.poll() is None:
			self.process.terminate()
			try:
				self.process.wait(timeout=10)
			except subprocess.TimeoutExpired:
				self.process.kill()
				self.process.wait(timeout=5)
		self._collect_output()
		if self.process is not None and self.process.stdout is not None:
			self.process.stdout.close()
		if self.temp_root is not None:
			shutil.rmtree(self.temp_root, ignore_errors=True)
		shutil.rmtree(self.user_dir, ignore_errors=True)


class HttpDualLoopbackBindingTest(unittest.TestCase):
	def test_local_mode_serves_both_loopbacks_and_rejects_lan(self) -> None:
		lan_address = find_non_loopback_ipv4()
		self.assertTrue(lan_address, "A non-loopback IPv4 address is required for this test")
		port = find_free_port()
		with GodotServer(port=port):
			ipv4_status, ipv4_payload = initialize("127.0.0.1", port)
			self.assertEqual(200, ipv4_status)
			self.assertIn("result", ipv4_payload)

			ipv6_status, ipv6_payload = initialize("::1", port)
			self.assertEqual(200, ipv6_status)
			self.assertIn("result", ipv6_payload)

			with self.assertRaises(OSError):
				initialize(lan_address, port)

	def test_lan_only_port_owner_does_not_block_local_loopback_listeners(self) -> None:
		lan_address = find_non_loopback_ipv4()
		self.assertTrue(lan_address, "A non-loopback IPv4 address is required for this test")
		with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as lan_listener:
			lan_listener.bind((lan_address, 0))
			lan_listener.listen()
			port = int(lan_listener.getsockname()[1])
			with GodotServer(port=port):
				ipv4_status, _ = initialize("127.0.0.1", port)
				ipv6_status, _ = initialize("::1", port)
				self.assertEqual(200, ipv4_status)
				self.assertEqual(200, ipv6_status)

	def test_one_loopback_bind_failure_rolls_back_the_other_listener(self) -> None:
		with socket.socket(socket.AF_INET6, socket.SOCK_STREAM) as ipv6_listener:
			ipv6_listener.bind(("::1", 0))
			ipv6_listener.listen()
			port = int(ipv6_listener.getsockname()[1])
			with GodotServer(port=port, expect_ready=False) as server:
				server.wait_until_start_failed()
				with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
					probe.settimeout(1)
					with self.assertRaises(OSError):
						probe.connect(("127.0.0.1", port))

	def test_remote_mode_accepts_lan_and_enforces_bearer_auth(self) -> None:
		lan_address = find_non_loopback_ipv4()
		self.assertTrue(lan_address, "A non-loopback IPv4 address is required for this test")
		port = find_free_port()
		token = "dual-loopback-test-token"
		with GodotServer(
			port=port,
			settings={"allow_remote": True, "auth_enabled": True, "auth_token": token},
		):
			unauthorized_status, _ = initialize(lan_address, port)
			self.assertEqual(401, unauthorized_status)
			authorized_status, payload = initialize(lan_address, port, token)
			self.assertEqual(200, authorized_status)
			self.assertIn("result", payload)


if __name__ == "__main__":
	unittest.main()
