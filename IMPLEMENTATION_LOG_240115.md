# IMPLEMENTATION LOG (Continuous) — Sprint 0.1.2

## 2026-01-13

### 23:00–24:00
- Added roadmap entries for Sprint 0.1.2 (entitlements/paywall/vendor prep).
- Implemented backend stub (`backend/`):
  - `GET /api/user/entitlements`
  - `POST /api/mock/purchase`
  - `POST /api/verify-identity`
  - SQLite storage + basic unit tests
- Implemented Android entitlements client:
  - `EntitlementsApiClient` (HttpURLConnection)
  - `EntitlementsRepository` updates `TierPrefs`
  - `InstallId` used as temporary user identifier
- Added Paywall UI:
  - LITE user attempting biometric access is redirected to Paywall
  - Mock purchase upgrades to ANGEL via backend and returns to app

Blockers:
- None in code, but production decisions are tracked in `PENDING_HUMAN_DECISIONS.md`.

