#!/usr/bin/env python3
"""Quick register test with full error output."""
import urllib.request
import json
import random
import traceback

BASE = "http://127.0.0.1:8000"
email = f"dbg_{random.randint(1000,9999)}@example.com"
user = f"dbguser_{random.randint(1000,9999)}"

body = json.dumps({"email": email, "username": user, "password": "test123456", "full_name": "Debug User"}).encode()
headers = {"Content-Type": "application/json"}

try:
    req = urllib.request.Request(BASE + "/auth/register", data=body, headers=headers, method="POST")
    resp = urllib.request.urlopen(req)
    print(f"SUCCESS {resp.status}: {resp.read().decode()}")
except urllib.error.HTTPError as e:
    print(f"HTTP ERROR {e.code}:")
    print(e.read().decode())
except Exception as e:
    print(f"ERROR: {e}")
    traceback.print_exc()
