#!/usr/bin/env python3
"""
Fans CRUD smoke test

Usage:
  python3 scripts/smoke/fans_crud.py [BASE_URL]

Environment variables:
  BASE_URL            Default: http://127.0.0.1:8081
  AUTH_TOKEN          Default: dev-token
  USER_PERMISSIONS    Default: fans

This script exercises:
  - POST   /api/v1/fans
  - GET    /api/v1/fans
  - GET    /api/v1/fans/id/{id}
  - PUT    /api/v1/fans/id/{id}
  - DELETE /api/v1/fans/id/{id}
  - GET    /api/v1/fans/id/{id} expecting 404 after deletion

It returns non-zero on failure and prints concise progress logs.
"""

import json
import os
import sys
import urllib.request
import urllib.error


def getenv(key: str, default: str) -> str:
    v = os.environ.get(key)
    return v if v else default


BASE = os.environ.get("BASE_URL") or (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8081")
AUTH_TOKEN = getenv("AUTH_TOKEN", "dev-token")
USER_PERMISSIONS = getenv("USER_PERMISSIONS", "fans")

HEADERS_BASE = {
    "Authorization": f"Bearer {AUTH_TOKEN}",
    "X-User-Permissions": USER_PERMISSIONS,
    "Content-Type": "application/json",
}


def request(method: str, path: str, data: dict | None = None):
    url = BASE + path
    body = None
    if data is not None:
        body = json.dumps(data).encode("utf-8")
    req = urllib.request.Request(url, data=body, method=method)
    for k, v in HEADERS_BASE.items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            code = resp.getcode()
            text = resp.read().decode("utf-8", errors="replace")
            return code, text
    except urllib.error.HTTPError as e:
        try:
            text = e.read().decode("utf-8", errors="replace")
        except Exception:
            text = str(e)
        return e.code, text
    except Exception as e:
        return 0, str(e)


def show(label: str, method: str, path: str, data: dict | None = None):
    code, text = request(method, path, data)
    print(f"[{label}] {method} {path} -> HTTP {code}")
    print(text[:300].replace("\n", " "))
    print()
    return code, text


def main() -> int:
    # Create
    code, text = show("Create", "POST", "/api/v1/fans", {
        "name": "Alice",
        "gender": "female",
        "birthday": "1990-01-01",
        "zodiac": "Capricorn",
    })
    if code != 200:
        return 1
    try:
        j = json.loads(text)
        d = j.get("data") or {}
        fan_id = d.get("id")
    except Exception:
        fan_id = None
    if not isinstance(fan_id, int) or fan_id <= 0:
        print("Failed to parse created fan id")
        return 1

    # List
    code, _ = show("List", "GET", "/api/v1/fans")
    if code != 200:
        return 1

    # Get by id
    code, text = show("Get", "GET", f"/api/v1/fans/id/{fan_id}")
    if code != 200:
        return 1

    # Update
    code, text = show("Update", "PUT", f"/api/v1/fans/id/{fan_id}", {
        "name": "AliceUpdated",
        "zodiac": "Aquarius",
    })
    if code != 200:
        return 1

    # Delete
    code, text = show("Delete", "DELETE", f"/api/v1/fans/id/{fan_id}")
    if code != 200:
        return 1

    # Confirm 404
    code, text = show("Confirm404", "GET", f"/api/v1/fans/id/{fan_id}")
    if code != 404:
        print("Expected 404 after deletion")
        return 1

    print("Fans CRUD smoke test: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())