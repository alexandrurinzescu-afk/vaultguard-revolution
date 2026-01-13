# VaultGuard Backend (Sprint 0.1.2 - Entitlements Stub)

This is a **local-only** backend scaffold used to unblock mobile development:
- entitlements (tier + feature flags)
- mock purchase upgrade
- identity verification stub

## Run (Windows PowerShell)

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

## Endpoints
- `GET /api/user/entitlements?userId=<id>`
- `POST /api/mock/purchase` body: `{ "userId": "...", "tier": "ANGEL" }`
- `POST /api/verify-identity` body: `{ "userId": "...", "vendor": "ONFIDO", "token": "mock" }`

## Notes
- SQLite file: `backend/vaultguard.db`
- This backend is **not** production-ready. It is intentionally simple and local-first.

