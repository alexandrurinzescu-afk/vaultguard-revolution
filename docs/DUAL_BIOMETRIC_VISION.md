# Dual Biometric Vision (Iris + Palmvein)

Last updated: 2026-01-09

## Purpose
VaultGuardRevolution targets a security posture where **two independent biometric modalities** can be used:
- **Iris** (high entropy, strong identity signal)
- **Palmvein** (vascular pattern, robust vs superficial artifacts)

The roadmap introduces a **dual-biometric** approach to reduce fraud risk, improve reliability, and support enterprise deployments.

## High-level goals
- **Dual modality support**: iris-only, palmvein-only, and dual mode.
- **Risk-based policies**: select modality/fusion strategy based on context (device, confidence, threat level).
- **Secure by default**: templates are always encrypted at rest via Android Keystore (AES-GCM).
- **Operational readiness**: enterprise logging/telemetry must be sanitized (no biometric payloads).

## Operating modes
1. **Iris-only (mobile camera / iris device)**
   - Primary for consumer + fallback.
2. **Palmvein-only (vendor device)**
   - Used when iris capture is degraded or unavailable.
3. **Dual (iris + palmvein)**
   - Strongest assurance mode for high-risk operations.

## Fusion strategy (initial)
This is a roadmap-level proposal; it becomes a concrete design during implementation.
- **Decision fusion (AND/OR)**:
  - AND for high assurance (both must pass).
  - OR for availability (either passes) with stricter thresholds and monitoring.
- **Score-level fusion** (optional):
  - Normalize scores, apply weighting, compute combined confidence.

## Data and security principles
- **No raw images persisted** unless explicitly required for debugging with strict safeguards.
- **Templates + metadata only**:
  - `template_bytes` (encrypted)
  - `modality` (iris / palmvein)
  - `created_at`, `device_id`, `sdk_version`, `quality_score`, `thresholds_used`
- **Encryption**:
  - Android Keystore-protected AES-GCM keys.
  - Rotation + re-enrollment strategy planned in roadmap.
- **Logging**:
  - Log only event IDs + metrics (latency, quality score), never template bytes.

## Architecture sketch (conceptual)
- **Capture layer**: per-modality SDK adapters (iris adapter, palmvein adapter)
- **Quality layer**: per-modality quality scoring + user feedback
- **Template layer**: extract templates, version them, validate format
- **Match layer**: 1:1 matching with configurable thresholds
- **Orchestration**: session state machine + fusion policy engine
- **Storage**: encrypted persistence + key management (Keystore)

## Known constraints / open items
- Palmvein SDK availability is currently a blocker until binaries + docs are obtained.
- ABI/transport differences across devices/vendors must be validated early.
- Threat model needs updating for:
  - presentation attacks
  - device compromise
  - template replay / downgrade attacks

## Immediate next steps (from roadmap)
- Stabilize `KeystoreManager` and secure storage primitives.
- Integrate iris SDK capture/template/match end-to-end.
- Acquire palmvein SDK and repeat the same integration pipeline.
- Implement dual orchestration + policy/fusion.

