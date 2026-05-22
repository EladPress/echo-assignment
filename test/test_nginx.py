"""
Nginx Compatibility Test Suite
==============================
Verifies that nginx-patched behaves identically to nginx:1.25-bookworm
for a representative set of HTTP scenarios.

What "working correctly" means:
  - Same HTTP status codes for all request types
  - Same Content-Type headers for the same resources
  - Same response body for the nginx welcome page
  - Same handling of 404s, malformed requests, and unknown methods
  - nginx version header matches (proving same nginx binary)
"""

import os
import time
import socket
import requests
import pytest

ORIGINAL_HOST = os.environ.get("ORIGINAL_HOST", "nginx-original")
PATCHED_HOST  = os.environ.get("PATCHED_HOST",  "nginx-patched")
PORT = 80

ORIGINAL_URL = f"http://{ORIGINAL_HOST}:{PORT}"
PATCHED_URL  = f"http://{PATCHED_HOST}:{PORT}"

# Headers we don't compare because they are expected to differ
# between two independently running containers.
IGNORED_HEADERS = {"date", "connection", "x-request-id"}


def wait_for_nginx(host: str, port: int = 80, timeout: int = 30) -> None:
    """Block until the nginx container is accepting TCP connections."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with socket.create_connection((host, port), timeout=1):
                return
        except OSError:
            time.sleep(0.5)
    raise RuntimeError(f"nginx at {host}:{port} did not become ready within {timeout}s")


@pytest.fixture(scope="session", autouse=True)
def wait_for_containers():
    """Wait for both nginx containers to be ready before running any tests."""
    wait_for_nginx(ORIGINAL_HOST)
    wait_for_nginx(PATCHED_HOST)


def compare(original: requests.Response, patched: requests.Response, check_body: bool = True) -> None:
    """
    Assert that two responses are equivalent.
    Compares status code, relevant headers, and optionally the body.
    Raises AssertionError with a clear message on any mismatch.
    """
    assert original.status_code == patched.status_code, (
        f"Status code mismatch: original={original.status_code}, patched={patched.status_code}"
    )

    orig_headers  = {k.lower(): v for k, v in original.headers.items()  if k.lower() not in IGNORED_HEADERS}
    patch_headers = {k.lower(): v for k, v in patched.headers.items() if k.lower() not in IGNORED_HEADERS}

    for key in orig_headers:
        if key in patch_headers:
            assert orig_headers[key] == patch_headers[key], (
                f"Header '{key}' mismatch: original='{orig_headers[key]}', patched='{patch_headers[key]}'"
            )

    if check_body:
        assert original.text == patched.text, (
            f"Body mismatch:\n--- original ---\n{original.text[:500]}\n"
            f"--- patched ---\n{patched.text[:500]}"
        )


# ---------------------------------------------------------------------------
# Test cases
# ---------------------------------------------------------------------------

class TestBasicRequests:

    def test_root_status_200(self):
        """GET / should return 200 OK with the nginx welcome page."""
        orig   = requests.get(f"{ORIGINAL_URL}/")
        patched = requests.get(f"{PATCHED_URL}/")
        assert orig.status_code == 200
        assert patched.status_code == 200

    def test_root_body_matches(self):
        """The welcome page body should be identical on both images."""
        orig   = requests.get(f"{ORIGINAL_URL}/")
        patched = requests.get(f"{PATCHED_URL}/")
        compare(orig, patched, check_body=True)

    def test_root_content_type(self):
        """GET / should return text/html content type on both."""
        orig   = requests.get(f"{ORIGINAL_URL}/")
        patched = requests.get(f"{PATCHED_URL}/")
        assert "text/html" in orig.headers.get("Content-Type", "")
        assert "text/html" in patched.headers.get("Content-Type", "")

    def test_nginx_server_header(self):
        """Server header must report the same nginx version on both images."""
        orig   = requests.get(f"{ORIGINAL_URL}/")
        patched = requests.get(f"{PATCHED_URL}/")
        orig_server   = orig.headers.get("Server", "")
        patched_server = patched.headers.get("Server", "")
        assert orig_server == patched_server, (
            f"Server header mismatch: original='{orig_server}', patched='{patched_server}'"
        )
        # Confirm this is actually nginx 1.25
        assert "nginx/1.25" in orig_server, f"Unexpected server header: {orig_server}"


class TestErrorHandling:

    def test_404_not_found(self):
        """Requesting a non-existent path should return 404 on both."""
        orig   = requests.get(f"{ORIGINAL_URL}/does-not-exist")
        patched = requests.get(f"{PATCHED_URL}/does-not-exist")
        compare(orig, patched, check_body=True)
        assert orig.status_code == 404

    def test_404_body_contains_nginx(self):
        """The 404 page should contain 'nginx' in the body on both."""
        orig   = requests.get(f"{ORIGINAL_URL}/missing")
        patched = requests.get(f"{PATCHED_URL}/missing")
        assert "nginx" in orig.text.lower()
        assert "nginx" in patched.text.lower()

    def test_unknown_method(self):
        """An unsupported HTTP method (DELETE /) should return the same status on both."""
        orig   = requests.delete(f"{ORIGINAL_URL}/")
        patched = requests.delete(f"{PATCHED_URL}/")
        compare(orig, patched, check_body=False)

    def test_malformed_path(self):
        """A path with special characters should be handled the same way."""
        orig   = requests.get(f"{ORIGINAL_URL}/<script>alert(1)</script>")
        patched = requests.get(f"{PATCHED_URL}/<script>alert(1)</script>")
        compare(orig, patched, check_body=False)


class TestHeaders:

    def test_custom_request_header_passthrough(self):
        """Both images should ignore unknown request headers without error."""
        headers = {"X-Custom-Header": "test-value", "X-Request-Id": "abc-123"}
        orig   = requests.get(f"{ORIGINAL_URL}/", headers=headers)
        patched = requests.get(f"{PATCHED_URL}/", headers=headers)
        compare(orig, patched, check_body=False)

    def test_head_request(self):
        """HEAD / should return headers but no body, same on both."""
        orig   = requests.head(f"{ORIGINAL_URL}/")
        patched = requests.head(f"{PATCHED_URL}/")
        compare(orig, patched, check_body=False)
        assert orig.text == ""
        assert patched.text == ""

    def test_keep_alive(self):
        """Both images should support keep-alive connections."""
        session = requests.Session()
        for url in [ORIGINAL_URL, PATCHED_URL]:
            r1 = session.get(f"{url}/")
            r2 = session.get(f"{url}/")
            assert r1.status_code == r2.status_code == 200


class TestLargeRequests:

    def test_large_body_post(self):
        """POST with a large body should be handled the same way on both."""
        large_body = "x" * 10_000
        orig   = requests.post(f"{ORIGINAL_URL}/", data=large_body)
        patched = requests.post(f"{PATCHED_URL}/", data=large_body)
        # Both should reject POST to / in the same way (405 or 403)
        assert orig.status_code == patched.status_code, (
            f"Large POST status mismatch: original={orig.status_code}, patched={patched.status_code}"
        )

    def test_long_url(self):
        """A very long URL should be rejected the same way on both (414 or 400)."""
        long_path = "/a" * 2000
        orig   = requests.get(f"{ORIGINAL_URL}{long_path}")
        patched = requests.get(f"{PATCHED_URL}{long_path}")
        assert orig.status_code == patched.status_code, (
            f"Long URL status mismatch: original={orig.status_code}, patched={patched.status_code}"
        )
