# VaultGuard Sentinel — Specification (App Store compliant, Draft)

**Status:** PLANNED (Approved for Development)  
**Priority:** HIGH  
**Goal:** In-app continuous protection (foreground only): detect risk signals and protect sensitive VaultGuard content when “it’s not you”, without any background camera or device-wide controls.

---

## Components

### 1) Foreground Re-Auth Sentinel (BiometricPrompt gate)
- **Input**: user-initiated OS biometric prompt (BiometricPrompt / FaceID/TouchID equivalent)
- **Output**: allow/deny + session window refresh
- **Rules**: re-auth on high-risk actions (view/export/delete), after idle/background, on suspicious signals
- **App Store constraints**: must be user-initiated and clearly explained; no covert biometric capture

### 2) In-App Behavioral Signals (non-biometric, privacy-safe)
- **Input**: touch/gesture dynamics inside the app only (typing cadence, tap precision), device state signals
- **Output**: risk score (NOT identity proof)
- **Notes**: treat as a *risk signal*; must be opt-in where required and never exported raw

### 3) Sensitive Screen Protection (in-app only)
- **Behavior**: blur/redact sensitive UI on app switch, screenshots/recording prevention where supported, lock screens behind re-auth
- **Policy**: configurable per feature (Vault, Documents, Export), with safe emergency override + audit logging
- **App Store constraints**: cannot control other apps; only protect VaultGuard screens/content

### 4) Sentinel Policy Engine
- **Behavior**: deterministic rules + optional lightweight on-device model (no cloud requirement)
- **Features**: cooldowns, false-positive suppression, configurable thresholds, safe mode

---

## Metrics (targets)
- **False positive lock rate**: < 0.5% (MVP)
- **Re-auth latency**: < 800ms p50 (prompt time excluded)
- **Battery impact**: < 1% / day
- **Onboarding**: clear consent + explanations; no hidden capture

---

## Security / privacy requirements
- All signals encrypted at rest (SecureStorage)
- Clear user consent + opt-out
- No background camera / microphone capture
- No device-wide “firewall” / MDM / Enterprise-only assumptions
- On mismatch: minimal data exposure, deterministic logging (audit)

---

## Status metadata
```json
{
  "module": "VaultGuardSentinel",
  "status": "PLANNED",
  "priority": "HIGH",
  "user_value": "PROTECT_VAULT_CONTENT_IN_APP",
  "competition_angle": "IN_APP_CONTINUOUS_PROTECTION_APP_STORE_COMPLIANT",
  "technical_risk": "LOW_TO_MEDIUM",
  "timeline": "TBD"
}
```

