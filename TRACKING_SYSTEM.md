# TRACKING SYSTEM — VaultGuard Revolution

**Goal:** Make progress measurable and prevent regressions.  
**Rule:** If it’s not tracked, it didn’t happen.

---

## Daily progress tracking (template)

Create a new file each day in `reports/daily/` named `YYYY-MM-DD.md`:

### Context
- Date:
- Active phase:
- Current milestone:
- Blockers:

### Work completed (today)
- [ ] Item
- [ ] Item

### Evidence (required)
- Build artifacts:
  - `:app:assembleDebug` ✅/❌
  - `:app:assembleRelease` ✅/❌
- Tests:
  - Unit tests ✅/❌
  - Instrumented smoke ✅/❌
- Coverage:
  - Overall %:
  - Critical paths %:
- Performance:
  - Camera startup p50/p95:
  - Scan+OCR p50/p95:

### Risks / next 24h plan
- Risks:
- Next:

---

## Automated build status monitoring

This repo already includes monitoring scripts in `monitoring/` and automation helpers in `scripts/`.

### Recommended schedule
- Every **4 hours**: run a full “health check” build + short test suite.
- On failure: automatically run recovery script and re-check.

### Outputs
- Build time metrics appended to `reports/build_metrics.csv`
- Failures appended to `reports/build_failures.log`

---

## Test coverage requirements

### Minimum targets (enforced as a gate)
- **80%+ overall** (unit + instrumented combined)
- **90%+** for:
  - `SecureStorage` encryption/decryption + migration/rotation
  - biometric rate limiting + self-destruct wipe
  - audit log integrity verification

### Critical test types
- Unit tests: field extraction parsing, audit hash chain verification, rate limiter/backoff
- Instrumented tests: encrypt/decrypt round-trip on device, wipe behavior

---

## Quality gates definition (pass/fail)

### Gate A — Build
- `:app:assembleDebug` ✅
- `:app:assembleRelease` ✅ (R8 enabled)

### Gate B — Tests
- Unit tests ✅
- Instrumented smoke ✅
- No flaky tests (must pass twice consecutively)

### Gate C — Security
- SecureStorage migration does not lose data
- Rotation re-encrypts and old blobs remain readable
- Rate limiting triggers and self-destruct wipes correctly
- Root/debugger policy executes as configured

### Gate D — Performance
- Camera startup <2s (p50)
- Scan+OCR <2s (p50), <3s (p95) on target device
- No memory leaks in batch scanning scenario

---## Guardian Angel Module tracking (Phase 2)### Metrics to log per build (targets)
- **False Positive Rate**: < 0.1%
- **Verification latency**: < 500ms
- **Battery impact**: < 1% / day
- **Adoption/onboarding friction**: qualitative + drop-off %

### Evidence (required)
- Device test logs (at least 2 devices)
- Battery benchmark run
- False-positive evaluation run (scripted scenarios)