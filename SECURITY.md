# Security Policy

## Incident: Exposed 2GIS API Key

**Date Found:** March 3, 2026  
**Status:** RESOLVED  

### What Happened

A 2GIS API key was hardcoded in `LogisticsView.swift` and exposed in public GitHub commits.

- **Affected Key:** `a98beecb-a8c9-4dc4-a38f-e4a838ce92ef`
- **Exposed Commits:** 161bd33 (rewritten, no longer public)
- **Detection:** GitGuardian security scan

### Remediation

✅ **COMPLETED:**
1. Created `APIConfig.swift` for secure credential management
2. Removed hardcoded key from source code
3. Rotated 2GIS API key on server (new key in `.env`)
4. Force-pushed clean history to GitHub (exposed commits removed)
5. Added comprehensive `.gitignore` to prevent future leaks
6. Restarted backend service with new credentials

### API Key Management

**Best Practices Used:**
- Keys are stored in environment variables (`.env`), NOT in code
- Keys are never committed to Git
- iOS app fetches keys from secure backend at app startup
- All API keys are protected by UFW firewall (only backend has access)
- Rate limiting (slowapi) prevents API abuse

### Prevention

To prevent similar incidents:

1. **NEVER hardcode API keys** in source code
2. Use environment variables or fetch from secure backend
3. Always use `.gitignore` extensively (see current config)
4. Enable GitGuardian or similar secret scanning
5. Rotate credentials after any exposure
6. Use rate limiting on API endpoints
7. Monitor git history for accidentally committed secrets

### Secure Credential Flow (AURA)

```
iOS App
  ↓
[App Startup]
  ↓
Request /auth/config from Backend
  ↓
Backend (in .env)
  ↓
Returns: { TWOGIS_API_KEY: "***" }
  ↓
Stored in iOS UserDefaults (APIConfig)
  ↓
Used for API calls during session
  ↓
[App Shutdown/Logout]
  ↓
Credentials cleared (APIConfig.clear())
```

### Reporting Security Issues

If you discover a security vulnerability:

1. **DO NOT** open a public GitHub issue
2. Email: `security@aura-app.com` (or maintainer)
3. Provide detailed information about the vulnerability
4. Allow reasonable time for remediation
5. Do not disclose publicly until patch is released

### Verification

To verify that the key was removed from public history:

```bash
# Should return NO matches
git log -S "a98beecb-a8c9-4dc4-a38f-e4a838ce92ef"

# View current API key management
cat APIConfig.swift
```

---

**Last Updated:** March 3, 2026  
**Next Review:** June 3, 2026 (quarterly)
