<!--
NOTE: This revised roadmap is App Store compliance-oriented (consumer iPhone users) and avoids any enterprise-only assumptions.
It also keeps Huifan-related items behind explicit consent and without requiring any additional certifications beyond existing Huifan ones.
-->

# VAULTGUARD REVOLUTION — APP STORE COMPLIANT ROADMAP (8 WEEKS)

**Version:** 2026-01-11  
**Mission:** Ship an App Store compliant consumer MVP in **8 weeks** with monetization and zero enterprise/government scopes.  
**Legal safety first:** remove or refactor anything likely to trigger App Store rejection.  
**Huifan alignment:** only use Huifan capabilities already covered by existing certifications (anything else is explicitly flagged as **Needs confirmation**).  

---

## Progress columns (required)
For every task row:
- **Planned**: approved scope
- **In Progress**: being implemented now
- **Testing**: validated on-device + edge cases
- **Done**: merged + backed up + regression-safe

Status columns: `[Planned] [In Progress] [Testing] [Done]`

---

## 2.5 GDPR & Privacy Compliance (mandatory for App Store approval)
Scope: consumer document vault + biometric authentication for app access (NOT identity verification).
| Task | Planned | In Progress | Testing | Done | App Store risk | Est |
|---|:---:|:---:|:---:|:---:|---|---|
| Legal disclaimer (no official identity verification; no gov recognition; no KYC/AML) | ✅ |  |  |  | Low | 0.25–0.5d |
| Privacy Gateway (in-app policy + accept/decline) + web link | ✅ |  |  |  | Low | 0.5–1d |
| Biometric consent (separate consent for iris/palm vein; revoke anytime) | ✅ |  |  |  | Low | 0.5–1d |
| Data deletion flow (one-click delete all user data + keys) | ✅ |  |  |  | Low | 0.5–1d |
| Data export (user-controlled export; no sensitive logs) | ✅ |  |  |  | Low | 0.5–1d |
| Data minimization & retention policy (no hidden tracking) | ✅ |  |  |  | Low | 0.5–1d |
| No background biometric capture (foreground-only) | ✅ |  |  |  | Low | 0.25d |
| iCloud backup rules (documents only; NOT biometric templates; opt-in; encrypted) | ✅ |  |  |  | Medium | 1–2d |

---

## Current reality snapshot (from repo)
These are implemented in the current codebase (Android-first), and should be ported/replicated for iOS MVP:

| Component | Planned | In Progress | Testing | Done | Notes |
|---|:---:|:---:|:---:|:---:|---|
| Keystore-backed encryption (AES-GCM) |  |  |  | ✅ | Implemented (Android Keystore). |
| BiometricPrompt gate + session window |  |  |  | ✅ | Implemented (foreground prompt). |
| SecureStorage (encrypted files + backup/restore + rotation + wipe) |  |  |  | ✅ | Implemented (Android). |
| Document Scanner MVP (capture + OCR + barcode + store) |  |  | 🔄 | ✅ | Works; still has polish stubs. |
| Monitoring/recovery scripts (dev environment) |  |  |  | ✅ | Operational for dev workflow. |

---

## PHASE 1 (Weeks 1–4) — App Store MVP Core
**Goal:** A consumer “Document Vault” app that is compliant, privacy-safe, and useful without enterprise/government claims.

### Week 1 — Core security + compliance scaffolding
| Task | Planned | In Progress | Testing | Done | Depends on | App Store risk | Huifan coverage | Est |
|---|:---:|:---:|:---:|:---:|---|---|---|---|
| Privacy Gateway (in-app policy + accept/decline) | ✅ |  |  |  | UI shell | Low | N/A | 0.5–1d |
| Data Deletion Flow (one-click delete all user data) | ✅ |  |  |  | SecureStorage | Low | N/A | 0.5–1d |
| Biometric Consent (separate consent for iris/palm vein processing) | ✅ |  |  |  | Privacy Gateway | Low | Needs confirmation | 0.5–1d |
| Huifan Disclosure (clear notice in-app) | ✅ |  |  |  | Privacy Gateway | Low | Covered | 0.25–0.5d |
| No Background Processing policy (explicit) | ✅ |  |  |  | Compliance docs | Low | N/A | 0.25d |
| Security logging redaction policy | ✅ |  |  |  | Audit logger | Low | N/A | 0.5–1d |

### Week 2 — Vault core UX + biometric unlock (foreground only)
| Task | Planned | In Progress | Testing | Done | Depends on | App Store risk | Huifan coverage | Est |
|---|:---:|:---:|:---:|:---:|---|---|---|---|
| Vault lock/unlock UX (foreground BiometricPrompt / FaceID/TouchID equivalent) | ✅ |  |  |  | Core UI | Low | Covered (OS biometrics) | 1–2d |
| “VaultGuard Sentinel” (in-app only) policy engine MVP | ✅ |  |  |  | Vault lock | Low | N/A | 1–2d |
| Sensitive screen protection (in-app blur/redact, re-lock on background) | ✅ |  |  |  | Sentinel | Low | N/A | 1–2d |
| Audit trail (encrypted, tamper-evident) for vault actions | ✅ |  |  |  | SecureStorage | Low | N/A | 1d |

### Week 3 — Document Scanner polish (consumer-grade)
| Task | Planned | In Progress | Testing | Done | Depends on | App Store risk | Huifan coverage | Est |
|---|:---:|:---:|:---:|:---:|---|---|---|---|
| Scanner cropping/perspective correction | ✅ |  |  |  | Scanner MVP | Low | N/A | 1–2d |
| OCR confidence + field validation rules (passport/ID/tickets) | ✅ |  |  |  | OCR engine | Low | N/A | 1–2d |
| Document library UX (list/detail/search/type filter) | ✅ |  |  |  | SecureStorage | Low | N/A | 1–2d |
| Performance budgets (scan+OCR p50/p95) | ✅ |  |  |  | Scanner | Low | N/A | 1d |

### Week 4 — Quality gates + privacy review readiness
| Task | Planned | In Progress | Testing | Done | Depends on | App Store risk | Huifan coverage | Est |
|---|:---:|:---:|:---:|:---:|---|---|---|---|
| Threat model (consumer scope) + data retention policy | ✅ |  |  |  | Core compliance | Low | N/A | 0.5–1d |
| Automated tests (unit + device smoke) for security critical paths | ✅ |  |  |  | Keystore/SecureStorage | Low | N/A | 2–3d |
| App Store privacy “nutrition label” data mapping (internal doc) | ✅ |  |  |  | Privacy Gateway | Low | N/A | 0.5–1d |

---

## PHASE 2 (Weeks 5–8) — Monetization & Launch
**Goal:** Monetization (Apple-approved), subscription tiers, iCloud backup (encrypted) and App Store submission readiness.

### Monetization model (Apple-approved IAP)
Free Tier (App Store Download):
- 10 documents/month
- Basic encryption
- Fingerprint/FaceID (OS biometrics) unlock

Pro Tier: $4.99/month or $49.99/year
- Unlimited documents
- Advanced OCR + validation rules
- Optional encrypted iCloud backup (documents only)
- Faster scan pipeline + export

Family/Business: $9.99/month (3 users)
- All Pro features
- Secure sharing between trusted users (app-level sharing only)
- Shared folders

### Week 5 — Subscription plumbing (RevenueCat)
| Task | Planned | In Progress | Testing | Done | Depends on | App Store risk | Huifan coverage | Est |
|---|:---:|:---:|:---:|:---:|---|---|---|---|
| RevenueCat integration (entitlements, restore purchases) | ✅ |  |  |  | Core MVP stable | Low | N/A | 2–3d |
| Paywall UX + feature gating (10 docs/month, Pro unlocks) | ✅ |  |  |  | RevenueCat | Low | N/A | 1–2d |
| Trial/intro pricing rules + cancellation UX | ✅ |  |  |  | RevenueCat | Low | N/A | 1d |

### Week 6 — Encrypted iCloud Backup (documents only)
| Task | Planned | In Progress | Testing | Done | Depends on | App Store risk | Huifan coverage | Est |
|---|:---:|:---:|:---:|:---:|---|---|---|---|
| Encrypted iCloud backup for documents (NOT biometric templates) | ✅ |  |  |  | SecureStorage | Medium | N/A | 2–4d |
| Backup consent + encryption key handling disclosure | ✅ |  |  |  | Privacy Gateway | Medium | N/A | 1–2d |
| Backup/restore validation (round-trip) | ✅ |  |  |  | Backup feature | Medium | N/A | 1–2d |

### Week 7 — Sharing feature refactor (consumer-friendly)
| Task | Planned | In Progress | Testing | Done | Depends on | App Store risk | Huifan coverage | Est |
|---|:---:|:---:|:---:|:---:|---|---|---|---|
| “Document Vault Pro” (refactor from Financial Module) | ✅ |  |  |  | Pro gating | Low | N/A | 1–2d |
| “Family/Business Sharing” (refactor from Enterprise Module) | ✅ |  |  |  | Pro gating | Medium | N/A | 2–4d |
| Remove “Government Verification” entirely | ✅ |  |  |  | Roadmap hygiene | Low | N/A | 0.25d |

### Week 8 — App Store submission & launch prep
| Task | Planned | In Progress | Testing | Done | Depends on | App Store risk | Huifan coverage | Est |
|---|:---:|:---:|:---:|:---:|---|---|---|---|
| App Store metadata + screenshots + preview video plan | ✅ |  |  |  | Feature complete | Low | N/A | 1–2d |
| EULA/Privacy policy links + in-app access | ✅ |  |  |  | Privacy Gateway | Low | N/A | 0.5–1d |
| App Review checklist run + fixes | ✅ |  |  |  | All above | Low | N/A | 1–2d |
| Launch monitoring (crash/perf) + rollback plan | ✅ |  |  |  | Release pipeline | Low | N/A | 1–2d |

---

## PHASE 3+ — Future Enterprise Features (deferred)
These are explicitly moved out of the 8-week App Store MVP.

### Deferred / refactored items
- Financial Security Module (4.2.1) → **Document Vault Pro** (kept consumer-safe)
- Enterprise Access Module (4.2.2) → **Family/Business Sharing** (consumer-safe, app-level)
- Government Verification (4.2.3) → **REMOVED**
- Cloud Integration (4.3) → **Encrypted iCloud Backup** (documents only; excludes biometric templates)

### Not in MVP (enterprise/government risk)
- Operator/turnstile workflows
- Government/elections verification
- Any device-wide control, surveillance, background camera usage

---

## Dependency map (must come before what)
- Privacy Gateway → Biometric Consent → Huifan Disclosure
- SecureStorage + Keystore → Data Deletion Flow + Audit Logger
- Vault lock/unlock UX → Sentinel policy engine → Sensitive screen protection
- Stable MVP + tests → RevenueCat monetization → iCloud backup
- Pro gating → Sharing features

---

## App Store risk assessment rubric (per feature)
- **Low**: standard UI, standard OS biometrics, local encryption, clear consent, no background capture
- **Medium**: cloud backup, sharing, anything touching “biometric templates” or unclear consent
- **High**: background camera/mic, covert biometrics, surveillance, device-wide control/MDM, government verification claims

---

## Backup & tracking protocol (mandatory)
- Before major roadmap edits: create `ROADMAP_PRE_REVISION_<timestamp>.md`
- Before/after each subpoint implementation: run `scripts/backup_after_subpoint.ps1`
- Use progress columns `[Planned] [In Progress] [Testing] [Done]` on tasks above

---

## App Store review checklist (must pass)
- No background camera/mic capture; no covert biometrics
- Explicit user consent for any biometric processing (iris/palm vein)
- Privacy policy accessible in-app; accept/decline gate
- One-click delete all user data; clear retention policy
- iCloud backup: encrypted, **documents only**, explicitly excludes biometric templates
- No government verification claims; consumer positioning only
- Subscriptions via Apple IAP (RevenueCat ok), restore purchases works
- Clear disclosures: Huifan technology notice (where applicable)

