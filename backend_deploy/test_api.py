#!/usr/bin/env python3
"""Test all new AURA API v1.3 endpoints."""
import urllib.request
import json

BASE = "http://127.0.0.1:8000"

def api(method, path, body=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    data = json.dumps(body).encode() if body else None
    try:
        req = urllib.request.Request(BASE + path, data=data, headers=headers, method=method)
        resp = urllib.request.urlopen(req)
        return resp.status, json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode())

def form_post(path, form_data):
    data = "&".join(f"{k}={v}" for k, v in form_data.items()).encode()
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    try:
        req = urllib.request.Request(BASE + path, data=data, headers=headers, method="POST")
        resp = urllib.request.urlopen(req)
        return resp.status, json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode())

print("=== AURA API v1.3 Tests ===\n")

# 1. Root check
status, data = api("GET", "/")
print(f"1. GET /           -> {status}: {data}")

# 2. Health
status, data = api("GET", "/health")
print(f"2. GET /health     -> {status}: {data}")

# 3. Register test user
import random
test_email = f"test_{random.randint(1000,9999)}@example.com"
test_user = f"testuser_{random.randint(1000,9999)}"
status, data = api("POST", "/auth/register", {
    "email": test_email,
    "username": test_user,
    "password": "test123456",
    "full_name": "Test User"
})
print(f"3. POST /auth/register -> {status}: user_id={data.get('user', {}).get('id')}, is_verified={data.get('user', {}).get('is_verified')}")
token = data.get("access_token", "")

# 4. Verify email (wrong code)
status, data = api("POST", "/auth/verify-email", {"email": test_email, "code": "000000"})
print(f"4. POST /auth/verify-email (wrong) -> {status}: {data}")

# 5. Forgot password
status, data = api("POST", "/auth/forgot-password", {"email": test_email})
print(f"5. POST /auth/forgot-password -> {status}: {data}")

# 6. Reset password (wrong code)
status, data = api("POST", "/auth/reset-password", {"email": test_email, "code": "000000", "new_password": "newpass123"})
print(f"6. POST /auth/reset-password (wrong) -> {status}: {data}")

# 7. Get me
status, data = api("GET", "/auth/me", token=token)
print(f"7. GET /auth/me -> {status}: email={data.get('email')}, is_verified={data.get('is_verified')}")

# 8. Change password
status, data = api("POST", "/auth/change-password", {"current_password": "test123456", "new_password": "newpass123"}, token=token)
print(f"8. POST /auth/change-password -> {status}: {data}")

# 9. Login with new password
status, data = form_post("/auth/login", {"username": test_email, "password": "newpass123"})
print(f"9. POST /auth/login (new pw) -> {status}: ok={bool(data.get('access_token'))}")
token = data.get("access_token", token)

# 10. Preferences - save
status, data = api("PUT", "/preferences", {"preferences": {"city": "Moscow", "dark_mode": "Dark", "calorie_goal": 2500}}, token=token)
print(f"10. PUT /preferences -> {status}: {data}")

# 11. Preferences - get
status, data = api("GET", "/preferences", token=token)
print(f"11. GET /preferences -> {status}: {data}")

# 12. Preferences - patch
status, data = api("PATCH", "/preferences", {"preferences": {"haptic_enabled": False}}, token=token)
print(f"12. PATCH /preferences -> {status}: haptic={data.get('preferences', {}).get('haptic_enabled')}")

# 13. Logout
status, data = api("POST", "/auth/logout", token=token)
print(f"13. POST /auth/logout -> {status}: {data}")

# 14. Try to use blacklisted token
status, data = api("GET", "/auth/me", token=token)
print(f"14. GET /auth/me (after logout) -> {status}: {data.get('detail', 'unexpected')}")

# 15. Login again for delete test
status, data = form_post("/auth/login", {"username": test_email, "password": "newpass123"})
token2 = data.get("access_token", "")
print(f"15. POST /auth/login (re-login) -> {status}: ok={bool(token2)}")

# 16. Delete account
status, data = api("DELETE", "/auth/me", token=token2)
print(f"16. DELETE /auth/me -> {status}: {data}")

# 17. Verify account is gone
status, data = form_post("/auth/login", {"username": test_email, "password": "newpass123"})
print(f"17. POST /auth/login (after delete) -> {status}: {data.get('detail', 'unexpected')}")

# 18. Resend verification (non-existent)
status, data = api("POST", "/auth/resend-verification", {"email": "nonexistent@example.com"})
print(f"18. POST /auth/resend-verification -> {status}: {data}")

print("\n=== All tests completed ===")
