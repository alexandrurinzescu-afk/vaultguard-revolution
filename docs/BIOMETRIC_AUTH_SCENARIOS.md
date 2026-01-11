# VaultGuard Revolution - Biometric Authentication Scenarios (Complete)

This is the canonical list of biometric authentication scenarios and expected behavior.
It is written to support phone biometrics (BiometricPrompt) and future Huifan devices.

---

## Definitions
- **Gate**: a required authentication step before a protected action.
- **Session window**: time period during which we can skip repeated prompts (e.g., 30s).
- **Fallback**: device credential (PIN/pattern/password) where allowed.

---

## A) Enrollment scenarios
1) **No biometrics enrolled**
   - Behavior: show instructions + deep-link to OS enrollment.
2) **Multiple biometrics enrolled**
   - Behavior: allow OS to choose; treat as BIOMETRIC_STRONG when available.
3) **Biometric changes after enrollment**
   - Behavior: keys that require auth may become invalid; require re-enrollment.

---

## B) Authentication scenarios (normal)
1) **Success**
   - Set session window; proceed with action.
2) **Failed match**
   - Show "Try again" UX; do not set session.
3) **Cancelled by user**
   - Treat as cancelled; do not set session.
4) **Timeout**
   - Allow retry; do not set session.

---

## C) Error codes (BiometricPrompt)
1) **ERROR_NO_BIOMETRICS**
   - Show OS enrollment steps.
2) **ERROR_HW_NOT_PRESENT**
   - Disable biometric-only flows; use device credential where possible.
3) **ERROR_HW_UNAVAILABLE**
   - Retry later; show temporary-unavailable message.
4) **ERROR_LOCKOUT / ERROR_LOCKOUT_PERMANENT**
   - Require device credential fallback, then allow biometrics again.

---

## D) Security and privacy scenarios
1) **Screenshot / screen recording**
   - Sensitive screens must use FLAG_SECURE.
2) **Background / task switch**
   - If app goes background, consider clearing session depending on risk level.
3) **Offline mode**
   - Gate must work offline (OS prompt is local).

---

## E) Keystore integration scenarios
1) **Key requires auth, session valid**
   - Skip prompt, proceed.
2) **Key requires auth, session expired**
   - Prompt, then proceed.
3) **Auth changes invalidate keys**
   - Detect failures and re-generate keys + re-enroll data where necessary.

---

## F) Multi-modal scenarios (future)
1) **Face + fingerprint**
   - Use OS strongest available.
2) **Iris + palm vein fusion**
   - Orchestrator must enforce ordered checks and confidence scoring.
3) **Fallback ordering**
   - Device credential is last resort depending on the use-case.

---

## G) High-risk use cases
1) **Ticket validation at turnstile**
   - Fast path; minimize retries; support offline verification.
2) **Police verification**
   - Strong audit logging + strict policy; redaction required.
3) **Payment authorization**
   - Must be compliant; avoid storing sensitive payment data.

